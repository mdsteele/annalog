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
.INCLUDE "fireball.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_CenterHitsTerrainOrSolidPlatform
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_Cosine
.IMPORT Func_InitActorDefault
.IMPORT Func_InitActorWithState1
.IMPORT Func_SignedMult
.IMPORT Func_Sine
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The speed of a fireball/fireblast, in half-pixels per frame.
kFireballSpeed = 5

;;; The OBJ palette numbers used for fireball and fireblast actors.
kPaletteObjFireball  = 1
kPaletteObjFireblast = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a fireblast projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to fire at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @preserve X, T2+
.EXPORT Func_InitActorProjFireblast
.PROC Func_InitActorProjFireblast
    ldy #eActor::ProjFireblast  ; param: actor type
    .assert eActor::ProjFireblast > 0, error
    bne Func_InitActorProjFireballOrFireblast  ; unconditional
.ENDPROC

;;; Initializes the specified actor as a fireball projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to fire at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @preserve X, T2+
.EXPORT Func_InitActorProjFireball
.PROC Func_InitActorProjFireball
    ldy #eActor::ProjFireball  ; param: actor type
    .assert * = Func_InitActorProjFireballOrFireblast, error, "fallthrough"
.ENDPROC

;;; Initializes the specified actor as a fireball or fireblast projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to fire at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @preserve X, T2+
.PROC Func_InitActorProjFireballOrFireblast
    jsr Func_InitActorWithState1  ; preserves X and T0+
    .assert * = Func_ReinitActorProjFireblastVelocity, error, "fallthrough"
.ENDPROC

;;; Sets a fireball projectile's velocity from its State1 angle value.
;;; @param X The actor index.
;;; @preserve X, Y, T2+
.EXPORT Func_ReinitActorProjFireblastVelocity
.PROC Func_ReinitActorProjFireblastVelocity
    tya
    pha  ; old Y value (so we can preserve it)
_InitVelX:
    lda Ram_ActorState1_byte_arr, x  ; fireball angle
    jsr Func_Cosine  ; preserves X and T0+, returns A
    ldy #kFireballSpeed  ; param: multiplier
    jsr Func_SignedMult  ; preserves X and T2+, returns YA
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
_InitVelY:
    lda Ram_ActorState1_byte_arr, x  ; fireball angle
    jsr Func_Sine  ; preserves X and T0+, returns A
    ldy #kFireballSpeed  ; param: multiplier
    jsr Func_SignedMult  ; preserves X and T2+, returns YA
    sta Ram_ActorVelY_i16_0_arr, x
    tya
    sta Ram_ActorVelY_i16_1_arr, x
_RestoreY:
    pla  ; old Y value (so we can preserve it)
    tay
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a fireball projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjFireball
.PROC FuncA_Actor_TickProjFireball
_IncrementAge:
    inc Ram_ActorState2_byte_arr, x  ; projectile age in frames
    beq FuncA_Actor_ExpireProjFireballOrFireblast
_HandleCollision:
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs FuncA_Actor_ExpireProjFireballOrFireblast
    rts
.ENDPROC

;;; Performs per-frame updates for a fireblast projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjFireblast
.PROC FuncA_Actor_TickProjFireblast
_IncrementAge:
    inc Ram_ActorState2_byte_arr, x  ; projectile age in frames
    beq FuncA_Actor_ExpireProjFireballOrFireblast
_DecrementReflectionTimer:
    lda Ram_ActorState3_byte_arr, x  ; reflection timer
    beq @done
    dec Ram_ActorState3_byte_arr, x  ; reflection timer
    @done:
_HandleCollision:
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs FuncA_Actor_ExpireProjFireballOrFireblast
    jsr FuncA_Actor_CenterHitsTerrainOrSolidPlatform  ; preserves X, returns C
    bcs FuncA_Actor_ExpireProjFireballOrFireblast
    rts
.ENDPROC

;;; Expires a fireball or fireblast projectile, replacing it with a motionless
;;; smoke particle.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_ExpireProjFireballOrFireblast
    ldy #eActor::SmokeParticle  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a fireball projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjFireball
.PROC FuncA_Objects_DrawActorProjFireball
    lda Zp_FrameCounter_u8
    div #2
    and #$03
    .assert kTileIdObjFireballFirst .mod 4 = 0, error
    ora #kTileIdObjFireballFirst  ; param: tile ID
    ldy #kPaletteObjFireball  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;; Draws a fireblast projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjFireblast
.PROC FuncA_Objects_DrawActorProjFireblast
    lda Zp_FrameCounter_u8
    div #2
    and #$01
    .assert kTileIdObjFireballFirst .mod 2 = 0, error
    ora #kTileIdObjFireblastFirst  ; param: tile ID
    ldy #kPaletteObjFireblast  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
