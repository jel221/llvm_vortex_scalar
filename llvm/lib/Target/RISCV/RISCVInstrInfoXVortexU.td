//===-- RISCVInstrInfoXVortexU.td --------------------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Vortex uniform registers (XVortexU). Instruction bits [1:0] select the
// register file of an otherwise standard encoding:
//   0b10 uniform: every register field names a u register.
//   0b01 uniform operand: a per-thread instruction whose second source is a
//        u register (xd = xs1 op us2, xd = us1 op imm, xs1 cmp us2, a uniform
//        store value, a load at a uniform address).
//   0b00 uniform first operand: xd = us1 op xs2, us1 cmp xs2, a store at a
//        uniform address.
// Uniform registers are XLEN bits wide and the instructions keep the base ISA's
// semantics (the W forms, ld/sd and lwu on RV64 only). The mnemonics are the
// standard ones; the operands' register classes pick the encoding.
//
//===----------------------------------------------------------------------===//

let Predicates = [HasVendorXVortexU], DecoderNamespace = "XVortexU" in {

//===----------------------------------------------------------------------===//
// Mode 0b10: uniform
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {
class VXU_rr<bits<7> funct7, bits<3> funct3, RISCVOpcode opcode, string opcodestr>
    : RVInstR<funct7, funct3, opcode, (outs UGPR:$rd), (ins UGPR:$rs1, UGPR:$rs2),
              opcodestr, "$rd, $rs1, $rs2"> {
  let Inst{1-0} = 0b10;
}
class VXU_ri<bits<3> funct3, RISCVOpcode opcode, string opcodestr>
    : RVInstI<funct3, opcode, (outs UGPR:$rd), (ins UGPR:$rs1, simm12:$imm12),
              opcodestr, "$rd, $rs1, $imm12"> {
  let Inst{1-0} = 0b10;
}
class VXU_shift<bits<5> imm11_7, bits<3> funct3, string opcodestr>
    : RVInstIShift<imm11_7, funct3, OPC_OP_IMM, (outs UGPR:$rd),
                   (ins UGPR:$rs1, uimmlog2xlen:$shamt), opcodestr, "$rd, $rs1, $shamt"> {
  let Inst{1-0} = 0b10;
}
class VXU_shiftw<bits<7> imm11_5, bits<3> funct3, string opcodestr>
    : RVInstIShiftW<imm11_5, funct3, OPC_OP_IMM_32, (outs UGPR:$rd),
                    (ins UGPR:$rs1, uimm5:$shamt), opcodestr, "$rd, $rs1, $shamt"> {
  let Inst{1-0} = 0b10;
}
}

def VXU_ADD    : VXU_rr<0b0000000, 0b000, OPC_OP, "add">;
def VXU_SUB    : VXU_rr<0b0100000, 0b000, OPC_OP, "sub">;
def VXU_SLL    : VXU_rr<0b0000000, 0b001, OPC_OP, "sll">;
def VXU_SLT    : VXU_rr<0b0000000, 0b010, OPC_OP, "slt">;
def VXU_SLTU   : VXU_rr<0b0000000, 0b011, OPC_OP, "sltu">;
def VXU_XOR    : VXU_rr<0b0000000, 0b100, OPC_OP, "xor">;
def VXU_SRL    : VXU_rr<0b0000000, 0b101, OPC_OP, "srl">;
def VXU_SRA    : VXU_rr<0b0100000, 0b101, OPC_OP, "sra">;
def VXU_OR     : VXU_rr<0b0000000, 0b110, OPC_OP, "or">;
def VXU_AND    : VXU_rr<0b0000000, 0b111, OPC_OP, "and">;
def VXU_MUL    : VXU_rr<0b0000001, 0b000, OPC_OP, "mul">;
def VXU_MULH   : VXU_rr<0b0000001, 0b001, OPC_OP, "mulh">;
def VXU_MULHSU : VXU_rr<0b0000001, 0b010, OPC_OP, "mulhsu">;
def VXU_MULHU  : VXU_rr<0b0000001, 0b011, OPC_OP, "mulhu">;
def VXU_DIV    : VXU_rr<0b0000001, 0b100, OPC_OP, "div">;
def VXU_DIVU   : VXU_rr<0b0000001, 0b101, OPC_OP, "divu">;
def VXU_REM    : VXU_rr<0b0000001, 0b110, OPC_OP, "rem">;
def VXU_REMU   : VXU_rr<0b0000001, 0b111, OPC_OP, "remu">;
def VXU_CZERO_EQZ : VXU_rr<0b0000111, 0b101, OPC_OP, "czero.eqz">;
def VXU_CZERO_NEZ : VXU_rr<0b0000111, 0b111, OPC_OP, "czero.nez">;

let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_ADDW   : VXU_rr<0b0000000, 0b000, OPC_OP_32, "addw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_SUBW   : VXU_rr<0b0100000, 0b000, OPC_OP_32, "subw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_SLLW   : VXU_rr<0b0000000, 0b001, OPC_OP_32, "sllw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_SRLW   : VXU_rr<0b0000000, 0b101, OPC_OP_32, "srlw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_SRAW   : VXU_rr<0b0100000, 0b101, OPC_OP_32, "sraw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_MULW   : VXU_rr<0b0000001, 0b000, OPC_OP_32, "mulw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_DIVW   : VXU_rr<0b0000001, 0b100, OPC_OP_32, "divw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_DIVUW  : VXU_rr<0b0000001, 0b101, OPC_OP_32, "divuw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_REMW   : VXU_rr<0b0000001, 0b110, OPC_OP_32, "remw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_REMUW  : VXU_rr<0b0000001, 0b111, OPC_OP_32, "remuw">;

let isReMaterializable = 1, isAsCheapAsAMove = 1 in
def VXU_ADDI   : VXU_ri<0b000, OPC_OP_IMM, "addi">;
def VXU_SLTI   : VXU_ri<0b010, OPC_OP_IMM, "slti">;
def VXU_SLTIU  : VXU_ri<0b011, OPC_OP_IMM, "sltiu">;
def VXU_XORI   : VXU_ri<0b100, OPC_OP_IMM, "xori">;
def VXU_ORI    : VXU_ri<0b110, OPC_OP_IMM, "ori">;
def VXU_ANDI   : VXU_ri<0b111, OPC_OP_IMM, "andi">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_ADDIW  : VXU_ri<0b000, OPC_OP_IMM_32, "addiw">;
def VXU_SLLI   : VXU_shift<0b00000, 0b001, "slli">;
def VXU_SRLI   : VXU_shift<0b00000, 0b101, "srli">;
def VXU_SRAI   : VXU_shift<0b01000, 0b101, "srai">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_SLLIW  : VXU_shiftw<0b0000000, 0b001, "slliw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_SRLIW  : VXU_shiftw<0b0000000, 0b101, "srliw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_SRAIW  : VXU_shiftw<0b0100000, 0b101, "sraiw">;

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {
let isReMaterializable = 1, isAsCheapAsAMove = 1 in
def VXU_LUI   : RVInstU<OPC_LUI, (outs UGPR:$rd), (ins uimm20_lui:$imm20),
                        "lui", "$rd, $imm20"> {
  let Inst{1-0} = 0b10;
}
def VXU_AUIPC : RVInstU<OPC_AUIPC, (outs UGPR:$rd), (ins uimm20_auipc:$imm20),
                        "auipc", "$rd, $imm20"> {
  let Inst{1-0} = 0b10;
}
}

let isBranch = 1, isTerminator = 1, hasSideEffects = 0, mayLoad = 0,
    mayStore = 0 in
class VXU_branch<bits<3> funct3, string opcodestr>
    : RVInstB<funct3, OPC_BRANCH, (outs),
              (ins UGPR:$rs1, UGPR:$rs2, simm13_lsb0:$imm12),
              opcodestr, "$rs1, $rs2, $imm12"> {
  let Inst{1-0} = 0b10;
}

def VXU_BEQ  : VXU_branch<0b000, "beq">;
def VXU_BNE  : VXU_branch<0b001, "bne">;
def VXU_BLT  : VXU_branch<0b100, "blt">;
def VXU_BGE  : VXU_branch<0b101, "bge">;
def VXU_BLTU : VXU_branch<0b110, "bltu">;
def VXU_BGEU : VXU_branch<0b111, "bgeu">;

let isCall = 1, isBarrier = 1, isCodeGenOnly = 0, hasSideEffects = 0,
    mayLoad = 0, mayStore = 0 in
def VXU_JALR : RVInstI<0b000, OPC_JALR, (outs UGPR:$rd),
                       (ins UGPR:$rs1, simm12:$imm12),
                       "jalr", "$rd, ${imm12}(${rs1})"> {
  let Inst{1-0} = 0b10;
}

let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
class VXU_load<bits<3> funct3, string opcodestr>
    : RVInstI<funct3, OPC_LOAD, (outs UGPR:$rd), (ins UGPR:$rs1, simm12:$imm12),
              opcodestr, "$rd, ${imm12}(${rs1})"> {
  let Inst{1-0} = 0b10;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
class VXU_store<bits<3> funct3, string opcodestr>
    : RVInstS<funct3, OPC_STORE, (outs), (ins UGPR:$rs2, UGPR:$rs1, simm12:$imm12),
              opcodestr, "$rs2, ${imm12}(${rs1})"> {
  let Inst{1-0} = 0b10;
}

def VXU_LB  : VXU_load<0b000, "lb">;
def VXU_LH  : VXU_load<0b001, "lh">;
def VXU_LW  : VXU_load<0b010, "lw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_LD  : VXU_load<0b011, "ld">;
def VXU_LBU : VXU_load<0b100, "lbu">;
def VXU_LHU : VXU_load<0b101, "lhu">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_LWU : VXU_load<0b110, "lwu">;
def VXU_SB  : VXU_store<0b000, "sb">;
def VXU_SH  : VXU_store<0b001, "sh">;
def VXU_SW  : VXU_store<0b010, "sw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXU_SD  : VXU_store<0b011, "sd">;

let hasNoSchedulingInfo = 1, hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {
class VXU_csr_r<bits<3> funct3, string opcodestr>
    : RVInstI<funct3, OPC_SYSTEM, (outs UGPR:$rd),
              (ins csr_sysreg:$imm12, UGPR:$rs1), opcodestr, "$rd, $imm12, $rs1"> {
  let Inst{1-0} = 0b10;
}
class VXU_csr_i<bits<3> funct3, string opcodestr>
    : RVInstI<funct3, OPC_SYSTEM, (outs UGPR:$rd),
              (ins csr_sysreg:$imm12, uimm5:$rs1), opcodestr, "$rd, $imm12, $rs1"> {
  let Inst{1-0} = 0b10;
}
}

def VXU_CSRRW  : VXU_csr_r<0b001, "csrrw">;
def VXU_CSRRS  : VXU_csr_r<0b010, "csrrs">;
def VXU_CSRRC  : VXU_csr_r<0b011, "csrrc">;
def VXU_CSRRWI : VXU_csr_i<0b101, "csrrwi">;
def VXU_CSRRSI : VXU_csr_i<0b110, "csrrsi">;
def VXU_CSRRCI : VXU_csr_i<0b111, "csrrci">;

// Moves between the files, on the fmv.d.x / fmv.x.d encodings: u.mvx takes the
// first active lane, x.mvu broadcasts.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, rs2 = 0b00000 in {
def VXU_MVX : RVInstR<0b1111001, 0b000, OPC_OP_FP, (outs UGPR:$rd), (ins GPR:$rs1),
                      "u.mvx", "$rd, $rs1"> {
  let Inst{1-0} = 0b10;
}
def VXU_MVU : RVInstR<0b1110001, 0b000, OPC_OP_FP, (outs GPR:$rd), (ins UGPR:$rs1),
                      "x.mvu", "$rd, $rs1"> {
  let Inst{1-0} = 0b10;
}
}

//===----------------------------------------------------------------------===//
// Mode 0b01: uniform operand
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {
class VXUO_rr<bits<7> funct7, bits<3> funct3, RISCVOpcode opcode, string opcodestr>
    : RVInstR<funct7, funct3, opcode, (outs GPR:$rd), (ins GPR:$rs1, UGPR:$rs2),
              opcodestr, "$rd, $rs1, $rs2"> {
  let Inst{1-0} = 0b01;
}
class VXUO_ri<bits<3> funct3, RISCVOpcode opcode, string opcodestr>
    : RVInstI<funct3, opcode, (outs GPR:$rd), (ins UGPR:$rs1, simm12:$imm12),
              opcodestr, "$rd, $rs1, $imm12"> {
  let Inst{1-0} = 0b01;
}
class VXUO_shift<bits<5> imm11_7, bits<3> funct3, string opcodestr>
    : RVInstIShift<imm11_7, funct3, OPC_OP_IMM, (outs GPR:$rd),
                   (ins UGPR:$rs1, uimmlog2xlen:$shamt), opcodestr, "$rd, $rs1, $shamt"> {
  let Inst{1-0} = 0b01;
}
class VXUO_shiftw<bits<7> imm11_5, bits<3> funct3, string opcodestr>
    : RVInstIShiftW<imm11_5, funct3, OPC_OP_IMM_32, (outs GPR:$rd),
                    (ins UGPR:$rs1, uimm5:$shamt), opcodestr, "$rd, $rs1, $shamt"> {
  let Inst{1-0} = 0b01;
}
}

def VXUO_ADD    : VXUO_rr<0b0000000, 0b000, OPC_OP, "add">;
def VXUO_SUB    : VXUO_rr<0b0100000, 0b000, OPC_OP, "sub">;
def VXUO_SLL    : VXUO_rr<0b0000000, 0b001, OPC_OP, "sll">;
def VXUO_SLT    : VXUO_rr<0b0000000, 0b010, OPC_OP, "slt">;
def VXUO_SLTU   : VXUO_rr<0b0000000, 0b011, OPC_OP, "sltu">;
def VXUO_XOR    : VXUO_rr<0b0000000, 0b100, OPC_OP, "xor">;
def VXUO_SRL    : VXUO_rr<0b0000000, 0b101, OPC_OP, "srl">;
def VXUO_SRA    : VXUO_rr<0b0100000, 0b101, OPC_OP, "sra">;
def VXUO_OR     : VXUO_rr<0b0000000, 0b110, OPC_OP, "or">;
def VXUO_AND    : VXUO_rr<0b0000000, 0b111, OPC_OP, "and">;
def VXUO_MUL    : VXUO_rr<0b0000001, 0b000, OPC_OP, "mul">;
def VXUO_MULH   : VXUO_rr<0b0000001, 0b001, OPC_OP, "mulh">;
def VXUO_MULHSU : VXUO_rr<0b0000001, 0b010, OPC_OP, "mulhsu">;
def VXUO_MULHU  : VXUO_rr<0b0000001, 0b011, OPC_OP, "mulhu">;
def VXUO_DIV    : VXUO_rr<0b0000001, 0b100, OPC_OP, "div">;
def VXUO_DIVU   : VXUO_rr<0b0000001, 0b101, OPC_OP, "divu">;
def VXUO_REM    : VXUO_rr<0b0000001, 0b110, OPC_OP, "rem">;
def VXUO_REMU   : VXUO_rr<0b0000001, 0b111, OPC_OP, "remu">;
def VXUO_CZERO_EQZ : VXUO_rr<0b0000111, 0b101, OPC_OP, "czero.eqz">;
def VXUO_CZERO_NEZ : VXUO_rr<0b0000111, 0b111, OPC_OP, "czero.nez">;

let Predicates = [HasVendorXVortexU, IsRV64] in {
def VXUO_ADDW   : VXUO_rr<0b0000000, 0b000, OPC_OP_32, "addw">;
def VXUO_SUBW   : VXUO_rr<0b0100000, 0b000, OPC_OP_32, "subw">;
def VXUO_SLLW   : VXUO_rr<0b0000000, 0b001, OPC_OP_32, "sllw">;
def VXUO_SRLW   : VXUO_rr<0b0000000, 0b101, OPC_OP_32, "srlw">;
def VXUO_SRAW   : VXUO_rr<0b0100000, 0b101, OPC_OP_32, "sraw">;
def VXUO_MULW   : VXUO_rr<0b0000001, 0b000, OPC_OP_32, "mulw">;
def VXUO_DIVW   : VXUO_rr<0b0000001, 0b100, OPC_OP_32, "divw">;
def VXUO_DIVUW  : VXUO_rr<0b0000001, 0b101, OPC_OP_32, "divuw">;
def VXUO_REMW   : VXUO_rr<0b0000001, 0b110, OPC_OP_32, "remw">;
def VXUO_REMUW  : VXUO_rr<0b0000001, 0b111, OPC_OP_32, "remuw">;
def VXUO_ADDIW  : VXUO_ri<0b000, OPC_OP_IMM_32, "addiw">;
def VXUO_SLLIW  : VXUO_shiftw<0b0000000, 0b001, "slliw">;
def VXUO_SRLIW  : VXUO_shiftw<0b0000000, 0b101, "srliw">;
def VXUO_SRAIW  : VXUO_shiftw<0b0100000, 0b101, "sraiw">;
}

def VXUO_ADDI   : VXUO_ri<0b000, OPC_OP_IMM, "addi">;
def VXUO_SLTI   : VXUO_ri<0b010, OPC_OP_IMM, "slti">;
def VXUO_SLTIU  : VXUO_ri<0b011, OPC_OP_IMM, "sltiu">;
def VXUO_XORI   : VXUO_ri<0b100, OPC_OP_IMM, "xori">;
def VXUO_ORI    : VXUO_ri<0b110, OPC_OP_IMM, "ori">;
def VXUO_ANDI   : VXUO_ri<0b111, OPC_OP_IMM, "andi">;
def VXUO_SLLI   : VXUO_shift<0b00000, 0b001, "slli">;
def VXUO_SRLI   : VXUO_shift<0b00000, 0b101, "srli">;
def VXUO_SRAI   : VXUO_shift<0b01000, 0b101, "srai">;

let isBranch = 1, isTerminator = 1, hasSideEffects = 0, mayLoad = 0,
    mayStore = 0 in
class VXUO_branch<bits<3> funct3, string opcodestr>
    : RVInstB<funct3, OPC_BRANCH, (outs),
              (ins GPR:$rs1, UGPR:$rs2, simm13_lsb0:$imm12),
              opcodestr, "$rs1, $rs2, $imm12"> {
  let Inst{1-0} = 0b01;
}

def VXUO_BEQ  : VXUO_branch<0b000, "beq">;
def VXUO_BNE  : VXUO_branch<0b001, "bne">;
def VXUO_BLT  : VXUO_branch<0b100, "blt">;
def VXUO_BGE  : VXUO_branch<0b101, "bge">;
def VXUO_BLTU : VXUO_branch<0b110, "bltu">;
def VXUO_BGEU : VXUO_branch<0b111, "bgeu">;

let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
class VXUO_store<bits<3> funct3, string opcodestr>
    : RVInstS<funct3, OPC_STORE, (outs), (ins UGPR:$rs2, GPR:$rs1, simm12:$imm12),
              opcodestr, "$rs2, ${imm12}(${rs1})"> {
  let Inst{1-0} = 0b01;
}

def VXUO_SB : VXUO_store<0b000, "sb">;
def VXUO_SH : VXUO_store<0b001, "sh">;
def VXUO_SW : VXUO_store<0b010, "sw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXUO_SD : VXUO_store<0b011, "sd">;

// Loads at a uniform address into a per-thread register: every lane reads the
// same word.
let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
class VXUO_load<bits<3> funct3, RISCVOpcode opcode, RegisterClass rc, string opcodestr>
    : RVInstI<funct3, opcode, (outs rc:$rd), (ins UGPR:$rs1, simm12:$imm12),
              opcodestr, "$rd, ${imm12}(${rs1})"> {
  let Inst{1-0} = 0b01;
}

def VXUO_LB  : VXUO_load<0b000, OPC_LOAD, GPR, "lb">;
def VXUO_LH  : VXUO_load<0b001, OPC_LOAD, GPR, "lh">;
def VXUO_LW  : VXUO_load<0b010, OPC_LOAD, GPR, "lw">;
def VXUO_LBU : VXUO_load<0b100, OPC_LOAD, GPR, "lbu">;
def VXUO_LHU : VXUO_load<0b101, OPC_LOAD, GPR, "lhu">;
let Predicates = [HasVendorXVortexU, IsRV64] in {
def VXUO_LD  : VXUO_load<0b011, OPC_LOAD, GPR, "ld">;
def VXUO_LWU : VXUO_load<0b110, OPC_LOAD, GPR, "lwu">;
}
let Predicates = [HasVendorXVortexU, HasStdExtF] in
def VXUO_FLW : VXUO_load<0b010, OPC_LOAD_FP, FPR32, "flw">;
let Predicates = [HasVendorXVortexU, HasStdExtD] in
def VXUO_FLD : VXUO_load<0b011, OPC_LOAD_FP, FPR64, "fld">;

//===----------------------------------------------------------------------===//
// Mode 0b00: uniform first operand
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class VXUF_rr<bits<7> funct7, bits<3> funct3, RISCVOpcode opcode, string opcodestr>
    : RVInstR<funct7, funct3, opcode, (outs GPR:$rd), (ins UGPR:$rs1, GPR:$rs2),
              opcodestr, "$rd, $rs1, $rs2"> {
  let Inst{1-0} = 0b00;
}

def VXUF_ADD    : VXUF_rr<0b0000000, 0b000, OPC_OP, "add">;
def VXUF_SUB    : VXUF_rr<0b0100000, 0b000, OPC_OP, "sub">;
def VXUF_SLL    : VXUF_rr<0b0000000, 0b001, OPC_OP, "sll">;
def VXUF_SLT    : VXUF_rr<0b0000000, 0b010, OPC_OP, "slt">;
def VXUF_SLTU   : VXUF_rr<0b0000000, 0b011, OPC_OP, "sltu">;
def VXUF_XOR    : VXUF_rr<0b0000000, 0b100, OPC_OP, "xor">;
def VXUF_SRL    : VXUF_rr<0b0000000, 0b101, OPC_OP, "srl">;
def VXUF_SRA    : VXUF_rr<0b0100000, 0b101, OPC_OP, "sra">;
def VXUF_OR     : VXUF_rr<0b0000000, 0b110, OPC_OP, "or">;
def VXUF_AND    : VXUF_rr<0b0000000, 0b111, OPC_OP, "and">;
def VXUF_MUL    : VXUF_rr<0b0000001, 0b000, OPC_OP, "mul">;
def VXUF_MULH   : VXUF_rr<0b0000001, 0b001, OPC_OP, "mulh">;
def VXUF_MULHSU : VXUF_rr<0b0000001, 0b010, OPC_OP, "mulhsu">;
def VXUF_MULHU  : VXUF_rr<0b0000001, 0b011, OPC_OP, "mulhu">;
def VXUF_DIV    : VXUF_rr<0b0000001, 0b100, OPC_OP, "div">;
def VXUF_DIVU   : VXUF_rr<0b0000001, 0b101, OPC_OP, "divu">;
def VXUF_REM    : VXUF_rr<0b0000001, 0b110, OPC_OP, "rem">;
def VXUF_REMU   : VXUF_rr<0b0000001, 0b111, OPC_OP, "remu">;
def VXUF_CZERO_EQZ : VXUF_rr<0b0000111, 0b101, OPC_OP, "czero.eqz">;
def VXUF_CZERO_NEZ : VXUF_rr<0b0000111, 0b111, OPC_OP, "czero.nez">;

let Predicates = [HasVendorXVortexU, IsRV64] in {
def VXUF_ADDW   : VXUF_rr<0b0000000, 0b000, OPC_OP_32, "addw">;
def VXUF_SUBW   : VXUF_rr<0b0100000, 0b000, OPC_OP_32, "subw">;
def VXUF_SLLW   : VXUF_rr<0b0000000, 0b001, OPC_OP_32, "sllw">;
def VXUF_SRLW   : VXUF_rr<0b0000000, 0b101, OPC_OP_32, "srlw">;
def VXUF_SRAW   : VXUF_rr<0b0100000, 0b101, OPC_OP_32, "sraw">;
def VXUF_MULW   : VXUF_rr<0b0000001, 0b000, OPC_OP_32, "mulw">;
def VXUF_DIVW   : VXUF_rr<0b0000001, 0b100, OPC_OP_32, "divw">;
def VXUF_DIVUW  : VXUF_rr<0b0000001, 0b101, OPC_OP_32, "divuw">;
def VXUF_REMW   : VXUF_rr<0b0000001, 0b110, OPC_OP_32, "remw">;
def VXUF_REMUW  : VXUF_rr<0b0000001, 0b111, OPC_OP_32, "remuw">;
}

let isBranch = 1, isTerminator = 1, hasSideEffects = 0, mayLoad = 0,
    mayStore = 0 in
class VXUF_branch<bits<3> funct3, string opcodestr>
    : RVInstB<funct3, OPC_BRANCH, (outs),
              (ins UGPR:$rs1, GPR:$rs2, simm13_lsb0:$imm12),
              opcodestr, "$rs1, $rs2, $imm12"> {
  let Inst{1-0} = 0b00;
}

def VXUF_BEQ  : VXUF_branch<0b000, "beq">;
def VXUF_BNE  : VXUF_branch<0b001, "bne">;
def VXUF_BLT  : VXUF_branch<0b100, "blt">;
def VXUF_BGE  : VXUF_branch<0b101, "bge">;
def VXUF_BLTU : VXUF_branch<0b110, "bltu">;
def VXUF_BGEU : VXUF_branch<0b111, "bgeu">;

// Stores at a uniform address of a per-thread value.
let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
class VXUF_store<bits<3> funct3, RISCVOpcode opcode, RegisterClass rc, string opcodestr>
    : RVInstS<funct3, opcode, (outs), (ins rc:$rs2, UGPR:$rs1, simm12:$imm12),
              opcodestr, "$rs2, ${imm12}(${rs1})"> {
  let Inst{1-0} = 0b00;
}

def VXUF_SB : VXUF_store<0b000, OPC_STORE, GPR, "sb">;
def VXUF_SH : VXUF_store<0b001, OPC_STORE, GPR, "sh">;
def VXUF_SW : VXUF_store<0b010, OPC_STORE, GPR, "sw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXUF_SD : VXUF_store<0b011, OPC_STORE, GPR, "sd">;
let Predicates = [HasVendorXVortexU, HasStdExtF] in
def VXUF_FSW : VXUF_store<0b010, OPC_STORE_FP, FPR32, "fsw">;
let Predicates = [HasVendorXVortexU, HasStdExtD] in
def VXUF_FSD : VXUF_store<0b011, OPC_STORE_FP, FPR64, "fsd">;

} // Predicates = [HasVendorXVortexU], DecoderNamespace = "XVortexU"

