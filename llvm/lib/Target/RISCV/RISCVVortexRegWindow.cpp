//===-- RISCVVortexRegWindow.cpp - Place Vortex register-window writes ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Vortex register windows give each instruction field (rd, rs1, rs2, rs3) a
// 3-bit window: the register a field names is (window << 5) | field. Register
// allocation sees x0..x(N-1); this pass inserts VX_RWIN so that, at every
// instruction, each field's window equals the block of the register encoded in
// it. x0 needs no window: it is the zero register in every window.
//
// The window state is zero at function entry, calls, returns, traps and around
// divergence (vx_split/vx_join/vx_pred/vx_tmc), and at inline asm.
//
// Within a block the placement is exact (dynamic programming over the window
// states). Across blocks a forward dataflow fixes each block's entry state;
// a block whose predecessors disagree starts from an unknown state. A block
// with a single successor prefers to end in the state its successor wants, so
// loop bodies close in the state the loop header needs and the switch into
// that state lands in the preheader.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVSubtarget.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/ScheduleDAGInstrs.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Target/TargetMachine.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-vortex-reg-window"
#define PASS_NAME "RISC-V Vortex register window placement"

STATISTIC(NumRwin, "Number of vx_rwin instructions inserted");

static cl::opt<bool> EnableReorder(
    "riscv-vortex-rwin-reorder", cl::Hidden, cl::init(true),
    cl::desc("Reorder independent instructions so consecutive ones share "
             "register windows"));

namespace {

constexpr unsigned NumFields = 4; // rd, rs1, rs2, rs3
constexpr int8_t AnyWin = -1;
constexpr uint32_t Inf = UINT32_MAX / 2;

struct Req {
  int8_t W[NumFields] = {AnyWin, AnyWin, AnyWin, AnyWin};
  bool any() const {
    for (auto W : this->W)
      if (W != AnyWin)
        return false;
    return true;
  }
};

// Dependence graph of a region, built post-RA; the pass orders it itself.
class WindowDAG : public ScheduleDAGInstrs {
public:
  WindowDAG(MachineFunction &MF)
      : ScheduleDAGInstrs(MF, nullptr, /*RemoveKillFlags=*/true) {}
  void schedule() override {}
};

class RISCVVortexRegWindow : public MachineFunctionPass {
public:
  static char ID;
  RISCVVortexRegWindow() : MachineFunctionPass(ID) {}

  bool runOnMachineFunction(MachineFunction &MF) override;
  StringRef getPassName() const override { return PASS_NAME; }
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

private:
  // Per-block placement for a given entry state and preferred exit state.
  struct Plan {
    uint32_t Cost = 0;
    unsigned Exit = 0;
    unsigned Want = 0; // state at the first constrained instruction, or NS
    SmallVector<std::pair<MachineInstr *, unsigned>, 4> Inserts;
  };

  const RISCVInstrInfo *TII = nullptr;
  const TargetRegisterInfo *TRI = nullptr;
  const MCSubtargetInfo *STI = nullptr;
  std::unique_ptr<MCCodeEmitter> CE;
  DenseMap<unsigned, SmallVector<int8_t, 8>> FieldCache;
  unsigned NB = 1; // windows per field
  unsigned NS = 1; // window states; NS also stands for "unknown"

  unsigned field(unsigned S, unsigned F) const {
    for (unsigned I = 0; I < F; ++I)
      S /= NB;
    return S % NB;
  }
  bool satisfies(unsigned S, const Req &R) const {
    if (S == NS)
      return R.any();
    for (unsigned F = 0; F < NumFields; ++F)
      if (R.W[F] != AnyWin && field(S, F) != unsigned(R.W[F]))
        return false;
    return true;
  }

  const SmallVector<int8_t, 8> &operandFields(const MachineInstr &MI);
  Req requirement(MachineInstr &MI);
  Plan planBlock(const SmallVectorImpl<std::pair<MachineInstr *, Req>> &Reqs,
                 unsigned Entry, unsigned Target) const;
  bool isRegionBoundary(const MachineInstr &MI) const;
  void reorderBlock(MachineBasicBlock &MBB, WindowDAG &DAG);
};

} // end anonymous namespace

char RISCVVortexRegWindow::ID = 0;

INITIALIZE_PASS(RISCVVortexRegWindow, DEBUG_TYPE, PASS_NAME, false, false)

FunctionPass *llvm::createRISCVVortexRegWindowPass() {
  return new RISCVVortexRegWindow();
}

