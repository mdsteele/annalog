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
.INCLUDE "cpu.inc"
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
.IMPORT FuncA_Console_TransferAllInstructions
.IMPORT FuncA_Console_TransferAllStatusRows
.IMPORT FuncA_Console_TransferInstruction
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_ClearRestOfOam
.IMPORT Func_MachineTick
.IMPORT Func_ProcessFrame
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Main_Console_ContinueEditing
.IMPORT Ram_ConsoleRegNames_u8_arr6
.IMPORT Ram_Console_sProgram
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineMaxInstructions_u8
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
kMenuCursorObjPalette = 1

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

;;; BG tile IDs for numbers, from 0 through 15.
.PROC DataA_Console_NumberLabels_u8_arr
    .byte "0123456789", $1a, $1b, $1c, $1d, $1e, $1f
    .assert * - DataA_Console_NumberLabels_u8_arr = kMaxMenuItems, error
.ENDPROC

;;; +--------+
;;; |COPY ADD|
;;; |SWAP SUB|
;;; |GOTO MUL|
;;; |SKIP IF |
;;; |MOVE TIL|
;;; |BEEP ACT|
;;; |WAIT END|
;;; |delete  |
;;; +--------+
.PROC DataA_Console_Opcode_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 5, 3, 3, 2, 2, 2, 3, 3, 1, 2, 2, 3, 3, 3, 2, 2
    d_addr Labels_u8_arr_ptr_arr
    .addr _LabelEmpty, _LabelCopy, _LabelSwap, _LabelAdd, _LabelSub, _LabelMul
    .addr _LabelGoto, _LabelSkip, _LabelIf, _LabelTil, _LabelAct, _LabelMove
    .addr _LabelWait, _LabelBeep, _LabelEnd, _LabelNop
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
_LabelWait:  .byte "WAIT"
_LabelBeep:  .byte "BEEP"
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
_SetColumnsForAllMenuItems:
    ldx #kMaxMenuItems - 1
    @loop:
    lda _Columns_u8_arr, x
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
_SetRowsForMenuLeftColumn:
    ldx #0
    ;; Check if the COPY opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeCopy >> 3)
    and #1 << (eFlag::UpgradeOpcodeCopy & $07)
    beq @noCopyOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Copy
    inx
    @noCopyOpcode:
    ;; Check if the SWAP opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeSwap >> 3)
    and #1 << (eFlag::UpgradeOpcodeSwap & $07)
    beq @noSwapOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Swap
    inx
    @noSwapOpcode:
    ;; Check if the GOTO opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeIfGoto >> 3)
    and #1 << (eFlag::UpgradeOpcodeIfGoto & $07)
    beq @noGotoOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Goto
    inx
    @noGotoOpcode:
    ;; Check if the SKIP opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeSkip >> 3)
    and #1 << (eFlag::UpgradeOpcodeSkip & $07)
    beq @noSkipOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Skip
    inx
    @noSkipOpcode:
    ;; Check if this machine supports the MOVE opcode.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::MoveH | bMachine::MoveV
    beq @noMoveOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Move
    inx
    @noMoveOpcode:
    ;; Check if the BEEP opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeBeep >> 3)
    and #1 << (eFlag::UpgradeOpcodeBeep & $07)
    beq @noBeepOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Beep
    inx
    @noBeepOpcode:
    ;; The WAIT opcode is always available.
    stx Ram_MenuRows_u8_arr + eOpcode::Wait
    ;; Put an entry for the EMPTY opcode on the last row of the menu.
    ldx Zp_ConsoleNumInstRows_u8
    dex
    stx Ram_MenuRows_u8_arr + eOpcode::Empty
