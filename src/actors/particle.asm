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
.IMPORT Func_Cosine
.IMPORT Func_InitActorDefault
.IMPORT Func_SignedMult
.IMPORT Func_Sine
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr

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
;;; @preserve X
.EXPORT Func_InitActorSmokeParticle
.PROC Func_InitActorSmokeParticle
    pha  ; angle
    ldy #eActor::SmokeParticle  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X
    pla  ; angle
_InitVelX:
    pha  ; angle
    jsr Func_Cosine  ; preserves X, returns A
    ldy #kParticleSpeed  ; param: multiplier
    jsr Func_SignedMult  ; preserves X, returns YA
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    pla  ; angle
_InitVelY:
    jsr Func_Sine  ; preserves X, returns A
    ldy #kParticleSpeed  ; param: multiplier
    jsr Func_SignedMult  ; preserves X, returns YA
    sta Ram_ActorVelY_i16_0_arr, x
    tya
    sta Ram_ActorVelY_i16_1_arr, x
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
