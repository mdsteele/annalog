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

.INCLUDE "avatar.inc"
.INCLUDE "charmap.inc"
.INCLUDE "cpu.inc"
.INCLUDE "devices/console.inc"
.INCLUDE "flag.inc"
.INCLUDE "hud.inc"
.INCLUDE "joypad.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "spawn.inc"
.INCLUDE "window.inc"

.IMPORT FuncA_Actor_TickAllSmokeActors
.IMPORT FuncA_Console_DrawFieldCursor
.IMPORT FuncA_Console_MoveFieldCursor
.IMPORT FuncA_Console_WriteNeedsPowerTransferData
.IMPORT FuncA_Console_WriteStatusTransferData
.IMPORT FuncA_Machine_TickAll
.IMPORT FuncA_Objects_DrawHudInWindow
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Room_CallRoomTick
.IMPORT FuncA_Room_MachineReset
.IMPORT FuncA_Terrain_ScrollTowardsAvatar
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_GetMachineProgram
.IMPORT Func_IsFlagSet
.IMPORT Func_ProcessFrame
.IMPORT Func_SetLastSpawnPoint
.IMPORT Func_SetMachineIndex
.IMPORT Func_TickAllDevices
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Console_Debug
.IMPORT Main_Explore_Continue
.IMPORT Main_Menu_EditSelectedField
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarSubX_u8
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sProgram_ptr
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_ScrollGoalX_u16
.IMPORTZP Zp_ScrollGoalY_u8
.IMPORTZP Zp_WindowNextRowToTransfer_u8
.IMPORTZP Zp_WindowTopGoal_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; How fast the console window scrolls up/down, in pixels per frame.
kConsoleWindowScrollSpeed = 6

;;; The width of an instruction in the console, in tiles.
kInstructionWidthTiles = 7

;;;=========================================================================;;;

.ZEROPAGE

;;; The index of the machine being controlled by the open console, or $ff if
;;; no console is open.
.EXPORTZP Zp_ConsoleMachineIndex_u8
Zp_ConsoleMachineIndex_u8: .res 1

;;; A pointer to the program in SRAM that the console is currently editing.
Zp_ConsoleSram_sProgram_ptr: .res 2

;;; The number of instruction rows in the console window (i.e. not including
;;; the borders or the bottom margin).
.EXPORTZP Zp_ConsoleNumInstRows_u8
Zp_ConsoleNumInstRows_u8: .res 1

;;; If nonzero, then the console is unpowered and cannot be used; in that case,
;;; the value is the circuit number (1-7) to display to the player in the error
;;; message.
Zp_ConsoleNeedsPower_u8: .res 1
.ASSERT kNumBreakerFlags = 7, error

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

;;; Mode for using a console device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @param X The console device index.
.EXPORT Main_Console_UseDevice
.PROC Main_Console_UseDevice
_SetSpawnPoint:
    txa  ; console device index
    ora #bSpawn::Device  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint  ; preserves X
_OpenConsoleWindow:
    lda Ram_DeviceTarget_byte_arr, x
    tax  ; machine index
    stx Zp_ConsoleMachineIndex_u8
    jsr Func_SetMachineIndex  ; preserves X
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Error
    beq @noReset
    jsr_prga FuncA_Room_MachineReset
    @noReset:
    jsr_prga FuncA_Console_Init
_GameLoop:
    jsr_prga FuncA_Objects_DrawHudInWindowAndObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Console_ScrollWindowUp  ; returns C
    bcs _StartInteraction
    jsr FuncM_ConsoleScrollTowardsGoalAndTick
    jmp _GameLoop
_StartInteraction:
    lda #bHud::NoMachine | bHud::Hidden
    sta Zp_FloatingHud_bHud
    lda Zp_ConsoleNeedsPower_u8
    bne Main_Console_NoPower
    ldx Zp_ConsoleMachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Error
    bne Main_Console_StartEditing
    jmp Main_Console_Debug
.ENDPROC

;;; Mode for using a console for a machine whose required circuit breaker
;;; hasn't yet been activated.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Console_NoPower
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
_CheckButtons:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton | bJoypad::BButton
    bne Main_Console_CloseWindow
