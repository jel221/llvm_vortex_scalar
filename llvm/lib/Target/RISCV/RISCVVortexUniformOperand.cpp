//===-- RISCVVortexUniformOperand.cpp - Fold uniform operands -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// XVortexU's uniform-operand forms are per-thread instructions that read a u
// register: as their second source (bits [1:0] = 0b01: the only source of an
// immediate form or a load, a store's data, a branch's second operand) or as
// their first (0b00: a non-commutative operation's first operand, a branch's
// first operand, a store's base). A warp-uniform value used by a per-thread
// instruction otherwise reaches it through a copy to the per-thread file
// (x.mvu); this pass folds the copy into the instruction:
//   COPY xT, uS ; add xD, xA, xT   ->   add xD, xA, uS   (0b01 form)
//   COPY xT, uS ; sub xD, xT, xA   ->   sub xD, uS, xA   (0b00 form)
// It also builds a constant moved to a u register (u.mvx of li) in the u file.
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVSubtarget.h"
#include "llvm/CodeGen/MachineDominators.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/InitializePasses.h"
#include <functional>
#include <map>

using namespace llvm;

#define DEBUG_TYPE "riscv-vortex-uniform-operand"
#define PASS_NAME "RISC-V Vortex uniform operand folding"

namespace {

enum class Form { RR, RRComm, RI, Branch, BranchSym, Load, Store };

// Opc takes the uniform value as the second (or only) source, FirstOpc as the
// first; 0 when there is no such form.
struct UniformForm {
  unsigned Opc;
  Form F;
  unsigned FirstOpc = 0;
};

// The uniform-operand form of a per-thread instruction.
static std::optional<UniformForm> uniformForm(unsigned Opc) {
  switch (Opc) {
  case RISCV::ADD:       return UniformForm{RISCV::VXUO_ADD, Form::RRComm};
  case RISCV::SUB:       return UniformForm{RISCV::VXUO_SUB, Form::RR, RISCV::VXUF_SUB};
  case RISCV::SLL:       return UniformForm{RISCV::VXUO_SLL, Form::RR, RISCV::VXUF_SLL};
  case RISCV::SLT:       return UniformForm{RISCV::VXUO_SLT, Form::RR, RISCV::VXUF_SLT};
  case RISCV::SLTU:      return UniformForm{RISCV::VXUO_SLTU, Form::RR, RISCV::VXUF_SLTU};
  case RISCV::XOR:       return UniformForm{RISCV::VXUO_XOR, Form::RRComm};
  case RISCV::SRL:       return UniformForm{RISCV::VXUO_SRL, Form::RR, RISCV::VXUF_SRL};
  case RISCV::SRA:       return UniformForm{RISCV::VXUO_SRA, Form::RR, RISCV::VXUF_SRA};
  case RISCV::OR:        return UniformForm{RISCV::VXUO_OR, Form::RRComm};
  case RISCV::AND:       return UniformForm{RISCV::VXUO_AND, Form::RRComm};
  case RISCV::MUL:       return UniformForm{RISCV::VXUO_MUL, Form::RRComm};
  case RISCV::MULH:      return UniformForm{RISCV::VXUO_MULH, Form::RRComm};
  case RISCV::MULHSU:    return UniformForm{RISCV::VXUO_MULHSU, Form::RR, RISCV::VXUF_MULHSU};
  case RISCV::MULHU:     return UniformForm{RISCV::VXUO_MULHU, Form::RRComm};
  case RISCV::DIV:       return UniformForm{RISCV::VXUO_DIV, Form::RR, RISCV::VXUF_DIV};
  case RISCV::DIVU:      return UniformForm{RISCV::VXUO_DIVU, Form::RR, RISCV::VXUF_DIVU};
  case RISCV::REM:       return UniformForm{RISCV::VXUO_REM, Form::RR, RISCV::VXUF_REM};
  case RISCV::REMU:      return UniformForm{RISCV::VXUO_REMU, Form::RR, RISCV::VXUF_REMU};
  case RISCV::CZERO_EQZ: return UniformForm{RISCV::VXUO_CZERO_EQZ, Form::RR, RISCV::VXUF_CZERO_EQZ};
  case RISCV::CZERO_NEZ: return UniformForm{RISCV::VXUO_CZERO_NEZ, Form::RR, RISCV::VXUF_CZERO_NEZ};
  case RISCV::ADDW:      return UniformForm{RISCV::VXUO_ADDW, Form::RRComm};
  case RISCV::SUBW:      return UniformForm{RISCV::VXUO_SUBW, Form::RR, RISCV::VXUF_SUBW};
  case RISCV::SLLW:      return UniformForm{RISCV::VXUO_SLLW, Form::RR, RISCV::VXUF_SLLW};
  case RISCV::SRLW:      return UniformForm{RISCV::VXUO_SRLW, Form::RR, RISCV::VXUF_SRLW};
  case RISCV::SRAW:      return UniformForm{RISCV::VXUO_SRAW, Form::RR, RISCV::VXUF_SRAW};
  case RISCV::MULW:      return UniformForm{RISCV::VXUO_MULW, Form::RRComm};
  case RISCV::DIVW:      return UniformForm{RISCV::VXUO_DIVW, Form::RR, RISCV::VXUF_DIVW};
  case RISCV::DIVUW:     return UniformForm{RISCV::VXUO_DIVUW, Form::RR, RISCV::VXUF_DIVUW};
  case RISCV::REMW:      return UniformForm{RISCV::VXUO_REMW, Form::RR, RISCV::VXUF_REMW};
  case RISCV::REMUW:     return UniformForm{RISCV::VXUO_REMUW, Form::RR, RISCV::VXUF_REMUW};
  case RISCV::ADDI:      return UniformForm{RISCV::VXUO_ADDI, Form::RI};
  case RISCV::SLTI:      return UniformForm{RISCV::VXUO_SLTI, Form::RI};
  case RISCV::SLTIU:     return UniformForm{RISCV::VXUO_SLTIU, Form::RI};
  case RISCV::XORI:      return UniformForm{RISCV::VXUO_XORI, Form::RI};
  case RISCV::ORI:       return UniformForm{RISCV::VXUO_ORI, Form::RI};
  case RISCV::ANDI:      return UniformForm{RISCV::VXUO_ANDI, Form::RI};
  case RISCV::SLLI:      return UniformForm{RISCV::VXUO_SLLI, Form::RI};
  case RISCV::SRLI:      return UniformForm{RISCV::VXUO_SRLI, Form::RI};
  case RISCV::SRAI:      return UniformForm{RISCV::VXUO_SRAI, Form::RI};
  case RISCV::ADDIW:     return UniformForm{RISCV::VXUO_ADDIW, Form::RI};
  case RISCV::SLLIW:     return UniformForm{RISCV::VXUO_SLLIW, Form::RI};
  case RISCV::SRLIW:     return UniformForm{RISCV::VXUO_SRLIW, Form::RI};
  case RISCV::SRAIW:     return UniformForm{RISCV::VXUO_SRAIW, Form::RI};
  case RISCV::BEQ:       return UniformForm{RISCV::VXUO_BEQ, Form::BranchSym};
  case RISCV::BNE:       return UniformForm{RISCV::VXUO_BNE, Form::BranchSym};
  case RISCV::BLT:       return UniformForm{RISCV::VXUO_BLT, Form::Branch, RISCV::VXUF_BLT};
  case RISCV::BGE:       return UniformForm{RISCV::VXUO_BGE, Form::Branch, RISCV::VXUF_BGE};
  case RISCV::BLTU:      return UniformForm{RISCV::VXUO_BLTU, Form::Branch, RISCV::VXUF_BLTU};
  case RISCV::BGEU:      return UniformForm{RISCV::VXUO_BGEU, Form::Branch, RISCV::VXUF_BGEU};
  case RISCV::SB:        return UniformForm{RISCV::VXUO_SB, Form::Store, RISCV::VXUF_SB};
  case RISCV::SH:        return UniformForm{RISCV::VXUO_SH, Form::Store, RISCV::VXUF_SH};
  case RISCV::SW:        return UniformForm{RISCV::VXUO_SW, Form::Store, RISCV::VXUF_SW};
  case RISCV::SD:        return UniformForm{RISCV::VXUO_SD, Form::Store, RISCV::VXUF_SD};
  case RISCV::FSW:       return UniformForm{0, Form::Store, RISCV::VXUF_FSW};
  case RISCV::FSD:       return UniformForm{0, Form::Store, RISCV::VXUF_FSD};
  case RISCV::LB:        return UniformForm{RISCV::VXUO_LB, Form::Load};
  case RISCV::LH:        return UniformForm{RISCV::VXUO_LH, Form::Load};
  case RISCV::LW:        return UniformForm{RISCV::VXUO_LW, Form::Load};
  case RISCV::LD:        return UniformForm{RISCV::VXUO_LD, Form::Load};
  case RISCV::LBU:       return UniformForm{RISCV::VXUO_LBU, Form::Load};
  case RISCV::LHU:       return UniformForm{RISCV::VXUO_LHU, Form::Load};
  case RISCV::LWU:       return UniformForm{RISCV::VXUO_LWU, Form::Load};
  case RISCV::FLW:       return UniformForm{RISCV::VXUO_FLW, Form::Load};
  case RISCV::FLD:       return UniformForm{RISCV::VXUO_FLD, Form::Load};
  default:               return std::nullopt;
  }
}

class RISCVVortexUniformOperand : public MachineFunctionPass {
public:
  static char ID;
  RISCVVortexUniformOperand() : MachineFunctionPass(ID) {}

