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
.INCLUDE "../ppu.inc"
.INCLUDE "pump.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tick implementation for lift machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
;;; @param X The platform index for the water to move.
;;; @param YA The maximum platform top position for the water.
.EXPORT FuncA_Machine_PumpTick
.PROC FuncA_Machine_PumpTick
    stya Zp_PointY_i16  ; max water platform top
    ;; Calculate the desired Y-position for the top edge of the water, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    mul #kBlockHeightPx
    sta T0  ; goal delta
    lda Zp_PointY_i16 + 0  ; max water platform top (lo)
    sub T0  ; goal delta
    sta Zp_PointY_i16 + 0
    lda Zp_PointY_i16 + 1  ; max water platform top (hi)
    sbc #0
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the water (faster if resetting).
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Resetting
    beq @fullSpeed
    lda Ram_MachineSlowdown_u8_arr, y
    beq @canMove
    rts
    @canMove:
    lda #kPumpWaterSlowdown
    sta Ram_MachineSlowdown_u8_arr, y
    @fullSpeed:
    ;; Move the water vertically, as necessary.
    lda #1  ; param: move delta
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a pump machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawPumpMachine
.PROC FuncA_Objects_DrawPumpMachine
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A
    cmp #kTileIdObjMachineLightOn
    bne @done
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    lda #kTileIdObjPumpLight  ; param: tile ID
    ldy #kPaletteObjMachineLight  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
