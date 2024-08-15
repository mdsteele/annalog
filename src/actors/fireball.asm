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
.INCLUDE "../device.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "fireball.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_CenterHitsTerrainOrSolidPlatform
.IMPORT FuncA_Actor_FindNearbyDevice
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsInRoomBounds
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_EmitSteamFromPipe
.IMPORT Func_InitActorDefault
.IMPORT Func_InitActorWithState1
.IMPORT Func_SetActorVelocityPolar
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorState4_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
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
;;; @preserve X, T3+
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
;;; @preserve X, T3+
.EXPORT Func_InitActorProjFireball
.PROC Func_InitActorProjFireball
    ldy #eActor::ProjFireball  ; param: actor type
    fall Func_InitActorProjFireballOrFireblast  ; preserves X and T3+
.ENDPROC

;;; Initializes the specified actor as a fireball or fireblast projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to fire at, measured in increments of tau/256.
;;; @param X The actor index.
;;; @preserve X, T3+
.PROC Func_InitActorProjFireballOrFireblast
    jsr Func_InitActorWithState1  ; preserves X and T0+
    fall Func_ReinitActorProjFireblastVelocity  ; preserves X and T3+
.ENDPROC

;;; Sets a fireball projectile's velocity from its State1 angle value.
;;; @param X The actor index.
;;; @preserve X, T3+
.EXPORT Func_ReinitActorProjFireblastVelocity
.PROC Func_ReinitActorProjFireblastVelocity
    ldy #kFireballSpeed  ; param: speed
    lda Ram_ActorState1_byte_arr, x  ; param: angle
    jmp Func_SetActorVelocityPolar  ; preserves X and T3+
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
    beq FuncA_Actor_ExpireProjFireballOrFireblast  ; preserves X
_HandleCollision:
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    jsr FuncA_Actor_IsInRoomBounds  ; preserves X, returns C
    bcc FuncA_Actor_RemoveProjFireballOrFireblast  ; preserves X
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs FuncA_Actor_ExpireProjFireballOrFireblast  ; preserves X
_UpdateAngle:
    lda Ram_ActorState4_byte_arr, x  ; angle delta
    beq @done
    add Ram_ActorState1_byte_arr, x  ; current angle
    sta Ram_ActorState1_byte_arr, x  ; current angle
    jmp Func_ReinitActorProjFireblastVelocity  ; preserves X
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for a fireblast projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjFireblast
.PROC FuncA_Actor_TickProjFireblast
_IncrementAge:
    inc Ram_ActorState2_byte_arr, x  ; projectile age in frames
    beq FuncA_Actor_ExpireProjFireballOrFireblast  ; preserves X
_DecrementReflectionTimer:
    lda Ram_ActorState3_byte_arr, x  ; reflection timer
    beq @done
    dec Ram_ActorState3_byte_arr, x  ; reflection timer
    @done:
_HandleCollision:
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X, returns C
    bcs FuncA_Actor_ExpireProjFireballOrFireblast  ; preserves X
    jsr FuncA_Actor_IsInRoomBounds  ; preserves X, returns C
    bcc FuncA_Actor_RemoveProjFireballOrFireblast  ; preserves X
    jsr FuncA_Actor_FindNearbyDevice  ; preserves X, returns N and Y
    bmi @noBoiler
    lda Ram_DeviceType_eDevice_arr, y
    cmp #eDevice::Boiler
    beq FuncA_Actor_FireblastHitBoiler  ; preserves X
    @noBoiler:
    jsr FuncA_Actor_CenterHitsTerrainOrSolidPlatform  ; preserves X, returns C
    bcs FuncA_Actor_ExpireProjFireballOrFireblast  ; preserves X
    rts
.ENDPROC

;;; @param X The actor index.
;;; @param Y The device index for the boiler.
;;; @preserve X
.PROC FuncA_Actor_FireblastHitBoiler
    stx T0  ; fireblast actor index
    lda Ram_DeviceTarget_byte_arr, y  ; param: bBoiler value
    jsr Func_EmitSteamFromPipe  ; preserves T0+
    ldx T0  ; fireblast actor index
    fall FuncA_Actor_ExpireProjFireballOrFireblast  ; preserves X
.ENDPROC


;;; Expires a fireball or fireblast projectile, replacing it with a motionless
;;; smoke particle.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_ExpireProjFireballOrFireblast
    ldy #eActor::SmokeParticle  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X
.ENDPROC

;;; Removes a fireball or fireblast projectile without creating a smoke
;;; particle.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_RemoveProjFireballOrFireblast
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
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
