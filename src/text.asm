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

.INCLUDE "cpu.inc"
.INCLUDE "dialog.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"

.IMPORT DataA_Text0_Strings_u8_arr2_arr
.IMPORT DataA_Text1_Strings_u8_arr2_arr
.IMPORT DataA_Text2_Strings_u8_arr2_arr
.IMPORT Ram_DialogText_u8_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Given the bank/pointer returned by FuncA_Dialog_GetNextDialogTextPointer,
;;; switches the PRGA bank and decompresses the dialog text into
;;; Ram_DialogText_u8_arr.
;;; @param T2 The PRGA bank that contains the compressed dialog text.
;;; @param T1T0 A pointer to the start of the compressed dialog text.
.EXPORT FuncM_CopyDialogText
.PROC FuncM_CopyDialogText
    main_prga T2
    ldy #0
    ldx #0
    beq @readChar  ; unconditional
    @writeChar:
    sta Ram_DialogText_u8_arr, x
    inx
    iny
    @readChar:
    lda (T1T0), y
    bpl @writeChar
    cmp #kDialogTextNewline
    beq @writeChar
    bge @finish
    @substring:
    mul #2  ; also throws away uppermost bit
    sty T3  ; main string byte index
    tay  ; substring offset
    .linecont +
    .assert DataA_Text1_Strings_u8_arr2_arr = \
            DataA_Text0_Strings_u8_arr2_arr, error
    .assert DataA_Text2_Strings_u8_arr2_arr = \
            DataA_Text0_Strings_u8_arr2_arr, error
    .linecont -
    lda DataA_Text0_Strings_u8_arr2_arr, y
    sta Ram_DialogText_u8_arr, x
    inx
    iny
    lda DataA_Text0_Strings_u8_arr2_arr, y
    cmp #kDialogTextNewline + 1
    bge @finish
    sta Ram_DialogText_u8_arr, x
    inx
    ldy T3  ; main string byte index
    iny
    bne @readChar  ; unconditional
    @finish:
    sta Ram_DialogText_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;
