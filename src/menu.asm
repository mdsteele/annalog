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

.INCLUDE "charmap.inc"
.INCLUDE "console.inc"
.INCLUDE "flag.inc"
.INCLUDE "joypad.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "menu.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"

.IMPORT FuncA_Console_DrawFieldCursorObjects
.IMPORT FuncA_Console_GetCurrentFieldType
.IMPORT FuncA_Console_GetCurrentFieldValue
.IMPORT FuncA_Console_SetCurrentFieldValue
.IMPORT FuncA_Console_TransferInstruction
.IMPORT Func_ClearRestOfOam
.IMPORT Func_DrawObjectsForRoom
.IMPORT Func_ProcessFrame
.IMPORT Func_ScrollTowardsGoal
.IMPORT Func_SetScrollGoalFromAvatar
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Console_sMachine_ptr
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The width of the console menu, in tiles.
kMenuWidthTiles = 8

;;; The topmost window row in the menu area of the console.
kMenuStartWindowRow = 1

;;; The leftmost nametable tile column in the menu area of the console.
kMenuStartTileColumn = 22

;;; The OBJ palette number used for the menu cursor.
kMenuCursorObjPalette = 0

;;;=========================================================================;;;

.ZEROPAGE

;;; A pointer to the static data for the current menu type.
Zp_Current_sMenu_ptr: .res 2

;;; The currently-selected menu item (0-15).
Zp_MenuItem_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Menu"

;;; The menu row (0-7) for each menu item, or $ff if the item is absent.
Ram_MenuRows_u8_arr: .res kMaxMenuItems

;;; The menu column (0-7) for each menu item.
Ram_MenuCols_u8_arr: .res kMaxMenuItems

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; +--------+
;;; |COPY ADD|
;;; |SWAP SUB|
;;; |GOTO MUL|
;;; |SKIP IF |
;;; |MOVE TIL|
;;; |ACT  NOP|
;;; |     END|
;;; |delete  |
;;; +--------+
.PROC DataA_Console_Opcode_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 5, 3, 3, 2, 2, 2, 3, 3, 1, 2, 2, 3, 0, 0, 2, 2
    d_addr Labels_u8_arr_ptr_arr
    .addr _LabelEmpty, _LabelCopy, _LabelSwap, _LabelAdd, _LabelSub, _LabelMul
    .addr _LabelGoto, _LabelSkip, _LabelIf, _LabelTil, _LabelAct, _LabelMove
    .addr _LabelEnd, _LabelEnd, _LabelEnd, _LabelNop
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_LabelEmpty: .byte "delete"
_LabelCopy:  .byte "COPY"
_LabelSwap:  .byte "SWAP"
_LabelAdd:   .byte "ADD"
_LabelSub:   .byte "SUB"
_LabelMul:   .byte "MUL"
_LabelGoto:  .byte "GOTO"
_LabelSkip:  .byte "SKIP"
_LabelIf:    .byte "IF"
_LabelTil:   .byte "TIL"
_LabelAct:   .byte "ACT"
_LabelMove:  .byte "MOVE"
_LabelEnd:   .byte "END"
_LabelNop:   .byte "NOP"
_OnUp:
    ldx Zp_MenuItem_u8
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    lda Ram_MenuCols_u8_arr, x
    sta Zp_Tmp2_byte  ; current menu col
    lda #0
    sta Zp_Tmp3_byte  ; best new row so far
    lda #$ff
    sta Zp_Tmp4_byte  ; best new item so far
    ;; Check all menu items, and find the lowest possible one that is still
    ;; above the current item and in the same column.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuCols_u8_arr, x
    cmp Zp_Tmp2_byte  ; current menu col
    bne @continue
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    bge @continue
    cmp Zp_Tmp3_byte  ; best new row so far
    blt @continue
    sta Zp_Tmp3_byte  ; best new row so far
    stx Zp_Tmp4_byte  ; best new item so far
    @continue:
    dex
    bpl @loop
    ;; If we found any such item, set it as the new selected item.
    lda Zp_Tmp4_byte  ; best new item so far
    bmi @doNotSet
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnDown:
    ldx Zp_MenuItem_u8
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    lda Ram_MenuCols_u8_arr, x
    sta Zp_Tmp2_byte  ; current menu col
    ;; If we don't find anything else, default to the "delete" option at the
    ;; bottom.
    ldy Zp_ConsoleNumInstRows_u8
    dey
    sty Zp_Tmp3_byte  ; best new row so far
    lda #eOpcode::Empty
    sta Zp_Tmp4_byte  ; best new item so far
    ;; Check all menu items, and find the highest possible one that is still
    ;; below the current item and in the same column.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuCols_u8_arr, x
    cmp Zp_Tmp2_byte  ; current menu col
    bne @continue
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    ble @continue
    cmp Zp_Tmp3_byte  ; best new row so far
    bge @continue
    sta Zp_Tmp3_byte  ; best new row so far
    stx Zp_Tmp4_byte  ; best new item so far
    @continue:
    dex
    bpl @loop
    ;; Set whatever we found as the new selected item.
    lda Zp_Tmp4_byte  ; best new item so far
    sta Zp_MenuItem_u8
    rts