  bool runOnMachineFunction(MachineFunction &MF) override;

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    AU.addRequired<MachineDominatorTreeWrapperPass>();
    AU.addPreserved<MachineDominatorTreeWrapperPass>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  StringRef getPassName() const override { return PASS_NAME; }

private:
  bool fold(MachineInstr &UseMI, unsigned OpNo, Register USrc);
  bool buildConstant(MachineInstr &Copy);
  void eraseIfDead(Register Reg);
  bool cse(MachineDominatorTree &MDT);

  const RISCVInstrInfo *TII = nullptr;
  MachineRegisterInfo *MRI = nullptr;
};

} // namespace

char RISCVVortexUniformOperand::ID = 0;

INITIALIZE_PASS_BEGIN(RISCVVortexUniformOperand, DEBUG_TYPE, PASS_NAME, false,
                      false)
INITIALIZE_PASS_DEPENDENCY(MachineDominatorTreeWrapperPass)
INITIALIZE_PASS_END(RISCVVortexUniformOperand, DEBUG_TYPE, PASS_NAME, false,
                    false)

static bool isCommutativeU(unsigned Opc) {
  switch (Opc) {
  case RISCV::VXU_ADD: case RISCV::VXU_AND: case RISCV::VXU_OR:
  case RISCV::VXU_XOR: case RISCV::VXU_MUL: case RISCV::VXU_MULH:
  case RISCV::VXU_MULHU: case RISCV::VXU_ADDW: case RISCV::VXU_MULW:
    return true;
  default:
    return false;
  }
}

