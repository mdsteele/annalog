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
.IMPORT FuncA_Console_IsInstructionEmpty
.IMPORT FuncA_Console_MoveMenuCursor
.IMPORT FuncA_Console_SetCurrentFieldValue
.IMPORT FuncA_Console_SetUpAddressMenu
.IMPORT FuncA_Console_SetUpCompareMenu
.IMPORT FuncA_Console_SetUpDebugMenu
.IMPORT FuncA_Console_SetUpDirectionMenu
.IMPORT FuncA_Console_SetUpEraseMenu
.IMPORT FuncA_Console_SetUpLValueMenu
.IMPORT FuncA_Console_SetUpOpcodeMenu
.IMPORT FuncA_Console_SetUpRValueMenu
.IMPORT FuncA_Console_TransferAllDiagramBoxRows
.IMPORT FuncA_Console_TransferAllInstructions
.IMPORT FuncA_Console_TransferInstruction
.IMPORT FuncM_DrawObjectsForRoomAndProcessFrame
.IMPORT FuncM_ScrollTowardsGoalAndTickConsoleAndProgressTimer
.IMPORT Func_PlaySfxExplodeFracture
.IMPORT Func_PlaySfxMenuCancel
.IMPORT Func_PlaySfxMenuConfirm
.IMPORT Func_SetMachineIndex
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Main_Console_ContinueEditing
.IMPORT Main_Console_StartDebugger
.IMPORT Ram_Console_sProgram
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_ConsoleFieldNumber_u8
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_ConsoleNominalFieldOffset_u8
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

;;; The current "nominal" menu column (0-7).  When moving the cursor
;;; left/right, this is automatically set to the actual column of the newly
;;; selected menu item field.  When moving the cursor up/down, this stays the
;;; same, and may optionally be used by the specific menu implementation to
;;; choose whichever item in each row has roughly this column.
.EXPORTZP Zp_MenuNominalCol_u8
Zp_MenuNominalCol_u8: .res 1

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

;;; Sets up the debug menu, and transfers all menu rows to the PPU.
.PROC FuncA_Console_InitDebugMenu
    lda #eDebug::StartDebugger
    sta Zp_MenuItem_u8
    ;; Set up and transfer the menu.
    ldy #eField::Debug  ; param: field type
    .assert eField::Debug > 0, error
    bne FuncA_Console_SetUpAndTransferMenu  ; unconditional
.ENDPROC

;;; Sets up the erase-program menu, and transfers all menu rows to the PPU.
.PROC FuncA_Console_InitEraseMenu
    ldy #eField::Erase  ; param: field type
    ;; Set current menu item to zero (for "NO").
    .assert eField::Erase = 0, error
    sty Zp_MenuItem_u8
    ;; Set up and transfer the menu.
    beq FuncA_Console_SetUpAndTransferMenu  ; unconditional
.ENDPROC

;;; Sets up the menu for the currently selected program field, and transfers
;;; all menu rows to the PPU.
.PROC FuncA_Console_InitFieldMenu
    ;; Set current menu item (must be initialized before setting up field
    ;; menu).
    jsr FuncA_Console_GetCurrentFieldValue  ; returns A
    sta Zp_MenuItem_u8
    ;; Call field-type-specific setup function.
    jsr FuncA_Console_GetCurrentFieldType  ; returns Y (param: field type)
    fall FuncA_Console_SetUpAndTransferMenu
.ENDPROC

;;; Sets up the menu for the specified field type, and transfers all menu rows
;;; to the PPU.
;;; @prereq Zp_MenuItem_u8 is initialized.
;;; @param Y The eField value for the field type.
.PROC FuncA_Console_SetUpAndTransferMenu
    ;; Initialize Zp_Current_sMachine_ptr (since some of the
    ;; field-type-specific setup functions require this).
    ldx Zp_ConsoleMachineIndex_u8  ; param: machine index
    jsr Func_SetMachineIndex  ; preserves Y
    ;; Call field-type-specific setup function.
    jsr FuncA_Console_SetUpMenuForFieldType
    jsr FuncA_Console_UpdateMenuNominalCol
_TransferMenuRows:
    ;; Transfer menu rows.
    ldx #0  ; param: menu row to transfer
    @loop:
    jsr FuncA_Console_TransferMenuRow  ; preserves X
    inx
    cpx Zp_ConsoleNumInstRows_u8
    blt @loop
    rts
.ENDPROC

;;; Sets the menu nominal column to the actual column of the currently-selected
;;; menu item.
.EXPORT FuncA_Console_UpdateMenuNominalCol
.PROC FuncA_Console_UpdateMenuNominalCol
    ldx Zp_MenuItem_u8
    lda Ram_MenuCols_u8_arr, x
    sta Zp_MenuNominalCol_u8
    rts
.ENDPROC