_OnLeft:
    ldx Zp_MenuItem_u8
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuCols_u8_arr, x
    bne @continue
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    bne @continue
    stx Zp_MenuItem_u8
    rts
    @continue:
    dex
    bpl @loop
    rts
_OnRight:
    ldx Zp_MenuItem_u8
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuCols_u8_arr, x
    beq @continue
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    bne @continue
    stx Zp_MenuItem_u8
    rts
    @continue:
    dex
    bpl @loop
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an instruction opcode menu.
.PROC FuncA_Console_SetUpOpcodeMenu
    ldax #DataA_Console_Opcode_sMenu
    stax Zp_Current_sMenu_ptr
_SetColumnsForAllMenuItem:
    ldx #kMaxMenuItems - 1
    @loop:
    lda _Columns_u8_arr, x
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
_SetRowsForMenuLeftColumn:
    ldx #0
    ;; TODO: Check if COPY opcode is unlocked.
    stx Ram_MenuRows_u8_arr + eOpcode::Copy
    inx
    ;; TODO: Check if SWAP opcode is unlocked.
    stx Ram_MenuRows_u8_arr + eOpcode::Swap
    inx
    ;; TODO: Check if GOTO opcode is unlocked.
    stx Ram_MenuRows_u8_arr + eOpcode::Goto
    inx
    ;; Check if the SKIP opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeSkip >> 3)
    and #1 << (eFlag::UpgradeOpcodeSkip & $07)
    beq @noSkipOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Skip
    inx
    @noSkipOpcode:
    ;; Check if this machine supports the ACT opcode.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Console_sMachine_ptr), y
    tay
    and #bMachine::Act
    beq @noActOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Act
    inx
    @noActOpcode:
    ;; Check if this machine supports the MOVE opcode.
    tya  ; machine flags
    and #bMachine::MoveH | bMachine::MoveV
    beq @noMoveOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Move
    @noMoveOpcode:
    ;; Put an entry for the EMPTY opcode on the last row of the menu.
    ldx Zp_ConsoleNumInstRows_u8
    dex
    stx Ram_MenuRows_u8_arr + eOpcode::Empty