_UpdateScrolling:
    jsr FuncM_ConsoleScrollTowardsGoalAndTick
    jmp _GameLoop
.ENDPROC

;;; Mode for scrolling out the console window.  Switches to explore mode once
;;; the window is fully hidden.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Console_CloseWindow
    ;; If the machine is powered, enable the floating HUD.
    lda Zp_ConsoleNeedsPower_u8
    bne @done
    lda Zp_ConsoleMachineIndex_u8
    sta Zp_FloatingHud_bHud
    @done:
_GameLoop:
    jsr_prga FuncA_Objects_DrawHudInWindowAndObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
_ScrollWindowDown:
    lda Zp_WindowTop_u8
    add #kConsoleWindowScrollSpeed
    cmp #kScreenHeightPx
    blt @notDone
    lda #$ff
    @notDone:
    sta Zp_WindowTop_u8
    cmp #$ff
    beq _Done
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsAvatar
    jsr FuncM_ConsoleTick
    jmp _GameLoop
_Done:
    lda #$ff
    sta Zp_ConsoleMachineIndex_u8
    jmp Main_Explore_Continue
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
    jsr_prga FuncA_Objects_DrawHudInWindowAndObjectsForRoom
    jsr_prga FuncA_Console_DrawFieldCursor
    jsr Func_ClearRestOfOamAndProcessFrame
_CheckButtons:
    ;; B button (exit console):
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::BButton = bProc::Overflow, error
    bvc @noClose
    jsr_prga FuncA_Console_SaveProgram
    jmp Main_Console_CloseWindow
    @noClose:
    ;; Start button (start debugging):
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq @noDebug
    ;; Don't start debugging if the program is empty.
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte
    and #$f0
    .assert eOpcode::Empty = 0, error
    beq @noDebug
    jmp Main_Console_Debug
    @noDebug:
    ;; Select button (insert instruction):
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Select
    beq @noInsert
    jsr_prga FuncA_Console_TryInsertInstruction  ; sets C on success
    bcs @edit
    @noInsert:
    ;; A button (edit field):
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bpl @noEdit
    @edit:
    jmp Main_Menu_EditSelectedField
    @noEdit:
    ;; D-pad:
    jsr_prga FuncA_Console_MoveFieldCursor
_Tick:
    jsr FuncM_ConsoleScrollTowardsGoalAndTick
    jmp _GameLoop
.ENDPROC

;;; Calls FuncA_Terrain_ScrollTowardsGoal and then FuncM_ConsoleTick.
.EXPORT FuncM_ConsoleScrollTowardsGoalAndTick
.PROC FuncM_ConsoleScrollTowardsGoalAndTick
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    .assert * = FuncM_ConsoleTick, error, "fallthrough"
.ENDPROC

;;; Calls per-frame tick functions that should still happen even when the
;;; machine console is open.
.PROC FuncM_ConsoleTick
    jsr_prga FuncA_Actor_TickAllSmokeActors
    jsr Func_TickAllDevices
    jsr_prga FuncA_Room_CallRoomTick
    jsr_prga FuncA_Machine_TickAll
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; Initializes console mode.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncA_Console_Init
    jsr FuncA_Console_LoadProgram
    lda Zp_MachineMaxInstructions_u8
    div #2
    sta Zp_ConsoleNumInstRows_u8
