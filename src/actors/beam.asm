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

.INCLUDE "../actor.inc"
.INCLUDE "../macros.inc"
.INCLUDE "beam.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; How many different images the beam smoke goes through during its animation.
kBeamAnimCount = 5
;;; How many VBlank frames each beam smoke animation frame lasts for.
.DEFINE kBeamAnimSlowdown 4
;;; How many frames the beam smoke stays on screen for.
kBeamDurationFrames = kBeamAnimCount * kBeamAnimSlowdown

;;; Various OBJ tile IDs used for drawing beam smoke.
kTileIdObjBeamSmoke1  = kTileIdObjSmokeBeamFirst + 0
kTileIdObjBeamSmoke2  = kTileIdObjSmokeBeamFirst + 1
kTileIdObjBeamSmoke3  = kTileIdObjSmokeBeamFirst + 2

;;; The OBJ palette number used for drawing beam smoke actors.
kPaletteObjSmokeBeam = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Initializes the specified actor as a beam smoke.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The OBJ tile ID to use.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Cutscene_InitActorSmokeBeam
.PROC FuncA_Cutscene_InitActorSmokeBeam
    ldy #eActor::SmokeBeam  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a beam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeBeam
.PROC FuncA_Actor_TickSmokeBeam
    inc Ram_ActorState1_byte_arr, x  ; animation timer
    lda Ram_ActorState1_byte_arr, x  ; animation timer
    cmp #kBeamDurationFrames
    blt @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a beam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorSmokeBeam
.PROC FuncA_Objects_DrawActorSmokeBeam
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    ;; Compute the tile ID to use for each object in the beam.
    lda Ram_ActorState1_byte_arr, x  ; animation timer
    div #kBeamAnimSlowdown
    tay
    lda _BeamTileId_u8_arr, y
    sta T2  ; beam tile ID
    ;; Draw objects from the base of the beam upwards, until we reach the top
    ;; of the screen.
    @loop:
    ldy #kPaletteObjSmokeBeam  ; param: object flags
    lda T2  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    lda #2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X and T0+
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    lda Zp_ShapePosY_i16 + 1
    bpl @loop
    rts
_BeamTileId_u8_arr:
:   .byte kTileIdObjBeamSmoke1
    .byte kTileIdObjBeamSmoke2
    .byte kTileIdObjBeamSmoke3
    .byte kTileIdObjBeamSmoke2
    .byte kTileIdObjBeamSmoke1
    .assert * - :- = kBeamAnimCount, error
.ENDPROC

;;;=========================================================================;;;
