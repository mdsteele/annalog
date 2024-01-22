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

.INCLUDE "../src/macros.inc"

.IMPORT Exit_Success
.IMPORT Func_DivMod
.IMPORT Func_ExpectAEqualsY
.IMPORT Func_SignedDivFrac
.IMPORT Func_SignedMult
.IMPORT Func_UnsignedDivFrac
.IMPORT Func_UnsignedMult

;;;=========================================================================;;;

.CODE

.PROC Func_TestUnsignedMult
    ldx #0
_Loop:
    lda _Multiplicands_u8_arr, x
    ldy _Multipliers_u8_arr, x
    jsr Func_UnsignedMult  ; preserves X, returns YA
    pha  ; actual (lo)
    tya  ; actual (hi)
    ldy _Products_u16_1_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    pla  ; actual (lo)
    ldy _Products_u16_0_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    inx
    cpx #_Multipliers_u8_arr - _Multiplicands_u8_arr
    blt _Loop
    rts
_Multiplicands_u8_arr:
    .byte $30, $27, $a7, $ff, $00
_Multipliers_u8_arr:
    .byte $05, $13, $c1, $00, $ff
_Products_u16_0_arr:
    .byte $f0, $e5, $e7, $00, $00
_Products_u16_1_arr:
    .byte $00, $02, $7d, $00, $00
.ENDPROC

.PROC Func_TestSignedMult
    ldx #0
_Loop:
    lda _Multiplicands_i8_arr, x
    ldy _Multipliers_u8_arr, x
    jsr Func_SignedMult  ; preserves X, returns YA
    pha  ; actual (lo)
    tya  ; actual (hi)
    ldy _Products_i16_1_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    pla  ; actual (lo)
    ldy _Products_i16_0_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    inx
    cpx #_Multipliers_u8_arr - _Multiplicands_i8_arr
    blt _Loop
    rts
_Multiplicands_i8_arr:
    .byte $00, $30, $27, $ff, $ff, $a7
_Multipliers_u8_arr:
    .byte $ff, $05, $13, $00, $03, $c1
_Products_i16_0_arr:
    .byte $00, $f0, $e5, $00, $fd, $e7
_Products_i16_1_arr:
    .byte $00, $00, $02, $00, $ff, $bc
.ENDPROC

.PROC Func_TestDivMod
    ldx #0
_Loop:
    lda _Dividends_u8_arr, x
    ldy _Divisors_u8_arr, x
    jsr Func_DivMod  ; preserves X, returns Y=quotient and A=remainder
    pha  ; actual remainder
    tya  ; actual quotient
    ldy _Quotients_u8_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    pla  ; actual remainder
    ldy _Remainders_u8_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    inx
    cpx #_Divisors_u8_arr - _Dividends_u8_arr
    blt _Loop
    rts
_Dividends_u8_arr:
    .byte 7, 237, 237, 255, 17, 99
_Divisors_u8_arr:
    .byte 3,   7, 255,  51, 17,  1
_Quotients_u8_arr:
    .byte 2,  33,   0,   5,  1, 99
_Remainders_u8_arr:
    .byte 1,   6, 237,   0,  0,  0
.ENDPROC

.PROC Func_TestUnsignedDivFrac
    ldx #0
_Loop:
    lda _Dividends_u8_arr, x
    ldy _Divisors_u8_arr, x
    jsr Func_UnsignedDivFrac  ; preserves X, returns YA
    pha  ; actual quotient (lo)
    tya  ; actual quotient (hi)
    ldy _Quotients_u16_1_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    pla  ; actual quotient (lo)
    ldy _Quotients_u16_0_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    inx
    cpx #_Divisors_u8_arr - _Dividends_u8_arr
    blt _Loop
    rts
_Dividends_u8_arr:
    .byte   7, 237,   3, 127, 255, 237, 255, 17, 99
_Divisors_u8_arr:
    .byte   3,   7,  10, 113, 237, 255,  51, 17,  1
_Quotients_u16_1_arr:
    .byte   2,  33,   0,   1,   1,   0,   5,  1, 99
_Quotients_u16_0_arr:
    .byte $55, $db, $4c, $1f, $13, $ed,   0,  0,  0
.ENDPROC

.PROC Func_TestSignedDivFrac
    ldx #0
_Loop:
    lda _Dividends_i8_arr, x
    ldy _Divisors_u8_arr, x
    jsr Func_SignedDivFrac  ; preserves X, returns YA
    pha  ; actual quotient (lo)
    tya  ; actual quotient (hi)
    ldy _Quotients_i16_1_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    pla  ; actual quotient (lo)
    ldy _Quotients_i16_0_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    inx
    cpx #_Divisors_u8_arr - _Dividends_i8_arr
    blt _Loop
    rts
_Dividends_i8_arr:
    .byte   7, <-7,   3, 127, <-127, <-127
_Divisors_u8_arr:
    .byte   3,   3,  10, 113,   113,   127
_Quotients_i16_1_arr:
    .byte $02, $fd,   0,   1,   $fe,   <-1
_Quotients_i16_0_arr:
    .byte $55, $ab, $4c, $1f,   $e1,     0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
RunTests:
    jsr Func_TestUnsignedMult
    jsr Func_TestSignedMult
    jsr Func_TestDivMod
    jsr Func_TestUnsignedDivFrac
    jsr Func_TestSignedDivFrac
Success:
    jmp Exit_Success

;;;=========================================================================;;;
