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
.INCLUDE "../avatar.inc"
.INCLUDE "../macros.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr

;;;=========================================================================;;;

;;; The tile ID for spike projectile actors.
kSpikeTileId = $a8

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a spike.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitSpikeActor
.PROC Func_InitSpikeActor
    ldy #eActor::Spike  ; param: actor type
    jmp Func_InitActorDefault
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a spike actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSpike
.PROC FuncA_Actor_TickSpike
    inc Ram_ActorState_byte_arr, x
    beq _Expire
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs _Expire
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs _Expire
_ApplyGravity:
    lda #kAvatarGravity
    add Ram_ActorVelY_i16_0_arr, x
    sta Ram_ActorVelY_i16_0_arr, x
    lda #0
    adc Ram_ActorVelY_i16_1_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    rts
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a spike actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawSpikeActor
.PROC FuncA_Objects_DrawSpikeActor
    lda #kSpikeTileId  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
