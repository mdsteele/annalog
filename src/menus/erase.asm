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

.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../menu.inc"
.INCLUDE "../program.inc"

.IMPORT Ram_MenuCols_u8_arr
.IMPORT Ram_MenuRows_u8_arr
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_MenuItem_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; +--------+
;;; |        |
;;; |        |
;;; | Erase  |
;;; |program?|
;;; |        |
;;; |YES   NO|
;;; |        |
;;; |        |
;;; +--------+
.PROC DataA_Console_Erase_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 1, 2, 4, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    .addr _LabelNo, _LabelYes, _LabelErase, _LabelProgram
    .addr 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_LabelNo:      .byte "NO"
_LabelYes:     .byte "YES"
_LabelErase:   .byte "Erase"
_LabelProgram: .byte "program?"
_OnLeft:
    ldx #1  ; "YES"
    bpl _SetItem  ; unconditional
_OnRight:
    ldx #0  ; "NO"
_SetItem:
    stx Zp_MenuItem_u8
_OnUp:
_OnDown:
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for the erase program menu.
.EXPORT FuncA_Console_SetUpEraseMenu
.PROC FuncA_Console_SetUpEraseMenu
    ldax #DataA_Console_Erase_sMenu
    stax Zp_Current_sMenu_ptr
    ;; Store the starting row in Y.
    lda Zp_ConsoleNumInstRows_u8
    sub #4
    div #2
    tay  ; starting row
    ;; Set menu item rows.
    sty Ram_MenuRows_u8_arr + 2  ; "Erase"
    iny
    sty Ram_MenuRows_u8_arr + 3  ; "program?"
    iny
    iny
    sty Ram_MenuRows_u8_arr + 0  ; "NO"
    sty Ram_MenuRows_u8_arr + 1  ; "YES"
    ;; Set menu item cols.
    ldx #0
    stx Ram_MenuCols_u8_arr + 3  ; "program?"
    stx Ram_MenuCols_u8_arr + 1  ; "YES"
    inx
    stx Ram_MenuCols_u8_arr + 2  ; "Erase"
    ldx #6
    stx Ram_MenuCols_u8_arr + 0  ; "NO"
    rts
.ENDPROC

;;; Determines if the current menu is the erase program menu.
;;; @prereq Zp_Current_sMenu_ptr is initialized.
;;; @return Z Set if Zp_Current_sMenu_ptr is set to the erase program menu.
.EXPORT FuncA_Console_IsEraseMenuActive
.PROC FuncA_Console_IsEraseMenuActive
    lda Zp_Current_sMenu_ptr + 0
    cmp #<DataA_Console_Erase_sMenu
    bne @done
    lda Zp_Current_sMenu_ptr + 1
    cmp #>DataA_Console_Erase_sMenu
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