// Field (0..3 for rd, rs1, rs2, rs3, or -1) of each operand of MI's opcode,
// found by encoding the instruction twice with distinct probe registers.
const SmallVector<int8_t, 8> &
RISCVVortexRegWindow::operandFields(const MachineInstr &MI) {
  auto It = FieldCache.find(MI.getOpcode());
  if (It != FieldCache.end())
    return It->second;

  SmallVector<int8_t, 8> Fields(MI.getNumOperands(), -1);
  uint32_t Enc[2] = {0, 0};
  SmallVector<unsigned, 8> Probe(MI.getNumOperands(), 0);
  bool OK = true;
  for (unsigned Pass = 0; Pass < 2 && OK; ++Pass) {
    MCInst Inst;
    Inst.setOpcode(MI.getOpcode());
    unsigned K = 0;
    for (unsigned I = 0, E = MI.getNumOperands(); I < E; ++I) {
      const MachineOperand &MO = MI.getOperand(I);
      if (MO.isReg() && MO.isImplicit())
        continue;
      if (MO.isReg()) {
        unsigned V = (Pass == 0) ? (K + 1) : (K + 17);
        if (V > 31) {
          OK = false;
          break;
        }
        Probe[I] = K + 1;
        Inst.addOperand(MCOperand::createReg(RISCV::X0 + V));
        ++K;
      } else {
        Inst.addOperand(MCOperand::createImm(0));
      }
    }
    if (!OK)
      break;
    SmallVector<char, 8> CB;
    SmallVector<MCFixup, 4> Fixups;
    CE->encodeInstruction(Inst, CB, Fixups, *STI);
    if (CB.size() != 4) {
      OK = false;
      break;
    }
    Enc[Pass] = uint32_t(uint8_t(CB[0])) | (uint32_t(uint8_t(CB[1])) << 8) |
                (uint32_t(uint8_t(CB[2])) << 16) |
                (uint32_t(uint8_t(CB[3])) << 24);
  }

  if (OK) {
    static const unsigned Shift[NumFields] = {7, 15, 20, 27};
    for (unsigned I = 0, E = MI.getNumOperands(); I < E; ++I) {
      if (!Probe[I])
        continue;
      for (unsigned F = 0; F < NumFields; ++F) {
        if (((Enc[0] >> Shift[F]) & 31) == Probe[I] &&
            ((Enc[1] >> Shift[F]) & 31) == Probe[I] + 16) {
          Fields[I] = F;
          break;
        }
      }
    }
  } else {
    // Not a plain 32-bit encoding: its operands must stay in window 0.
    Fields.assign(MI.getNumOperands(), -2);
  }
  return FieldCache.try_emplace(MI.getOpcode(), std::move(Fields))
      .first->second;
}

static bool isZeroReg(Register Reg) {
  return Reg == RISCV::X0 || Reg == RISCV::X0_W || Reg == RISCV::X0_H;
}

Req RISCVVortexRegWindow::requirement(MachineInstr &MI) {
  Req R;
  if (MI.isMetaInstruction())
    return R;
  Req Zero;
  for (auto &W : Zero.W)
    W = 0;

  switch (MI.getOpcode()) {
  case RISCV::ECALL:
  case RISCV::EBREAK:
  case RISCV::VX_SPLIT:
  case RISCV::VX_SPLIT_N:
  case RISCV::VX_JOIN:
  case RISCV::VX_PRED:
  case RISCV::VX_PRED_N:
  case RISCV::VX_TMC:
    for (const MachineOperand &MO : MI.explicit_operands())
      if (MO.isReg() && MO.getReg() &&
          TRI->getEncodingValue(MO.getReg()) >= 32)
        report_fatal_error("vortex register windows: " +
                           TII->getName(MI.getOpcode()) +
                           " names a register above x31");
    return Zero;
  default:
    break;
  }
  if (MI.isInlineAsm() || MI.isCall() || MI.isReturn())
    return Zero;

  bool HasReg = false;
  for (const MachineOperand &MO : MI.explicit_operands())
    if (MO.isReg() && MO.getReg() && !isZeroReg(MO.getReg()))
      HasReg = true;
  if (!HasReg)
    return R;

  if (MI.getDesc().isPseudo()) {
    for (const MachineOperand &MO : MI.explicit_operands())
      if (MO.isReg() && MO.getReg() &&
          TRI->getEncodingValue(MO.getReg()) >= 32)
        report_fatal_error("vortex register windows: pseudo " +
                           TII->getName(MI.getOpcode()) +
                           " names a register above x31");
    return Zero;
  }

  const auto &Fields = operandFields(MI);
  for (unsigned I = 0, E = MI.getNumOperands(); I < E; ++I) {
    const MachineOperand &MO = MI.getOperand(I);
    if (!MO.isReg() || MO.isImplicit() || !MO.getReg())
      continue;
    int F = Fields[I];
    unsigned Win = TRI->getEncodingValue(MO.getReg()) >> 5;
    if (F == -2 || F == -1) {
      if (Win != 0)
        report_fatal_error("vortex register windows: " +
                           TII->getName(MI.getOpcode()) +
                           " cannot name a register above x31");
      if (F == -2)
        return Zero;
      continue;
    }
    if (isZeroReg(MO.getReg()))
      continue;
    if (R.W[F] != AnyWin && R.W[F] != int8_t(Win))
      report_fatal_error("vortex register windows: " +
                         TII->getName(MI.getOpcode()) +
                         " needs two windows in one field");
    R.W[F] = Win;
  }
  return R;
}

