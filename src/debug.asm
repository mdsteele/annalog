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
.INCLUDE "machine.inc"
.INCLUDE "machines/shared.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "window.inc"

.IMPORT DataA_Console_DiagramBank_u8_arr
.IMPORT FuncA_Console_DrawDebugCursor
.IMPORT FuncA_Console_SaveProgram
.IMPORT FuncA_Machine_ExecuteNext
.IMPORT FuncA_Objects_DrawHudInWindowAndObjectsForRoom
.IMPORT FuncA_Room_MachineResetRun
.IMPORT FuncM_ConsoleScrollTowardsGoalAndTick
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_PlaySfxMenuCancel
.IMPORT Func_PlaySfxMenuMove
.IMPORT Func_SetMachineIndex
.IMPORT Main_Console_ContinueEditing
.IMPORT Ram_Console_sProgram
.IMPORT Ram_MachinePc_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_ConsoleFieldNumber_u8
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_ConsoleNominalFieldOffset_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sProgram_ptr
.IMPORTZP Zp_P1ButtonsHeld_bJoypad
.IMPORTZP Zp_P1ButtonsPressed_bJoypad

;;;=========================================================================;;;

;;; How long the A button must be initially held down, in frames, before the
;;; debugger will begin repeatedly stepping through instructions for as long as
;;; the button is still held.
kDebugStepRepeatDelay = 30

;;; The PPU addresses (within the lower nametable) for the starts of the
;;; attribute bytes that cover the debug diagram.
.LINECONT +
.ASSERT (kWindowStartRow + 1) .mod 4 = 0, error
Ppu_DebugAttrStart1 = Ppu_Nametable3_sName + sName::Attrs_u8_arr64 + \
    ((kWindowStartRow + 1) / 4) * 8 + 5
Ppu_DebugAttrStart2 = Ppu_Nametable3_sName + sName::Attrs_u8_arr64 + \
    ((kWindowStartRow + 5) / 4) * 8 + 5
.LINECONT -

;;;=========================================================================;;;

.ZEROPAGE

;;; How many frames the A button has been held down for in the debugger, up to
;;; a maximum of kDebugStepRepeatDelay.
Zp_DebugHoldAFrames_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for step-debugging a machine in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Console_Debug
.PROC Main_Console_Debug
    jsr_prga FuncA_Console_InitDebugger
_GameLoop:
    jsr_prga FuncA_Objects_DrawHudInWindowAndObjectsForRoom
    jsr_prga FuncA_Console_DrawDebugCursor
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Machine_DebuggerHandleJoypad  ; returns C
    bcs _ResumeEditing
    jsr FuncM_ConsoleScrollTowardsGoalAndTick
    jmp _GameLoop
_ResumeEditing:
    jsr_prga FuncA_Console_FinishDebuggingMachine
    jsr_prga FuncA_Room_MachineResetRun
    jmp Main_Console_ContinueEditing
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Responds to any joypad presses while in debugging mode.
;;; @return C Set if we should stop debugging.
.PROC FuncA_Machine_DebuggerHandleJoypad
    ldx Zp_ConsoleMachineIndex_u8
_HandleStartButtonPress:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    bne _StopDebugging
_HandleBButtonPress:
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::BButton = bProc::Overflow, error
    bvc @done
    ;; If the machine is Halted or Error, pressing B exits debug mode (in
    ;; particular so that a novice player can easily dismiss a machine error
    ;; report by mashing buttons).  Otherwise, ignore the B button (so that it
    ;; can be used to control the B-Remote during debugging).
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Error
    beq _StopDebugging
    cmp #eMachine::Halted
    beq _StopDebugging
    @done:
_HandleAButtonPress:
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bpl @done  ; A button was not pressed this frame
    ;; If the machine status is Running, execute the next instruction.
    lda Ram_MachineStatus_eMachine_arr, x
    .assert eMachine::Running = 0, error
    beq _ExecuteNext
    ;; If the machine is Halted or Error, stop debugging.  Otherwise, the
    ;; machine is either resetting or still blocked on the current instruction;
    ;; in either case the debugger can't advance yet, so we do nothing.
    cmp #eMachine::Halted
    beq _StopDebugging
    cmp #eMachine::Error
    beq _StopDebugging
    @done:
