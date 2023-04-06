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
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "menu.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"

.IMPORT FuncA_Console_DrawMenuCursor
.IMPORT FuncA_Console_GetCurrentFieldType
.IMPORT FuncA_Console_GetCurrentFieldValue
.IMPORT FuncA_Console_MoveMenuCursor
.IMPORT FuncA_Console_SetCurrentFieldValue
.IMPORT FuncA_Console_SetUpAddressMenu
.IMPORT FuncA_Console_SetUpCompareMenu
.IMPORT FuncA_Console_SetUpDirectionMenu
.IMPORT FuncA_Console_SetUpLValueMenu
.IMPORT FuncA_Console_SetUpOpcodeMenu
.IMPORT FuncA_Console_SetUpRValueMenu
.IMPORT FuncA_Console_TransferAllInstructions
.IMPORT FuncA_Console_TransferAllStatusRows
.IMPORT FuncA_Console_TransferInstruction
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncM_ConsoleScrollTowardsGoalAndTick
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_SetMachineIndex
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Main_Console_ContinueEditing
.IMPORT Ram_Console_sProgram
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_ConsoleNumInstRows_u8
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8

;;;=========================================================================;;;

;;; The width of the console menu, in tiles.
kMenuWidthTiles = 8

;;;=========================================================================;;;

.ZEROPAGE

;;; A pointer to the static data for the current menu type.
.EXPORTZP Zp_Current_sMenu_ptr
Zp_Current_sMenu_ptr: .res 2

;;; The currently-selected menu item (0-15).
.EXPORTZP Zp_MenuItem_u8
Zp_MenuItem_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Menu"

;;; The menu row (0-7) for each menu item, or $ff if the item is absent.
.EXPORT Ram_MenuRows_u8_arr
Ram_MenuRows_u8_arr: .res kMaxMenuItems

;;; The menu column (0-7) for each menu item.
.EXPORT Ram_MenuCols_u8_arr
Ram_MenuCols_u8_arr: .res kMaxMenuItems

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Initializes console menu mode.
.PROC FuncA_Console_InitMenu
    jsr FuncA_Console_SetUpCurrentFieldMenu
    ;; Transfer menu rows.
    ldx #0  ; param: menu row to transfer
    @loop:
    jsr FuncA_Console_TransferMenuRow  ; preserves X
    inx
    cpx Zp_ConsoleNumInstRows_u8
    blt @loop
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
    ;; Initialize Zp_Current_sMachine_ptr (since some of the
    ;; field-type-specific setup functions require this).
    ldx Zp_ConsoleMachineIndex_u8  ; param: machine index
    jsr Func_SetMachineIndex
    ;; Jump to field-type-specific setup function.
    jsr FuncA_Console_GetCurrentFieldType  ; returns A
    tay
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eField
    d_entry table, Opcode,    FuncA_Console_SetUpOpcodeMenu
    d_entry table, LValue,    FuncA_Console_SetUpLValueMenu
    d_entry table, RValue,    FuncA_Console_SetUpRValueMenu
    d_entry table, Address,   FuncA_Console_SetUpAddressMenu
    d_entry table, Compare,   FuncA_Console_SetUpCompareMenu
    d_entry table, Direction, FuncA_Console_SetUpDirectionMenu
    D_END
.ENDREPEAT
.ENDPROC

;;; Transfers the specified menu row (0-7) to the PPU.
;;; @param X The menu row to transfer.
;;; @preserve X
.PROC FuncA_Console_TransferMenuRow
    stx T2  ; menu row
_WriteTransferEntryHeader:
    ;; Get the transfer destination address, and store it in T0 (lo)
    ;; and T1 (hi).
    .assert kMenuStartWindowRow = 1, error
    inx
    txa  ; window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    tya
    add #kMenuStartTileColumn
    sta T0  ; transfer destination (lo)
    txa
    adc #0
    sta T1  ; transfer destination (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kMenuWidthTiles
    sta Zp_PpuTransferLen_u8
    ;; Write the transfer entry header.
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda T1  ; transfer destination (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    lda T0  ; transfer destination (lo)
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kMenuWidthTiles
    sta Ram_PpuTransfer_arr, x
    inx
_InitTransferData:
    ;; Fill the transfer data with spaces for now.
    stx T0  ; start of transfer data
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
    cmp T2  ; menu row
    bne @noLabel
    sty T1  ; item index
    ;; Make T5T4 point to start of the label string.
    tya
    asl a
    add #sMenu::Labels_u8_arr_ptr_arr
    tay
    lda (Zp_Current_sMenu_ptr), y
    sta T4  ; label string ptr (lo)
    iny
    lda (Zp_Current_sMenu_ptr), y
    sta T5  ; label string ptr (hi)
    ;; Set T3 to the (width - 1) of the label.
    lda T1  ; item index
    add #sMenu::WidthsMinusOne_u8_arr
    tay
    lda (Zp_Current_sMenu_ptr), y  ; item width
    sta T3  ; the label's (width - 1)
    ;; Set X to the PPU transfer array index for the last byte in the label.
    adc Ram_MenuCols_u8_arr, y  ; starting menu col
    adc T0  ; start of transfer data
    tax
    ;; Copy the label into the PPU transfer entry.
    ldy T3  ; the label's (width - 1)
    @labelLoop:
    lda (T5T4), y  ; label chr
    sta Ram_PpuTransfer_arr, x
    dex
    dey
    bpl @labelLoop
    ;; Restore Y as the item loop index, and move on to the next item (if any).
    ldy T1  ; item index
    @noLabel:
    dey
    bpl @itemLoop
    ldx T2  ; menu row
    rts
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
    ldx Zp_ConsoleMachineIndex_u8  ; param: machine index
    jsr Func_SetMachineIndex
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
    jmp FuncA_Console_TransferInstruction
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

;;; Responds to any joypad presses while in menu mode.
;;; @return C Set if the menu should exit, cleared otherwise.
.PROC FuncA_Console_MenuHandleJoypad
    bit Zp_P1ButtonsPressed_bJoypad
    ;; B button:
    .assert bJoypad::BButton = bProc::Overflow, error
    bvs _Cancel
    ;; A button:
    .assert bJoypad::AButton = bProc::Negative, error
    bmi _SetValue
    ;; D-pad:
    jsr FuncA_Console_MoveMenuCursor
    clc
    rts
_Cancel:
    ;; If we cancel editing a NOP opcode (i.e. we were inserting a new
    ;; instruction), then delete that instruction (thus cancelling the
    ;; insertion).  In all other cases, we can simply exit the menu.
    jsr FuncA_Console_GetCurrentFieldType  ; returns A
    cmp #eField::Opcode
    bne _ExitMenu
    jsr FuncA_Console_GetCurrentFieldValue  ; returns A
    cmp #eOpcode::Nop
    bne _ExitMenu
    lda #eOpcode::Empty
    sta Zp_MenuItem_u8
_SetValue:
    jsr FuncA_Console_MenuSetValue
_ExitMenu:
    jsr FuncA_Console_TransferAllStatusRows
    sec
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for the console instruction field editing menu.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Menu_EditSelectedField
.PROC Main_Menu_EditSelectedField
    jsr_prga FuncA_Console_InitMenu
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr_prga FuncA_Console_DrawMenuCursor
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr FuncA_Console_MenuHandleJoypad  ; returns C
    jcs Main_Console_ContinueEditing
_Tick:
    jsr FuncM_ConsoleScrollTowardsGoalAndTick
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;
