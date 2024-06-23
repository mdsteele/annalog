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
.INCLUDE "../ppu.inc"
.INCLUDE "particle.inc"
.INCLUDE "smoke.inc"

.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorDefault
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetActorVelocityPolar
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr

;;;=========================================================================;;;

;;; The speed of a smoke particle, in half-pixels per frame.
kParticleSpeed = 3

;;; The first tile ID for the smoke particle animation.
kTileIdObjParticleFirst = kTileIdObjSmokeFirst

;;; The OBJ palette number used for smoke particle actors.
kPaletteObjParticle = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a smoke particle.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to move at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @preserve X, T3+
.EXPORT Func_InitActorSmokeParticle
.PROC Func_InitActorSmokeParticle
    pha  ; angle
    ldy #eActor::SmokeParticle  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X and T0+
    ldy #kParticleSpeed  ; param: speed
    pla  ; param: angle
    jmp Func_SetActorVelocityPolar  ; preserves X and T3+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Spawns a new smoke particle actor (if possible), starting it at the
;;; room pixel position stored in Zp_PointX_i16 and Zp_PointY_i16.
;;; @param A The angle for the particle to move at.
;;; @preserve Y, T4+
.EXPORT FuncA_Room_SpawnParticleAtPoint
.PROC FuncA_Room_SpawnParticleAtPoint
    sta T0  ; angle
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
    bcs @done
    jsr Func_SetActorCenterToPoint  ; preserves X, Y, and T0+
    sty T3  ; old Y value (just to preserve it)
    lda T0  ; param: angle
    jsr Func_InitActorSmokeParticle  ; preserves T3+
    ldy T3  ; old Y value (just to preserve it)
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a smoke particle actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeParticle
.PROC FuncA_Actor_TickSmokeParticle
    inc Ram_ActorState1_byte_arr, x
    lda Ram_ActorState1_byte_arr, x
    cmp #kSmokeParticleNumFrames
    blt @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a smoke particle actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorSmokeParticle
.PROC FuncA_Objects_DrawActorSmokeParticle
    lda Ram_ActorState1_byte_arr, x
    div #2
    add #kTileIdObjParticleFirst  ; param: tile ID
    ldy #kPaletteObjParticle  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
