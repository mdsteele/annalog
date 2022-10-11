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

;;; The maximum number of machines that can exist at once in a room.
.DEFINE kMaxMachines 4

;;; The names (i.e. BG/OBJ tile IDs) for registers $a and $b.
kMachineRegNameA = $20  ; 'A'
kMachineRegNameB = $21  ; 'B'

;;;=========================================================================;;;

;;; CHR04 bank numbers to set for various machine status diagrams.
.ENUM eDiagram
    Lift    = $01
    Trolley = $02
    Winch   = $03
    Boiler  = $04
    Field   = $05
    Jet     = $06
.ENDENUM

;;;=========================================================================;;;

;;; Flags indicating features of a given machine.
.SCOPE bMachine
    MoveH  = %10000000  ; The machine supports MOVE left/right instructions.
    FlipH  = %01000000  ; The machine is drawn horizontally flipped.
    MoveV  = %00100000  ; The machine supports MOVE up/down instructions.
    Act    = %00010000  ; The machine supports ACT instructions.
    WriteC = %00001000  ; The $c register is writable.
    WriteD = %00000100  ; The $d register is writable.
    WriteE = %00000010  ; The $e register is writable.
    WriteF = %00000001  ; The $f register is writable.
.ENDSCOPE

;;; States that a given machine can be in.
.ENUM eMachine
    Running    ; The machine is executing its program.
    Resetting  ; The machine is resetting to its original position.
    Working    ; Execution is blocked until the machine reaches its goal.
    Syncing    ; Execution is blocked on a SYNC instruction.
    Waiting    ; Execution is blocked for a set number of frames.
    Ended      ; An END instruction was reached.
    Error      ; The machine tried to do something it couldn't do.
.ENDENUM

;;; Static data about a particular machine.
.STRUCT sMachine
    ;; Which program this machine executes.
    Code_eProgram     .byte
    ;; Which breaker flag must be set in order to use this machine, or zero for
    ;; none.
    Breaker_eFlag     .byte
    ;; Which features this machine supports.
    Flags_bMachine    .byte
    ;; The diagram to display in the console status box.
    Status_eDiagram   .byte
    ;; The X/Y scroll goal to set when using a console to program this machine.
    ScrollGoalX_u16   .word
    ScrollGoalY_u8    .byte
    ;; The names (i.e. BG tile IDs) for registers $c through $f.
    RegNames_u8_arr4  .res 4
    ;; The main platform index for this machine (not used for all machines).
    MainPlatform_u8   .byte
    ;; Function to initialize machine-specific state (when entering the area).
    ;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
    Init_func_ptr     .addr
    ;; Function to get the value of a register $c to $f.  This should be
    ;; side-effect-free, as it is also called when drawing the HUD.
    ;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
    ;; @param A The register to read ($c-$f).
    ;; @return A The value of the register (0-9).
    ReadReg_func_ptr  .addr
    ;; Function to call when a register from $c to $f is written.  If the write
    ;; causes the machine to take some action that takes time, this should call
    ;; FuncA_Machine_StartWorking or FuncA_Machine_StartWaiting; if the write
    ;; is instantaneous, this can just return without changing the mode.
    ;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
    ;; @prereq PRGA_Machine is loaded.
    ;; @param A The register to write to ($c-$f).
    ;; @param X The value to write (0-9).
    WriteReg_func_ptr .addr
    ;; Function to call when the machine tries to move.  If the machine can't
    ;; move, this should call FuncA_Machine_Error; otherwise it should probably
    ;; call FuncA_Machine_StartWorking or FuncA_Machine_StartWaiting.
    ;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
    ;; @prereq PRGA_Machine is loaded.
    ;; @param X The eDir value for the direction to move in.
    TryMove_func_ptr  .addr
    ;; Function to call when the machine tries to act.  If the machine can't
    ;; act, this should call FuncA_Machine_Error; otherwise it should probably
    ;; call FuncA_Machine_StartWorking or FuncA_Machine_StartWaiting.
    ;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
    ;; @prereq PRGA_Machine is loaded.
    TryAct_func_ptr   .addr
    ;; Function to call each frame to update the machine.
    ;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
    ;; @prereq PRGA_Machine is loaded.
    Tick_func_ptr     .addr
    ;; Function to call each frame to draw the machine's objects.
    ;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
    ;; @prereq PRGA_Objects is loaded.
    Draw_func_ptr     .addr
    ;; Function to call to start resetting the machine.
    ;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
    Reset_func_ptr    .addr
.ENDSTRUCT

;;;=========================================================================;;;