_SetRowsForMenuRightColumn:
    ldx #0
    ;; Check if the ADD/SUB opcodes are unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeAddSub >> 3)
    and #1 << (eFlag::UpgradeOpcodeAddSub & $07)
    beq @noAddSubOpcodes
    stx Ram_MenuRows_u8_arr + eOpcode::Add
    inx
    stx Ram_MenuRows_u8_arr + eOpcode::Sub
    inx
    @noAddSubOpcodes:
    ;; Check if the MUL opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeMul >> 3)
    and #1 << (eFlag::UpgradeOpcodeMul & $07)
    beq @noMulOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Mul
    inx
    @noMulOpcode:
    ;; Check if the IF opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeIfGoto >> 3)
    and #1 << (eFlag::UpgradeOpcodeIfGoto & $07)
    beq @noIfOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::If
    inx
    @noIfOpcode:
    ;; Check if the TIL opcode is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeTil >> 3)
    and #1 << (eFlag::UpgradeOpcodeTil & $07)
    beq @noTilOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Til
    inx
    @noTilOpcode:
    ;; Check if this machine supports the ACT opcode.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::Act
    beq @noActOpcode
    stx Ram_MenuRows_u8_arr + eOpcode::Act
    inx
    @noActOpcode:
    ;; The END opcode is always available.
    stx Ram_MenuRows_u8_arr + eOpcode::End
    rts
_Columns_u8_arr:
    D_ENUM eOpcode
    d_byte Empty, 0
    d_byte Copy,  0
    d_byte Swap,  0
    d_byte Add,   5
    d_byte Sub,   5
    d_byte Mul,   5
    d_byte Goto,  0
    d_byte Skip,  0
    d_byte If,    5
    d_byte Til,   5
    d_byte Act,   5
    d_byte Move,  0
    d_byte Wait,  0
    d_byte Beep,  0
    d_byte End,   5
    d_byte Nop,   5
    D_END
.ENDPROC

;;; +--------+
;;; |        |
;;; |        |
;;; |  0     |
;;; | 123 AB |
;;; | 456 CD |
;;; | 789 EF |
;;; |        |
;;; |        |
;;; +--------+
.PROC DataA_Console_Value_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    .repeat 10, index
    .addr DataA_Console_NumberLabels_u8_arr + index
    .endrepeat
    .repeat 6, index
    .addr Ram_ConsoleRegNames_u8_arr6 + index
    .endrepeat
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_OnUp:
    lda Zp_MenuItem_u8
    cmp #4
    bge @doNotGoToZero
    lda #0
    beq @setToA  ; unconditional
    @doNotGoToZero:
    cmp #$a
    bge @register
    sub #3
    bpl @setToA  ; unconditional
    @register:
    tax
    @loop1:
    dex
    dex
    cpx #$a
    blt @tryOtherColumn
    lda Ram_MenuRows_u8_arr, x
    bmi @loop1
    bpl @setToX  ; unconditional
    @tryOtherColumn:
    lda Zp_MenuItem_u8
    eor #$01
    tax
    @loop2:
    dex
    dex
    cpx #$a
    blt @doNotSet
    lda Ram_MenuRows_u8_arr, x
    bmi @loop2
    @setToX:
    txa
    @setToA:
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnDown:
    lda Zp_MenuItem_u8
    bne @notAtZero
    lda #2
    bne @setToA  ; unconditional
    @notAtZero:
    cmp #$a
    bge @register
    cmp #7
    bge @doNotSet
    add #3
    bne @setToA  ; unconditional
    @register:
    tax
    @loop1:
    inx
    inx
    cpx #$10
    bge @tryOtherColumn
    lda Ram_MenuRows_u8_arr, x
    bmi @loop1
    bpl @setToX  ; unconditional
    @tryOtherColumn:
    lda Zp_MenuItem_u8
    eor #$01
    tax
    @loop2:
    inx
    inx
    cpx #$10
    bge @doNotSet
    lda Ram_MenuRows_u8_arr, x
    bmi @loop2
    @setToX:
    txa
    @setToA:
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnLeft:
    ldx Zp_MenuItem_u8
    bne @notAtZero
    lda #1
    bne @setToA  ; unconditional
    @notAtZero:
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    lda Ram_MenuCols_u8_arr, x
    sta Zp_Tmp2_byte  ; current menu col
    lda #0
    sta Zp_Tmp3_byte  ; best new col so far
    lda #$ff
    sta Zp_Tmp4_byte  ; best new item so far
    ;; Check all menu items, and find the rightmost possible one that is still
    ;; to the left of the current item and in the same row.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    bne @continue
    lda Ram_MenuCols_u8_arr, x
    cmp Zp_Tmp2_byte  ; current menu col
    bge @continue
    cmp Zp_Tmp3_byte  ; best new col so far
    blt @continue
    sta Zp_Tmp3_byte  ; best new col so far
    stx Zp_Tmp4_byte  ; best new item so far
    @continue:
    dex
    bpl @loop
    ;; If we found any such item, set it as the new selected item.
    lda Zp_Tmp4_byte  ; best new item so far
    bmi @doNotSet
    @setToA:
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
_OnRight:
    ldx Zp_MenuItem_u8
    bne @notAtZero
    lda #3
    bne @setToA  ; unconditional
    @notAtZero:
    lda Ram_MenuRows_u8_arr, x
    sta Zp_Tmp1_byte  ; current menu row
    lda Ram_MenuCols_u8_arr, x
    sta Zp_Tmp2_byte  ; current menu col
    lda #$ff
    sta Zp_Tmp3_byte  ; best new col so far
    sta Zp_Tmp4_byte  ; best new item so far
    ;; Check all menu items, and find the leftmost possible one that is still
    ;; to the right of the current item and in the same row.
    ldx #kMaxMenuItems - 1
    @loop:
    lda Ram_MenuRows_u8_arr, x
    cmp Zp_Tmp1_byte  ; current menu row
    bne @continue
    lda Ram_MenuCols_u8_arr, x
    cmp Zp_Tmp2_byte  ; current menu col
    ble @continue
    cmp Zp_Tmp3_byte  ; best new col so far
    bge @continue
    sta Zp_Tmp3_byte  ; best new col so far
    stx Zp_Tmp4_byte  ; best new item so far
    @continue:
    dex
    bpl @loop
    ;; If we found any such item, set it as the new selected item.
    lda Zp_Tmp4_byte  ; best new item so far
    bmi @doNotSet
    @setToA:
    sta Zp_MenuItem_u8
    @doNotSet:
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an L-value menu.
.PROC FuncA_Console_SetUpLValueMenu
    jsr FuncA_Console_SetUpValueMenuCommon
