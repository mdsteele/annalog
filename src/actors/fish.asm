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
.INCLUDE "../terrain.inc"
.INCLUDE "fish.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr

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
    ;; Set the point to a position in front of the fish.
    jsr Func_SetPointToActorCenter  ; preserves X
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @facingLeft
    @facingRight:
    lda #kFishTurnDistance  ; param: offset
    jsr Func_MovePointRightByA  ; preserves X
    jmp @checkTerrain
    @facingLeft:
    lda #kFishTurnDistance  ; param: offset
    jsr Func_MovePointLeftByA  ; preserves X
    @checkTerrain:
    ;; Check the terrain in front of the fish.  If it's solid, turn around.
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc @continueForward
    ;; Make the fish face the opposite direction.
    @turnAround:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    @continueForward:
_SetVelocity:
    ;; TODO: Move fast if player avatar is ahead, move slower otherwise.
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @facingLeft
    @facingRight:
    lda #<kFishSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kFishSpeed
    sta Ram_ActorVelX_i16_1_arr, x
    bpl @done  ; unconditional
    @facingLeft:
    lda #<($ffff & -kFishSpeed)
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>($ffff & -kFishSpeed)
    sta Ram_ActorVelX_i16_1_arr, x
    @done:
    inc Ram_ActorState1_byte_arr, x
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a fish baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadFish
.PROC FuncA_Objects_DrawActorBadFish
    lda Ram_ActorState1_byte_arr, x
    div #8
    and #$03
    tay
    lda _TileIds_u8_arr4, y  ; param: first tile ID
    ldy #kPaletteObjFish  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr4:
    .byte kTileIdObjFishFirst + 0
    .byte kTileIdObjFishFirst + 4
    .byte kTileIdObjFishFirst + 8
    .byte kTileIdObjFishFirst + 4
.ENDPROC

;;;=========================================================================;;;
