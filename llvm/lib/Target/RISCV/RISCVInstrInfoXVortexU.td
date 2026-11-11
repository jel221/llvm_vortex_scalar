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
//        store value), and global indexed accesses at us1 + xs2.
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

// Global indexed accesses on the AMO opcode, at us1 + xs2: funct5 11110
// loads into xd, funct5 11111 stores the register in the rd field; funct3 is
// the width as in LOAD/STORE.
let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
class VXUO_gload<bits<3> funct3, string opcodestr>
    : RVInstRAtomic<0b11110, 0, 0, funct3, OPC_AMO, (outs GPR:$rd),
                    (ins UGPR:$rs1, GPR:$rs2), opcodestr, "$rd, $rs1, $rs2"> {
  let Inst{1-0} = 0b01;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
class VXUO_gstore<bits<3> funct3, string opcodestr>
    : RVInstRAtomic<0b11111, 0, 0, funct3, OPC_AMO, (outs),
                    (ins GPR:$rd, UGPR:$rs1, GPR:$rs2), opcodestr, "$rd, $rs1, $rs2"> {
  let Inst{1-0} = 0b01;
}

def VXUO_GLB  : VXUO_gload<0b000, "vx_glb">;
def VXUO_GLH  : VXUO_gload<0b001, "vx_glh">;
def VXUO_GLW  : VXUO_gload<0b010, "vx_glw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXUO_GLD  : VXUO_gload<0b011, "vx_gld">;
def VXUO_GLBU : VXUO_gload<0b100, "vx_glbu">;
def VXUO_GLHU : VXUO_gload<0b101, "vx_glhu">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXUO_GLWU : VXUO_gload<0b110, "vx_glwu">;
def VXUO_GSB  : VXUO_gstore<0b000, "vx_gsb">;
def VXUO_GSH  : VXUO_gstore<0b001, "vx_gsh">;
def VXUO_GSW  : VXUO_gstore<0b010, "vx_gsw">;
let Predicates = [HasVendorXVortexU, IsRV64] in
def VXUO_GSD  : VXUO_gstore<0b011, "vx_gsd">;

} // Predicates = [HasVendorXVortexU], DecoderNamespace = "XVortexU"
