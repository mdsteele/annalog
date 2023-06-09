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
.INCLUDE "../ppu.inc"
.INCLUDE "reloader.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Ram_MachineState1_byte_arr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; The OBJ palette number used for drawing reloader machines.
kPaletteObjRocket = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a rocket ammo rack machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawAmmoRackMachine
.PROC FuncA_Objects_DrawAmmoRackMachine
_RocketSlots:
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeRightOneTile
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; ammo slot bits
    sta T2  ; ammo slot bits
    @loop:
    lsr T2
    bcc @continue
    ldy #kPaletteObjRocket  ; param: object flags
    lda #kTileIdObjReloaderRocketVert  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves T2+
    @continue:
    lda #kTileWidthPx * 2
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves T0+
    lda T2  ; ammo slot bits
    bne @loop
_MachineLight:
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A (param: tile ID)
    ldy #kPaletteObjMachineLight | bObj::FlipV  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