;;; Initializes Zp_Current_sMenu_ptr, Ram_MenuRows_u8_arr, and
;;; Ram_MenuCols_u8_arr appropriately for the specified field type.
;;; @prereq Zp_Current_sMachine_ptr is initialized.
;;; @prereq Zp_MenuItem_u8 is initialized.
;;; @param Y The eField value for the field type.
.PROC FuncA_Console_SetUpMenuForFieldType
    ;; Clear items.
    lda #$ff
    ldx #kMaxMenuItems - 1
    @loop:
    sta Ram_MenuRows_u8_arr, x
    dex
    bpl @loop
    ;; Call field-type-specific setup function.
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eField
    d_entry table, Erase,     FuncA_Console_SetUpEraseMenu
    d_entry table, Debug,     FuncA_Console_SetUpDebugMenu
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
    txa  ; param: window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    tya     ; window row PPU addr (lo)
    add #kMenuStartTileColumn
    sta T0  ; transfer destination (lo)
    txa     ; window row PPU addr (hi)
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
    mul #kSizeofAddr
    add #sMenu::Labels_u8_arr_ptr_arr
    tay
    lda (Zp_Current_sMenu_ptr), y
    sta T4  ; label string ptr (lo)
    iny
    lda (Zp_Current_sMenu_ptr), y
    sta T5  ; label string ptr (hi)
    ;; Set T3 to the (width - 1) of the label.
    ldy T1  ; item index
    .assert sMenu::WidthsMinusOne_u8_arr = 1, error
    iny  ; now Y is sMenu::WidthsMinusOne_u8_arr + item index
    lda (Zp_Current_sMenu_ptr), y  ; item width
    sta T3  ; the label's (width - 1)
    ;; Set X to the PPU transfer array index for the last byte in the label.
    ldy T1  ; item index
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
    mul #.sizeof(sIns)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, y
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
    mul #.sizeof(sIns)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, y
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
    mul #.sizeof(sIns)
    tax  ; byte offset for instruction
    tay  ; byte offset for following instruction
    .repeat .sizeof(sIns)
    iny
    .endrepeat
    bne @compare  ; unconditional
    @loop:
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr, y
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr, x
    inx
    iny
    @compare:
    cpy #.sizeof(sIns) * kMaxProgramLength
    blt @loop
    ;; Mark the final instruction empty.
    lda Zp_MachineMaxInstructions_u8
    mul #.sizeof(sIns)
    tax
    lda #0
    .repeat .sizeof(sIns)
    dex
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr, x
    .endrepeat
_RewriteGotos:
    ;; Loop over all instructions.
    ldx #0  ; byte offset into program
    @loop:
    ;; If this is not a GOTO instruction, skip it.
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    and #$f0
    cmp #eOpcode::Goto * $10
    bne @continue
    ;; Get the destination address of the GOTO.
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    and #$0f
    ;; If it points to before the removed instruction, no change is needed.
    cmp Zp_ConsoleInstNumber_u8
    blt @continue
    ;; If it points to after the removed instruction, decrement the address.
    bne @decrement
    ;; Otherwise, the GOTO points to the removed instruction exactly.  If that
    ;; address still points to a non-empty instruction (which used to be the
    ;; next instruction, before we shifted things), leave the address the same.
    mul #.sizeof(sIns)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, y
    and #$f0
    bne @continue
    ;; Otherwise, the removed instruction that the GOTO points to was the last
    ;; instruction, so its old "next" instruction was instruction zero, so make
    ;; the GOTO point to that.
    lda #eOpcode::Goto * $10 + 0
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    bne @continue  ; unconditional
    ;; Decrement the destination address.
    @decrement:
    dec Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    @continue:
    .repeat .sizeof(sIns)
    inx
    .endrepeat
    cpx #.sizeof(sIns) * kMaxProgramLength
    blt @loop
_RedrawInstructions:
    jmp FuncA_Console_TransferAllInstructions
.ENDPROC

;;; Erases the console program, and sets the console cursor back to the first
;;; (now empty) instruction.
.PROC FuncA_Console_EraseProgram
    lda #0
    sta Zp_ConsoleInstNumber_u8
    sta Zp_ConsoleFieldNumber_u8
    sta Zp_ConsoleNominalFieldOffset_u8
    ldx #.sizeof(sProgram) - 1
    @loop:
    sta Ram_Console_sProgram, x
    dex
    .assert .sizeof(sProgram) <= $80, error
    bpl @loop
    jmp FuncA_Console_TransferAllInstructions
.ENDPROC