_SetColumnsForAllMenuItems:
    ldx #kMaxMenuItems - 1
    @loop:
    lda _Columns_u8_arr, x
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
_DisableMenuItemsForReadOnlyRegisters:
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp1_byte  ; machine flags
    lda #$ff
    sta Ram_MenuRows_u8_arr + $b  ; the B register is always read-only
    .assert bMachine::WriteF = $01, error
    .assert bMachine::WriteE = $02, error
    .assert bMachine::WriteD = $04, error
    .assert bMachine::WriteC = $08, error
    ldx #$f
    @loop:
    lsr Zp_Tmp1_byte
    bcs @continue
    sta Ram_MenuRows_u8_arr, x
    @continue:
    dex
    cpx #$b
    bne @loop
    rts
_Columns_u8_arr:
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4, 3, 4, 3, 4
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for an R-value menu.
.PROC FuncA_Console_SetUpRValueMenu
    jsr FuncA_Console_SetUpValueMenuCommon
_SetColumnsForAllMenuItems:
    ldx #kMaxMenuItems - 1
    @loop:
    lda _Columns_u8_arr, x
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
_SetRowsForImmediateValues:
    lda Zp_ConsoleNumInstRows_u8
    sub #4
    lsr a
    tax
    stx Ram_MenuRows_u8_arr + 0
    inx
    stx Ram_MenuRows_u8_arr + 1
    stx Ram_MenuRows_u8_arr + 2
    stx Ram_MenuRows_u8_arr + 3
    inx
    stx Ram_MenuRows_u8_arr + 4
    stx Ram_MenuRows_u8_arr + 5
    stx Ram_MenuRows_u8_arr + 6
    inx
    stx Ram_MenuRows_u8_arr + 7
    stx Ram_MenuRows_u8_arr + 8
    stx Ram_MenuRows_u8_arr + 9
    rts
_Columns_u8_arr:
    .byte 2, 1, 2, 3, 1, 2, 3, 1, 2, 3, 5, 6, 5, 6, 5, 6
.ENDPROC

;;; Helper function for FuncA_Console_SetUpLValueMenu and
;;; FuncA_Console_SetUpRValueMenu.
.PROC FuncA_Console_SetUpValueMenuCommon
    ldax #DataA_Console_Value_sMenu
    stax Zp_Current_sMenu_ptr
