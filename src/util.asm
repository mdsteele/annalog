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

.ZEROPAGE

;;; Temporary variables that any main-thread function can use.  In general, it
;;; should be assumed that these are not preserved across function calls.
.EXPORTZP Zp_Tmp1_byte, Zp_Tmp2_byte, Zp_Tmp3_byte, Zp_Tmp4_byte, Zp_Tmp5_byte
.EXPORTZP Zp_Tmp_ptr
Zp_Tmp1_byte: .res 1
Zp_Tmp2_byte: .res 1
Zp_Tmp3_byte: .res 1
Zp_Tmp4_byte: .res 1
Zp_Tmp5_byte: .res 1
Zp_Tmp_ptr: .res 2

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

;;; Computes floor(A / Y) and (A mod Y) for unsigned inputs.
;;; @param A The 8-bit unsigned dividend.
;;; @param Y The 8-bit unsigned divisor (must be nonzero).
;;; @return A The remainder.
;;; @return Y The quotient (rounded down).
;;; @preserve X
.EXPORT Func_DivMod
.PROC Func_DivMod
    sta Zp_Tmp1_byte  ; dividend
    sty Zp_Tmp2_byte  ; divisor
    ;; The below comes from http://6502org.wikidot.com/software-math-intdiv
    lda #0
    ldy #8
    asl Zp_Tmp1_byte  ; dividend/quotient
L1: rol a
    cmp Zp_Tmp2_byte  ; divisor
    bcc L2
    sbc Zp_Tmp2_byte  ; divisor
L2: rol Zp_Tmp1_byte  ; dividend/quotient
    dey
    bne L1
    ldy Zp_Tmp1_byte  ; quotient
    rts
.ENDPROC

;;;=========================================================================;;;
