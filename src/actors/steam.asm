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
.INCLUDE "../oam.inc"
.INCLUDE "solifuge.inc"
.INCLUDE "steam.inc"

.IMPORT FuncA_Actor_IsCollidingWithAvatar
.IMPORT FuncA_Actor_IsCollidingWithOtherActor
.IMPORT FuncA_Objects_Draw1x2Actor
.IMPORT FuncA_Objects_Draw2x1Actor
.IMPORT Func_InitActorDefault
.IMPORT Func_RemoveActor
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_ConsoleMachineIndex_u8

;;;=========================================================================;;;

;;; The maximum acceleration applied to the player avatar when being pushed by
;;; steam, in subpixels per frame per frame.
kSteamMaxAccel = 220

;;; The number of distinct animation shapes a steam projectile has.
kSteamNumAnimShapes = 8

;;; The number of VBlank frames per steam animation shape.
.DEFINE kSteamAnimSlowdown 4

;;; The OBJ palette number to use for drawing steam projectile actors.
kPaletteObjSteam = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a rightward steam projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorProjSteamRight
.PROC Func_InitActorProjSteamRight
    ldy #eActor::ProjSteamRight  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X and T0+
.ENDPROC

;;; Initializes the specified actor as an upward steam projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorProjSteamUp
.PROC Func_InitActorProjSteamUp
    ldy #eActor::ProjSteamUp  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; If the console window is open, turns all steam projectiles into steam
;;; smoke.  If the console window is closed, does nothing.  This should be
;;; called from room tick functions in rooms containing boiler machines.
.EXPORT FuncA_Room_TurnSteamToSmokeIfConsoleOpen
.PROC FuncA_Room_TurnSteamToSmokeIfConsoleOpen
    lda Zp_ConsoleMachineIndex_u8
    bmi @done
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjSteamRight
    beq @change
    cmp #eActor::ProjSteamUp
    bne @continue
    @change:
    .linecont +
    .assert eActor::SmokeSteamRight - eActor::ProjSteamRight = \
            eActor::SmokeSteamUp   - eActor::ProjSteamUp, error
    .linecont -
    add #eActor::SmokeSteamRight - eActor::ProjSteamRight
    sta Ram_ActorType_eActor_arr, x
    @continue:
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a horizontal steam projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjSteamRight
.PROC FuncA_Actor_TickProjSteamRight
    ;; If the player avatar is in the steam, push them sideways.
    jsr FuncA_Actor_IsCollidingWithAvatar  ; preserves X, returns C
    bcc @noPush
    jsr FuncA_Actor_GetSteamAccel  ; preserves X, returns A
    add Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 0
    lda #0
    adc Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelX_i16 + 1
    @noPush:
    jmp FuncA_Actor_IncrementSteamAge  ; preserves X
.ENDPROC

;;; Performs per-frame updates for an upward steam projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjSteamUp
.PROC FuncA_Actor_TickProjSteamUp
    jsr FuncA_Actor_GetSteamAccel  ; preserves X, returns A
    sta T3  ; 1x accel
    asl a
    sta T4  ; 2x accel (lo)
    lda #0
    rol a
    sta T5  ; 2x accel (hi)
_PushSolifuges:
    ldy #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, y
    ;; Check if this other actor is a solifuge and is in the steam.
    cmp #eActor::BadSolifuge
    bne @continue
    jsr FuncA_Actor_IsCollidingWithOtherActor  ; preserves X, Y, T3+; returns C
    bcc @continue
    ;; Accelerate the solifuge doubly upwards.
    lda Ram_ActorVelY_i16_0_arr, y
    sub T4  ; 2x accel (lo)
    sta Ram_ActorVelY_i16_0_arr, y
    lda Ram_ActorVelY_i16_1_arr, y
    sbc T5  ; 2x accel (hi)
    sta Ram_ActorVelY_i16_1_arr, y
    lda #bBadSolifuge::Steamed
    sta Ram_ActorState1_byte_arr, y  ; bBadSolifuge value
    lda #0
    sta Ram_ActorVelX_i16_0_arr, y
    sta Ram_ActorVelX_i16_1_arr, y
    @continue:
    dey
    .assert kMaxActors <= $80, error
    bpl @loop