;;; Responds to any joypad presses while in menu mode.
;;; @return C Set if the menu should exit, cleared otherwise.
;;; @return T1T0 If exiting menu, the next main to jump to.
.PROC FuncA_Console_MenuHandleJoypad
    bit Zp_P1ButtonsPressed_bJoypad
    ;; B button:
    .assert bJoypad::BButton = bProc::Overflow, error
    bvs _Cancel
    ;; A button:
    .assert bJoypad::AButton = bProc::Negative, error
    bmi _Confirm
    ;; D-pad:
    jsr FuncA_Console_MoveMenuCursor
    clc  ; clear C to indicate that we should stay in the menu
    rts
_InitEraseMenu:
    jsr Func_PlaySfxMenuConfirm
    jsr FuncA_Console_InitEraseMenu
    clc  ; clear C to indicate that we should stay in the menu
    rts
_Confirm:
    ldy #sMenu::Type_eField
    lda (Zp_Current_sMenu_ptr), y
    .assert eField::Erase = 0, error
    beq _ConfirmEraseMenu
    cmp #eField::Debug
    bne _ConfirmFieldMenu
    fall _ConfirmDebugMenu
_ConfirmDebugMenu:
    ldx Zp_MenuItem_u8
    cpx #eDebug::Cancel
    beq _Cancel
    cpx #eDebug::StartDebugger
    beq _TryStartDebugger
    cpx #eDebug::EraseProgram
    beq _InitEraseMenu
    fall _ResetAllMachines
_ResetAllMachines:
    jsr Func_PlaySfxMenuConfirm
    ;; TODO: implement this
    jmp _ExitMenuAndContinueEditing
_ConfirmEraseMenu:
    lda Zp_MenuItem_u8  ; 0 for NO, 1 for YES
    beq _Cancel
    ;; Erase the program.
    jsr Func_PlaySfxMenuConfirm
    jsr Func_PlaySfxExplodeFracture
    jsr FuncA_Console_EraseProgram
    jmp _ExitMenuAndContinueEditing
_Cancel:
    jsr Func_PlaySfxMenuCancel
    ;; If we cancel editing a NOP opcode (i.e. we were inserting a new
    ;; instruction), then delete that instruction (thus cancelling the
    ;; insertion).  In all other cases, we can simply exit the menu.
    ldy #sMenu::Type_eField
    lda (Zp_Current_sMenu_ptr), y
    cmp #eField::Opcode
    bne _ExitMenuAndContinueEditing  ; not editing an opcode field
    jsr FuncA_Console_GetCurrentFieldValue  ; returns A
    cmp #eOpcode::Nop
    bne _ExitMenuAndContinueEditing  ; not editing a NOP opcode
    lda #eOpcode::Empty
    sta Zp_MenuItem_u8
    .assert eOpcode::Empty = 0, error
    beq _SetFieldValue  ; unconditional
_ConfirmFieldMenu:
    jsr Func_PlaySfxMenuConfirm
_SetFieldValue:
    jsr FuncA_Console_MenuSetValue
_ExitMenuAndContinueEditing:
    jsr FuncA_Console_TransferAllDiagramBoxRows
    ldya #Main_Console_ContinueEditing
_ExitMenuAndReturnYA:
    stya T1T0  ; main ptr to jump to
    sec  ; set C to indicate that we should exit the menu
    rts
_TryStartDebugger:
    ;; Only start debugging if the program isn't empty.
    ldy #0  ; param: instruction number
    jsr FuncA_Console_IsInstructionEmpty  ; returns Z
    bne _DoStartDebugger
    jsr Func_PlaySfxMenuCancel
    clc  ; clear C to indicate that we should stay in the menu
    rts
_DoStartDebugger:
    jsr Func_PlaySfxMenuConfirm
    jsr FuncA_Console_TransferAllDiagramBoxRows
    ldya #Main_Console_StartDebugger
    bmi _ExitMenuAndReturnYA  ; unconditional
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for opening the console debug menu.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Menu_EnterDebugMenu
.PROC Main_Menu_EnterDebugMenu
    jsr_prga FuncA_Console_InitDebugMenu
    jmp Main_Menu_RunMenu
.ENDPROC

;;; Mode for opening the console instruction field editing menu.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Menu_EditSelectedField
.PROC Main_Menu_EditSelectedField
    jsr_prga FuncA_Console_InitFieldMenu
    fall Main_Menu_RunMenu
.ENDPROC

;;; Mode for an open console menu.
;;; @prereq Rendering is enabled.
;;; @prereq The console menu is initialized.
;;; @prereq Explore mode is initialized.
.PROC Main_Menu_RunMenu
_GameLoop:
    jsr_prga FuncA_Console_DrawMenuCursor
    jsr FuncM_DrawObjectsForRoomAndProcessFrame
    jsr_prga FuncA_Console_MenuHandleJoypad  ; returns C and T1T0
    bcs _ExitMenu
    jsr FuncM_ScrollTowardsGoalAndTickConsoleAndProgressTimer
    jmp _GameLoop
_ExitMenu:
    jmp (T1T0)
.ENDPROC

;;;=========================================================================;;;
