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

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr

;;;=========================================================================;;;

;;; The OBJ palette number used for spike projectile actors.
kPaletteObjSpike = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a spike projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorProjSpike
.PROC Func_InitActorProjSpike
    ldy #eActor::ProjSpike  ; param: actor type
    jmp Func_InitActorDefault
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
    bcs _Expire
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs _Expire
    jmp FuncA_Actor_ApplyGravity  ; preserves X
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
    lda #kTileIdObjSpike  ; param: tile ID
    ldy #kPaletteObjSpike  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
