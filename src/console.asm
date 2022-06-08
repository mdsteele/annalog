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
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "window.inc"

.IMPORT FuncA_Console_GetCurrentFieldOffset
.IMPORT FuncA_Console_GetCurrentFieldWidth
.IMPORT FuncA_Console_GetCurrentInstNumFields
.IMPORT FuncA_Console_SetFieldForNominalOffset
.IMPORT FuncA_Console_WriteNeedsPowerTransferData
.IMPORT FuncA_Console_WriteStatusTransferData
.IMPORT FuncA_Machine_Tick
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_ClearRestOfOam
.IMPORT Func_IsFlagSet
.IMPORT Func_MachineReset
.IMPORT Func_ProcessFrame
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetScrollGoalFromAvatar
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Explore_Continue
.IMPORT Main_Menu_EditSelectedField
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sProgram_ptr
.IMPORTZP Zp_HudMachineIndex_u8
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_ScrollGoalX_u16
.IMPORTZP Zp_ScrollGoalY_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowNextRowToTransfer_u8
.IMPORTZP Zp_WindowTopGoal_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.LINECONT +
.DEFINE OpcodeLabels \
    _OpEmpty, _OpCopy, _OpSwap, _OpAdd, _OpSub, _OpMul, _OpGoto, _OpSkip, \
    _OpIf, _OpTil, _OpAct, _OpMove, _OpWait, _OpBeep, _OpEnd, _OpNop
.LINECONT -

;;;=========================================================================;;;

;;; How fast the console window scrolls up/down, in pixels per frame.
kConsoleWindowScrollSpeed = 6

;;; The OBJ palette number used for the console cursor.
kCursorObjPalette = 1

;;; The width of an instruction in the console, in tiles.
kInstructionWidthTiles = 7

;;;=========================================================================;;;

.ZEROPAGE

;;; The index of the machine being controlled by the open console, or $ff for
;;; none.
.EXPORTZP Zp_ConsoleMachineIndex_u8
Zp_ConsoleMachineIndex_u8: .res 1

;;; A pointer to the program in SRAM that the console is currently editing.
Zp_ConsoleSram_sProgram_ptr: .res 2

;;; The number of instruction rows in the console window (i.e. not including
;;; the borders or the bottom margin).
.EXPORTZP Zp_ConsoleNumInstRows_u8
Zp_ConsoleNumInstRows_u8: .res 1

;;; If nonzero, then the console is unpowered and cannot be used; in that case,
;;; the value is the conduit circuit number (1-6) to display to the player in
;;; the error message.
Zp_ConsoleNeedsPower_u8: .res 1

;;; The "current" instruction number within Ram_Console_sProgram.  While
;;; editing or debug stepping, this is the instruction highlighted by the
;;; cursor.  While drawing the console window, this is the instruction being
;;; drawn.
.EXPORTZP Zp_ConsoleInstNumber_u8
Zp_ConsoleInstNumber_u8: .res 1

;;; Which field within the current instruction is currently selected.
.EXPORTZP Zp_ConsoleFieldNumber_u8
Zp_ConsoleFieldNumber_u8: .res 1

;;; The current "nominal" field offset (0-6 inclusive).  When moving the cursor
;;; left/right, this is set to the actual offset of the selected instruction
;;; field.  When moving the cursor up/down, this stays the same, and is used to
;;; choose whichever field in each instruction has roughly this offset.
.EXPORTZP Zp_ConsoleNominalFieldOffset_u8
Zp_ConsoleNominalFieldOffset_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Console"

;;; A copy of the program that is being edited in the console.  This gets
;;; populated from SRAM, and will be copied back out to SRAM when done editing.
.EXPORT Ram_Console_sProgram
Ram_Console_sProgram: .tag sProgram

