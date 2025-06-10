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
.IMPORT Func_ClearFlag
.IMPORT Func_ExpectZIsClear
.IMPORT Func_ExpectZIsSet
.IMPORT Func_IsFlagSet
.IMPORT Func_SetFlag

;;;=========================================================================;;;

.BSS

.EXPORT Ram_ProgressFlags_arr
.PROC Ram_ProgressFlags_arr
    .res $100 / 8
.ENDPROC

;;;=========================================================================;;;

.CODE

.EXPORT Data_PowersOfTwo_u8_arr8
.PROC Data_PowersOfTwo_u8_arr8
    .repeat 8, i
    .byte 1 << i
    .endrepeat
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
ZeroSram:
    lda #0
    ldx #.sizeof(Ram_ProgressFlags_arr)
    @loop:
    dex
    sta Ram_ProgressFlags_arr, x
    bne @loop
Tests:
    ;; Flags 9 and 10 are initially clear.
    ldx #9  ; param: flag
    jsr Func_IsFlagSet
    jsr Func_ExpectZIsSet
    ldx #10  ; param: flag
    jsr Func_IsFlagSet
    jsr Func_ExpectZIsSet
    ;; Set flag 9.  Flag 10 should be unaffected.
    ldx #9  ; param: flag
    jsr Func_SetFlag
    ldx #9  ; param: flag
    jsr Func_IsFlagSet
    jsr Func_ExpectZIsClear
    ldx #10  ; param: flag
    jsr Func_IsFlagSet
    jsr Func_ExpectZIsSet
    ;; Set flag 10.  Now both flags should be set.
    ldx #10  ; param: flag
    jsr Func_SetFlag
    ldx #9  ; param: flag
    jsr Func_IsFlagSet
    jsr Func_ExpectZIsClear
    ldx #10  ; param: flag
    jsr Func_IsFlagSet
    jsr Func_ExpectZIsClear
    ;; Clear flag 9.  Now only flag 10 should be set.
    ldx #9  ; param: flag
    jsr Func_ClearFlag
    ldx #9  ; param: flag
    jsr Func_IsFlagSet
    jsr Func_ExpectZIsSet
    ldx #10  ; param: flag
    jsr Func_IsFlagSet
    jsr Func_ExpectZIsClear
Success:
    jmp Exit_Success

;;;=========================================================================;;;