//===----------------------------------------------------------------------===//
// Code generation: warp-uniform values in the u registers
//===----------------------------------------------------------------------===//

// A u register reloads through a per-thread load and u.mvx (expanded with the
// frame index); it spills with a uniform-operand store.
let Predicates = [HasVendorXVortexU], hasSideEffects = 0, mayLoad = 1,
    mayStore = 0 in
def PseudoVXU_RELOAD : Pseudo<(outs UGPR:$rd), (ins GPR:$rs1, simm12:$imm12), []>;

// A node every lane of the warp computes alike (SelectionDAG divergence,
// RISCVTargetLowering::isSDNodeSourceOfDivergence).
class VXUniform1<SDPatternOperator op>
    : PatFrag<(ops node:$a), (op node:$a), [{ return !N->isDivergent(); }]>;
class VXUniform2<SDPatternOperator op>
    : PatFrag<(ops node:$a, node:$b), (op node:$a, node:$b),
              [{ return !N->isDivergent(); }]>;

def vxu_brcc : PatFrag<(ops node:$a, node:$b, node:$cc, node:$bb),
                       (riscv_brcc node:$a, node:$b, node:$cc, node:$bb),
                       [{ return !N->isDivergent(); }]>;

let Predicates = [HasVendorXVortexU], AddedComplexity = 20 in {

class PatUU<SDPatternOperator op, RVInst inst>
    : Pat<(XLenVT (VXUniform2<op> (XLenVT UGPR:$a), (XLenVT UGPR:$b))),
          (inst UGPR:$a, UGPR:$b)>;
class PatUImm<SDPatternOperator op, RVInst inst, ImmLeaf imm>
    : Pat<(XLenVT (VXUniform2<op> (XLenVT UGPR:$a), imm:$i)),
          (inst UGPR:$a, imm:$i)>;

def : PatUU<add, VXU_ADD>;
def : PatUU<sub, VXU_SUB>;
def : PatUU<and, VXU_AND>;
def : PatUU<or,  VXU_OR>;
def : PatUU<xor, VXU_XOR>;
def : PatUU<shiftop<shl>, VXU_SLL>;
def : PatUU<shiftop<srl>, VXU_SRL>;
def : PatUU<shiftop<sra>, VXU_SRA>;
def : PatUU<setlt,  VXU_SLT>;
def : PatUU<setult, VXU_SLTU>;
def : PatUImm<add, VXU_ADDI, simm12>;
def : PatUImm<and, VXU_ANDI, simm12>;
def : PatUImm<or,  VXU_ORI,  simm12>;
def : PatUImm<xor, VXU_XORI, simm12>;
def : PatUImm<setlt,  VXU_SLTI,  simm12>;
def : PatUImm<setult, VXU_SLTIU, simm12>;
def : PatUImm<shl, VXU_SLLI, uimmlog2xlen>;
def : PatUImm<srl, VXU_SRLI, uimmlog2xlen>;
def : PatUImm<sra, VXU_SRAI, uimmlog2xlen>;

def : Pat<(XLenVT (VXUniform2<seteq> (XLenVT UGPR:$a), 0)), (VXU_SLTIU UGPR:$a, 1)>;
def : Pat<(XLenVT (VXUniform2<setne> (XLenVT UGPR:$a), 0)),
          (VXU_SLTU (XLenVT U0), UGPR:$a)>;
def : Pat<(XLenVT (VXUniform2<seteq> (XLenVT UGPR:$a), (XLenVT UGPR:$b))),
          (VXU_SLTIU (VXU_XOR UGPR:$a, UGPR:$b), 1)>;
def : Pat<(XLenVT (VXUniform2<setne> (XLenVT UGPR:$a), (XLenVT UGPR:$b))),
          (VXU_SLTU (XLenVT U0), (VXU_XOR UGPR:$a, UGPR:$b))>;
def : Pat<(XLenVT (VXUniform2<seteq> (XLenVT UGPR:$a), simm12:$i)),
          (VXU_SLTIU (VXU_XORI UGPR:$a, simm12:$i), 1)>;
def : Pat<(XLenVT (VXUniform2<setne> (XLenVT UGPR:$a), simm12:$i)),
          (VXU_SLTU (XLenVT U0), (VXU_XORI UGPR:$a, simm12:$i))>;

let Predicates = [HasVendorXVortexU, HasStdExtZicond] in {
def : PatUU<riscv_czero_eqz, VXU_CZERO_EQZ>;
def : PatUU<riscv_czero_nez, VXU_CZERO_NEZ>;
}

let Predicates = [HasVendorXVortexU, HasStdExtM] in {
def : PatUU<mul,   VXU_MUL>;
def : PatUU<mulhs, VXU_MULH>;
def : PatUU<mulhu, VXU_MULHU>;
def : PatUU<sdiv,  VXU_DIV>;
def : PatUU<udiv,  VXU_DIVU>;
def : PatUU<srem,  VXU_REM>;
def : PatUU<urem,  VXU_REMU>;
}

// Loads and stores at a uniform address: once per warp. A stack address is
// per-thread, so it is never uniform.
class PatULd<PatFrag LoadOp, RVInst inst, ValueType vt = XLenVT>
    : Pat<(vt (VXUniform1<LoadOp> (AddrRegImm (XLenVT UGPR:$rs1), simm12:$imm12))),
          (inst UGPR:$rs1, simm12:$imm12)>;
class PatUSt<PatFrag StoreOp, RVInst inst, ValueType vt = XLenVT>
    : Pat<(VXUniform2<StoreOp> (vt UGPR:$rs2),
                               (AddrRegImm (XLenVT UGPR:$rs1), simm12:$imm12)),
          (inst UGPR:$rs2, UGPR:$rs1, simm12:$imm12)>;

def : PatULd<sextloadi8,  VXU_LB>;
def : PatULd<extloadi8,   VXU_LBU>;
def : PatULd<zextloadi8,  VXU_LBU>;
def : PatULd<sextloadi16, VXU_LH>;
def : PatULd<extloadi16,  VXU_LH>;
def : PatULd<zextloadi16, VXU_LHU>;
def : PatUSt<truncstorei8,  VXU_SB>;
def : PatUSt<truncstorei16, VXU_SH>;

let Predicates = [HasVendorXVortexU, IsRV32] in {
def : PatULd<load, VXU_LW, i32>;
def : PatUSt<store, VXU_SW, i32>;
}
let Predicates = [HasVendorXVortexU, IsRV64] in {
def : PatULd<load, VXU_LD, i64>;
def : PatULd<sextloadi32, VXU_LW, i64>;
def : PatULd<extloadi32,  VXU_LW, i64>;
def : PatULd<zextloadi32, VXU_LWU, i64>;
def : PatUSt<truncstorei32, VXU_SW, i64>;
def : PatUSt<store, VXU_SD, i64>;
}

// Uniform branches: no copy of the operands to the per-thread file.
multiclass PatUBcc<CondCode Cond, RVInstB Inst> {
  def : Pat<(vxu_brcc (XLenVT UGPR:$rs1), UGPR:$rs2, Cond, bb:$imm12),
            (Inst UGPR:$rs1, UGPR:$rs2, simm13_lsb0:$imm12)>;
}
defm : PatUBcc<SETEQ,  VXU_BEQ>;
defm : PatUBcc<SETNE,  VXU_BNE>;
defm : PatUBcc<SETLT,  VXU_BLT>;
defm : PatUBcc<SETGE,  VXU_BGE>;
defm : PatUBcc<SETULT, VXU_BLTU>;
defm : PatUBcc<SETUGE, VXU_BGEU>;

// A compare with zero reads u0.
multiclass PatUBccZ<CondCode Cond, RVInstB Inst> {
  def : Pat<(vxu_brcc (XLenVT UGPR:$rs1), 0, Cond, bb:$imm12),
            (Inst UGPR:$rs1, (XLenVT U0), simm13_lsb0:$imm12)>;
}
defm : PatUBccZ<SETEQ,  VXU_BEQ>;
defm : PatUBccZ<SETNE,  VXU_BNE>;
defm : PatUBccZ<SETLT,  VXU_BLT>;
defm : PatUBccZ<SETGE,  VXU_BGE>;
defm : PatUBccZ<SETULT, VXU_BLTU>;
defm : PatUBccZ<SETUGE, VXU_BGEU>;

} // Predicates = [HasVendorXVortexU], AddedComplexity = 20

// The uniformity marker: the value moves to a u register.
def riscv_vx_uniform_node : SDNode<"RISCVISD::VX_UNIFORM",
                                   SDTypeProfile<1, 1, [SDTCisSameAs<0, 1>]>>;
let Predicates = [HasVendorXVortexU] in
def : Pat<(XLenVT (riscv_vx_uniform_node (XLenVT GPR:$x))),
          (COPY_TO_REGCLASS GPR:$x, UGPR)>;