;;; The names (i.e. BG tile IDs) for registers $a through $f for the current
;;; machine.
.EXPORT Ram_ConsoleRegNames_u8_arr6
Ram_ConsoleRegNames_u8_arr6: .res 6

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for scrolling in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param X The machine index to open a console for.
.EXPORT Main_Console_OpenWindow
.PROC Main_Console_OpenWindow
    jsr_prga FuncA_Console_Init
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowUp:
    lda Zp_WindowTop_u8
    sub #kConsoleWindowScrollSpeed
    cmp Zp_WindowTopGoal_u8
    bge @notDone
    lda Zp_WindowTopGoal_u8
    @notDone:
    sta Zp_WindowTop_u8
    jsr_prga FuncA_Console_TransferNextWindowRow
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp Zp_WindowTopGoal_u8
    beq _StartEditing
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
_StartEditing:
    lda Zp_ConsoleNeedsPower_u8
    beq Main_Console_StartEditing
    jmp Main_Console_NoPower
.ENDPROC

;;; Mode for scrolling out the console window.  Switches to explore mode once
;;; the window is fully hidden.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Console_CloseWindow
    lda #$ff
    sta Zp_ConsoleMachineIndex_u8
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowDown:
    lda Zp_WindowTop_u8
    add #kConsoleWindowScrollSpeed
    cmp #kScreenHeightPx
    blt @notDone
    lda #$ff
    @notDone:
    sta Zp_WindowTop_u8
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp #$ff
    jeq Main_Explore_Continue
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for editing a program in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Console_StartEditing
    ;; Initialize the cursor.
    lda #0
    sta Zp_ConsoleInstNumber_u8
    sta Zp_ConsoleFieldNumber_u8
    sta Zp_ConsoleNominalFieldOffset_u8
    .assert * = Main_Console_ContinueEditing, error, "fallthrough"
.ENDPROC

;;; Mode for editing a program in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Console_ContinueEditing
.PROC Main_Console_ContinueEditing
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    lda #$00  ; param: cursor diminished bool ($00 = undiminished)
    jsr_prga FuncA_Console_DrawFieldCursorObjects
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckButtons:
    ;; B button:
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::BButton = bProc::Overflow, error
    bvc @noClose
    jsr_prga FuncA_Console_SaveProgram
    jmp Main_Console_CloseWindow
    @noClose:
    ;; Select button:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Select
    beq @noInsert
    jsr_prga FuncA_Console_TryInsertInstruction  ; sets C on success
    bcs @edit
    @noInsert:
    ;; A button:
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bpl @noEdit
    @edit:
    jmp Main_Menu_EditSelectedField
    @noEdit:
    ;; D-pad:
    jsr_prga FuncA_Console_MoveFieldCursor
_Tick:
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    ldx Zp_ConsoleMachineIndex_u8  ; param: machine index
    jsr Func_SetMachineIndex
    jsr_prga FuncA_Machine_Tick
    jmp _GameLoop
.ENDPROC

;;; Mode for using a console for a machine whose required conduit hasn't yet
;;; been activated.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Console_NoPower
.PROC Main_Console_NoPower
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckButtons:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton | bJoypad::BButton
    jne Main_Console_CloseWindow
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Initializes console mode.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param X The machine index to open a console for.
.PROC FuncA_Console_Init
    stx Zp_ConsoleMachineIndex_u8
    jsr Func_SetMachineIndex
    jsr Func_MachineReset
    jsr FuncA_Console_LoadProgram
    lda Zp_MachineMaxInstructions_u8
    div #2
    sta Zp_ConsoleNumInstRows_u8
_CheckIfPowered:
    ;; Get the conduit eFlag that this machine requires, or zero if the machine
    ;; does not need any conduit to be powered.
    ldy #sMachine::Conduit_eFlag
    lda (Zp_Current_sMachine_ptr), y
    .assert kFirstConduitFlag > 0, error
    beq @setNeedsPower
    tax  ; param: eFlag
    jsr Func_IsFlagSet  ; preserves X, sets Z if flag is not set
    beq @needsPower
    lda #0
    beq @setNeedsPower  ; unconditional
    @needsPower:
    txa  ; eFlag value
    .assert kFirstConduitFlag > 1, error
    sub #kFirstConduitFlag - 1
    @setNeedsPower:
    sta Zp_ConsoleNeedsPower_u8
    ;; If the machine is powered, enable the HUD, otherwise disable the HUD.
    beq @enableHud
    @disableHud:
    ldx #$ff
    bne @setHud  ; unconditional
    @enableHud:
    ldx Zp_MachineIndex_u8
    @setHud:
    stx Zp_HudMachineIndex_u8
