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

.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_MachineFinishResetting
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; How many frames a teleport field machine spends per act operation.
kFieldActCooldown = $80

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "T" register for a teleport field machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The value of the machine's "T" register (0-9).
.EXPORT Func_MachineFieldReadRegT
.PROC Func_MachineFieldReadRegT
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, x
    .assert kFieldActCooldown + $1f < $100, error
    add #$1f
    div #$20
    .assert (kFieldActCooldown + $1f) / $20 <= 9, error
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryAct implemention for teleport field machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.EXPORT FuncA_Machine_FieldTryAct
.PROC FuncA_Machine_FieldTryAct
    ;; TODO: do teleport if avatar is within the teleportor
    ldx Zp_MachineIndex_u8
    lda #kFieldActCooldown
    sta Ram_MachineParam1_u8_arr, x
    clc  ; success
    rts
.ENDPROC

;;; Tick implemention for teleport field machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_FieldTick
.PROC FuncA_Machine_FieldTick
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, x
    jeq Func_MachineFinishResetting
    dec Ram_MachineParam1_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a teleport field machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawFieldMachine
.PROC FuncA_Objects_DrawFieldMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_Light:
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @done
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
    ;; TODO: draw rest of machine
    ;; TODO: draw teleportation effect
    rts
.ENDPROC

;;;=========================================================================;;;