// A uniform computation with no memory access or side effect, whose operands
// are registers and immediates.
static bool isPureU(const MachineInstr &MI, const MachineRegisterInfo &MRI) {
  if (MI.getNumExplicitDefs() != 1 || MI.mayLoadOrStore() ||
      MI.hasUnmodeledSideEffects() || MI.isCall() || MI.isTerminator() ||
      MI.getNumImplicitOperands() != 0)
    return false;
  Register Dst = MI.getOperand(0).getReg();
  if (!Dst.isVirtual() || MRI.getRegClass(Dst) != &RISCV::UGPRRegClass)
    return false;
  for (const MachineOperand &MO : MI.explicit_uses()) {
    if (MO.isImm())
      continue;
    if (!MO.isReg() || (!MO.getReg().isVirtual() && MO.getReg() != RISCV::U0))
      return false;
  }
  return MI.getOpcode() != RISCV::VXU_AUIPC && MI.getOpcode() != RISCV::VXU_JALR;
}

// Rewrites UseMI, whose operand OpNo reads a copy of the u register USrc, into
// its uniform-operand form; false when the operand is not one the form takes.
bool RISCVVortexUniformOperand::fold(MachineInstr &UseMI, unsigned OpNo,
                                     Register USrc) {
  auto UF = uniformForm(UseMI.getOpcode());
  if (!UF)
    return false;
  // A form that is not available on this subtarget (the W forms, sd) does not
  // reach here: the per-thread instruction would not have been selected.
  MachineBasicBlock &MBB = *UseMI.getParent();
  const DebugLoc &DL = UseMI.getDebugLoc();
  MachineInstrBuilder MIB;
  switch (UF->F) {
  case Form::RR:
  case Form::RRComm: {
    // rd, rs1, rs2
    if (UseMI.getNumExplicitOperands() != 3 || !UseMI.getOperand(1).isReg() ||
        !UseMI.getOperand(2).isReg() ||
        UseMI.getOperand(1).getReg() == UseMI.getOperand(2).getReg())
      return false;
    if (OpNo == 2 || (OpNo == 1 && UF->F == Form::RRComm)) {
      MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->Opc), UseMI.getOperand(0).getReg())
                .add(UseMI.getOperand(3 - OpNo))
                .addReg(USrc);
    } else if (OpNo == 1 && UF->FirstOpc) {
      MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->FirstOpc),
                    UseMI.getOperand(0).getReg())
                .addReg(USrc)
                .add(UseMI.getOperand(2));
    } else {
      return false;
    }
    break;
  }
  case Form::RI:
    // rd, rs1, imm: the uniform value is the only source
    if (OpNo != 1 || !UseMI.getOperand(2).isImm())
      return false;
    MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->Opc), UseMI.getOperand(0).getReg())
              .addReg(USrc)
              .add(UseMI.getOperand(2));
    break;
  case Form::Branch:
  case Form::BranchSym: {
    // rs1, rs2, target
    if (UseMI.getOperand(0).getReg() == UseMI.getOperand(1).getReg())
      return false;
    if (OpNo == 1 || (OpNo == 0 && UF->F == Form::BranchSym)) {
      MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->Opc))
                .add(UseMI.getOperand(1 - OpNo))
                .addReg(USrc)
                .add(UseMI.getOperand(2));
    } else if (OpNo == 0 && UF->FirstOpc) {
      MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->FirstOpc))
                .addReg(USrc)
                .add(UseMI.getOperand(1))
                .add(UseMI.getOperand(2));
    } else {
      return false;
    }
    break;
  }
  case Form::Load:
    // rd, rs1 (base), offset: every lane reads the uniform address
    if (OpNo != 1)
      return false;
    MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->Opc), UseMI.getOperand(0).getReg())
              .addReg(USrc)
              .add(UseMI.getOperand(2));
    MIB.cloneMemRefs(UseMI);
    break;
  case Form::Store:
    // rs2 (data), rs1 (base), offset
    if (!UseMI.getOperand(1).isReg() ||
        UseMI.getOperand(1).getReg() == UseMI.getOperand(0).getReg())
      return false;
    if (OpNo == 0 && UF->Opc) {
      MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->Opc))
                .addReg(USrc)
                .add(UseMI.getOperand(1))
                .add(UseMI.getOperand(2));
    } else if (OpNo == 1 && UF->FirstOpc) {
      MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->FirstOpc))
                .add(UseMI.getOperand(0))
                .addReg(USrc)
                .add(UseMI.getOperand(2));
    } else {
      return false;
    }
    MIB.cloneMemRefs(UseMI);
    break;
  }
  MIB->setFlags(UseMI.getFlags());
  UseMI.eraseFromParent();
  return true;
}

