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

.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_PlaySfxConveyor
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Ppu_ChrBgAnimB0
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; Factor between the State1 conveyor motion counter and swiching CHR banks.
.DEFINE kConveyorSlowdown 8

;;; How long it takes a conveyor machine to switch gears, in frames.
kConveyorGearCooldown = 15

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implemention for conveyor machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_ConveyorWriteReg
.PROC FuncA_Machine_ConveyorWriteReg
    ;; If the gear value is the same as before, do nothing (and don't make the
    ;; machine wait for a cooldown).
    ldy Zp_MachineIndex_u8
    cmp Ram_MachineGoalHorz_u8_arr, y  ; conveyor gear
    bne @setGear
    rts
    ;; Change the gear value.
    @setGear:
    sta Ram_MachineGoalHorz_u8_arr, y  ; conveyor gear
    jsr FuncA_Machine_PlaySfxConveyor
    ;; Make the machine wait a bit.
    lda #kConveyorGearCooldown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for conveyor machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawConveyorMachine
.PROC FuncA_Objects_DrawConveyorMachine
_Belts:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; conveyor motion
    div #kConveyorSlowdown
    and #$03
    add #<.bank(Ppu_ChrBgAnimB0)
    sta Zp_Chr04Bank_u8
_Machine:
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    ldy #kPaletteObjMachineLight | bObj::FlipV  ; param: object flags
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
