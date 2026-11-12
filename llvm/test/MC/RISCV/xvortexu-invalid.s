# RUN: not llvm-mc -triple=riscv32 -mattr=+m < %s 2>&1 \
# RUN:     | FileCheck --check-prefix=CHECK-NOU %s
# RUN: not llvm-mc -triple=riscv32 -mattr=+m,+xvortexu < %s 2>&1 \
# RUN:     | FileCheck --check-prefix=CHECK-RV32 %s
# RUN: not llvm-mc -triple=riscv32 -mattr=+m < %s 2>&1 \
# RUN:     | FileCheck --check-prefix=CHECK-ARCH %s

add u1, u2, u3
# CHECK-NOU: :[[@LINE-1]]:1: error: instruction requires the following: 'XVortexU' (Vortex Uniform Registers)

# A per-thread W form, and a per-thread shift amount, follow XLEN.
addw a0, a1, u3
# CHECK-RV32: :[[@LINE-1]]:1: error: instruction requires the following: RV64I Base Instruction Set
slli a0, u5, 40
# CHECK-RV32: :[[@LINE-1]]:14: error: immediate must be an integer in the range [0, 31]

# Uniform registers are XLEN wide: the RV64 forms are RV64 only.
addw u1, u2, u3
# CHECK-RV32: :[[@LINE-1]]:1: error: instruction requires the following: RV64I Base Instruction Set
ld u1, 0(u2)
# CHECK-RV32: :[[@LINE-1]]:1: error: instruction requires the following: RV64I Base Instruction Set
slli u1, u2, 40
# CHECK-RV32: :[[@LINE-1]]:14: error: immediate must be an integer in the range [0, 31]
ld a0, 8(u1)
# CHECK-RV32: :[[@LINE-1]]:1: error: instruction requires the following: RV64I Base Instruction Set
subw a0, u1, a2
# CHECK-RV32: :[[@LINE-1]]:1: error: instruction requires the following: RV64I Base Instruction Set

# The uniform encodings are the compressed ones.
.attribute arch, "rv32i_xvortexu1p0_c"
# CHECK-ARCH: :[[@LINE-1]]:18: error: invalid arch name 'rv32i_xvortexu1p0_c', 'xvortexu' and 'c' extensions are incompatible
