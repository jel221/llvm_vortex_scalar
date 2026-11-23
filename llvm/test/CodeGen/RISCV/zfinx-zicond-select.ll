; RUN: llc -mtriple=riscv32 -mattr=+zfinx,+zicond -verify-machineinstrs < %s | FileCheck %s

; Under Zfinx an f32 lives in a GPR, so Zicond selects it without a branch.
define float @fmin_select(float %a, float %b) {
; CHECK-LABEL: fmin_select:
; CHECK:       flt.s a2, a0, a1
; CHECK-NEXT:  czero.nez a1, a1, a2
; CHECK-NEXT:  czero.eqz a0, a0, a2
; CHECK-NEXT:  or a0, a0, a1
; CHECK:       ret
  %c = fcmp olt float %a, %b
  %r = select i1 %c, float %a, float %b
  ret float %r
}

define float @select_zero(i1 %c, float %a) {
; CHECK-LABEL: select_zero:
; CHECK-NOT:   b{{eq|ne}}z
; CHECK:       czero.eqz
; CHECK:       ret
  %r = select i1 %c, float %a, float 0.0
  ret float %r
}
