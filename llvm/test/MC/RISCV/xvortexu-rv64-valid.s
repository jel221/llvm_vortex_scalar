# RUN: llvm-mc %s -triple=riscv64 -mattr=+m,+f,+d,+zicond,+xvortexu -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ASM,CHECK-ASM-AND-OBJ %s
# RUN: llvm-mc -filetype=obj -triple=riscv64 -mattr=+m,+f,+d,+zicond,+xvortexu < %s \
# RUN:     | llvm-objdump --mattr=+m,+f,+d,+zicond,+xvortexu --no-print-imm-hex -d - \
# RUN:     | FileCheck --check-prefix=CHECK-ASM-AND-OBJ %s

# The W forms, ld/sd/lwu and 6-bit shift amounts, on RV64 only.

# CHECK-ASM-AND-OBJ: addw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x00,0x31,0x00]
addw u1, u2, u3
# CHECK-ASM-AND-OBJ: subw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x00,0x31,0x40]
subw u1, u2, u3
# CHECK-ASM-AND-OBJ: sllw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x10,0x31,0x00]
sllw u1, u2, u3
# CHECK-ASM-AND-OBJ: srlw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x50,0x31,0x00]
srlw u1, u2, u3
# CHECK-ASM-AND-OBJ: sraw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x50,0x31,0x40]
sraw u1, u2, u3
# CHECK-ASM-AND-OBJ: mulw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x00,0x31,0x02]
mulw u1, u2, u3
# CHECK-ASM-AND-OBJ: divw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x40,0x31,0x02]
divw u1, u2, u3
# CHECK-ASM-AND-OBJ: divuw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x50,0x31,0x02]
divuw u1, u2, u3
# CHECK-ASM-AND-OBJ: remw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x60,0x31,0x02]
remw u1, u2, u3
# CHECK-ASM-AND-OBJ: remuw u1, u2, u3
# CHECK-ASM: encoding: [0xba,0x70,0x31,0x02]
remuw u1, u2, u3
# CHECK-ASM-AND-OBJ: addiw u1, u2, -7
# CHECK-ASM: encoding: [0x9a,0x00,0x91,0xff]
addiw u1, u2, -7
# CHECK-ASM-AND-OBJ: slli u1, u2, 63
# CHECK-ASM: encoding: [0x92,0x10,0xf1,0x03]
slli u1, u2, 63
# CHECK-ASM-AND-OBJ: srli u1, u2, 33
# CHECK-ASM: encoding: [0x92,0x50,0x11,0x02]
srli u1, u2, 33
# CHECK-ASM-AND-OBJ: slliw u1, u2, 31
# CHECK-ASM: encoding: [0x9a,0x10,0xf1,0x01]
slliw u1, u2, 31
# CHECK-ASM-AND-OBJ: srliw u1, u2, 5
# CHECK-ASM: encoding: [0x9a,0x50,0x51,0x00]
srliw u1, u2, 5
# CHECK-ASM-AND-OBJ: sraiw u1, u2, 9
# CHECK-ASM: encoding: [0x9a,0x50,0x91,0x40]
sraiw u1, u2, 9
# CHECK-ASM-AND-OBJ: ld u1, 8(u2)
# CHECK-ASM: encoding: [0x82,0x30,0x81,0x00]
ld u1, 8(u2)
# CHECK-ASM-AND-OBJ: lwu u1, 4(u2)
# CHECK-ASM: encoding: [0x82,0x60,0x41,0x00]
lwu u1, 4(u2)
# CHECK-ASM-AND-OBJ: sd u1, 8(u2)
# CHECK-ASM: encoding: [0x22,0x34,0x11,0x00]
sd u1, 8(u2)
# CHECK-ASM-AND-OBJ: sd u3, 4(a0)
# CHECK-ASM: encoding: [0x21,0x32,0x35,0x00]
sd u3, 4(a0)

# RV64 forms of the uniform-operand loads (0b01) and the uniform-first-operand
# operations and stores (0b00).
# CHECK-ASM-AND-OBJ: ld a0, 8(u1)
# CHECK-ASM: encoding: [0x01,0xb5,0x80,0x00]
ld a0, 8(u1)
# CHECK-ASM-AND-OBJ: lwu a0, 8(u1)
# CHECK-ASM: encoding: [0x01,0xe5,0x80,0x00]
lwu a0, 8(u1)
# CHECK-ASM-AND-OBJ: fld fa0, 8(u1)
# CHECK-ASM: encoding: [0x05,0xb5,0x80,0x00]
fld fa0, 8(u1)
# CHECK-ASM-AND-OBJ: subw a0, u1, a2
# CHECK-ASM: encoding: [0x38,0x85,0xc0,0x40]
subw a0, u1, a2
# CHECK-ASM-AND-OBJ: sllw a0, u1, a2
# CHECK-ASM: encoding: [0x38,0x95,0xc0,0x00]
sllw a0, u1, a2
# CHECK-ASM-AND-OBJ: sd a0, 4(u1)
# CHECK-ASM: encoding: [0x20,0xb2,0xa0,0x00]
sd a0, 4(u1)
# CHECK-ASM-AND-OBJ: fsd fa0, 4(u1)
# CHECK-ASM: encoding: [0x24,0xb2,0xa0,0x00]
fsd fa0, 4(u1)