_SetDiagram:
    ldy #sMachine::Status_eDiagram
    chr04_bank (Zp_Current_sMachine_ptr), y
_SetScrollGoal:
    .assert sMachine::ScrollGoalX_u16 = 1 + sMachine::Status_eDiagram, error
    iny  ; now Y is sMachine::ScrollGoalX_u16 + 0
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_ScrollGoalX_u16 + 0
    iny  ; now Y is sMachine::ScrollGoalX_u16 + 1
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_ScrollGoalX_u16 + 1
    .assert sMachine::ScrollGoalY_u8 = 2 + sMachine::ScrollGoalX_u16, error
    iny  ; now Y is sMachine::ScrollGoalY_u8
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_ScrollGoalY_u8
_CopyRegNames:
    ;; Set name of register $a, or #0 if that register isn't yet unlocked (by
    ;; the COPY opcode).
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeCopy >> 3)
    and #1 << (eFlag::UpgradeOpcodeCopy & $07)
    beq @noRegA
    lda #kMachineRegNameA
    @noRegA:
    sta Ram_ConsoleRegNames_u8_arr6 + 0
    ;; Set name of register $b, or #0 if that register isn't yet unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeRegisterB >> 3)
    and #1 << (eFlag::UpgradeRegisterB & $07)
    beq @noRegB
    lda #kMachineRegNameB
    @noRegB:
    sta Ram_ConsoleRegNames_u8_arr6 + 1
    ;; Copy the machine's names for registers $c through $f.
    .assert sMachine::RegNames_u8_arr4 = 1 + sMachine::ScrollGoalY_u8, error
    iny  ; now Y is sMachine::RegNames_u8_arr4
    ldx #2
    @loop:
    lda (Zp_Current_sMachine_ptr), y
    sta Ram_ConsoleRegNames_u8_arr6, x
    iny
    inx
    cpx #6
    blt @loop
_InitWindow:
    lda #kScreenHeightPx - kConsoleWindowScrollSpeed
    sta Zp_WindowTop_u8
    lda #1
    sta Zp_WindowNextRowToTransfer_u8
    ;; Calculate the window top goal from the number of instruction rows.
    lda Zp_ConsoleNumInstRows_u8
    mul #kTileHeightPx
    sta Zp_Tmp1_byte
    lda #kScreenHeightPx - (kTileHeightPx * 2 + kWindowMarginBottomPx)
    sub Zp_Tmp1_byte
    sta Zp_WindowTopGoal_u8
    rts
.ENDPROC

;;; Copies Zp_Current_sProgram_ptr to Zp_ConsoleSram_sProgram_ptr, then loads
;;; the program from SRAM into Ram_Console_sProgram, then makes
;;; Zp_Current_sProgram_ptr point to Ram_Console_sProgram.
;;; @prereq Zp_Current_sProgram_ptr has been initialized.
.PROC FuncA_Console_LoadProgram
    ldax Zp_Current_sProgram_ptr
    stax Zp_ConsoleSram_sProgram_ptr
    ;; Initialize Ram_Console_sProgram from SRAM.
    ldy #.sizeof(sProgram) - 1
    @loop:
    lda (Zp_ConsoleSram_sProgram_ptr), y
    sta Ram_Console_sProgram, y
    dey
    bpl @loop
    ;; Make Zp_Current_sProgram_ptr point to Ram_Console_sProgram.
    ldax #Ram_Console_sProgram
    stax Zp_Current_sProgram_ptr
    rts
.ENDPROC