void RISCVVortexUniformOperand::eraseIfDead(Register Reg) {
  if (!Reg.isVirtual() || !MRI->use_nodbg_empty(Reg))
    return;
  MachineInstr *Def = MRI->getUniqueVRegDef(Reg);
  if (!Def || Def->hasUnmodeledSideEffects() || Def->mayStore())
    return;
  SmallVector<Register, 2> Srcs;
  for (const MachineOperand &MO : Def->uses())
    if (MO.isReg() && MO.getReg().isVirtual())
      Srcs.push_back(MO.getReg());
  Def->eraseFromParent();
  for (Register R : Srcs)
    eraseIfDead(R);
}

// u.mvx of a constant: the constant is built in the u file instead, and a zero
// is u0 itself. u.mvx of an x.mvu is the u register it came from.
bool RISCVVortexUniformOperand::buildConstant(MachineInstr &Copy) {
  Register Dst = Copy.getOperand(0).getReg();
  Register Src = Copy.getOperand(1).getReg();
  while (Src.isVirtual()) {
    MachineInstr *Def = MRI->getUniqueVRegDef(Src);
    if (!Def || !Def->isCopy())
      break;
    Src = Def->getOperand(1).getReg();
  }
  MachineBasicBlock &MBB = *Copy.getParent();
  const DebugLoc &DL = Copy.getDebugLoc();
  Register OldSrc = Copy.getOperand(1).getReg();

  if (Src == RISCV::X0) {
    for (MachineOperand &MO : make_early_inc_range(MRI->use_nodbg_operands(Dst))) {
      const MachineInstr &UseMI = *MO.getParent();
      if (!UseMI.isPHI() && !UseMI.isCopy() && !UseMI.isInlineAsm())
        MO.setReg(RISCV::U0);
    }
    if (!MRI->use_nodbg_empty(Dst))
      BuildMI(MBB, Copy, DL, TII->get(RISCV::VXU_ADDI), Dst)
          .addReg(RISCV::U0)
          .addImm(0);
  } else if (Src.isVirtual() && MRI->getRegClass(Src) == &RISCV::UGPRRegClass) {
    // a round trip through the per-thread file
    MRI->replaceRegWith(Dst, Src);
  } else {
    if (!Src.isVirtual())
      return false;
    MachineInstr *Def = MRI->getUniqueVRegDef(Src);
    if (!Def)
      return false;
    unsigned Opc = Def->getOpcode();
    if ((Opc == RISCV::ADDI || Opc == RISCV::ADDIW) && Def->getOperand(1).isReg() &&
        Def->getOperand(2).isImm()) {
      Register Base = Def->getOperand(1).getReg();
      unsigned UOpc = Opc == RISCV::ADDI ? RISCV::VXU_ADDI : RISCV::VXU_ADDIW;
      if (Base == RISCV::X0) {
        BuildMI(MBB, Copy, DL, TII->get(UOpc), Dst)
            .addReg(RISCV::U0)
            .add(Def->getOperand(2));
      } else {
        MachineInstr *Hi = Base.isVirtual() ? MRI->getUniqueVRegDef(Base) : nullptr;
        if (!Hi || Hi->getOpcode() != RISCV::LUI || !Hi->getOperand(1).isImm())
          return false;
        Register T = MRI->createVirtualRegister(&RISCV::UGPRRegClass);
        BuildMI(MBB, Copy, DL, TII->get(RISCV::VXU_LUI), T).add(Hi->getOperand(1));
        BuildMI(MBB, Copy, DL, TII->get(UOpc), Dst)
            .addReg(T)
            .add(Def->getOperand(2));
      }
    } else if (Opc == RISCV::LUI && Def->getOperand(1).isImm()) {
      BuildMI(MBB, Copy, DL, TII->get(RISCV::VXU_LUI), Dst).add(Def->getOperand(1));
    } else {
      return false;
    }
  }
  Copy.eraseFromParent();
  eraseIfDead(OldSrc);
  return true;
}