_SetRowsForMenuRightColumn:
    ldx #0
    ;; TODO: Check if ADD/SUB opcodes are unlocked.
    stx Ram_MenuRows_u8_arr + eOpcode::Add
    inx
    stx Ram_MenuRows_u8_arr + eOpcode::Sub
    inx
    ;; TODO: Check if MUL opcode is unlocked.
    stx Ram_MenuRows_u8_arr + eOpcode::Mul
    inx
    ;; TODO: Check if IF opcode is unlocked.
    stx Ram_MenuRows_u8_arr + eOpcode::If
    inx
    ;; Check if the TIL opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeTil >> 3)
    and #1 << (eFlag::UpgradeOpcodeTil & $07)
    beq @noTilOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Til
    inx
    @noTilOpcode:
    ;; TODO: Check if NOP opcode is unlocked.
    stx Ram_MenuRows_u8_arr + eOpcode::Nop
    inx
    ;; The END opcode is always available.
    stx Ram_MenuRows_u8_arr + eOpcode::End
    rts
_Columns_u8_arr:
    .byte 0, 0, 0, 5, 5, 5, 0, 0, 5, 5, 0, 0, 0, 5, 5, 5
.ENDPROC

;;; +--------+
;;; |        |
;;; |        |
;;; |   A    |
;;; |   B    |
;;; |   C    |
;;; |        |
;;; |        |
;;; |        |
;;; +--------+

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an L-value menu.
.PROC FuncA_Console_SetUpLValueMenu
    jmp FuncA_Console_SetUpAddressMenu  ; TODO: implement L-value menu
.ENDPROC

;;; +--------+
;;; |        |
;;; |        |
;;; |  0     |
;;; | 123 AX |
;;; | 456 BY |
;;; | 789 CZ |
;;; |        |
;;; |        |
;;; +--------+

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an R-value menu.
.PROC FuncA_Console_SetUpRValueMenu
    jmp FuncA_Console_SetUpAddressMenu  ; TODO: implement R-value menu
.ENDPROC

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
_Start:
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    .repeat kMaxMenuItems, index
    .addr _Labels + index
    .endrepeat
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_Labels: .byte "0123456789", $1a, $1b, $1c, $1d, $1e, $1f
_OnUp:
    ldx Zp_MenuItem_u8
    bne @decrement
    lda Zp_ConsoleNumInstRows_u8
    asl a
    tax
    @decrement:
    dex
    stx Zp_MenuItem_u8
    rts
_OnDown:
    lda Zp_ConsoleNumInstRows_u8
    asl a
    sta Zp_Tmp1_byte
    ldx Zp_MenuItem_u8
    inx
    cpx Zp_Tmp1_byte
    blt @setItem
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
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an instruction address menu.
.PROC FuncA_Console_SetUpAddressMenu
    ldax #DataA_Console_Address_sMenu
    stax Zp_Current_sMenu_ptr
    ;; TODO: Exclude menu items for empty instructions (and also in cursor
    ;;   movement functions above).
    ldx #0
    ldy Zp_ConsoleNumInstRows_u8
    @loop:
    txa
    sta Ram_MenuRows_u8_arr, x
    sta Ram_MenuRows_u8_arr, y
    lda #2
    sta Ram_MenuCols_u8_arr, x
    lda #5
    sta Ram_MenuCols_u8_arr, y
    iny
    inx
    cpx Zp_ConsoleNumInstRows_u8
    bne @loop
    rts
.ENDPROC

;;; +--------+
;;; |        |
;;; |  =  /  |
;;; |        |
;;; |  <  >  |
;;; |        |
;;; |  {  }  |
;;; |        |
;;; |        |
;;; +--------+
.PROC DataA_Console_Compare_sMenu
_Start:
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    .addr _LabelEq, _LabelNe, _LabelLt, _LabelGt, _LabelLe, _LabelGe
    .addr 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_LabelEq: .byte "="
_LabelNe: .byte $0a
_LabelLt: .byte "<"
_LabelGt: .byte ">"
_LabelLe: .byte $0d
_LabelGe: .byte $0e
_OnUp:
    lda Zp_MenuItem_u8
    sub #2
    bge _SetItem
    rts
_OnDown:
    lda Zp_MenuItem_u8
    add #2
    cmp #6
    blt _SetItem
    rts
_OnLeft:
    lda Zp_MenuItem_u8
    and #$06
    bpl _SetItem  ; unconditional
