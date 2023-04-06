;;;=========================================================================;;;
;;; Copyright 2022 Matthew D. Steele <mdsteele@alum.mit.edu>                ;;;
;;;                                                                         ;;;
;;; This file is part of Annalog.                                           ;;;
;;;                                                                         ;;;
;;; Annalog is free software: you can redistribute it and/or modify it      ;;;
;;; under the terms of the GNU General Public License as published by the   ;;;
;;; Free Software Foundation, either version 3 of the License, or (at your  ;;;
;;; option) any later version.                                              ;;;
;;;                                                                         ;;;
;;; Annalog is distributed in the hope that it will be useful, but WITHOUT  ;;;
;;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or   ;;;
;;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License   ;;;
;;; for more details.                                                       ;;;
;;;                                                                         ;;;
;;; You should have received a copy of the GNU General Public License along ;;;
;;; with Annalog.  If not, see <http://www.gnu.org/licenses/>.              ;;;
;;;=========================================================================;;;

.INCLUDE "macros.inc"

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Does nothing and returns immediately.  Can be used as a null function
;;; pointer.
.EXPORT Func_Noop
.PROC Func_Noop
    rts
.ENDPROC

;;; Maps from N to 2^N for 0 <= N < 8.
.EXPORT Data_PowersOfTwo_u8_arr8
.PROC Data_PowersOfTwo_u8_arr8
    .repeat 8, i
    .byte 1 << i
    .endrepeat
.ENDPROC

;;; Computes A * Y for unsigned A and Y.
;;; @param A The 8-bit unsigned multiplicand.
;;; @param Y The 8-bit unsigned multiplier.
;;; @return YA The 16-bit unsigned product.
;;; @preserve X, T2+
.EXPORT Func_UnsignedMult
.PROC Func_UnsignedMult
    sty T0
    sta T1
    ;; This comes from https://www.lysator.liu.se/~nisse/misc/6502-mul.html
    lda #0
    ldy #8
    lsr T0
    @loop:
    bcc @noAdd
    add T1
    @noAdd:
    ror a
    ror T0
    dey
    bne @loop
    tay     ; unsigned product (hi)
    lda T0  ; unsigned product (lo)
    rts
.ENDPROC

;;; Computes A * Y for signed A and unsigned Y.
;;; @param A The 8-bit signed multiplicand.
;;; @param Y The 8-bit unsigned multiplier.
;;; @return YA The 16-bit signed product.
;;; @preserve X, T2+
.EXPORT Func_SignedMult
.PROC Func_SignedMult
    ora #0
    bpl Func_UnsignedMult  ; preserves X and T2+, returns YA
    eor #$ff
    add #1
    jsr Func_UnsignedMult  ; preserves X and T2+, returns YA
    eor #$ff
    add #1
    pha  ; signed product (lo)
    tya
    eor #$ff
    adc #0
    tay  ; signed product (hi)
    pla  ; signed product (lo)
    rts
.ENDPROC

;;; Computes floor(A / Y) and (A mod Y) for unsigned inputs.
;;; @param A The 8-bit unsigned dividend.
;;; @param Y The 8-bit unsigned divisor (must be nonzero).
;;; @return A The remainder.
;;; @return Y The quotient (rounded down).
;;; @preserve X, T2+
.EXPORT Func_DivMod
.PROC Func_DivMod
    sta T0  ; dividend
    sty T1  ; divisor
    ;; The below comes from http://6502org.wikidot.com/software-math-intdiv
    lda #0
    ldy #8
    asl T0  ; dividend/quotient
L1: rol a
    cmp T1  ; divisor
    bcc L2
    sbc T1  ; divisor
L2: rol T0  ; dividend/quotient
    dey
    bne L1
    ldy T0  ; quotient
    rts
.ENDPROC

;;;=========================================================================;;;