// Folding leaves uniform computations the earlier CSE could not see as equal
// (their operands were copies through the per-thread file, or a sunk copy of
// one reached a block that already had it); one per dominator scope remains.
bool RISCVVortexUniformOperand::cse(MachineDominatorTree &MDT) {
  using Key = SmallVector<int64_t, 6>;
  std::map<Key, Register> Avail;
  bool Changed = false;
  std::function<void(MachineDomTreeNode *)> Visit = [&](MachineDomTreeNode *N) {
    SmallVector<Key, 8> Added;
    for (MachineInstr &MI : make_early_inc_range(*N->getBlock())) {
      if (!isPureU(MI, *MRI))
        continue;
      Key K{MI.getOpcode()};
      for (const MachineOperand &MO : MI.explicit_uses()) {
        K.push_back(MO.isImm() ? 0 : 1);
        K.push_back(MO.isImm() ? MO.getImm() : int64_t(MO.getReg().id()));
      }
      if (isCommutativeU(MI.getOpcode()) && K.size() == 5 &&
          std::make_pair(K[1], K[2]) > std::make_pair(K[3], K[4])) {
        std::swap(K[1], K[3]);
        std::swap(K[2], K[4]);
      }
      Register Dst = MI.getOperand(0).getReg();
      auto It = Avail.find(K);
      if (It != Avail.end()) {
        MRI->replaceRegWith(Dst, It->second);
        MRI->clearKillFlags(It->second);
        MI.eraseFromParent();
        Changed = true;
        continue;
      }
      Avail.emplace(K, Dst);
      Added.push_back(K);
    }
    for (MachineDomTreeNode *C : N->children())
      Visit(C);
    for (const Key &K : Added)
      Avail.erase(K);
  };
  Visit(MDT.getRootNode());
  return Changed;
}