// Exact per-block placement: Cost[s] is the fewest vx_rwin that reach the
// current instruction in state s with every earlier requirement met.
RISCVVortexRegWindow::Plan RISCVVortexRegWindow::planBlock(
    const SmallVectorImpl<std::pair<MachineInstr *, Req>> &Reqs,
    unsigned Entry, unsigned Target) const {
  const unsigned N = Reqs.size();
  std::vector<uint32_t> Cost(NS + 1, Inf), Next(NS + 1);
  Cost[Entry] = 0;
  // Switched[i][s]: state s at instruction i was set by a vx_rwin before it.
  std::vector<std::vector<bool>> Switched(N, std::vector<bool>(NS + 1));
  std::vector<unsigned> BestBefore(N);

  for (unsigned I = 0; I < N; ++I) {
    const Req &R = Reqs[I].second;
    unsigned Best = 0;
    for (unsigned S = 1; S <= NS; ++S)
      if (Cost[S] < Cost[Best])
        Best = S;
    BestBefore[I] = Best;
    for (unsigned S = 0; S <= NS; ++S) {
      Next[S] = Inf;
      if (!satisfies(S, R))
        continue;
      uint32_t Keep = Cost[S];
      uint32_t Switch = (S == NS || R.any()) ? Inf : Cost[Best] + 1;
      if (Keep <= Switch) {
        Next[S] = Keep;
      } else {
        Next[S] = Switch;
        Switched[I][S] = true;
      }
    }
    Cost.swap(Next);
  }

  Plan P;
  unsigned Exit = 0;
  uint32_t ExitCost = Inf;
  for (unsigned S = 0; S <= NS; ++S) {
    if (Cost[S] >= Inf)
      continue;
    uint32_t C = Cost[S] + ((Target != NS && S != Target) ? 1 : 0);
    if (C < ExitCost || (C == ExitCost && S == Target)) {
      ExitCost = C;
      Exit = S;
    }
  }
  assert(ExitCost < Inf && "no feasible window placement");
  P.Exit = Exit;
  P.Cost = Cost[Exit];
  P.Want = NS;

  unsigned S = Exit;
  for (unsigned I = N; I-- > 0;) {
    if (!Reqs[I].second.any())
      P.Want = S;
    if (Switched[I][S]) {
      P.Inserts.push_back({Reqs[I].first, S});
      S = BestBefore[I];
    }
  }
  std::reverse(P.Inserts.begin(), P.Inserts.end());
  return P;
}

bool RISCVVortexRegWindow::isRegionBoundary(const MachineInstr &MI) const {
  const MachineBasicBlock *MBB = MI.getParent();
  if (MI.isDebugInstr() || MI.isCall() || MI.isInlineAsm() ||
      TII->isSchedulingBoundary(MI, MBB, *MBB->getParent()))
    return true;
  Req R = const_cast<RISCVVortexRegWindow *>(this)->requirement(
      const_cast<MachineInstr &>(MI));
  bool AllZero = true;
  for (auto W : R.W)
    AllZero &= (W == 0);
  return AllZero;
}

