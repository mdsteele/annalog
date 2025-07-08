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

.IMPORT Func_Noop
.IMPORT Ram_MenuCols_u8_arr
.IMPORT Ram_MenuRows_u8_arr
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_MenuItem_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; +--------+
;;; | DEBUG  |
;;; | ERASE  |
;;; |        |
;;; |        |
;;; |        |
;;; |        |
;;; |        |
;;; | cancel |
;;; +--------+
.PROC DataA_Console_Debug_sMenu
    D_STRUCT sMenu
    d_byte Type_eField, eField::Debug
    d_byte WidthsMinusOne_u8_arr
    .byte 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    D_ARRAY .enum, eDebug, kSizeofAddr
    d_addr StartDebugger, _LabelDebug
    d_addr EraseProgram,  _LabelErase
    d_addr Cancel,        _LabelCancel
    D_END
    .addr 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  Func_Noop
    d_addr OnRight_func_ptr, Func_Noop
    D_END
_LabelDebug:  .byte " DEBUG  "
_LabelErase:  .byte " ERASE  "
_LabelCancel: .byte " cancel "
_OnUp:
    ldy Zp_MenuItem_u8
    @loop:
    dey
    bmi _Return
    lda Ram_MenuRows_u8_arr, y
    bmi @loop
    bpl _SetMenuItem  ; unconditional
_OnDown:
    ldy Zp_MenuItem_u8
    @loop:
    iny
    cpy #eDebug::NUM_VALUES
    bge _Return
    lda Ram_MenuRows_u8_arr, y
    bmi @loop
_SetMenuItem:
    sty Zp_MenuItem_u8
_Return:
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for the debug menu.
.EXPORT FuncA_Console_SetUpDebugMenu
.PROC FuncA_Console_SetUpDebugMenu
    ldax #DataA_Console_Debug_sMenu
    stax Zp_Current_sMenu_ptr
    ;; Set menu item cols and rows.
    ldx #eDebug::NUM_VALUES - 1
    @loop:
    lda #0
    sta Ram_MenuCols_u8_arr, x
    txa
    sta Ram_MenuRows_u8_arr, x
    dex
    .assert eDebug::NUM_VALUES <= $80, error
    bpl @loop
    ;; Put "cancel" in the last row.
    ldy Zp_ConsoleNumInstRows_u8
    dey
    sty Ram_MenuRows_u8_arr + eDebug::Cancel
    rts
.ENDPROC

;;;=========================================================================;;;