bool RISCVVortexUniformOperand::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()))
    return false;
  const auto &ST = MF.getSubtarget<RISCVSubtarget>();
  if (!ST.hasVendorXVortexU())
    return false;
  TII = ST.getInstrInfo();
  MRI = &MF.getRegInfo();

  bool Changed = false;
  SmallVector<MachineInstr *, 16> ToU;
  for (MachineBasicBlock &MBB : MF)
    for (MachineInstr &MI : MBB)
      if (MI.isCopy() && MI.getOperand(0).getReg().isVirtual() &&
          MRI->getRegClass(MI.getOperand(0).getReg()) == &RISCV::UGPRRegClass &&
          (MI.getOperand(1).getReg() == RISCV::X0 ||
           MI.getOperand(1).getReg().isVirtual()))
        ToU.push_back(&MI);
  for (MachineInstr *MI : ToU)
    Changed |= buildConstant(*MI);

  // The copies first: folding rewrites the instructions around them.
  SmallVector<MachineInstr *, 16> Copies;
  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : MBB) {
      if (!MI.isCopy())
        continue;
      Register Dst = MI.getOperand(0).getReg();
      Register Src = MI.getOperand(1).getReg();
      if (Dst.isVirtual() && Src.isVirtual() &&
          RISCV::GPRRegClass.hasSubClassEq(MRI->getRegClass(Dst)) &&
          MRI->getRegClass(Src) == &RISCV::UGPRRegClass)
        Copies.push_back(&MI);
    }
  }

  for (MachineInstr *MI : Copies) {
    Register Dst = MI->getOperand(0).getReg();
    Register Src = MI->getOperand(1).getReg();
    SmallVector<std::pair<MachineInstr *, unsigned>, 4> Uses;
    for (MachineOperand &MO : MRI->use_nodbg_operands(Dst))
      Uses.push_back({MO.getParent(), MO.getOperandNo()});
    SmallPtrSet<MachineInstr *, 4> Folded;
    for (auto [UseMI, OpNo] : Uses) {
      if (Folded.contains(UseMI))
        continue;
      if (fold(*UseMI, OpNo, Src)) {
        Folded.insert(UseMI);
        Changed = true;
      }
    }
    if (MRI->use_nodbg_empty(Dst)) {
      MI->eraseFromParent();
      Changed = true;
    }
  }
  Changed |= cse(getAnalysis<MachineDominatorTreeWrapperPass>().getDomTree());
  return Changed;
}

FunctionPass *llvm::createRISCVVortexUniformOperandPass() {
  return new RISCVVortexUniformOperand();
}