_CheckIfPowered:
    ;; Get the breaker eFlag that this machine requires, or zero if the machine
    ;; does not need any circuit breaker to be powered.
    ldy #sMachine::Breaker_eFlag
    lda (Zp_Current_sMachine_ptr), y
    .assert kFirstBreakerFlag > 0, error
    beq @setNeedsPower
    tax  ; param: eFlag
    jsr Func_IsFlagSet  ; preserves X, sets Z if flag is not set
    beq @needsPower
    lda #0
    beq @setNeedsPower  ; unconditional
    @needsPower:
    txa  ; eFlag value
    .assert kFirstBreakerFlag > 1, error
    sub #kFirstBreakerFlag - 1
    @setNeedsPower:
    sta Zp_ConsoleNeedsPower_u8
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
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpCopy
    beq @noRegA
    lda #kMachineRegNameA
    @noRegA:
    sta Ram_ConsoleRegNames_u8_arr6 + 0
    ;; Set name of register $b, or #0 if that register isn't yet unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeBRemote
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
_InitAvatar:
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
_InitWindow:
    lda #kScreenHeightPx - kConsoleWindowScrollSpeed
    sta Zp_WindowTop_u8
    lda #1
    sta Zp_WindowNextRowToTransfer_u8
    ;; Calculate the window top goal from the number of instruction rows.
    lda Zp_ConsoleNumInstRows_u8
    mul #kTileHeightPx
    sta T0  ; instruction pane height in pixels
    lda #kScreenHeightPx - (kTileHeightPx * 2 + kWindowMarginBottomPx)
    sub T0  ; instruction pane height in pixels
    sta Zp_WindowTopGoal_u8
    rts
.ENDPROC

;;; Makes Zp_ConsoleSram_sProgram_ptr point to the current machine's program in
;;; SRAM, then loads the program from SRAM into Ram_Console_sProgram.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncA_Console_LoadProgram
    jsr Func_GetMachineProgram
    ldax Zp_Current_sProgram_ptr
    stax Zp_ConsoleSram_sProgram_ptr
    ;; Initialize Ram_Console_sProgram from SRAM.
    ldy #.sizeof(sProgram) - 1
    @loop:
    lda (Zp_ConsoleSram_sProgram_ptr), y
    sta Ram_Console_sProgram, y
    dey
    bpl @loop
    rts
.ENDPROC

;;; Saves Ram_Console_sProgram back to SRAM.
;;; @prereq Zp_ConsoleSram_sProgram_ptr has been initialized.
.EXPORT FuncA_Console_SaveProgram
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

;;; Scrolls the console window in a bit, and transfers PPU data as needed; call
;;; this each frame when the window is opening.
;;; @return C Set if the window is now fully scrolled in.
.PROC FuncA_Console_ScrollWindowUp
_AdjustAvatar:
    lda #eAvatar::Reading
    sta Zp_AvatarPose_eAvatar
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
    sta Zp_AvatarFlags_bObj
    ;; Slide the player avatar to stand directly in front of the console.
    lda #0
    sta Zp_AvatarSubX_u8
    lda Zp_AvatarPosX_i16 + 0
    and #$0f
    cmp #kConsoleAvatarOffset
    beq @done
    blt @adjustRight
    @adjustLeft:
    dec Zp_AvatarPosX_i16 + 0
    bne @done  ; unconditional
    @adjustRight:
    inc Zp_AvatarPosX_i16 + 0
    @done:
_ScrollWindow:
    lda Zp_WindowTop_u8
    sub #kConsoleWindowScrollSpeed
    cmp Zp_WindowTopGoal_u8
    bge @notDone
    lda Zp_WindowTopGoal_u8
    @notDone:
    sta Zp_WindowTop_u8
    jsr FuncA_Console_TransferNextWindowRow
_CheckIfDone:
    lda Zp_WindowTopGoal_u8
    cmp Zp_WindowTop_u8  ; clears C if Zp_WindowTopGoal_u8 < Zp_WindowTop_u8
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
    mul #.sizeof(sIns)
    sta T0  ; machine max program byte length
    tay
    .assert sIns::Op_byte = .sizeof(sIns) - 1, error
    dey
    lda Ram_Console_sProgram, y
    and #$f0
    beq @canInsert
    clc  ; clear C to indicate failure
    rts
    @canInsert:
_ShiftInstructions:
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sIns)
    sta T1  ; byte offset for current instruction
    ldy T0  ; machine max program byte length
    ldx T0  ; machine max program byte length
    .repeat .sizeof(sIns)
    dex
    .endrepeat
    @loop:
    dex
    dey
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr, x
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr, y
    cpx T1  ; byte offset for current instruction
    bne @loop
    ;; Set the current instruction to NOP, and select field zero.
    lda #eOpcode::Nop * $10
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    lda #0
    sta Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, x
    sta Zp_ConsoleFieldNumber_u8
    sta Zp_ConsoleNominalFieldOffset_u8
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
    ;; If it points to before the inserted instruction, no change is needed.
    cmp Zp_ConsoleInstNumber_u8
    blt @continue
    ;; Otherwise, increment the destination address.
    inc Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, x
    @continue:
    .repeat .sizeof(sIns)
    inx
    .endrepeat
    cpx #.sizeof(sIns) * kMaxProgramLength
    blt @loop
