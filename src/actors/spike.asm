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
.INCLUDE "spike.inc"

.IMPORT FuncA_Actor_ApplyGravityWithTerminalVelocity
.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsInRoomBounds
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorDefault
.IMPORT Func_PlaySfxThump
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr

;;;=========================================================================;;;

;;; The maximum downward speed of a falling spike projectile, in pixels per
;;; frame.
kSpikeTerminalVelocity = 6

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a spike projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorProjSpike
.PROC Func_InitActorProjSpike
    ldy #eActor::ProjSpike  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a spike projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjSpike
.PROC FuncA_Actor_TickProjSpike
    inc Ram_ActorState1_byte_arr, x
    beq _Expire
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs _Thump
    jsr FuncA_Actor_IsInRoomBounds  ; preserves X, returns C
    bcc _Expire
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs _Thump
    lda #kSpikeTerminalVelocity  ; param: terminal velocity
    jmp FuncA_Actor_ApplyGravityWithTerminalVelocity  ; preserves X
_Thump:
    jsr Func_PlaySfxThump  ; preserves X
    ldy #eActor::SmokeParticle  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a spike projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjSpike
.PROC FuncA_Objects_DrawActorProjSpike
    lda #kTileIdObjProjSpike  ; param: tile ID
    ldy #kPaletteObjProjSpike  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