_OnRight:
    lda Zp_MenuItem_u8
    ora #$01
_SetItem:
    sta Zp_MenuItem_u8
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for a comparison operator menu.
.PROC FuncA_Console_SetUpCompareMenu
    ldax #DataA_Console_Compare_sMenu
    stax Zp_Current_sMenu_ptr
    ;; Store the starting row in Zp_Tmp1_byte.
    lda Zp_ConsoleNumInstRows_u8
    sub #5
    lsr a
    sta Zp_Tmp1_byte
    ;; Set up rows and cols.
    ldx #5
    @loop:
    txa
    and #$06
    add Zp_Tmp1_byte
    sta Ram_MenuRows_u8_arr, x
    txa
    and #$01
    bne @rightCol
    lda #2
    bne @setCol  ; unconditional
    @rightCol:
    lda #5
    @setCol:
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
    rts
.ENDPROC

;;; +--------+
;;; |        |
;;; |   ^    |
;;; |        |
;;; | <   >  |
;;; |        |
;;; |   v    |
;;; |        |
;;; |        |
;;; +--------+
.PROC DataA_Console_Direction_sMenu
_Start:
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    .addr _LabelUp, _LabelDown, _LabelLeft, _LabelRight
    .addr 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_LabelUp:    .byte $5a
_LabelDown:  .byte $5b
_LabelLeft:  .byte $5c
_LabelRight: .byte $5d
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
.PROC FuncA_Console_SetUpDirectionMenu
    ldax #DataA_Console_Direction_sMenu
    stax Zp_Current_sMenu_ptr
    ;; Store the starting row in Zp_Tmp1_byte.
    lda Zp_ConsoleNumInstRows_u8
    sub #5
    lsr a
    sta Zp_Tmp1_byte
    ;; Check if this machine supports moving vertically.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Console_sMachine_ptr), y
    tay
    and #bMachine::MoveV
    beq @noMoveVert
    ;; If so, position menu items for up/down.
    lda Zp_Tmp1_byte
    sta Ram_MenuRows_u8_arr + eDir::Up
    add #4
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
    inx
    stx Ram_MenuRows_u8_arr + eDir::Left
    stx Ram_MenuRows_u8_arr + eDir::Right
    lda #1
    sta Ram_MenuCols_u8_arr + eDir::Left
    lda #5
    sta Ram_MenuCols_u8_arr + eDir::Right
    @noMoveHorz:
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Zp_MenuItem_u8, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for editing the currently-selected field.
.PROC FuncA_Console_SetUpCurrentFieldMenu
    ;; Clear items.
    lda #$ff
    ldx #kMaxMenuItems - 1
    @loop:
    sta Ram_MenuRows_u8_arr, x
    dex
    bpl @loop
    ;; Set current menu item.
    jsr FuncA_Console_GetCurrentFieldValue  ; returns A
    sta Zp_MenuItem_u8
    ;; Jump to field-type-specific setup function.
    jsr FuncA_Console_GetCurrentFieldType  ; returns A
    asl a
    tay
    lda _JumpTable_ptr_arr + 0, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_arr + 1, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_arr:
    .addr FuncA_Console_SetUpOpcodeMenu
    .addr FuncA_Console_SetUpLValueMenu
    .addr FuncA_Console_SetUpRValueMenu
    .addr FuncA_Console_SetUpAddressMenu
    .addr FuncA_Console_SetUpCompareMenu
    .addr FuncA_Console_SetUpDirectionMenu
.ENDPROC

;;; Transfers the specified menu row (0-7) to the PPU.
;;; @param X The menu row to transfer.
;;; @preserve X
.PROC FuncA_Console_TransferMenuRow
    stx Zp_Tmp3_byte  ; menu row