// Post-RA list scheduling of each region (no reordering across calls,
// divergence or other window-zero points): among the instructions whose
// dependences are met, take the earliest one the current windows already
// satisfy, else the earliest one. A phase whose operands span several blocks
// then switches once per block instead of once per element.
void RISCVVortexRegWindow::reorderBlock(MachineBasicBlock &MBB,
                                        WindowDAG &DAG) {
  for (auto I = MBB.begin(), E = MBB.end(); I != E;) {
    if (isRegionBoundary(*I)) {
      ++I;
      continue;
    }
    auto Begin = I;
    unsigned N = 0;
    while (I != E && !isRegionBoundary(*I)) {
      ++I;
      ++N;
    }
    auto End = I;
    if (N < 3)
      continue;

    DAG.startBlock(&MBB);
    DAG.enterRegion(&MBB, Begin, End, N);
    DAG.buildSchedGraph(nullptr);
    const unsigned NU = DAG.SUnits.size();
    std::vector<Req> R(NU);
    std::vector<unsigned> Preds(NU, 0);
    for (SUnit &SU : DAG.SUnits) {
      R[SU.NodeNum] = requirement(*SU.getInstr());
      for (const SDep &D : SU.Preds)
        if (D.getSUnit()->NodeNum < NU)
          ++Preds[SU.NodeNum];
    }
    SmallVector<unsigned, 32> Ready;
    for (unsigned U = 0; U < NU; ++U)
      if (!Preds[U])
        Ready.push_back(U);
    int8_t Cur[NumFields] = {AnyWin, AnyWin, AnyWin, AnyWin};
    SmallVector<MachineInstr *, 64> Order;
    while (!Ready.empty()) {
      unsigned BestIdx = 0;
      bool BestFits = false;
      for (unsigned K = 0; K < Ready.size(); ++K) {
        const Req &Q = R[Ready[K]];
        bool Fits = true;
        for (unsigned F = 0; F < NumFields; ++F)
          Fits &= Q.W[F] == AnyWin || Cur[F] == AnyWin || Q.W[F] == Cur[F];
        if ((Fits && !BestFits) ||
            (Fits == BestFits && Ready[K] < Ready[BestIdx])) {
          BestIdx = K;
          BestFits = Fits;
        }
      }
      unsigned U = Ready[BestIdx];
      Ready.erase(Ready.begin() + BestIdx);
      for (unsigned F = 0; F < NumFields; ++F)
        if (R[U].W[F] != AnyWin)
          Cur[F] = R[U].W[F];
      SUnit &SU = DAG.SUnits[U];
      Order.push_back(SU.getInstr());
      for (const SDep &D : SU.Succs) {
        unsigned S = D.getSUnit()->NodeNum;
        if (S < NU && --Preds[S] == 0)
          Ready.push_back(S);
      }
    }
    DAG.exitRegion();
    DAG.finishBlock();
    assert(Order.size() == N && "region not fully scheduled");
    for (MachineInstr *MI : Order)
      MBB.splice(End, &MBB, MI->getIterator());
  }
}

