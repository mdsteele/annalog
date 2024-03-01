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
.INCLUDE "../oam.inc"
.INCLUDE "ember.inc"

.IMPORT FuncA_Actor_ApplyGravityWithTerminalVelocity
.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr

;;;=========================================================================;;;

;;; The maximum downward speed of a falling ember projectile, in pixels per
;;; frame.
kEmberTerminalVelocity = 5

;;; The OBJ palette number used for ember projectile actors.
kPaletteObjEmber = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as an ember projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorProjEmber
.PROC Func_InitActorProjEmber
    ldy #eActor::ProjEmber  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an ember projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjEmber
.PROC FuncA_Actor_TickProjEmber
    inc Ram_ActorState1_byte_arr, x
    beq _Expire
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs _Expire
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs _Expire
_FlipHorz:
    lda Ram_ActorState1_byte_arr, x
    mul #16
    and #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
_ApplyGravity:
    lda #kEmberTerminalVelocity  ; param: terminal velocity
    jmp FuncA_Actor_ApplyGravityWithTerminalVelocity  ; preserves X
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an ember projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjEmber
.PROC FuncA_Objects_DrawActorProjEmber
    lda #kTileIdObjEmber  ; param: tile ID
    ldy #kPaletteObjEmber  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
