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
    Halted     ; Empty program, or an END instruction was reached.
    Running    ; The machine is executing its program.
    Resetting  ; The machine is resetting to its original position.
    ErrMove    ; Error: The machine tried to move, but couldn't.
.ENDENUM

;;; Static data about a particular machine.
.STRUCT sMachine
    ;; Which program this machine executes.
    Code_eProgram     .byte
    ;; Which features this machine supports.
    Flags_bMachine    .byte
    ;; The names (i.e. BG tile IDs) for registers $a through $f.
    RegNames_u8_arr6  .res 6
    ;; Functions to call when a register from $c to $f is read/written.
    ;; TODO: What is the signature of these functions?
    ReadReg_func_ptr  .addr
    WriteReg_func_ptr .addr
    ;; Function to call when the machine tries to move.
    ;; TODO: What is the signature of this function?
    Move_func_ptr     .addr
    ;; Function to call when the machine tries to act.
    ;; TODO: What is the signature of this function?
    Act_func_ptr      .addr
    ;; Function to call each frame to update the machine.
    ;; TODO: What is the signature of this function?
    Tick_func_ptr     .addr
    ;; Function to call each frame to draw the machine's objects.
    ;; TODO: What is the signature of this function?
    Draw_func_ptr     .addr
    ;; Function to call to reset the machine.
    ;; TODO: What is the signature of this function?
    Reset_func_ptr    .addr
    ;; Unused space to pad .sizeof(sMachine) to a power of 2.
    Reserved          .res $0a
.ENDSTRUCT
.ASSERT .sizeof(sMachine) = $20, error

;;;=========================================================================;;;
