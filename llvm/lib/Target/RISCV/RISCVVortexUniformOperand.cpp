//===-- RISCVVortexUniformOperand.cpp - Fold uniform operands -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// XVortexU's uniform-operand forms (instruction bits [1:0] = 0b01) are
// per-thread instructions that read a u register as their second source (the
// only source of an immediate form, a store's data, a branch's second
// operand). A warp-uniform value used by a per-thread instruction otherwise
// reaches it through a copy to the per-thread file (x.mvu); this pass folds the
// copy into the instruction:
//   COPY xT, uS ; add xD, xA, xT   ->   add xD, xA, uS   (0b01 form)
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVSubtarget.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/InitializePasses.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-vortex-uniform-operand"
#define PASS_NAME "RISC-V Vortex uniform operand folding"

namespace {

enum class Form { RR, RRComm, RI, Branch, BranchSym, Store };

struct UniformForm {
  unsigned Opc;
  Form F;
};

// The uniform-operand form of a per-thread instruction.
static std::optional<UniformForm> uniformForm(unsigned Opc) {
  switch (Opc) {
  case RISCV::ADD:       return UniformForm{RISCV::VXUO_ADD, Form::RRComm};
  case RISCV::SUB:       return UniformForm{RISCV::VXUO_SUB, Form::RR};
  case RISCV::SLL:       return UniformForm{RISCV::VXUO_SLL, Form::RR};
  case RISCV::SLT:       return UniformForm{RISCV::VXUO_SLT, Form::RR};
  case RISCV::SLTU:      return UniformForm{RISCV::VXUO_SLTU, Form::RR};
  case RISCV::XOR:       return UniformForm{RISCV::VXUO_XOR, Form::RRComm};
  case RISCV::SRL:       return UniformForm{RISCV::VXUO_SRL, Form::RR};
  case RISCV::SRA:       return UniformForm{RISCV::VXUO_SRA, Form::RR};
  case RISCV::OR:        return UniformForm{RISCV::VXUO_OR, Form::RRComm};
  case RISCV::AND:       return UniformForm{RISCV::VXUO_AND, Form::RRComm};
  case RISCV::MUL:       return UniformForm{RISCV::VXUO_MUL, Form::RRComm};
  case RISCV::MULH:      return UniformForm{RISCV::VXUO_MULH, Form::RRComm};
  case RISCV::MULHSU:    return UniformForm{RISCV::VXUO_MULHSU, Form::RR};
  case RISCV::MULHU:     return UniformForm{RISCV::VXUO_MULHU, Form::RRComm};
  case RISCV::DIV:       return UniformForm{RISCV::VXUO_DIV, Form::RR};
  case RISCV::DIVU:      return UniformForm{RISCV::VXUO_DIVU, Form::RR};
  case RISCV::REM:       return UniformForm{RISCV::VXUO_REM, Form::RR};
  case RISCV::REMU:      return UniformForm{RISCV::VXUO_REMU, Form::RR};
  case RISCV::CZERO_EQZ: return UniformForm{RISCV::VXUO_CZERO_EQZ, Form::RR};
  case RISCV::CZERO_NEZ: return UniformForm{RISCV::VXUO_CZERO_NEZ, Form::RR};
  case RISCV::ADDW:      return UniformForm{RISCV::VXUO_ADDW, Form::RRComm};
  case RISCV::SUBW:      return UniformForm{RISCV::VXUO_SUBW, Form::RR};
  case RISCV::SLLW:      return UniformForm{RISCV::VXUO_SLLW, Form::RR};
  case RISCV::SRLW:      return UniformForm{RISCV::VXUO_SRLW, Form::RR};
  case RISCV::SRAW:      return UniformForm{RISCV::VXUO_SRAW, Form::RR};
  case RISCV::MULW:      return UniformForm{RISCV::VXUO_MULW, Form::RRComm};
  case RISCV::DIVW:      return UniformForm{RISCV::VXUO_DIVW, Form::RR};
  case RISCV::DIVUW:     return UniformForm{RISCV::VXUO_DIVUW, Form::RR};
  case RISCV::REMW:      return UniformForm{RISCV::VXUO_REMW, Form::RR};
  case RISCV::REMUW:     return UniformForm{RISCV::VXUO_REMUW, Form::RR};
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
  case RISCV::BLT:       return UniformForm{RISCV::VXUO_BLT, Form::Branch};
  case RISCV::BGE:       return UniformForm{RISCV::VXUO_BGE, Form::Branch};
  case RISCV::BLTU:      return UniformForm{RISCV::VXUO_BLTU, Form::Branch};
  case RISCV::BGEU:      return UniformForm{RISCV::VXUO_BGEU, Form::Branch};
  case RISCV::SB:        return UniformForm{RISCV::VXUO_SB, Form::Store};
  case RISCV::SH:        return UniformForm{RISCV::VXUO_SH, Form::Store};
  case RISCV::SW:        return UniformForm{RISCV::VXUO_SW, Form::Store};
  case RISCV::SD:        return UniformForm{RISCV::VXUO_SD, Form::Store};
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
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  StringRef getPassName() const override { return PASS_NAME; }

private:
  bool fold(MachineInstr &UseMI, unsigned OpNo, Register USrc);

  const RISCVInstrInfo *TII = nullptr;
  MachineRegisterInfo *MRI = nullptr;
};

} // namespace

char RISCVVortexUniformOperand::ID = 0;

INITIALIZE_PASS(RISCVVortexUniformOperand, DEBUG_TYPE, PASS_NAME, false, false)

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
    // rd, rs1, rs2: the uniform value goes in rs2
    if (UseMI.getNumExplicitOperands() != 3 || !UseMI.getOperand(1).isReg() ||
        !UseMI.getOperand(2).isReg())
      return false;
    unsigned Other;
    if (OpNo == 2)
      Other = 1;
    else if (OpNo == 1 && UF->F == Form::RRComm)
      Other = 2;
    else
      return false;
    if (UseMI.getOperand(Other).getReg() == UseMI.getOperand(OpNo).getReg())
      return false;
    MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->Opc), UseMI.getOperand(0).getReg())
              .add(UseMI.getOperand(Other))
              .addReg(USrc);
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
    // rs1, rs2, target: the uniform value is the second operand
    unsigned Other;
    if (OpNo == 1)
      Other = 0;
    else if (OpNo == 0 && UF->F == Form::BranchSym)
      Other = 1;
    else
      return false;
    if (UseMI.getOperand(Other).getReg() == UseMI.getOperand(OpNo).getReg())
      return false;
    MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->Opc))
              .add(UseMI.getOperand(Other))
              .addReg(USrc)
              .add(UseMI.getOperand(2));
    break;
  }
  case Form::Store:
    // rs2 (data), rs1 (base), imm: the uniform value is the data
    if (OpNo != 0 || UseMI.getOperand(1).getReg() == UseMI.getOperand(0).getReg())
      return false;
    MIB = BuildMI(MBB, UseMI, DL, TII->get(UF->Opc))
              .addReg(USrc)
              .add(UseMI.getOperand(1))
              .add(UseMI.getOperand(2));
    MIB.cloneMemRefs(UseMI);
    break;
  }
  MIB->setFlags(UseMI.getFlags());
  UseMI.eraseFromParent();
  return true;
}

bool RISCVVortexUniformOperand::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()))
    return false;
  const auto &ST = MF.getSubtarget<RISCVSubtarget>();
  if (!ST.hasVendorXVortexU())
    return false;
  TII = ST.getInstrInfo();
  MRI = &MF.getRegInfo();

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

  bool Changed = false;
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
  return Changed;
}

FunctionPass *llvm::createRISCVVortexUniformOperandPass() {
  return new RISCVVortexUniformOperand();
}
