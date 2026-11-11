# RUN: llvm-mc %s -triple=riscv32 -mattr=+m,+zicond,+xvortexu -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ASM,CHECK-ASM-AND-OBJ %s
# RUN: llvm-mc -filetype=obj -triple=riscv32 -mattr=+m,+zicond,+xvortexu < %s \
# RUN:     | llvm-objdump --mattr=+m,+zicond,+xvortexu --no-print-imm-hex -d - \
# RUN:     | FileCheck --check-prefixes=CHECK-ASM-AND-OBJ,CHECK-OBJ %s

# Bits 1:0 of 0b10: every register field names a u register.
# Bits 1:0 of 0b01: the second source (or the only source of an immediate
# form, or a store value) is a u register; global indexed accesses on the
# AMO opcode address us1 + zext(xs2).

# CHECK-ASM-AND-OBJ: add u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x00,0x31,0x00]
add u1, u2, u3
# CHECK-ASM-AND-OBJ: sub u4, u5, u6
# CHECK-ASM: encoding: [0x32,0x82,0x62,0x40]
sub u4, u5, u6
# CHECK-ASM-AND-OBJ: sll u7, u8, u9
# CHECK-ASM: encoding: [0xb2,0x13,0x94,0x00]
sll u7, u8, u9
# CHECK-ASM-AND-OBJ: slt u10, u11, u12
# CHECK-ASM: encoding: [0x32,0xa5,0xc5,0x00]
slt u10, u11, u12
# CHECK-ASM-AND-OBJ: sltu u13, u14, u15
# CHECK-ASM: encoding: [0xb2,0x36,0xf7,0x00]
sltu u13, u14, u15
# CHECK-ASM-AND-OBJ: xor u16, u17, u18
# CHECK-ASM: encoding: [0x32,0xc8,0x28,0x01]
xor u16, u17, u18
# CHECK-ASM-AND-OBJ: srl u19, u20, u21
# CHECK-ASM: encoding: [0xb2,0x59,0x5a,0x01]
srl u19, u20, u21
# CHECK-ASM-AND-OBJ: sra u22, u23, u24
# CHECK-ASM: encoding: [0x32,0xdb,0x8b,0x41]
sra u22, u23, u24
# CHECK-ASM-AND-OBJ: or u25, u26, u27
# CHECK-ASM: encoding: [0xb2,0x6c,0xbd,0x01]
or u25, u26, u27
# CHECK-ASM-AND-OBJ: and u28, u29, u30
# CHECK-ASM: encoding: [0x32,0xfe,0xee,0x01]
and u28, u29, u30
# CHECK-ASM-AND-OBJ: mul u31, u1, u2
# CHECK-ASM: encoding: [0xb2,0x8f,0x20,0x02]
mul u31, u1, u2
# CHECK-ASM-AND-OBJ: mulh u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x10,0x31,0x02]
mulh u1, u2, u3
# CHECK-ASM-AND-OBJ: mulhsu u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x20,0x31,0x02]
mulhsu u1, u2, u3
# CHECK-ASM-AND-OBJ: mulhu u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x30,0x31,0x02]
mulhu u1, u2, u3
# CHECK-ASM-AND-OBJ: div u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x40,0x31,0x02]
div u1, u2, u3
# CHECK-ASM-AND-OBJ: divu u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x50,0x31,0x02]
divu u1, u2, u3
# CHECK-ASM-AND-OBJ: rem u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x60,0x31,0x02]
rem u1, u2, u3
# CHECK-ASM-AND-OBJ: remu u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x70,0x31,0x02]
remu u1, u2, u3
# CHECK-ASM-AND-OBJ: czero.eqz u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x50,0x31,0x0e]
czero.eqz u1, u2, u3
# CHECK-ASM-AND-OBJ: czero.nez u1, u2, u3
# CHECK-ASM: encoding: [0xb2,0x70,0x31,0x0e]
czero.nez u1, u2, u3
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
# CHECK-ASM-AND-OBJ: addi u1, u2, -2048
# CHECK-ASM: encoding: [0x92,0x00,0x01,0x80]
addi u1, u2, -2048
# CHECK-ASM-AND-OBJ: slti u1, u2, 2047
# CHECK-ASM: encoding: [0x92,0x20,0xf1,0x7f]
slti u1, u2, 2047
# CHECK-ASM-AND-OBJ: sltiu u1, u2, 1
# CHECK-ASM: encoding: [0x92,0x30,0x11,0x00]
sltiu u1, u2, 1
# CHECK-ASM-AND-OBJ: xori u1, u2, -1
# CHECK-ASM: encoding: [0x92,0x40,0xf1,0xff]
xori u1, u2, -1
# CHECK-ASM-AND-OBJ: ori u1, u2, 255
# CHECK-ASM: encoding: [0x92,0x60,0xf1,0x0f]
ori u1, u2, 255
# CHECK-ASM-AND-OBJ: andi u1, u2, 15
# CHECK-ASM: encoding: [0x92,0x70,0xf1,0x00]
andi u1, u2, 15
# CHECK-ASM-AND-OBJ: addiw u1, u2, -7
# CHECK-ASM: encoding: [0x9a,0x00,0x91,0xff]
addiw u1, u2, -7
# CHECK-ASM-AND-OBJ: slli u1, u2, 63
# CHECK-ASM: encoding: [0x92,0x10,0xf1,0x03]
slli u1, u2, 63
# CHECK-ASM-AND-OBJ: srli u1, u2, 33
# CHECK-ASM: encoding: [0x92,0x50,0x11,0x02]
srli u1, u2, 33
# CHECK-ASM-AND-OBJ: srai u1, u2, 1
# CHECK-ASM: encoding: [0x92,0x50,0x11,0x40]
srai u1, u2, 1
# CHECK-ASM-AND-OBJ: slliw u1, u2, 31
# CHECK-ASM: encoding: [0x9a,0x10,0xf1,0x01]
slliw u1, u2, 31
# CHECK-ASM-AND-OBJ: srliw u1, u2, 5
# CHECK-ASM: encoding: [0x9a,0x50,0x51,0x00]
srliw u1, u2, 5
# CHECK-ASM-AND-OBJ: sraiw u1, u2, 9
# CHECK-ASM: encoding: [0x9a,0x50,0x91,0x40]
sraiw u1, u2, 9
# CHECK-ASM-AND-OBJ: lui u1, 1048575
# CHECK-ASM: encoding: [0xb6,0xf0,0xff,0xff]
lui u1, 1048575
# CHECK-ASM-AND-OBJ: auipc u2, 1
# CHECK-ASM: encoding: [0x16,0x11,0x00,0x00]
auipc u2, 1
# CHECK-ASM: beq u1, u2, 16
# CHECK-OBJ: beq u1, u2, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x62,0x88,0x20,0x00]
beq u1, u2, 16
# CHECK-ASM: bne u1, u2, -16
# CHECK-OBJ: bne u1, u2, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0xe2,0x98,0x20,0xfe]
bne u1, u2, -16
# CHECK-ASM: blt u1, u2, 2048
# CHECK-OBJ: blt u1, u2, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0xe2,0xc0,0x20,0x00]
blt u1, u2, 2048
# CHECK-ASM: bge u1, u2, -4096
# CHECK-OBJ: bge u1, u2, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x62,0xd0,0x20,0x80]
bge u1, u2, -4096
# CHECK-ASM: bltu u1, u2, 8
# CHECK-OBJ: bltu u1, u2, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x62,0xe4,0x20,0x00]
bltu u1, u2, 8
# CHECK-ASM: bgeu u1, u2, 4094
# CHECK-OBJ: bgeu u1, u2, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0xe2,0xff,0x20,0x7e]
bgeu u1, u2, 4094
# CHECK-ASM-AND-OBJ: jalr u1, 12(u2)
# CHECK-ASM: encoding: [0xe6,0x00,0xc1,0x00]
jalr u1, 12(u2)
# CHECK-ASM-AND-OBJ: lb u1, -1(u2)
# CHECK-ASM: encoding: [0x82,0x00,0xf1,0xff]
lb u1, -1(u2)
# CHECK-ASM-AND-OBJ: lh u1, 2(u2)
# CHECK-ASM: encoding: [0x82,0x10,0x21,0x00]
lh u1, 2(u2)
# CHECK-ASM-AND-OBJ: lw u1, 4(u2)
# CHECK-ASM: encoding: [0x82,0x20,0x41,0x00]
lw u1, 4(u2)
# CHECK-ASM-AND-OBJ: ld u1, 8(u2)
# CHECK-ASM: encoding: [0x82,0x30,0x81,0x00]
ld u1, 8(u2)
# CHECK-ASM-AND-OBJ: lbu u1, 1(u2)
# CHECK-ASM: encoding: [0x82,0x40,0x11,0x00]
lbu u1, 1(u2)
# CHECK-ASM-AND-OBJ: lhu u1, 2(u2)
# CHECK-ASM: encoding: [0x82,0x50,0x21,0x00]
lhu u1, 2(u2)
# CHECK-ASM-AND-OBJ: lwu u1, 4(u2)
# CHECK-ASM: encoding: [0x82,0x60,0x41,0x00]
lwu u1, 4(u2)
# CHECK-ASM-AND-OBJ: sb u1, -1(u2)
# CHECK-ASM: encoding: [0xa2,0x0f,0x11,0xfe]
sb u1, -1(u2)
# CHECK-ASM-AND-OBJ: sh u1, 2(u2)
# CHECK-ASM: encoding: [0x22,0x11,0x11,0x00]
sh u1, 2(u2)
# CHECK-ASM-AND-OBJ: sw u1, 4(u2)
# CHECK-ASM: encoding: [0x22,0x22,0x11,0x00]
sw u1, 4(u2)
# CHECK-ASM-AND-OBJ: sd u1, 8(u2)
# CHECK-ASM: encoding: [0x22,0x34,0x11,0x00]
sd u1, 8(u2)
# CHECK-ASM-AND-OBJ: csrrw u1, mscratch, u2
# CHECK-ASM: encoding: [0xf2,0x10,0x01,0x34]
csrrw u1, mscratch, u2
# CHECK-ASM-AND-OBJ: csrrs u1, mhartid, u0
# CHECK-ASM: encoding: [0xf2,0x20,0x40,0xf1]
csrrs u1, mhartid, u0
# CHECK-ASM-AND-OBJ: csrrc u1, mscratch, u3
# CHECK-ASM: encoding: [0xf2,0xb0,0x01,0x34]
csrrc u1, mscratch, u3
# CHECK-ASM-AND-OBJ: csrrwi u1, mscratch, 5
# CHECK-ASM: encoding: [0xf2,0xd0,0x02,0x34]
csrrwi u1, mscratch, 5
# CHECK-ASM-AND-OBJ: csrrsi u1, mscratch, 31
# CHECK-ASM: encoding: [0xf2,0xe0,0x0f,0x34]
csrrsi u1, mscratch, 31
# CHECK-ASM-AND-OBJ: csrrci u1, mscratch, 1
# CHECK-ASM: encoding: [0xf2,0xf0,0x00,0x34]
csrrci u1, mscratch, 1
# CHECK-ASM-AND-OBJ: add a0, a1, u3
# CHECK-ASM: encoding: [0x31,0x85,0x35,0x00]
add a0, a1, u3
# CHECK-ASM-AND-OBJ: sub a0, a1, u3
# CHECK-ASM: encoding: [0x31,0x85,0x35,0x40]
sub a0, a1, u3
# CHECK-ASM-AND-OBJ: sll a0, a1, u3
# CHECK-ASM: encoding: [0x31,0x95,0x35,0x00]
sll a0, a1, u3
# CHECK-ASM-AND-OBJ: slt a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xa5,0x35,0x00]
slt a0, a1, u3
# CHECK-ASM-AND-OBJ: sltu a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xb5,0x35,0x00]
sltu a0, a1, u3
# CHECK-ASM-AND-OBJ: xor a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xc5,0x35,0x00]
xor a0, a1, u3
# CHECK-ASM-AND-OBJ: srl a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xd5,0x35,0x00]
srl a0, a1, u3
# CHECK-ASM-AND-OBJ: sra a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xd5,0x35,0x40]
sra a0, a1, u3
# CHECK-ASM-AND-OBJ: or a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xe5,0x35,0x00]
or a0, a1, u3
# CHECK-ASM-AND-OBJ: and a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xf5,0x35,0x00]
and a0, a1, u3
# CHECK-ASM-AND-OBJ: mul a0, a1, u3
# CHECK-ASM: encoding: [0x31,0x85,0x35,0x02]
mul a0, a1, u3
# CHECK-ASM-AND-OBJ: mulh a0, a1, u3
# CHECK-ASM: encoding: [0x31,0x95,0x35,0x02]
mulh a0, a1, u3
# CHECK-ASM-AND-OBJ: mulhsu a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xa5,0x35,0x02]
mulhsu a0, a1, u3
# CHECK-ASM-AND-OBJ: mulhu a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xb5,0x35,0x02]
mulhu a0, a1, u3
# CHECK-ASM-AND-OBJ: div a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xc5,0x35,0x02]
div a0, a1, u3
# CHECK-ASM-AND-OBJ: divu a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xd5,0x35,0x02]
divu a0, a1, u3
# CHECK-ASM-AND-OBJ: rem a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xe5,0x35,0x02]
rem a0, a1, u3
# CHECK-ASM-AND-OBJ: remu a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xf5,0x35,0x02]
remu a0, a1, u3
# CHECK-ASM-AND-OBJ: czero.eqz a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xd5,0x35,0x0e]
czero.eqz a0, a1, u3
# CHECK-ASM-AND-OBJ: czero.nez a0, a1, u3
# CHECK-ASM: encoding: [0x31,0xf5,0x35,0x0e]
czero.nez a0, a1, u3
# CHECK-ASM-AND-OBJ: addi a0, u5, -1
# CHECK-ASM: encoding: [0x11,0x85,0xf2,0xff]
addi a0, u5, -1
# CHECK-ASM-AND-OBJ: slti a0, u5, 3
# CHECK-ASM: encoding: [0x11,0xa5,0x32,0x00]
slti a0, u5, 3
# CHECK-ASM-AND-OBJ: sltiu a0, u5, 3
# CHECK-ASM: encoding: [0x11,0xb5,0x32,0x00]
sltiu a0, u5, 3
# CHECK-ASM-AND-OBJ: xori a0, u5, 3
# CHECK-ASM: encoding: [0x11,0xc5,0x32,0x00]
xori a0, u5, 3
# CHECK-ASM-AND-OBJ: ori a0, u5, 3
# CHECK-ASM: encoding: [0x11,0xe5,0x32,0x00]
ori a0, u5, 3
# CHECK-ASM-AND-OBJ: andi a0, u5, 3
# CHECK-ASM: encoding: [0x11,0xf5,0x32,0x00]
andi a0, u5, 3
# CHECK-ASM-AND-OBJ: slli a0, u5, 31
# CHECK-ASM: encoding: [0x11,0x95,0xf2,0x01]
slli a0, u5, 31
# CHECK-ASM-AND-OBJ: srli a0, u5, 2
# CHECK-ASM: encoding: [0x11,0xd5,0x22,0x00]
srli a0, u5, 2
# CHECK-ASM-AND-OBJ: srai a0, u5, 3
# CHECK-ASM: encoding: [0x11,0xd5,0x32,0x40]
srai a0, u5, 3
# CHECK-ASM: beq a0, u1, 16
# CHECK-OBJ: beq a0, u1, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x61,0x08,0x15,0x00]
beq a0, u1, 16
# CHECK-ASM: bne a0, u1, 16
# CHECK-OBJ: bne a0, u1, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x61,0x18,0x15,0x00]
bne a0, u1, 16
# CHECK-ASM: blt a0, u1, 16
# CHECK-OBJ: blt a0, u1, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x61,0x48,0x15,0x00]
blt a0, u1, 16
# CHECK-ASM: bge a0, u1, 16
# CHECK-OBJ: bge a0, u1, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x61,0x58,0x15,0x00]
bge a0, u1, 16
# CHECK-ASM: bltu a0, u1, 16
# CHECK-OBJ: bltu a0, u1, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x61,0x68,0x15,0x00]
bltu a0, u1, 16
# CHECK-ASM: bgeu a0, u1, 16
# CHECK-OBJ: bgeu a0, u1, {{0x[0-9a-f]+}}
# CHECK-ASM: encoding: [0x61,0x78,0x15,0x00]
bgeu a0, u1, 16
# CHECK-ASM-AND-OBJ: sb u3, 4(a0)
# CHECK-ASM: encoding: [0x21,0x02,0x35,0x00]
sb u3, 4(a0)
# CHECK-ASM-AND-OBJ: sh u3, 4(a0)
# CHECK-ASM: encoding: [0x21,0x12,0x35,0x00]
sh u3, 4(a0)
# CHECK-ASM-AND-OBJ: sw u3, 4(a0)
# CHECK-ASM: encoding: [0x21,0x22,0x35,0x00]
sw u3, 4(a0)
# CHECK-ASM-AND-OBJ: sd u3, 4(a0)
# CHECK-ASM: encoding: [0x21,0x32,0x35,0x00]
sd u3, 4(a0)
# CHECK-ASM-AND-OBJ: u.mvx u1, a0
# CHECK-ASM: encoding: [0xd2,0x00,0x05,0xf2]
u.mvx u1, a0
# CHECK-ASM-AND-OBJ: x.mvu a0, u1
# CHECK-ASM: encoding: [0x52,0x85,0x00,0xe2]
x.mvu a0, u1
# CHECK-ASM-AND-OBJ: vx_glb a0, u1, a2
# CHECK-ASM: encoding: [0x2d,0x85,0xc0,0xf0]
vx_glb a0, u1, a2
# CHECK-ASM-AND-OBJ: vx_glh a0, u1, a2
# CHECK-ASM: encoding: [0x2d,0x95,0xc0,0xf0]
vx_glh a0, u1, a2
# CHECK-ASM-AND-OBJ: vx_glw a0, u1, a2
# CHECK-ASM: encoding: [0x2d,0xa5,0xc0,0xf0]
vx_glw a0, u1, a2
# CHECK-ASM-AND-OBJ: vx_gld a0, u1, a2
# CHECK-ASM: encoding: [0x2d,0xb5,0xc0,0xf0]
vx_gld a0, u1, a2
# CHECK-ASM-AND-OBJ: vx_glbu a0, u1, a2
# CHECK-ASM: encoding: [0x2d,0xc5,0xc0,0xf0]
vx_glbu a0, u1, a2
# CHECK-ASM-AND-OBJ: vx_glhu a0, u1, a2
# CHECK-ASM: encoding: [0x2d,0xd5,0xc0,0xf0]
vx_glhu a0, u1, a2
# CHECK-ASM-AND-OBJ: vx_glwu a0, u1, a2
# CHECK-ASM: encoding: [0x2d,0xe5,0xc0,0xf0]
vx_glwu a0, u1, a2
# CHECK-ASM-AND-OBJ: vx_gsb a3, u1, a2
# CHECK-ASM: encoding: [0xad,0x86,0xc0,0xf8]
vx_gsb a3, u1, a2
# CHECK-ASM-AND-OBJ: vx_gsh a3, u1, a2
# CHECK-ASM: encoding: [0xad,0x96,0xc0,0xf8]
vx_gsh a3, u1, a2
# CHECK-ASM-AND-OBJ: vx_gsw a3, u1, a2
# CHECK-ASM: encoding: [0xad,0xa6,0xc0,0xf8]
vx_gsw a3, u1, a2
# CHECK-ASM-AND-OBJ: vx_gsd a3, u1, a2
# CHECK-ASM: encoding: [0xad,0xb6,0xc0,0xf8]
vx_gsd a3, u1, a2
