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
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"

.IMPORT FuncA_Console_DrawDebugCursor
.IMPORT FuncA_Machine_ExecuteNext
.IMPORT FuncA_Objects_DrawHudInWindowAndObjectsForRoom
.IMPORT FuncA_Room_MachineReset
.IMPORT FuncM_ConsoleScrollTowardsGoalAndTick
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_SetMachineIndex
.IMPORT Main_Console_ContinueEditing
.IMPORT Ram_Console_sProgram
.IMPORT Ram_MachinePc_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_ConsoleFieldNumber_u8
.IMPORTZP Zp_ConsoleInstNumber_u8
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_ConsoleNominalFieldOffset_u8
.IMPORTZP Zp_Current_sProgram_ptr
.IMPORTZP Zp_P1ButtonsPressed_bJoypad

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for step-debugging a machine in the console window.
;;; @prereq Rendering is enabled.
;;; @prereq The console window is fully visible.
;;; @prereq Explore mode is initialized.
.EXPORT Main_Console_Debug
.PROC Main_Console_Debug
_GameLoop:
    jsr_prga FuncA_Objects_DrawHudInWindowAndObjectsForRoom
    jsr_prga FuncA_Console_DrawDebugCursor
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Machine_DebuggerHandleJoypad  ; returns C
    bcs _ResumeEditing
    jsr FuncM_ConsoleScrollTowardsGoalAndTick
    jmp _GameLoop
_ResumeEditing:
    jsr_prga FuncA_Room_FinishDebuggingMachine
    jmp Main_Console_ContinueEditing
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Responds to any joypad presses while in debugging mode.
;;; @return C Set if we should stop debugging.
.PROC FuncA_Machine_DebuggerHandleJoypad
_HandleStartButton:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    bne _StopDebugging
_HandleBButton:
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::BButton = bProc::Overflow, error
    bvc @done
    ;; If the machine is Ended or Error, pressing B exits debug mode (in
    ;; particular so that a novice player can easily dismiss a machine error
    ;; report by mashing buttons).  Otherwise, ignore the B button (so that it
    ;; can be used to control the B-Remote during debugging).
    ldx Zp_ConsoleMachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Error
    beq _StopDebugging
    cmp #eMachine::Ended
    beq _StopDebugging
    @done:
_HandleAButton:
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bpl _ContinueDebugging
    ldx Zp_ConsoleMachineIndex_u8
    ;; If the machine status is Running, execute the next instruction.
    lda Ram_MachineStatus_eMachine_arr, x
    .assert eMachine::Running = 0, error
    beq _ExecuteNext
    ;; TODO: If status is Syncing, skip past the SYNC instruction.
    ;; If the machine status is Ended or Error, stop debugging.  Otherwise, the
    ;; machine is either resetting or still blocked on the current instruction;
    ;; in either case the debugger can't advance yet, so we do nothing.
    cmp #eMachine::Ended
    beq _StopDebugging
    cmp #eMachine::Error
    bne _ContinueDebugging
_StopDebugging:
    sec  ; set C to indicate that debugging should stop
    rts
_ExecuteNext:
    jsr Func_SetMachineIndex
    ldax #Ram_Console_sProgram
    stax Zp_Current_sProgram_ptr
    jsr FuncA_Machine_ExecuteNext
_ContinueDebugging:
    clc  ; clear C to indicate that debugging should continue
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Stops the console debugger.
.PROC FuncA_Room_FinishDebuggingMachine
    ;; Make the console field cursor point at the current instruction.
    ldx Zp_ConsoleMachineIndex_u8  ; param: machine index
    lda Ram_MachinePc_u8_arr, x
    sta Zp_ConsoleInstNumber_u8
    lda #0
    sta Zp_ConsoleFieldNumber_u8
    sta Zp_ConsoleNominalFieldOffset_u8
    ;; Reset the machine.
    jsr Func_SetMachineIndex
    jmp FuncA_Room_MachineReset
.ENDPROC

;;;=========================================================================;;;