bool RISCVVortexRegWindow::runOnMachineFunction(MachineFunction &MF) {
  unsigned MaxRegs = RISCV::getVortexMaxRegs();
  if (MaxRegs <= 32 || skipFunction(MF.getFunction()))
    return false;

  const auto &ST = MF.getSubtarget<RISCVSubtarget>();
  TII = ST.getInstrInfo();
  TRI = ST.getRegisterInfo();
  STI = &ST;
  CE.reset(MF.getTarget().getTarget().createMCCodeEmitter(
      *MF.getTarget().getMCInstrInfo(), MF.getContext()));
  FieldCache.clear();
  NB = MaxRegs / 32;
  NS = NB * NB * NB * NB;

  // Study modes modelling 64-bit encodings: a one-instruction prefix carries
  // the windows of the instruction after it (mode 1: only where needed; mode
  // 2: on every instruction), and the sticky windows stay zero.
  if (unsigned Mode = RISCV::getVortexRwinMode()) {
    bool Modified = false;
    for (auto &MBB : MF) {
      for (auto &MI : make_early_inc_range(MBB)) {
        if (MI.isMetaInstruction() || MI.getOpcode() == RISCV::VX_RPFX)
          continue;
        // nothing may split a block's terminators (a later jump has no
        // register operand to window)
        if (MI.isTerminator() && MI.getIterator() != MBB.getFirstTerminator())
          continue;
        Req R = requirement(MI);
        bool Needed = false;
        for (auto W : R.W)
          Needed |= W > 0;
        if (!Needed && Mode == 1)
          continue;
        auto B = BuildMI(MBB, MI, MI.getDebugLoc(), TII->get(RISCV::VX_RPFX));
        for (auto W : R.W)
          B.addImm(W > 0 ? W : 0);
        ++NumRwin;
        Modified = true;
      }
    }
    CE.reset();
    return Modified;
  }

  if (EnableReorder) {
    WindowDAG DAG(MF);
    for (auto &MBB : MF)
      reorderBlock(MBB, DAG);
  }

  // Requirements of every block, in order.
  DenseMap<const MachineBasicBlock *,
           SmallVector<std::pair<MachineInstr *, Req>, 32>>
      Reqs;
  for (auto &MBB : MF)
    for (auto &MI : MBB)
      Reqs[&MBB].push_back({&MI, requirement(MI)});

  ReversePostOrderTraversal<MachineFunction *> RPOT(&MF);
  const MachineBasicBlock *EntryMBB = &MF.front();
  constexpr unsigned Undef = ~0u;
  DenseMap<const MachineBasicBlock *, unsigned> Entry, Exit, Want;
  DenseMap<const MachineBasicBlock *, Plan> Plans;
  for (auto *MBB : RPOT) {
    Exit[MBB] = Undef;
    Want[MBB] = NS;
  }

  auto mergePreds = [&](const MachineBasicBlock *MBB, bool Strict) {
    unsigned M = (MBB == EntryMBB) ? 0u : Undef;
    for (auto *Pred : MBB->predecessors()) {
      unsigned E = Exit.lookup(Pred);
      if (E == Undef) {
        if (Strict)
          return NS;
        continue;
      }
      if (M == Undef)
        M = E;
      else if (M != E)
        return NS;
    }
    return (M == Undef) ? NS : M;
  };
  auto targetOf = [&](const MachineBasicBlock *MBB) {
    if (MBB->succ_size() != 1)
      return NS;
    return Want.lookup(*MBB->succ_begin());
  };

  // Heuristic rounds: entry states, exit preferences and wants settle.
  for (unsigned Round = 0; Round < 8; ++Round) {
    bool Changed = false;
    for (auto *MBB : RPOT) {
      unsigned E = mergePreds(MBB, false);
      Plan P = planBlock(Reqs[MBB], E, targetOf(MBB));
      unsigned W = (P.Want != NS) ? P.Want : targetOf(MBB);
      Changed |= Entry[MBB] != E || Exit[MBB] != P.Exit || Want[MBB] != W;
      Entry[MBB] = E;
      Exit[MBB] = P.Exit;
      Want[MBB] = W;
      Plans[MBB] = std::move(P);
    }
    if (!Changed)
      break;
  }

  // Sound fixed point: a block whose entry state no longer matches all of its
  // predecessors' exits restarts from unknown, which only removes knowledge.
  DenseMap<const MachineBasicBlock *, bool> ForcedUnknown;
  for (bool Changed = true; Changed;) {
    Changed = false;
    for (auto *MBB : RPOT) {
      unsigned E = ForcedUnknown.lookup(MBB) ? NS : mergePreds(MBB, true);
      if (E == Entry[MBB])
        continue;
      E = NS;
      ForcedUnknown[MBB] = true;
      Plan P = planBlock(Reqs[MBB], E, targetOf(MBB));
      Entry[MBB] = E;
      Exit[MBB] = P.Exit;
      Plans[MBB] = std::move(P);
      Changed = true;
    }
  }

  bool Modified = false;
  for (auto *MBB : RPOT) {
    for (auto &[MI, S] : Plans[MBB].Inserts) {
      BuildMI(*MI->getParent(), MI, MI->getDebugLoc(),
              TII->get(RISCV::VX_RWIN))
          .addImm(field(S, 0))
          .addImm(field(S, 1))
          .addImm(field(S, 2))
          .addImm(field(S, 3));
      ++NumRwin;
      Modified = true;
    }
  }

  // Check: replay every block from its entry state.
  for (auto *MBB : RPOT) {
    unsigned S = Entry[MBB];
    for (auto &MI : *MBB) {
      if (MI.getOpcode() == RISCV::VX_RWIN) {
        S = 0;
        for (unsigned F = NumFields; F-- > 0;)
          S = S * NB + MI.getOperand(F).getImm();
        continue;
      }
      if (!satisfies(S, requirement(MI)))
        report_fatal_error("vortex register windows: placement check failed");
    }
    if (S != Exit[MBB])
      report_fatal_error("vortex register windows: exit state mismatch");
    if (Entry[MBB] != NS) {
      if (MBB == EntryMBB && Entry[MBB] != 0)
        report_fatal_error("vortex register windows: nonzero entry state");
      for (auto *Pred : MBB->predecessors())
        if (Exit.lookup(Pred) != Entry[MBB])
          report_fatal_error("vortex register windows: edge state mismatch");
    }
  }

  CE.reset();
  return Modified;
}