_Finish:
    jsr FuncA_Console_TransferAllInstructions
    sec  ; set C to indicate success
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
    cpy #kWindowMaxNumRows - 1
    blt _BottomMargin
    rts
_BottomMargin:
    jmp Func_Window_TransferClearRow
_BottomBorder:
    jmp Func_Window_TransferBottomBorder
_Interior:
    jsr Func_Window_PrepareRowTransfer
    ;; Draw margins, borders, and column separators:
    lda #' '
    sta Ram_PpuTransfer_arr, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 1, x
    lda #kTileIdBgWindowVert
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
    tya  ; param: circuit number (1-7)
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
    ;; Get the transfer destination address, and store it in T0 (lo) and T1
    ;; (hi).
    lda Zp_ConsoleInstNumber_u8
    cmp Zp_ConsoleNumInstRows_u8
    blt @leftColumn
    sub Zp_ConsoleNumInstRows_u8
    @leftColumn:
    add #1  ; add 1 for the top border
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    sty T0  ; window row PPU address (lo)
    lda #14
    ldy Zp_ConsoleInstNumber_u8
    cpy Zp_ConsoleNumInstRows_u8
    bge @rightColumn
    lda #4
    @rightColumn:
    add T0  ; window row PPU address (lo)
    sta T0  ; transfer destination (lo)
    txa     ; window row PPU address (hi)
    adc #0
    sta T1  ; transfer destination (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #4 + kInstructionWidthTiles
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
    lda #kInstructionWidthTiles
    sta Ram_PpuTransfer_arr, x
    inx
    .assert * = FuncA_Console_WriteInstTransferData, error, "fallthrough"
.ENDPROC

;;; Writes seven bytes into a PPU transfer entry with the text of instruction
;;; number Zp_ConsoleInstNumber_u8 within Ram_Console_sProgram.
;;; @param X PPU transfer array index within an entry's data.
;;; @return X Updated PPU transfer array index.
.PROC FuncA_Console_WriteInstTransferData
    jsr FuncA_Console_IsPrevInstructionEmpty
    beq _Write7Spaces
    ;; Store the Arg_byte in T1.
    lda Zp_ConsoleInstNumber_u8
    mul #.sizeof(sIns)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Arg_byte, y
    sta T1  ; Arg_byte
    ;; Store the Op_byte in T0.
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, y
    sta T0  ; Op_byte
    ;; Extract the opcode and jump to the correct label below.
    div #$10
    tay
    lda _JumpTable_ptr_0_arr, y
    sta T2
    lda _JumpTable_ptr_1_arr, y
    sta T3
    jmp (T3T2)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eOpcode
    d_entry table, Empty, _OpEmpty
    d_entry table, Copy,  _OpCopy
    d_entry table, Sync,  _OpSync
    d_entry table, Add,   _OpAdd
    d_entry table, Sub,   _OpSub
    d_entry table, Mul,   _OpMul
    d_entry table, Goto,  _OpGoto
    d_entry table, Skip,  _OpSkip
    d_entry table, If,    _OpIf
    d_entry table, Til,   _OpTil
    d_entry table, Act,   _OpAct
    d_entry table, Move,  _OpMove
    d_entry table, Rest,  _OpRest
    d_entry table, Beep,  _OpBeep
    d_entry table, End,   _OpEnd
    d_entry table, Nop,   _OpNop
    D_END
.ENDREPEAT
_Write7Spaces:
    jsr _Write3Spaces
    jmp _Write4Spaces
_OpEmpty:
_OpNop:
    ldya #@string
    jsr _WriteString5
    jmp _Write2Spaces
    @string: .byte " ----"
_OpCopy:
    lda T0  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteArrowLeft
    lda T1  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write4Spaces
_OpSync:
    ldya #@string
    jsr _WriteString5
    jmp _Write2Spaces
    @string: .byte "SYNC "
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
    lda T0  ; Op_byte
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
    lda T0  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "SKIP "
_OpIf:
    ldya #@string
    jsr _WriteString3
    lda T1  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteComparisonOperator
    lda T1  ; Arg_byte
    jsr _WriteHighRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "IF "
_OpTil:
    ldya #@string
    jsr _WriteString3
    jsr _Write1Space
    lda T1  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteComparisonOperator
    lda T1  ; Arg_byte
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
    lda T0  ; Op_byte
    .assert eDir::NUM_VALUES = 4, error
    and #$03
    .assert eDir::Up    = kTileIdBgArrowUp    - kTileIdBgArrowUp, error
    .assert eDir::Right = kTileIdBgArrowRight - kTileIdBgArrowUp, error
    .assert eDir::Down  = kTileIdBgArrowDown  - kTileIdBgArrowUp, error
    .assert eDir::Left  = kTileIdBgArrowLeft  - kTileIdBgArrowUp, error
    .assert kTileIdBgArrowUp & $03 = 0, error
    ora #kTileIdBgArrowUp
    sta Ram_PpuTransfer_arr, x
    inx
    jmp _Write1Space
    @string: .byte "MOVE "
_OpRest:
    ldya #@string
    jsr _WriteString5
    jmp _Write2Spaces
    @string: .byte "REST "
_OpBeep:
    ldya #@string
    jsr _WriteString5
    lda T0  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jmp _Write1Space
    @string: .byte "BEEP "
_OpEnd:
    ldya #@string
    jsr _WriteString3
    jmp _Write4Spaces
    @string: .byte "END"
_WriteString3:
    stya T3T2
    ldy #0
    @loop:
    lda (T3T2), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #3
    bne @loop
    rts
_WriteString5:
    stya T3T2
    ldy #0
    @loop:
    lda (T3T2), y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #5
    bne @loop
    rts
_WriteBinop:
    pha
    lda T0  ; Op_byte
    jsr _WriteLowRegisterOrImmediate
    jsr _WriteArrowLeft
    lda T1  ; Arg_byte
    jsr _WriteLowRegisterOrImmediate
    pla
    sta Ram_PpuTransfer_arr, x
    inx
    lda T1  ; Arg_byte
    jsr _WriteHighRegisterOrImmediate
    jmp _Write2Spaces
_Write4Spaces:
    lda #' '
    sta Ram_PpuTransfer_arr, x
    inx
_Write3Spaces:
    lda #' '
    sta Ram_PpuTransfer_arr, x
    inx
_Write2Spaces:
    lda #' '
    sta Ram_PpuTransfer_arr, x
    inx
_Write1Space:
    lda #' '
    sta Ram_PpuTransfer_arr, x
    inx
    rts
_WriteArrowLeft:
    lda #kTileIdBgArrowLeft
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
    lda T0  ; Op_byte
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
.EXPORT FuncA_Console_IsPrevInstructionEmpty
.PROC FuncA_Console_IsPrevInstructionEmpty
    ldy Zp_ConsoleInstNumber_u8
    dey
    bmi @done
    tya
    mul #.sizeof(sIns)
    tay
    lda Ram_Console_sProgram + sProgram::Code_sIns_arr + sIns::Op_byte, y
    and #$f0
    .assert eOpcode::Empty = 0, error
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the in-window console HUD, as well as any objects in the room.
.EXPORT FuncA_Objects_DrawHudInWindowAndObjectsForRoom
.PROC FuncA_Objects_DrawHudInWindowAndObjectsForRoom
_Hud:
    lda Zp_ConsoleNeedsPower_u8
    bne @done
    ldx Zp_ConsoleMachineIndex_u8  ; param: machine index
    jsr Func_SetMachineIndex
    jsr FuncA_Objects_DrawHudInWindow
    @done:
_Room:
    jmp FuncA_Objects_DrawObjectsForRoom
.ENDPROC

;;;=========================================================================;;;