;;; Saves Ram_Console_sProgram back to SRAM.
;;; @prereq Zp_ConsoleSram_sProgram_ptr has been initialized.
.PROC FuncA_Console_SaveProgram
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Copy Ram_Console_sProgram back to SRAM.
    ldy #.sizeof(sProgram) - 1
    @loop:
    lda Ram_Console_sProgram, y
    sta (Zp_ConsoleSram_sProgram_ptr), y
    dey
    bpl @loop
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    rts
.ENDPROC

;;; Moves the console field cursor based on the current joypad state.
.PROC FuncA_Console_MoveFieldCursor
.PROC _MoveCursorVertically
_CheckDown:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    beq _CheckUp
    ldx Zp_ConsoleInstNumber_u8
    ;; Check if the currently selection instruction is eOpcode::Empty; if so,
    ;; moving down from there wraps back to instruction number zero.
    txa
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    .assert eOpcode::Empty = 0, error
    beq @wrap
    ;; Increment the instruction number, but if that would exceed the max
    ;; number of instructions in the console window, then wrap back to zero.
    inx
    cpx Zp_MachineMaxInstructions_u8
    blt @noWrap
    @wrap:
    ldx #0
    @noWrap:
    stx Zp_ConsoleInstNumber_u8
    jmp _FinishUpDown
_CheckUp:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Up
    beq _NoUpOrDown
    ;; If the current instruction number is nonzero, just decrement it.
    ldx Zp_ConsoleInstNumber_u8
    beq @loop
    dec Zp_ConsoleInstNumber_u8
    bpl _FinishUpDown  ; unconditional
    ;; Otherwise, search forward (starting from instruction zero) for the first
    ;; empty instruction.
    @loop:
    txa
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    ;; If this instruction is empty, select it.
    .assert eOpcode::Empty = 0, error
    beq @select
    ;; Otherwise, keep looking.  If there are no empty instructions, we'll
    ;; select the last instruction.
    inx
    cpx Zp_MachineMaxInstructions_u8
    blt @loop
    dex
    @select:
    stx Zp_ConsoleInstNumber_u8
_FinishUpDown:
    jsr FuncA_Console_SetFieldForNominalOffset
_NoUpOrDown:
.ENDPROC
.PROC _MoveCursorHorizontally
    jsr FuncA_Console_GetCurrentInstNumFields  ; returns X
    stx Zp_Tmp1_byte  ; num fields
_CheckLeft:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Left
    beq _CheckRight
    ;; Decrement the field number; if we weren't at zero, we're done.
    ldx Zp_ConsoleFieldNumber_u8
    dex
    bpl @setFieldNumber
    ;; We're trying to move left from field zero.  If we're in the left-hand
    ;; column of instructions, then give up.
    lda Zp_ConsoleInstNumber_u8
    sub Zp_ConsoleNumInstRows_u8
    blt _NoLeftOrRight
    ;; Looks like we're in the right-hand column, so move to the last field of
    ;; the instruction on the same row in the left-hand column.
    sta Zp_ConsoleInstNumber_u8
    jsr FuncA_Console_GetCurrentInstNumFields  ; returns X
    dex
    @setFieldNumber:
    stx Zp_ConsoleFieldNumber_u8
    jmp _FinishLeftRight
_CheckRight:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Right
    beq _NoLeftOrRight
    ;; Increment the field number; if we weren't in the last field, we're done.
    ldx Zp_ConsoleFieldNumber_u8
    inx
    cpx Zp_Tmp1_byte  ; num fields
    blt @setFieldNumber
    ;; We're trying to move right from the last field.  If we're in the
    ;; right-hand column of instructions, then give up.
    lda Zp_ConsoleInstNumber_u8
    cmp Zp_ConsoleNumInstRows_u8
    bge _NoLeftOrRight
    ;; Looks like we're in the left-hand column, so move to the first field of
    ;; the instruction on the same row in the right-hand column.
    add Zp_ConsoleNumInstRows_u8
    sta Zp_ConsoleInstNumber_u8
    ;; If we're now beyond the first empty instruction, then undo what we just
    ;; did, and go back to the left-hand instruction column.
    jsr FuncA_Console_IsPrevInstructionEmpty  ; returns Z
    bne @prevInstNotEmpty
    lda Zp_ConsoleInstNumber_u8
    sub Zp_ConsoleNumInstRows_u8
    sta Zp_ConsoleInstNumber_u8
    bpl _NoLeftOrRight  ; unconditional
    ;; Otherwise, now that we moved to the right-hand instruction column,
    ;; select the leftmost field.
    @prevInstNotEmpty:
    ldx #0
    @setFieldNumber:
    stx Zp_ConsoleFieldNumber_u8