_HandleAButtonHeld:
    bit Zp_P1ButtonsHeld_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bmi @holdingA
    @notHoldingA:
    lda #0
    sta Zp_DebugHoldAFrames_u8
    beq _ContinueDebugging  ; unconditional
    @holdingA:
    lda Zp_DebugHoldAFrames_u8
    cmp #kDebugStepRepeatDelay
    bge _ExecuteNextIfRunning
    inc Zp_DebugHoldAFrames_u8
    bne _ContinueDebugging  ; unconditional
_ExecuteNextIfRunning:
    lda Ram_MachineStatus_eMachine_arr, x
    .assert eMachine::Running = 0, error
    bne _ContinueDebugging
_ExecuteNext:
    jsr Func_PlaySfxMenuMove
    jsr Func_SetMachineIndex
    ldax #Ram_Console_sProgram
    stax Zp_Current_sProgram_ptr
    jsr FuncA_Machine_ExecuteNext
_ContinueDebugging:
    clc  ; clear C to indicate that debugging should continue
    rts
_StopDebugging:
    jsr Func_PlaySfxMenuCancel
    sec  ; set C to indicate that debugging should stop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; The PPU transfer entry for setting nametable attributes for the debugger
;;; diagram.
.PROC DataA_Console_DebugAttrTransfer_arr
_Row1:
    .byte kPpuCtrlFlagsHorz      ; control flags
    .dbyt Ppu_DebugAttrStart1    ; destination address
    .byte @dataEnd - @dataStart  ; transfer length
    @dataStart:
    .byte $44
    @dataEnd:
_Row2:
    .byte kPpuCtrlFlagsHorz      ; control flags
    .dbyt Ppu_DebugAttrStart2    ; destination address
    .byte @dataEnd - @dataStart  ; transfer length
    @dataStart:
    .byte $44
    @dataEnd:
.ENDPROC

;;; The PPU transfer entry for undoing the nametable attributes changes made by
;;; DataA_Console_DebugAttrTransfer_arr above.
.PROC DataA_Console_UndoDebugAttrTransfer_arr
_Row1:
    .byte kPpuCtrlFlagsHorz      ; control flags
    .dbyt Ppu_DebugAttrStart1    ; destination address
    .byte @dataEnd - @dataStart  ; transfer length
    @dataStart:
    .byte $00
    @dataEnd:
_Row2:
    .byte kPpuCtrlFlagsHorz      ; control flags
    .dbyt Ppu_DebugAttrStart2    ; destination address
    .byte @dataEnd - @dataStart  ; transfer length
    @dataStart:
    .byte $00
    @dataEnd:
.ENDPROC

;;; Initializes debug mode.
.PROC FuncA_Console_InitDebugger
    lda #0
    sta Zp_DebugHoldAFrames_u8
    ;; If we started the debugger because the machine was already Halted or
    ;; Error when we opened the console, don't change the diagram (and there is
    ;; no need to save the program).
    ldx Zp_ConsoleMachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Error
    beq _Return
    cmp #eMachine::Halted
    beq _Return
_SaveProgram:
    jsr Func_SetMachineIndex
    jsr FuncA_Console_SaveProgram
_ChangeDiagram:
    main_chr0c #kChrBankDiagramDebugger
_SetBgAttributes:
    ldax #DataA_Console_DebugAttrTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Console_DebugAttrTransfer_arr)  ; param: data size
    jmp Func_BufferPpuTransfer
_Return:
    rts
.ENDPROC

;;; Stops the console debugger, and sets the current machine index so that the
;;; machine can be reset.
.PROC FuncA_Console_FinishDebuggingMachine
    ;; Make the console field cursor point at the current instruction.
    ldx Zp_ConsoleMachineIndex_u8  ; param: machine index
    lda Ram_MachinePc_u8_arr, x
    sta Zp_ConsoleInstNumber_u8
    lda #0
    sta Zp_ConsoleFieldNumber_u8
    sta Zp_ConsoleNominalFieldOffset_u8
    jsr Func_SetMachineIndex
_ChangeDiagram:
    ldy #sMachine::Status_eDiagram
    lda (Zp_Current_sMachine_ptr), y
    tax  ; eDiagram value
    main_chr0c DataA_Console_DiagramBank_u8_arr, x
_ResetBgAttributes:
    ldax #DataA_Console_UndoDebugAttrTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Console_UndoDebugAttrTransfer_arr)  ; param: data size
    jmp Func_BufferPpuTransfer
.ENDPROC

;;;=========================================================================;;;
