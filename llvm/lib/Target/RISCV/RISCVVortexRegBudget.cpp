//===- RISCVVortexRegBudget.cpp - Vortex registers per thread -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Gives every function the number of registers per thread it may allocate,
// as the "vortex-max-regs" attribute. A warp holds its registers in one
// partition of the core's register file for as long as it runs, so the count
// decides how many warps can be resident. A kernel annotated
// `vortex.launch_bounds` (threads per block, minimum resident blocks per
// core) gets the most registers that still keep those blocks resident, as
// CUDA's __launch_bounds__ does. Other code keeps half of each partition's
// warps resident. A function takes the smallest count among the kernels that
// call it, since its registers count toward theirs.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVSubtarget.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Target/TargetMachine.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-vortex-reg-budget"
#define PASS_NAME "RISC-V Vortex registers per thread"

static cl::opt<unsigned> GprRows(
    "riscv-vortex-gpr-rows", cl::Hidden, cl::init(0),
    cl::desc("Register-file rows per partition (0 = registers per thread "
             "are not chosen for occupancy)"));
static cl::opt<unsigned> RegParts(
    "riscv-vortex-reg-parts", cl::Hidden, cl::init(1),
    cl::desc("Register-file partitions per core"));
static cl::opt<unsigned> NumWarps("riscv-vortex-num-warps", cl::Hidden,
                                  cl::init(4), cl::desc("Warps per core"));
static cl::opt<unsigned> WarpSize("riscv-vortex-warp-size", cl::Hidden,
                                  cl::init(4), cl::desc("Threads per warp"));
static cl::opt<unsigned> RegBudget(
    "riscv-vortex-reg-budget", cl::Hidden, cl::init(0),
    cl::desc("Registers per thread for code without launch bounds, a "
             "multiple of 8 (0 = keep half of a partition's warps resident)"));

namespace {

class RISCVVortexRegBudget : public ModulePass {
public:
  static char ID;
  RISCVVortexRegBudget() : ModulePass(ID) {}
  bool runOnModule(Module &M) override;
  StringRef getPassName() const override { return PASS_NAME; }
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<TargetPassConfig>();
    AU.setPreservesCFG();
  }
};

struct Kernel {
  unsigned Threads = 0, Blocks = 0; // launch bounds; 0 threads = none
};

} // end anonymous namespace

// Collects functions annotated vortex.kernel, with the launch bounds of those
// annotated vortex.launch_bounds.
static void findKernels(Module &M, MapVector<Function *, Kernel> &Kernels) {
  const GlobalVariable *GA = M.getGlobalVariable("llvm.global.annotations");
  if (!GA || !GA->hasInitializer())
    return;
  const auto *CA = dyn_cast<ConstantArray>(GA->getInitializer());
  if (!CA)
    return;
  for (const Value *Op : CA->operands()) {
    const auto *CS = dyn_cast<ConstantStruct>(Op);
    if (!CS || CS->getNumOperands() < 2)
      continue;
    auto *F = dyn_cast<Function>(CS->getOperand(0)->stripPointerCasts());
    const auto *StrGV =
        dyn_cast<GlobalVariable>(CS->getOperand(1)->stripPointerCasts());
    if (!F || !StrGV || !StrGV->hasInitializer())
      continue;
    const auto *Str = dyn_cast<ConstantDataArray>(StrGV->getInitializer());
    if (!Str || !Str->isCString())
      continue;
    StringRef Name = Str->getAsCString();
    if (Name == "vortex.kernel") {
      Kernels[F];
      continue;
    }
    if (Name != "vortex.launch_bounds")
      continue;
    SmallVector<unsigned, 2> Args;
    if (CS->getNumOperands() > 4)
      if (const auto *ArgGV =
              dyn_cast<GlobalVariable>(CS->getOperand(4)->stripPointerCasts()))
        if (const auto *AS =
                dyn_cast_or_null<ConstantStruct>(ArgGV->getInitializer()))
          for (const Value *A : AS->operands())
            if (const auto *CI = dyn_cast<ConstantInt>(A))
              Args.push_back(CI->getZExtValue());
    if (Args.empty() || Args[0] == 0) {
      M.getContext().diagnose(DiagnosticInfoGeneric(
          "vortex.launch_bounds on " + F->getName() +
          " needs the threads per block, then optionally the blocks per core"));
      continue;
    }
    Kernel &K = Kernels[F];
    K.Threads = Args[0];
    K.Blocks = Args.size() > 1 && Args[1] ? Args[1] : 1;
  }
}