_FinishLeftRight:
    jsr FuncA_Console_GetCurrentFieldOffset  ; returns A
    sta Zp_ConsoleNominalFieldOffset_u8
_NoLeftOrRight:
.ENDPROC
    rts
.ENDPROC

;;; Inserts a new instruction (if there's room) above the current one and
;;; redraws all instrutions.  If there's no room for a new instruction, clears
;;; C and returns without redrawing anything.
;;; @return C Set if an instruction was successfully inserted.
.PROC FuncA_Console_TryInsertInstruction
    ;; Check if the final instruction in the program is empty; if not, we can't
    ;; insert a new instruction.
    lda Zp_MachineMaxInstructions_u8
    mul #.sizeof(sInst)
    sta Zp_Tmp1_byte  ; machine max program byte length
    tay
    .assert sInst::Op_byte = .sizeof(sInst) - 1, error
    dey
    lda Ram_Console_sProgram, y
    and #$f0
    beq @canInsert
    clc  ; clear C to indicate failure
    rts
    @canInsert:
_ShiftInstructions:
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sInst)
    sta Zp_Tmp2_byte  ; byte offset for current instruction
    ldy Zp_Tmp1_byte  ; machine max program byte length
    ldx Zp_Tmp1_byte  ; machine max program byte length
    .repeat .sizeof(sInst)
    dex
    .endrepeat
    @loop:
    dex
    dey
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr, x
    sta Ram_Console_sProgram + sProgram::Code_sInst_arr, y
    cpx Zp_Tmp2_byte  ; byte offset for current instruction
    bne @loop
    ;; Set the current instruction to END, and select field zero.
    lda #eOpcode::End * $10
    sta Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, x
    lda #0
    sta Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Arg_byte, x
    sta Zp_ConsoleFieldNumber_u8
    sta Zp_ConsoleNominalFieldOffset_u8
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
    ;; If it points to before the inserted instruction, no change is needed.
    cmp Zp_ConsoleInstNumber_u8
    blt @continue
    ;; Otherwise, increment the destination address.
    inc Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, x
    @continue:
    .repeat .sizeof(sInst)
    inx
    .endrepeat
    cpx #.sizeof(sInst) * kMaxProgramLength
    blt @loop
_Finish:
    jsr FuncA_Console_TransferAllInstructions
    sec  ; set C to indicate success
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the console instruction field cursor.
;;; @param A True ($ff) to draw the cursor diminished, false ($00) otherwise.
.EXPORT FuncA_Console_DrawFieldCursorObjects
.PROC FuncA_Console_DrawFieldCursorObjects
    sta Zp_Tmp4_byte  ; cursor diminished bool
_YPosition:
    ;; Calculate the window row that the cursor is in.
    lda Zp_ConsoleInstNumber_u8
    cmp Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    sub Zp_ConsoleNumInstRows_u8
    @leftColumn:
    add #1  ; add 1 for the top border
    ;; Calculate the Y-position of the objects and store in Zp_Tmp1_byte.
    mul #kTileHeightPx
    adc Zp_WindowTop_u8  ; carry will by clear
    adc #$ff  ; subtract 1 (carry will still be clear)
    sta Zp_Tmp1_byte  ; Y-position
_XPosition:
    jsr FuncA_Console_GetCurrentFieldOffset  ; preserves Zp_Tmp*, returns A
    mul #kTileWidthPx
    add #kTileWidthPx * 4
    ldx Zp_ConsoleInstNumber_u8
    cpx Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    add #kTileWidthPx * 10
    @leftColumn:
    sta Zp_Tmp2_byte  ; X-position