_WriteTransferEntryHeader:
    ;; Get the transfer destination address, and store it in Zp_Tmp1_byte (lo)
    ;; and Zp_Tmp2_byte (hi).
    .assert kMenuStartWindowRow = 1, error
    inx
    txa  ; window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    tya
    add #kMenuStartTileColumn
    sta Zp_Tmp1_byte  ; transfer destination (lo)
    txa
    adc #0
    sta Zp_Tmp2_byte  ; transfer destination (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kMenuWidthTiles
    sta Zp_PpuTransferLen_u8
    ;; Write the transfer entry header.
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp2_byte  ; transfer destination (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp1_byte  ; transfer destination (lo)
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kMenuWidthTiles
    sta Ram_PpuTransfer_arr, x
    inx
_InitTransferData:
    ;; Fill the transfer data with spaces for now.
    stx Zp_Tmp1_byte  ; start of transfer data
    lda #0
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    cpx Zp_PpuTransferLen_u8
    bne @loop
_TransferLabels:
    ;; Update the transfer data with any menu labels in this row.
    ldy #kMaxMenuItems - 1
    @itemLoop:
    lda Ram_MenuRows_u8_arr, y
    cmp Zp_Tmp3_byte  ; menu row
    bne @noLabel
    sty Zp_Tmp2_byte  ; item index
    ;; Make Zp_Tmp_ptr point to start of the label string.
    tya
    asl a
    add #sMenu::Labels_u8_arr_ptr_arr
    tay
    lda (Zp_Current_sMenu_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMenu_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Set Zp_Tmp4_byte to the (width - 1) of the label.
    lda Zp_Tmp2_byte  ; item index
    add #sMenu::WidthsMinusOne_u8_arr
    tay
    lda (Zp_Current_sMenu_ptr), y  ; item width
    sta Zp_Tmp4_byte  ; the label's (width - 1)
    ;; Set X to the PPU transfer array index for the last byte in the label.
    adc Ram_MenuCols_u8_arr, y  ; starting menu col
    adc Zp_Tmp1_byte  ; start of transfer data
    tax
    ;; Copy the label into the PPU transfer entry.
    ldy Zp_Tmp4_byte  ; the label's (width - 1)
    @labelLoop:
    lda (Zp_Tmp_ptr), y  ; label chr
    sta Ram_PpuTransfer_arr, x
    dex
    dey
    bpl @labelLoop
    ;; Restore Y as the item loop index, and move on to the next item (if any).
    ldy Zp_Tmp2_byte  ; item index
    @noLabel:
    dey
    bpl @itemLoop
    ldx Zp_Tmp3_byte  ; menu row
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the console menu cursor.
.PROC FuncA_Console_DrawMenuCursorObjects
    ldx Zp_MenuItem_u8
_XPosition:
    lda Ram_MenuCols_u8_arr, x
    mul #kTileWidthPx
    add #kMenuStartTileColumn * kTileWidthPx
    sta Zp_Tmp2_byte  ; cursor left X-position, in pixels
_CursorWidth:
    txa
    add #sMenu::WidthsMinusOne_u8_arr
    tay
    lda (Zp_Current_sMenu_ptr), y
    sta Zp_Tmp3_byte  ; cursor (width - 1), in tiles
_YPosition:
    ;; Calculate the window row that the cursor is in.
    lda Ram_MenuRows_u8_arr, x
    add #kMenuStartWindowRow
    ;; Calculate the Y-position of the objects and store in Zp_Tmp1_byte.
    mul #kTileHeightPx
    adc Zp_WindowTop_u8  ; carry will by clear
    adc #$ff  ; subtract 1 (carry will still be clear)
    sta Zp_Tmp1_byte  ; cursor Y-position, in pixels
_PrepareForLoop:
    ldx Zp_Tmp3_byte  ; cursor (width - 1), in tiles
    ldy Zp_OamOffset_u8
_ObjectLoop:
    ;; Set Y-position.
    lda Zp_Tmp1_byte  ; Y-position
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    ;; Set and increment X-position.
    lda Zp_Tmp2_byte  ; X-position
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta Zp_Tmp2_byte  ; X-position
    ;; Set flags.
    lda #bObj::Pri | kMenuCursorObjPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set tile ID.
    lda Zp_Tmp3_byte  ; cursor (width - 1), in tiles
    beq @tileSingle
    cpx Zp_Tmp3_byte  ; cursor (width - 1), in tiles
    beq @tileLeft
    txa
    beq @tileRight
    @tileMiddle:
    lda #kConsoleObjTileIdCursorSolidMiddle
    bne @setTile  ; unconditional
    @tileRight:
    lda #kConsoleObjTileIdCursorSolidRight
    bne @setTile  ; unconditional
    @tileLeft:
    lda #kConsoleObjTileIdCursorSolidLeft
    bne @setTile  ; unconditional
    @tileSingle:
    lda #kConsoleObjTileIdCursorSolidSingle
    @setTile:
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Move offset to the next object.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    dex
    bpl _ObjectLoop
    sty Zp_OamOffset_u8
    rts
.ENDPROC

;;; Moves the console menu cursor (updating Zp_MenuItem_u8 appropriately) based
;;; on the current joypad state.
.PROC FuncA_Console_MoveMenuCursor
_MoveCursorUp:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Up
    beq @noUp
    ldy #sMenu::OnUp_func_ptr
    jsr _MenuFunc
    @noUp:
_MoveCursorDown:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    beq @noDown
    ldy #sMenu::OnDown_func_ptr
    jsr _MenuFunc
    @noDown:
_MoveCursorLeft:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Left
    beq @noLeft
    ldy #sMenu::OnLeft_func_ptr
    jsr _MenuFunc
    @noLeft:
_MoveCursorRight:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Right
    beq @noRight
    ldy #sMenu::OnRight_func_ptr
    jsr _MenuFunc
    @noRight:
    rts
_MenuFunc:
    lda (Zp_Current_sMenu_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sMenu_ptr), y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8_Menu"

;;; Mode for the console instruction field editing menu.
;;; TODO: Make this a Main that jumps back to console edit mode when done.
.EXPORT Func_Menu_EditSelectedField
.PROC Func_Menu_EditSelectedField
    prga_bank #<.bank(FuncA_Console_SetUpCurrentFieldMenu)
    jsr FuncA_Console_SetUpCurrentFieldMenu
_TransferMenuRows:
    ldx #0  ; param: menu row to transfer
    @loop:
    jsr FuncA_Console_TransferMenuRow  ; preserves X
    inx
    cpx Zp_ConsoleNumInstRows_u8
    blt @loop
_GameLoop:
    prga_bank #<.bank(FuncA_Console_DrawMenuCursorObjects)
    jsr FuncA_Console_DrawMenuCursorObjects
    jsr FuncA_Console_DrawFieldCursorObjects
    jsr Func_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckForCancel:
    prga_bank #<.bank(FuncA_Console_MoveMenuCursor)
    ;; B button:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::BButton
    bne _Cancel
    ;; A button:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton
    bne _Finish
    ;; D-pad:
    jsr FuncA_Console_MoveMenuCursor
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr Func_ScrollTowardsGoal
    jmp _GameLoop
_Finish:
    lda Zp_MenuItem_u8
    jsr FuncA_Console_SetCurrentFieldValue
    ;; TODO: If the current instruction is now Empty, remove it (updating any
    ;;   GOTO instruction addresses as needed), set the current
    ;;   field/column to zero, and redraw all instructions (over a couple of
    ;;   frames) instead of just the current instruction.
    prga_bank #<.bank(FuncA_Console_TransferInstruction)
    jsr FuncA_Console_TransferInstruction
    ;; TODO: If the current instruction was previously empty, and the next
    ;;   instruction is empty, then redraw the next instruction too.
_Cancel:
    ;; TODO: Redraw the status box over the menu.
    rts
.ENDPROC

;;;=========================================================================;;;
