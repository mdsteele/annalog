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

;;; The maximum number of devices that can exist at once in an area.
kMaxMachines = 8

;;; The number of padding bytes at the end of each sMachine struct.
.DEFINE kMachinePadding 6

;;; How many bytes of RAM are reserved for room-specific machine state.
kMachineStateSize = $c0

;;; The OBJ palette number used for the blinking error light on machines.
kMachineLightPalette = 1

;;;=========================================================================;;;

;;; CHR04 bank numbers to set for various machine status diagrams.
.ENUM eDiagram
    Barrier = $01
    Trolley = $02
.ENDENUM

;;;=========================================================================;;;

;;; Flags indicating features of a given machine.
.SCOPE bMachine
    MoveH  = %10000000  ; The machine supports MOVE left/right instructions.
    MoveV  = %01000000  ; The machine supports MOVE up/down instructions.
    Act    = %00100000  ; The machine supports ACT instructions.
    WriteC = %00001000  ; The $c register is writable.
    WriteD = %00000100  ; The $d register is writable.
    WriteE = %00000010  ; The $e register is writable.
    WriteF = %00000001  ; The $f register is writable.
.ENDSCOPE

;;; States that a given machine can be in.
.ENUM eMachine
    Running    ; The machine is executing its program.
    Resetting  ; The machine is resetting to its original position.
    Ended      ; An END instruction was reached.
    Error      ; The machine tried to do something it couldn't do.
.ENDENUM

;;; Static data about a particular machine.
.STRUCT sMachine
    ;; Which program this machine executes.
    Code_eProgram     .byte
    ;; Which features this machine supports.
    Flags_bMachine    .byte
    ;; The diagram to display in the console status box.
    Status_eDiagram   .byte
    ;; The X/Y scroll goal to set when using a console to program this machine.
    ScrollGoalX_u16   .word
    ScrollGoalY_u8    .byte
    ;; The names (i.e. BG tile IDs) for registers $c through $f.
    RegNames_u8_arr4  .res 4
    ;; Function to initialize machine-specific state (when entering the area).
    Init_func_ptr     .addr
    ;; Function to call when a register from $c to $f is read.
    ;; @param A The register to read ($c-$f).
    ;; @return A The value of the register (0-9).
    ReadReg_func_ptr  .addr
    ;; Function to call when a register from $c to $f is written.
    ;; @param A The register to write to ($c-$f).
    ;; @param X The value to write (0-9).
    WriteReg_func_ptr .addr
    ;; Function to call when the machine tries to move.
    ;; @param X The eDir value for the direction to move in.
    ;; @return C Cleared if the machine was able to move, set otherwise.
    TryMove_func_ptr  .addr
    ;; Function to call when the machine tries to act.
    ;; @return C Cleared if the machine was able to act, set otherwise.
    TryAct_func_ptr   .addr
    ;; Function to call each frame to update the machine.
    Tick_func_ptr     .addr
    ;; Function to call each frame to draw the machine's objects.  The
    ;; function's code may reside in PRG8, PRGE, PRGA_Objects, or in its room's
    ;; PRGC bank.
    Draw_func_ptr     .addr
    ;; Function to call to start resetting the machine.
    Reset_func_ptr    .addr
    ;; Unused space to pad .sizeof(sMachine) to a power of 2.
    Padding           .res kMachinePadding
.ENDSTRUCT
.ASSERT .sizeof(sMachine) = $20, error

;;;=========================================================================;;;
