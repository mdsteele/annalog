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

.INCLUDE "../macros.inc"
.INCLUDE "../menu.inc"
.INCLUDE "../program.inc"

.IMPORT DataA_Console_NumberLabels_u8_arr
.IMPORT Ram_Console_sProgram
.IMPORT Ram_MenuCols_u8_arr
.IMPORT Ram_MenuRows_u8_arr
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_MenuItem_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; +--------+
;;; |  0  8  |
;;; |  1  9  |
;;; |  2  a  |
;;; |  3  b  |
;;; |  4  c  |
;;; |  5  d  |
;;; |  6  e  |
;;; |  7  f  |
;;; +--------+
.PROC DataA_Console_Address_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    .repeat kMaxMenuItems, index
    .addr DataA_Console_NumberLabels_u8_arr + index
    .endrepeat
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_OnUp:
    ldx Zp_MenuItem_u8
    dex
    bpl @setItem
    ldx Zp_MachineMaxInstructions_u8
    @loop:
    dex
    lda Ram_MenuRows_u8_arr, x
    bmi @loop
    @setItem:
    stx Zp_MenuItem_u8
    rts
_OnDown:
    ldx Zp_MenuItem_u8
    inx
    lda Ram_MenuRows_u8_arr, x
    bpl @setItem
    ldx #0
    @setItem:
    stx Zp_MenuItem_u8
    rts
_OnLeft:
    lda Zp_MenuItem_u8
    sub Zp_ConsoleNumInstRows_u8
    bmi @doNotSet
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnRight:
    lda Zp_MenuItem_u8
    cmp Zp_ConsoleNumInstRows_u8
    bge @doNotSet
    add Zp_ConsoleNumInstRows_u8
    tax
    lda Ram_MenuRows_u8_arr, x
    bmi @doNotSet
    stx Zp_MenuItem_u8
    @doNotSet:
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an instruction address menu.
.EXPORT FuncA_Console_SetUpAddressMenu
.PROC FuncA_Console_SetUpAddressMenu
    ldax #DataA_Console_Address_sMenu
    stax Zp_Current_sMenu_ptr
    ldx #0
    ldy #sIns::Op_byte
    @loop:
    lda Ram_Console_sProgram, y
    and #$f0
    beq @done
    txa
    sub Zp_ConsoleNumInstRows_u8
    bge @rightColumn
    @leftColumn:
    txa
    sta Ram_MenuRows_u8_arr, x
    lda #2
    bne @setCol  ; unconditional
    @rightColumn:
    sta Ram_MenuRows_u8_arr, x
    lda #5
    @setCol:
    sta Ram_MenuCols_u8_arr, x
    inx
    .repeat .sizeof(sIns)
    iny
    .endrepeat
    cpx Zp_MachineMaxInstructions_u8
    blt @loop
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