_PushAvatar:
    ;; If the player avatar is in the steam, push them upwards.
    jsr FuncA_Actor_IsCollidingWithAvatar  ; preserves X and T1+, returns C
    bcc @noPush
    lda Zp_AvatarState_bAvatar
    and #<~bAvatar::Jumping
    sta Zp_AvatarState_bAvatar
    lda Zp_AvatarVelY_i16 + 0
    sub T3  ; 1x accel
    sta Zp_AvatarVelY_i16 + 0
    lda Zp_AvatarVelY_i16 + 1
    sbc #0
    ;; Clamp upward velocity.
    bpl @noClamp
    .assert <kAvatarMaxAirSpeedVert = 0, error
    cmp #>-kAvatarMaxAirSpeedVert
    bge @noClamp
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    lda #>-kAvatarMaxAirSpeedVert
    @noClamp:
    sta Zp_AvatarVelY_i16 + 1
    @noPush:
    fall FuncA_Actor_IncrementSteamAge  ; preserves X
.ENDPROC

;;; Increments the state byte for the specified steam actor, and removes the
;;; steam when the state byte reaches kSteamNumFrames.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_IncrementSteamAge
    inc Ram_ActorState1_byte_arr, x  ; steam age in frames
    lda Ram_ActorState1_byte_arr, x  ; steam age in frames
    cmp #kSteamNumFrames
    blt @done
    jmp Func_RemoveActor  ; preserves X
    @done:
    rts
.ENDPROC

;;; Determines the acceleration that the specified steam actor should apply to
;;; the player avatar, based on its age.
;;; @param X The actor index.
;;; @return A The steam's acceleration, in subpixels per frame per frame.
;;; @preserve X
.PROC FuncA_Actor_GetSteamAccel
    ldy Ram_ActorState1_byte_arr, x  ; steam age in frames
    lda #kSteamMaxAccel
    cpy #kSteamNumFrames / 4
    blt @done
    div #2
    cpy #kSteamNumFrames / 2
    blt @done
    div #2
    cpy #kSteamNumFrames * 3 / 4
    blt @done
    div #2
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for a horizontal steam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeSteamRight := FuncA_Actor_IncrementSteamAge

;;; Performs per-frame updates for an upward steam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeSteamUp := FuncA_Actor_IncrementSteamAge

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a horizontal steam projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjSteamRight
.PROC FuncA_Objects_DrawActorProjSteamRight
    lda Ram_ActorState1_byte_arr, x  ; steam age in frames
    .assert kSteamNumFrames = kSteamNumAnimShapes * kSteamAnimSlowdown, error
    div #kSteamAnimSlowdown
    mul #2
    .assert kTileIdObjSteamHorzFirst .mod 16 = 0, error
    ora #kTileIdObjSteamHorzFirst  ; param: first tile ID
    ldy #kPaletteObjSteam  ; param: palette
    jmp FuncA_Objects_Draw2x1Actor  ; preserves X
.ENDPROC

;;; Draws an upward steam projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjSteamUp
.PROC FuncA_Objects_DrawActorProjSteamUp
    lda Ram_ActorState1_byte_arr, x  ; steam age in frames
    .assert kSteamNumFrames = kSteamNumAnimShapes * kSteamAnimSlowdown, error
    div #kSteamAnimSlowdown
    mul #2
    .assert kTileIdObjSteamVertFirst .mod 16 = 0, error
    ora #kTileIdObjSteamVertFirst  ; param: first tile ID
    ldy #kPaletteObjSteam  ; param: palette
    jmp FuncA_Objects_Draw1x2Actor  ; preserves X
.ENDPROC

;;; Draws a horizontal steam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.LINECONT +
.EXPORT FuncA_Objects_DrawActorSmokeSteamRight := \
    FuncA_Objects_DrawActorProjSteamRight
.LINECONT -

;;; Draws an upward steam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.LINECONT +
.EXPORT FuncA_Objects_DrawActorSmokeSteamUp := \
    FuncA_Objects_DrawActorProjSteamUp
.LINECONT -

;;;=========================================================================;;;