_PrepareForLoop:
    jsr FuncA_Console_GetCurrentFieldWidth  ; preserves Zp_Tmp*, returns A
    sta Zp_Tmp3_byte  ; cursor width - 1
    tax  ; loop variable (counts from cursor width - 1 down to zero)
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
    lda #bObj::Pri | kCursorObjPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set tile ID.
    lda Zp_Tmp4_byte  ; cursor diminished bool
    bpl @undiminished
    lda Zp_Tmp3_byte  ; cursor width - 1
    beq @dimSingle
    cpx Zp_Tmp3_byte  ; cursor width - 1
    beq @dimLeft
    txa
    bne @continue
    @dimRight:
    lda #kConsoleObjTileIdCursorDimRight
    bne @setTile  ; unconditional
    @dimLeft:
    lda #kConsoleObjTileIdCursorDimLeft
    bne @setTile  ; unconditional
    @dimSingle:
    lda #kConsoleObjTileIdCursorDimSingle
    bne @setTile  ; unconditional
    @undiminished:
    lda Zp_Tmp3_byte  ; cursor width - 1
    beq @tileSingle
    cpx Zp_Tmp3_byte  ; cursor width - 1
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
    @continue:
    dex
    bpl _ObjectLoop
    sty Zp_OamOffset_u8
    rts
.ENDPROC

;;; Transfers the next console window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC FuncA_Console_TransferNextWindowRow
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    cpy Zp_ConsoleNumInstRows_u8
    blt _Interior
    beq _BottomBorder
    cpy #kWindowMaxNumRows
    blt _BottomMargin
    rts
_BottomMargin:
    jmp Func_Window_TransferClearRow
_BottomBorder:
    jmp Func_Window_TransferBottomBorder
_Interior:
    jsr Func_Window_PrepareRowTransfer
    ;; Draw margins, borders, and column separators:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 1, x
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr + 1, x
    sta Ram_PpuTransfer_arr + 21, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 2, x
    ldy Zp_ConsoleNeedsPower_u8
    bne _NeedsPower
_DrawInstructions:
    sta Ram_PpuTransfer_arr + 11, x
    inx
    inx
    ;; Calculate the instruction number for the left column.
    lda Zp_WindowNextRowToTransfer_u8
    sub #2
    sta Zp_ConsoleInstNumber_u8
    ;; Draw the instruction for the left column.
    .assert '0' & $0f = 0, error
    ora #'0'
    sta Ram_PpuTransfer_arr, x
    inx
    lda #':'
    sta Ram_PpuTransfer_arr, x
    inx
    jsr FuncA_Console_WriteInstTransferData
    inx
    ;; Calculate the instruction number for the right column.
    lda Zp_ConsoleInstNumber_u8
    add Zp_ConsoleNumInstRows_u8
    sta Zp_ConsoleInstNumber_u8
    ;; Draw the instruction for the right column.
    .assert '0' & $0f = 0, error
    ora #'0'
    sta Ram_PpuTransfer_arr, x
    inx
    lda #':'
    sta Ram_PpuTransfer_arr, x
    inx
    jsr FuncA_Console_WriteInstTransferData
    inx
    bne _DrawStatus  ; unconditional
_NeedsPower:
    inx
    inx
    tya  ; param: conduit number (1-6)
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    dey  ; param: status box row
    jsr FuncA_Console_WriteNeedsPowerTransferData
    inx
_DrawStatus:
    ;; Draw the status box.
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    dey  ; param: status box row
    jmp FuncA_Console_WriteStatusTransferData
.ENDPROC