_SetRowsForRegisters:
    lda Zp_ConsoleNumInstRows_u8
    sub #4
    lsr a
    sta Zp_Tmp1_byte  ; starting row
    ldy #$f
    ldx #5
    @loop:
    lda Ram_ConsoleRegNames_u8_arr6, x
    beq @continue
    txa
    lsr a
    sec
    adc Zp_Tmp1_byte  ; starting row
    sta Ram_MenuRows_u8_arr, y
    @continue:
    dey
    dex
    bpl @loop
    rts
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
.PROC FuncA_Console_SetUpAddressMenu
    ldax #DataA_Console_Address_sMenu
    stax Zp_Current_sMenu_ptr
    ldx #0
    ldy #sInst::Op_byte
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
    .repeat .sizeof(sInst)
    iny
    .endrepeat
    cpx Zp_MachineMaxInstructions_u8
    blt @loop
    @done:
    rts
.ENDPROC

;;; +--------+
;;; |        |
;;; |        |
;;; | = < >  |
;;; |        |
;;; | / { }  |
;;; |        |
;;; |        |
;;; |        |
;;; +--------+
.PROC DataA_Console_Compare_sMenu
    D_STRUCT sMenu
    d_byte WidthsMinusOne_u8_arr
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr Labels_u8_arr_ptr_arr
    .addr _LabelEq, _LabelNe, _LabelLt, _LabelLe, _LabelGt, _LabelGe
    .addr 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    d_addr OnUp_func_ptr,    _OnUp
    d_addr OnDown_func_ptr,  _OnDown
    d_addr OnLeft_func_ptr,  _OnLeft
    d_addr OnRight_func_ptr, _OnRight
    D_END
_LabelEq: .byte "="
_LabelNe: .byte $0a
_LabelLt: .byte "<"
_LabelLe: .byte $0c
_LabelGt: .byte ">"
_LabelGe: .byte $0e
_OnLeft:
    lda Zp_MenuItem_u8
    sub #2
    bge _SetItem
    rts
_OnRight:
    lda Zp_MenuItem_u8
    add #2
    cmp #6
    blt _SetItem
    rts
_OnUp:
    lda Zp_MenuItem_u8
    and #$06
    bpl _SetItem  ; unconditional
_OnDown:
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
    sub #3
    lsr a
    sta Zp_Tmp1_byte  ; starting row
    ;; Set up rows and cols.
    ldx #eCmp::NUM_VALUES - 1
    @loop:
    txa
    and #$01
    asl a
    add Zp_Tmp1_byte  ; starting row
    sta Ram_MenuRows_u8_arr, x
    txa
    ora #$01
    sta Ram_MenuCols_u8_arr, x
    dex
    bpl @loop
    rts
.ENDPROC

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
    D_ENUM eField, 2
    d_addr Opcode,    FuncA_Console_SetUpOpcodeMenu
    d_addr LValue,    FuncA_Console_SetUpLValueMenu
    d_addr RValue,    FuncA_Console_SetUpRValueMenu
    d_addr Address,   FuncA_Console_SetUpAddressMenu
    d_addr Compare,   FuncA_Console_SetUpCompareMenu
    d_addr Direction, FuncA_Console_SetUpDirectionMenu
    D_END
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

;;; Allocates and populates OAM slots for the console menu cursor and field
;;; cursor.
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
_DrawFieldCursor:
    jmp FuncA_Console_DrawFieldCursorObjects
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

;;; Calls FuncA_Console_SetCurrentFieldValue with Zp_MenuItem_u8, then performs
;;; PPU transfers to redraw any instructions as needed (possibly over multiple
;;; frames).
.PROC FuncA_Console_MenuSetValue
    ;; Check if the current instruction was previously empty.
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    pha  ; zero if instruction was empty
    ;; Set the field value.
    lda Zp_MenuItem_u8  ; param: new field value
    jsr FuncA_Console_SetCurrentFieldValue
    ;; Check if the instruction is empty now.
    pla  ; zero if instruction was empty
    tax
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    beq _NowEmpty
_NowNotEmpty:
    ;; The instruction is non-empty now.  If it was non-empty before too, then
    ;; we only need to redraw the current instruction.
    txa  ; zero if instruction was empty
    bne @transferCurrent
    ;; The instruction was empty before and is now non-empty, so we need to
    ;; redraw the next (empty) instruction, if there is one.
    ldx Zp_ConsoleInstNumber_u8
    inx
    cpx Zp_MachineMaxInstructions_u8
    beq @transferCurrent
    ;; Redraw the next instruction.
    stx Zp_ConsoleInstNumber_u8
    jsr FuncA_Console_TransferInstruction
    dec Zp_ConsoleInstNumber_u8
    ;; Redraw the current instruction.
    @transferCurrent:
    jsr FuncA_Console_TransferInstruction
    rts
