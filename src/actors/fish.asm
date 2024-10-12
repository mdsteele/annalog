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
.INCLUDE "fish.inc"

.IMPORT FuncA_Actor_FaceOppositeDir
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_PointHitsTerrain
.IMPORT Ram_ActorState1_byte_arr

;;;=========================================================================;;;

;;; How fast the fish swims, in subpixels per frame.
kFishSpeed = $0130

;;; How many pixels in front of its center a fish actor checks for solid
;;; terrain to see if it needs to turn around.
kFishTurnDistance = 12

;;; The OBJ palette number to use for drawing fish baddie actors.
kPaletteObjFish = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a fish baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadFish
.PROC FuncA_Actor_TickBadFish
    ;; Check the terrain in front of the fish.  If it's solid, turn around.
    lda #kFishTurnDistance  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc @continueForward
    jsr FuncA_Actor_FaceOppositeDir  ; preserves X
    @continueForward:
_SetVelocity:
    ldya #kFishSpeed  ; param: speed
    jsr FuncA_Actor_SetVelXForward  ; preserves X
    inc Ram_ActorState1_byte_arr, x  ; animation timer
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a fish baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadFish
.PROC FuncA_Objects_DrawActorBadFish
    lda Ram_ActorState1_byte_arr, x  ; animation timer
    div #8
    and #$03
    tay
    lda _TileIds_u8_arr4, y  ; param: first tile ID
    ldy #kPaletteObjFish  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr4:
    .byte kTileIdObjBadFishFirst + 0
    .byte kTileIdObjBadFishFirst + 4
    .byte kTileIdObjBadFishFirst + 8
    .byte kTileIdObjBadFishFirst + 4
.ENDPROC

;;;=========================================================================;;;