;;; Redraws all instructions (over the course of two frames, since it's too
;;; much to transfer to the PPU all in one frame).
.EXPORT FuncA_Console_TransferAllInstructions
.PROC FuncA_Console_TransferAllInstructions
    lda Zp_ConsoleInstNumber_u8
    pha  ; current instruction number
    lda #0
    sta Zp_ConsoleInstNumber_u8
    @loop:
    jsr FuncA_Console_TransferInstruction
    inc Zp_ConsoleInstNumber_u8
    ldx Zp_ConsoleInstNumber_u8
    cpx Zp_ConsoleNumInstRows_u8
    bne @continue
    jsr Func_ProcessFrame
    ldx Zp_ConsoleInstNumber_u8
    @continue:
    cpx Zp_MachineMaxInstructions_u8
    blt @loop
    jsr Func_ProcessFrame
    pla  ; current instruction number
    sta Zp_ConsoleInstNumber_u8
    rts
.ENDPROC

;;; Appends a PPU transfer entry to redraw the current instruction.
.EXPORT FuncA_Console_TransferInstruction
.PROC FuncA_Console_TransferInstruction
    ;; Get the transfer destination address, and store it in Zp_Tmp1_byte (lo)
    ;; and Zp_Tmp2_byte (hi).
    lda Zp_ConsoleInstNumber_u8
    cmp Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    sub Zp_ConsoleNumInstRows_u8
    @leftColumn:
    add #1  ; add 1 for the top border
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    sty Zp_Tmp1_byte
    lda #14
    ldy Zp_ConsoleInstNumber_u8
    cpy Zp_ConsoleNumInstRows_u8
    bge @rightColumn
    lda #4
    @rightColumn:
    add Zp_Tmp1_byte
    sta Zp_Tmp1_byte  ; transfer destination (lo)
    txa
    adc #0
    sta Zp_Tmp2_byte  ; transfer destination (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kInstructionWidthTiles
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
    lda #kInstructionWidthTiles
    sta Ram_PpuTransfer_arr, x
    inx
    .assert * = FuncA_Console_WriteInstTransferData, error, "fallthrough"
.ENDPROC

;;; Writes seven bytes into a PPU transfer entry with the text of instruction
;;; number Zp_ConsoleInstNumber_u8 within Ram_Console_sProgram.
;;; @prereq Zp_Current_sMachine_ptr is initialized.
;;; @param X PPU transfer array index within an entry's data.
;;; @return X Updated PPU transfer array index.
.PROC FuncA_Console_WriteInstTransferData
    jsr FuncA_Console_IsPrevInstructionEmpty
    beq _Write7Spaces
    ;; Store the Arg_byte in Zp_Tmp2_byte.
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Arg_byte, y
    sta Zp_Tmp2_byte  ; Arg_byte
    ;; Store the Op_byte in Zp_Tmp1_byte.
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    sta Zp_Tmp1_byte  ; Op_byte
    ;; Extract the opcode and jump to the correct label below.
    div #$10
    tay
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_Write7Spaces:
    jsr _Write3Spaces
    jmp _Write4Spaces
_JumpTable_ptr_0_arr: .lobytes OpcodeLabels
_JumpTable_ptr_1_arr: .hibytes OpcodeLabels
_OpEmpty:
    ldya #@string
    jsr _WriteString5
    jmp _Write2Spaces
    @string: .byte " ----"
_OpCopy:
    lda Zp_Tmp1_byte  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteArrowLeft
    lda Zp_Tmp2_byte  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write4Spaces
_OpSwap:
    lda Zp_Tmp1_byte  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteArrowLeft
    lda #kTileIdArrowRight
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp2_byte  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write3Spaces
_OpAdd:
    lda #'+'
    jmp _WriteBinop
_OpSub:
    lda #'-'
    jmp _WriteBinop
_OpMul:
    lda #'x'
    jmp _WriteBinop
_OpGoto:
    ldya #@string
    jsr _WriteString5
    lda Zp_Tmp1_byte  ; Op_byte
    and #$0f
    .assert '0' & $0f = 0, error
    ora #'0'
    sta Ram_PpuTransfer_arr, x
    inx
    jmp _Write1Space
    @string: .byte "GOTO "
_OpSkip:
    ldya #@string
    jsr _WriteString5
    lda Zp_Tmp1_byte  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "SKIP "
_OpIf:
    ldya #@string
    jsr _WriteString3
    lda Zp_Tmp2_byte  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteComparisonOperator
    lda Zp_Tmp2_byte  ; Arg_byte
    jsr _WriteHighRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "IF "
_OpTil:
    ldya #@string
    jsr _WriteString3
    jsr _Write1Space
    lda Zp_Tmp2_byte  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteComparisonOperator
    lda Zp_Tmp2_byte  ; Arg_byte
    jmp _WriteHighRegisterOrImmediate
    @string: .byte "TIL"
_OpAct:
    ldya #@string
    jsr _WriteString3
    jmp _Write4Spaces
    @string: .byte "ACT"
_OpMove:
    ldya #@string
    jsr _WriteString5
    lda Zp_Tmp1_byte  ; Op_byte
    and #$03
    .assert eDir::Up = 0, error
    .assert kTileIdArrowUp & $03 = 0, error
    ora #kTileIdArrowUp
    sta Ram_PpuTransfer_arr, x
    inx
    jmp _Write1Space
    @string: .byte "MOVE "
_OpWait:
    ldya #@string
    jsr _WriteString5
    jmp _Write2Spaces
    @string: .byte "WAIT "
_OpBeep:
    ldya #@string
    jsr _WriteString5
    lda Zp_Tmp1_byte  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "BEEP "
_OpEnd:
    ldya #@string
    jsr _WriteString3
    jmp _Write4Spaces
    @string: .byte "END"
_OpNop:
    ldya #@string
    jsr _WriteString3
    jmp _Write4Spaces
    @string: .byte "NOP"
_WriteString3:
    stya Zp_Tmp_ptr
    ldy #0
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #3
    bne @loop
    rts
_WriteString5:
    stya Zp_Tmp_ptr
    ldy #0
    @loop:
    lda (Zp_Tmp_ptr), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #5
    bne @loop
    rts
_WriteBinop:
    pha
    lda Zp_Tmp1_byte  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteArrowLeft
    lda Zp_Tmp2_byte  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    pla
    sta Ram_PpuTransfer_arr, x
    inx
    lda Zp_Tmp2_byte  ; Arg_byte
    jsr _WriteHighRegisterOrImmediate
    jmp _Write2Spaces
_Write4Spaces:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    inx
_Write3Spaces:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    inx
_Write2Spaces:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    inx
_Write1Space:
    lda #kWindowTileIdBlank
    sta Ram_PpuTransfer_arr, x
    inx
    rts
_WriteArrowLeft:
    lda #kTileIdArrowLeft
    sta Ram_PpuTransfer_arr, x
    inx
    rts
_WriteHighRegisterOrImmediate:
    div #$10
_WriteLowRegisterOrImmediate:
    and #$0f
    cmp #$0a  ; immediate values are 0-9; registers are $a-$f
    bge @register
    .assert '0' & $0f = 0, error
    ora #'0'  ; Get tile ID for immediate value (0-9).
    bne @write  ; unconditional
    @register:
    sub #$0a
    tay
    lda Ram_ConsoleRegNames_u8_arr6, y
    @write:
    sta Ram_PpuTransfer_arr, x
    inx
    rts
_WriteComparisonOperator:
    lda Zp_Tmp1_byte  ; Op_byte
    and #$07
    .assert eCmp::Eq = 0, error
    .assert '=' & $07 = 0, error
    ora #'='
    sta Ram_PpuTransfer_arr, x
    inx
    rts
.ENDPROC

;;; Determines if the current instruction number is beyond the first empty
;;; instruction in the program.
;;; @return Z Set if the previous instruction is empty; cleared if the previous
;;;     instruction is not empty (or if we're on the first instruction).
.PROC FuncA_Console_IsPrevInstructionEmpty
    ldy Zp_ConsoleInstNumber_u8
    dey
    bmi @done
    tya
    mul #.sizeof(sInst)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sInst_arr + sInst::Op_byte, y
    and #$f0
    .assert eOpcode::Empty = 0, error
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