// The most registers per thread, a multiple of 8, with which each partition
// holds Warps warps; Spare is the rows each warp also needs for f registers.
static unsigned regsFor(unsigned Warps, unsigned Spare, unsigned Ceiling,
                        bool &Fits) {
  unsigned Rows = GprRows / std::max(Warps, 1u);
  unsigned R = Rows > Spare ? (Rows - Spare) / 8 * 8 : 0;
  Fits = R >= 32;
  return std::clamp(R, 32u, Ceiling);
}

bool RISCVVortexRegBudget::runOnModule(Module &M) {
  unsigned Ceiling = RISCV::getVortexMaxRegs();
  if (Ceiling <= 32)
    return false;
  if (RegBudget && (RegBudget < 32 || RegBudget > 256 || RegBudget % 8))
    report_fatal_error(
        "-riscv-vortex-reg-budget must be a multiple of 8 from 32 to 256");

  const TargetMachine &TM =
      getAnalysis<TargetPassConfig>().getTM<TargetMachine>();
  auto spareRows = [&](const Function &F) -> unsigned {
    const auto &ST = TM.getSubtarget<RISCVSubtarget>(F);
    return ST.hasStdExtF() && !ST.hasStdExtZfinx() ? 32 : 0;
  };
  unsigned Parts = std::max<unsigned>(RegParts, 1);
  unsigned Slots = std::max(NumWarps / Parts, 1u);

  auto defaultRegs = [&](const Function &F) -> unsigned {
    if (RegBudget)
      return std::min<unsigned>(RegBudget, Ceiling);
    if (!GprRows)
      return Ceiling;
    bool Fits;
    return regsFor(std::max(Slots / 2, 1u), spareRows(F), Ceiling, Fits);
  };

  MapVector<Function *, Kernel> Kernels;
  findKernels(M, Kernels);

  DenseMap<Function *, unsigned> Regs;
  for (auto &[F, K] : Kernels) {
    unsigned R = defaultRegs(*F);
    if (K.Threads && GprRows) {
      unsigned CtaWarps = (K.Threads + WarpSize - 1) / WarpSize;
      unsigned Blocks = K.Blocks;
      if (CtaWarps * Blocks > NumWarps) {
        unsigned Most = NumWarps / std::max(CtaWarps, 1u);
        M.getContext().diagnose(DiagnosticInfoGeneric(
            Twine("launch bounds of ") + F->getName() + " ask for " +
                Twine(Blocks) + " resident blocks of " + Twine(CtaWarps) +
                " warps, but a core has " + Twine(NumWarps) + " warps",
            DS_Warning));
        Blocks = std::max(Most, 1u);
      }
      unsigned Warps = (CtaWarps * Blocks + Parts - 1) / Parts;
      bool Fits;
      R = regsFor(Warps, spareRows(*F), Ceiling, Fits);
      if (!Fits)
        M.getContext().diagnose(DiagnosticInfoGeneric(
            Twine("launch bounds of ") + F->getName() +
                " leave fewer than 32 registers per thread; using 32",
            DS_Warning));
    }
    // Every function the kernel reaches counts toward its registers.
    SmallVector<Function *, 16> Work{F};
    while (!Work.empty()) {
      Function *G = Work.pop_back_val();
      auto [It, New] = Regs.try_emplace(G, R);
      if (!New) {
        if (It->second <= R)
          continue;
        It->second = R;
      }
      for (Instruction &I : instructions(*G))
        if (auto *CB = dyn_cast<CallBase>(&I))
          if (Function *C = CB->getCalledFunction())
            if (!C->isDeclaration())
              Work.push_back(C);
    }
  }

  bool Changed = false;
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    auto It = Regs.find(&F);
    unsigned R = It != Regs.end() ? It->second : defaultRegs(F);
    F.addFnAttr("vortex-max-regs", utostr(R));
    Changed = true;
  }
  return Changed;
}

INITIALIZE_PASS_BEGIN(RISCVVortexRegBudget, DEBUG_TYPE, PASS_NAME, false, false)
INITIALIZE_PASS_DEPENDENCY(TargetPassConfig)
INITIALIZE_PASS_END(RISCVVortexRegBudget, DEBUG_TYPE, PASS_NAME, false, false)

char RISCVVortexRegBudget::ID = 0;

ModulePass *llvm::createRISCVVortexRegBudgetPass() {
  return new RISCVVortexRegBudget();
}
