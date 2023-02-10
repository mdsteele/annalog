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
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sMenu_ptr
.IMPORTZP Zp_MenuItem_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; +--------+
;;; |        |
;;; |        |
;;; |   ^    |
;;; |  < >   |
;;; |   v    |
;;; |        |
;;; |        |
;;; |        |
;;; +--------+
.PROC DataA_Console_Direction_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    D_ENUM eDir, kSizeofAddr
    d_addr Up,    _LabelUp
    d_addr Down,  _LabelDown
    d_addr Left,  _LabelLeft
    d_addr Right, _LabelRight
    D_END
    .addr 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_LabelUp:    .byte kTileIdArrowUp
_LabelDown:  .byte kTileIdArrowDown
_LabelLeft:  .byte kTileIdArrowLeft
_LabelRight: .byte kTileIdArrowRight
_OnUp:
    ldx #eDir::Up
    bpl _SetItem  ; unconditional
_OnDown:
    ldx #eDir::Down
    bpl _SetItem  ; unconditional
_OnLeft:
    ldx #eDir::Left
    bpl _SetItem  ; unconditional
_OnRight:
    ldx #eDir::Right
_SetItem:
    lda Ram_MenuRows_u8_arr, x
    bmi @done
    stx Zp_MenuItem_u8
    @done:
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for a direction menu.
;;; @prereq Zp_Current_sMachine_ptr is initialized.
.EXPORT FuncA_Console_SetUpDirectionMenu
.PROC FuncA_Console_SetUpDirectionMenu
    ldax #DataA_Console_Direction_sMenu
    stax Zp_Current_sMenu_ptr
    ;; Store the starting row in Zp_Tmp1_byte.
    lda Zp_ConsoleNumInstRows_u8
    sub #3
    lsr a
    sta Zp_Tmp1_byte
    ;; Check if this machine supports moving vertically.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    tay
    and #bMachine::MoveV
    beq @noMoveVert
    ;; If so, position menu items for up/down.
    lda Zp_Tmp1_byte
    sta Ram_MenuRows_u8_arr + eDir::Up
    add #2
    sta Ram_MenuRows_u8_arr + eDir::Down
    lda #3
    sta Ram_MenuCols_u8_arr + eDir::Up
    sta Ram_MenuCols_u8_arr + eDir::Down
    @noMoveVert:
    ;; Check if this machine supports moving horizontally.
    tya  ; machine flags
    and #bMachine::MoveH
    beq @noMoveHorz
    ;; If so, position menu items for left/right.
    ldx Zp_Tmp1_byte
    inx
    stx Ram_MenuRows_u8_arr + eDir::Left
    stx Ram_MenuRows_u8_arr + eDir::Right
    lda #2
    sta Ram_MenuCols_u8_arr + eDir::Left
    lda #4
    sta Ram_MenuCols_u8_arr + eDir::Right
    @noMoveHorz:
    rts
.ENDPROC

;;;=========================================================================;;;
