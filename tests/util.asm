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

;;;=========================================================================;;;

.CODE

Data_Dividends_u8_arr:
    .byte 7, 237, 237, 255, 17, 99
Data_Divisors_u8_arr:
    .byte 3,   7, 255,  51, 17,  1
Data_Quotients_u8_arr:
    .byte 2,  33,   0,   5,  1, 99
Data_Remainders_u8_arr:
    .byte 1,   6, 237,   0,  0,  0
kNumTests = * - Data_Remainders_u8_arr

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
    inx  ; now X is zero
TestLoop:
    lda Data_Dividends_u8_arr, x
    ldy Data_Divisors_u8_arr, x
    jsr Func_DivMod  ; preserves X, returns Y=quotient and A=remainder
    pha  ; actual remainder
    tya  ; actual quotient
    ldy Data_Quotients_u8_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    pla  ; actual remainder
    ldy Data_Remainders_u8_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    inx
    cpx #kNumTests
    blt TestLoop
Success:
    jmp Exit_Success

;;;=========================================================================;;;
