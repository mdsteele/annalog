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
.INCLUDE "emitter.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_DivMod
.IMPORT Func_GetRandomByte
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; OBJ tiles IDs used for drawing emitter machines.
kTileIdObjEmitterBeamHorz   = kTileIdObjEmitterFirst + 0
kTileIdObjEmitterBeamVert   = kTileIdObjEmitterFirst + 1
kTileIdObjEmitterGlowXFirst = kTileIdObjEmitterFirst + 2
kTileIdObjEmitterGlowYFirst = kTileIdObjEmitterFirst + 4

;;; OBJ palette numbers used for drawing emitter machines.
kPaletteObjEmitterBeam = 1
kPaletteObjEmitterGlow = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a forcefield emitter machine that fires a vertical beam at various
;;; X-positions.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The length of the beam, in tiles.
.EXPORT FuncA_Objects_DrawEmitterXMachine
.PROC FuncA_Objects_DrawEmitterXMachine
    sta T0  ; beam length in tiles
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    lda #kBlockHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves T0+
    ldx Zp_MachineIndex_u8
    lda #9
    sub Ram_MachineGoalHorz_u8_arr, x
    mul #kBlockHeightPx
    adc #kTileWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X and T0+
    lda Ram_MachineSlowdown_u8_arr, x
    beq _DrawGlow
_DrawBeam:
    jsr Func_GetRandomByte  ; preserves T0+, returns A
    ldy T0  ; beam length in tiles
    jsr Func_DivMod  ; returns remainder in A
    mul #kTileHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    lda #kTileIdObjEmitterBeamVert  ; param: tile ID
    ldy #kPaletteObjEmitterBeam  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jmp FuncA_Objects_DrawEmitterMachine
_DrawGlow:
    lda Zp_FrameCounter_u8
    div #4
    and #$01
    add #kTileIdObjEmitterGlowXFirst  ; param: tile ID
    ldy #kPaletteObjEmitterGlow  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jmp FuncA_Objects_DrawEmitterMachine
.ENDPROC

;;; Draws a forcefield emitter machine that fires a horizontal beam at various
;;; Y-positions.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The length of the beam, in tiles.
.EXPORT FuncA_Objects_DrawEmitterYMachine
.PROC FuncA_Objects_DrawEmitterYMachine
    sta T0  ; beam length in tiles
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves T0+
    ldx Zp_MachineIndex_u8
    lda #9
    sub Ram_MachineGoalVert_u8_arr, x
    mul #kBlockHeightPx
    adc #kTileHeightPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and T0+
    lda Ram_MachineSlowdown_u8_arr, x
    beq _DrawGlow
_DrawBeam:
    jsr Func_GetRandomByte  ; preserves T0+, returns A
    ldy T0  ; beam length in tiles
    jsr Func_DivMod  ; returns remainder in A
    mul #kTileWidthPx  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kTileIdObjEmitterBeamHorz  ; param: tile ID
    ldy #kPaletteObjEmitterBeam  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jmp FuncA_Objects_DrawEmitterMachine
_DrawGlow:
    lda Zp_FrameCounter_u8
    div #4
    and #$01
    add #kTileIdObjEmitterGlowYFirst  ; param: tile ID
    ldy #kPaletteObjEmitterGlow  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    .assert * = FuncA_Objects_DrawEmitterMachine, error, "fallthrough"
.ENDPROC

;;; Draws a forcefield emitter machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncA_Objects_DrawEmitterMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A (param: tile ID)
    ldy #kPaletteObjMachineLight | bObj::FlipH  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
