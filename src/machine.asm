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
.INCLUDE "machine.inc"
.INCLUDE "program.inc"

;;;=========================================================================;;;

.ZEROPAGE

;;; A pointer to the machine data array for the current area.  This is expected
;;; to point somewhere in PRGC.
.EXPORTZP Zp_Machines_sMachine_arr_ptr
Zp_Machines_sMachine_arr_ptr: .res 2

;;;=========================================================================;;;

.SEGMENT "RAM_Machine"

;;; The current status for each machine.
Ram_MachineStatus_eMachine_arr: .res kMaxMachines

;;; The program counter for each machine.
Ram_MachinePc_u8_arr: .res kMaxMachines

;;; The value of the $a register for each machine.
Ram_MachineRegA_u8_arr: .res kMaxMachines

;;; TODO: Machine position and other state.

;;;=========================================================================;;;

.SEGMENT "PRGC_Room"

.EXPORT DataC_Machines_sMachine_arr
.PROC DataC_Machines_sMachine_arr
    .byte eProgram::JailCellDoor
    .byte bMachine::MoveV
    .byte "T", "R", 0, 0, 0, "Y"
    .res $18  ; TODO: other sMachine fields
.ENDPROC
.ASSERT * - DataC_Machines_sMachine_arr = .sizeof(sMachine) * 1, error

;;;=========================================================================;;;
