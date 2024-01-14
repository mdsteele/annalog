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
.IMPORT Func_Cosine
.IMPORT Func_ExpectAEqualsY
.IMPORT Func_SignedAtan2
.IMPORT Func_Sine

;;;=========================================================================;;;

.CODE

Data_InputAngles_u8_arr:
    .byte $00, $10, $3f, $40, $41, $50, $80, $90, $c0, $d0
Data_Sines_i8_arr:
    .byte $00, $31, $7f, $7f, $7f, $75, $00, $cf, $81, $8b
Data_Cosines_i8_arr:
    .byte $7f, $75, $03, $00, $fd, $cf, $81, $8b, $00, $31
kNumSineTests = * - Data_Cosines_i8_arr

Data_InputX_i8_arr:
    .byte   5,   5,   0, <-5, <-5, <-5,   0,   5,  47
Data_InputY_i8_arr:
    .byte   0,   5,   5,   5,   0, <-5, <-5, <-5, 123
Data_Arctangents_u8_arr:
    .byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $33
kNumAtan2Tests = * - Data_Arctangents_u8_arr

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
SineTestSetup:
    ldx #0
SineTestLoop:
    lda Data_InputAngles_u8_arr, x
    jsr Func_Sine  ; preserves X, returns A
    ldy Data_Sines_i8_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    lda Data_InputAngles_u8_arr, x
    jsr Func_Cosine  ; preserves X, returns A
    ldy Data_Cosines_i8_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    inx
    cpx #kNumSineTests
    blt SineTestLoop
Atan2TestSetup:
    ldx #0
Atan2TestLoop:
    stx T4  ; loop index
    ldy Data_InputY_i8_arr, x  ; param: signed Y-position
    lda Data_InputX_i8_arr, x
    tax                        ; param: signed X-position
    jsr Func_SignedAtan2  ; preserves T4+, returns A
    ldx T4  ; loop index
    ldy Data_Arctangents_u8_arr, x
    jsr Func_ExpectAEqualsY  ; preserves X
    inx
    cpx #kNumAtan2Tests
    blt Atan2TestLoop
Success:
    jmp Exit_Success

;;;=========================================================================;;;