_NowEmpty:
    ;; The instruction is empty now.  If it already was before, we're done.
    txa  ; zero if instruction was empty
    bne @doRemove
    rts
    @doRemove:
    ;; The instruction is empty now, but didn't used to be, so we need to
    ;; remove it and shift all following instructions back by one.
_ShiftInstructions:
    ;; Shift all instructions after the current one back one slot.
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sInst)
    tax  ; byte offset for instruction
    tay  ; byte offset for following instruction
    .repeat .sizeof(sInst)
    iny
    .endrepeat
    bne @compare  ; unconditional
    @loop:
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr, y
    sta Ram_Console_sProgram + sProgram::Code_sInst_arr, x
    inx
    iny
    @compare:
    cpy #.sizeof(sInst) * kMaxProgramLength
    blt @loop
    ;; Mark the final instruction empty.
    lda Zp_MachineMaxInstructions_u8
    mul #.sizeof(sInst)
    tax
    lda #0
    .repeat .sizeof(sInst)
    dex
    sta Ram_Console_sProgram + sProgram::Code_sInst_arr, x
    .endrepeat
_RewriteGotos:
    ;; Loop over all instructions.
    ldx #0  ; byte offset into program
    @loop:
    ;; If this is not a GOTO instruction, skip it.
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, x
    and #$f0
    cmp #eOpcode::Goto * $10
    bne @continue
    ;; Get the destination address of the GOTO.
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, x
    and #$0f
    ;; If it points to before the removed instruction, no change is needed.
    cmp Zp_ConsoleInstNumber_u8
    blt @continue
    ;; If it points to after the removed instruction, decrement the address.
    bne @decrement
    ;; Otherwise, the GOTO points to the removed instruction exactly.  If that
    ;; address still points to a non-empty instruction (which used to be the
    ;; next instruction, before we shifted things), leave the address the same.
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    bne @continue
    ;; Otherwise, the removed instruction that the GOTO points to was the last
    ;; instruction, so its old "next" instruction was instruction zero, so make
    ;; the GOTO point to that.
    lda #eOpcode::Goto * $10 + 0
    sta Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, x
    bne @continue  ; unconditional
    ;; Decrement the destination address.
    @decrement:
    dec Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, x
    @continue:
    .repeat .sizeof(sInst)
    inx
    .endrepeat
    cpx #.sizeof(sInst) * kMaxProgramLength
    blt @loop
_RedrawInstructions:
    jmp FuncA_Console_TransferAllInstructions
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for the console instruction field editing menu.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Menu_EditSelectedField
.PROC Main_Menu_EditSelectedField
    jsr_prga FuncA_Console_SetUpCurrentFieldMenu
    ;; Transfer menu rows.
    ldx #0  ; param: menu row to transfer
    @loop:
    jsr FuncA_Console_TransferMenuRow  ; preserves X
    inx
    cpx Zp_ConsoleNumInstRows_u8
    blt @loop
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr_prga FuncA_Console_DrawMenuCursorObjects
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckForCancel:
    bit Zp_P1ButtonsPressed_bJoypad
    ;; B button:
    .assert bJoypad::BButton = bProc::Overflow, error
    bvs _ExitMenu
    ;; A button:
    .assert bJoypad::AButton = bProc::Negative, error
    bmi _SetValue
    ;; D-pad:
    jsr_prga FuncA_Console_MoveMenuCursor
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jsr Func_MachineTick
    jmp _GameLoop
_SetValue:
    jsr_prga FuncA_Console_MenuSetValue
_ExitMenu:
    jsr_prga FuncA_Console_TransferAllStatusRows
    jmp Main_Console_ContinueEditing
.ENDPROC

;;;=========================================================================;;;
