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
.INCLUDE "device.inc"
.INCLUDE "joypad.inc"
.INCLUDE "machine.inc"
.INCLUDE "machines/shared.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "window.inc"

.IMPORT DataA_Console_DiagramBank_u8_arr
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Console_DrawDebugCursor
.IMPORT FuncA_Console_SaveProgram
.IMPORT FuncA_Machine_ExecuteNext
.IMPORT FuncA_Objects_DrawHudInWindowAndObjectsForRoom
.IMPORT FuncA_Room_MachineResetRun
.IMPORT FuncM_ScrollTowardsGoalAndTickConsoleAndProgressTimer
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_PlaySfxMenuCancel
.IMPORT Func_PlaySfxMenuMove
.IMPORT Func_SetMachineIndex
.IMPORT Main_Console_ContinueEditing
.IMPORT Ram_Console_sProgram
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachinePc_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_ConsoleFieldNumber_u8
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_ConsoleNominalFieldOffset_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sProgram_ptr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_MachineIndex_u8
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

;;; True ($ff) if the debugger is "real" (displaying the "DEBEGGER" diagram and
;;; allowing instruction stepping), or false ($00) if the debugger is "fake"
;;; (just reporting an error/halt, and displaying the machine's usual diagram).
Zp_IsRealDebugger_bool: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for reporting a machine halt/error when the console window first
;;; opens, before beginning editing.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Console_ReportHaltOrError
.PROC Main_Console_ReportHaltOrError
    ldx #$00  ; param: is real debugger bool
    beq Main_Console_Debug  ; unconditional
.ENDPROC

;;; Mode for step-debugging a machine program in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Console_StartDebugger
.PROC Main_Console_StartDebugger
    ldx #$ff  ; param: is real debugger bool
    fall Main_Console_Debug
.ENDPROC

;;; Shared mode for step-debugging and error reporting.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
;;; @param X True ($ff) if this is a "real" debugger, false ($00) otherwise.
.PROC Main_Console_Debug
    jsr_prga FuncA_Console_InitDebugger  ; returns Y (param: machines mask)
    jsr_prga FuncA_Room_ResetRunMultipleMachines
_GameLoop:
    jsr_prga FuncA_Objects_DrawHudInWindowAndObjectsForRoom
    jsr_prga FuncA_Console_DrawDebugCursor
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Machine_DebuggerHandleJoypad  ; returns C
    bcs _ResumeEditing
    jsr FuncM_ScrollTowardsGoalAndTickConsoleAndProgressTimer
    jmp _GameLoop
_ResumeEditing:
    jsr_prga FuncA_Console_FinishDebuggingMachine  ; returns Y (param: mask)
    jsr_prga FuncA_Room_ResetRunMultipleMachines
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
.PROC DataA_Console_DebugAttr_sXfer_arr
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_DebugAttrStart1
    d_xfer_data $44
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_DebugAttrStart2
    d_xfer_data $44
    d_xfer_terminator
.ENDPROC

;;; The PPU transfer entry for undoing the nametable attributes changes made by
;;; DataA_Console_DebugAttr_sXfer_arr above.
.PROC DataA_Console_UndoDebugAttr_sXfer_arr
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_DebugAttrStart1
    d_xfer_data $00
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_DebugAttrStart2
    d_xfer_data $00
    d_xfer_terminator
.ENDPROC

;;; Initializes debug mode.
;;; @param X True ($ff) if this is a "real" debugger, false ($00) otherwise.
;;; @return Y A byte with bit N set if the Nth machine should be reset.
.PROC FuncA_Console_InitDebugger
    stx Zp_IsRealDebugger_bool
    lda #0
    sta Zp_DebugHoldAFrames_u8
    ;; If we started the debugger because the machine was already Halted or
    ;; Error when we opened the console, don't change the diagram (and there is
    ;; no need to save the program).
    txa  ; is real debugger bool
    bmi @realDebugger
    ldy #0  ; do not reset any machines
    rts
    @realDebugger:
_SaveProgram:
    jsr Func_SetMachineIndex
    jsr FuncA_Console_SaveProgram
_ChangeDiagram:
    main_chr0c #kChrBankDiagramDebugger
_SetBgAttributes:
    ldax #DataA_Console_DebugAttr_sXfer_arr  ; param: data pointer
    jsr Func_BufferPpuTransfer
_ResetAllMachines:
    fall FuncA_Console_GetResettableMachinesMask  ; returns Y
.ENDPROC

;;; Returns a bitmask that indicates which machines in the room can be reset by
;;; the debugger.  This includes all machines in the room that have at least
;;; one associated console device.
;;; @return Y A byte with bit N set if the Nth machine can be reset.
.PROC FuncA_Console_GetResettableMachinesMask
    ldy #0
    sty T0  ; machines mask
    beq @start  ; unconditional
    @machineLoop:
    ldx #kMaxDevices - 1
    @deviceLoop:
    lda Ram_DeviceType_eDevice_arr, x
    cmp #eDevice::ConsoleFloor
    beq @isConsole
    cmp #eDevice::ConsoleCeiling
    bne @continue  ; this device is not a console
    @isConsole:
    tya  ; machine index
    cmp Ram_DeviceTarget_byte_arr, x
    bne @continue  ; this console is not for this machine
    lda Data_PowersOfTwo_u8_arr8, y
    ora T0  ; machines mask
    sta T0  ; machines mask
    @continue:
    dex
    .assert kMaxDevices <= $80, error
    bpl @deviceLoop
    iny
    @start:
    cpy Zp_Current_sRoom + sRoom::NumMachines_u8
    blt @machineLoop
    ldy T0  ; machines mask
    rts
.ENDPROC

;;; Stops the console debugger, and sets the current machine index so that the
;;; machine can be reset.
;;; @return Y A byte with bit N set if the Nth machine should be reset.
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
    ldax #DataA_Console_UndoDebugAttr_sXfer_arr  ; param: data pointer
    jsr Func_BufferPpuTransfer
_ResetMachines:
    ;; If this is a "real" debugger, reset all resettable machines when
    ;; debugging is over (in case any other machines executed during debugging
    ;; due to this machine hitting a SYNC instruction).
    bit Zp_IsRealDebugger_bool
    bmi FuncA_Console_GetResettableMachinesMask
    ;; If this is a "fake" debugger (error/halt reporting only), then only
    ;; reset this machine.
    ldx Zp_ConsoleMachineIndex_u8
    ldy Data_PowersOfTwo_u8_arr8, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Resets all the machines indicated by the specified bitmask.
;;; @param Y A byte with bit N set if the Nth machine should be reset.
.PROC FuncA_Room_ResetRunMultipleMachines
    ldx #0
    beq @while  ; unconditional
    @loop:
    tya  ; machines mask
    and Data_PowersOfTwo_u8_arr8, x
    beq @continue
    tya  ; machines mask
    pha  ; machines mask
    jsr Func_SetMachineIndex
    jsr FuncA_Room_MachineResetRun
    ldx Zp_MachineIndex_u8
    pla  ; machines mask
    tay  ; machines mask
    @continue:
    inx
    @while:
    cpx Zp_Current_sRoom + sRoom::NumMachines_u8
    blt @loop
    rts
.ENDPROC

;;;=========================================================================;;;
