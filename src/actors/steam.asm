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
.INCLUDE "steam.inc"

.IMPORT FuncA_Actor_IsCollidingWithAvatar
.IMPORT FuncA_Objects_Draw1x2Actor
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
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

;;; Initializes the specified actor as a horizontal steam projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The facing direction (either 0 or bObj::FlipH).
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorProjSteamHorz
.PROC Func_InitActorProjSteamHorz
    pha  ; facing dir
    ldy #eActor::ProjSteamHorz  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X and T0+
    pla  ; facing dir
    sta Ram_ActorFlags_bObj_arr, x
    rts
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

;;; Initializes the specified actor as a horizontal steam smoke.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The facing direction (either 0 or bObj::FlipH).
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorSmokeSteamHorz := Func_InitActorProjSteamHorz

;;; Initializes the specified actor as an upward steam smoke.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT Func_InitActorSmokeSteamUp := Func_InitActorProjSteamUp

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
    cmp #eActor::ProjSteamHorz
    beq @change
    cmp #eActor::ProjSteamUp
    bne @continue
    @change:
    .linecont +
    .assert eActor::SmokeSteamHorz - eActor::ProjSteamHorz = \
            eActor::SmokeSteamUp   - eActor::ProjSteamUp, error
    .linecont -
    add #eActor::SmokeSteamHorz - eActor::ProjSteamHorz
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
.EXPORT FuncA_Actor_TickProjSteamHorz
.PROC FuncA_Actor_TickProjSteamHorz
    ;; If the player avatar is in the steam, push them sideways.
    jsr FuncA_Actor_IsCollidingWithAvatar  ; preserves X, returns C
    bcc @noPush
    jsr FuncA_Actor_GetSteamAccel  ; preserves X, returns T0
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @pushRight
    @pushLeft:
    lda Zp_AvatarVelX_i16 + 0
    sub T0  ; accel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #0
    sta Zp_AvatarVelX_i16 + 1
    jmp FuncA_Actor_IncrementSteamAge  ; preserves X
    @pushRight:
    lda Zp_AvatarVelX_i16 + 0
    add T0  ; accel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #0
    sta Zp_AvatarVelX_i16 + 1
    @noPush:
    jmp FuncA_Actor_IncrementSteamAge  ; preserves X
.ENDPROC

;;; Performs per-frame updates for an upward steam projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjSteamUp
.PROC FuncA_Actor_TickProjSteamUp
    ;; If the player avatar is in the steam, push them upwards.
    jsr FuncA_Actor_IsCollidingWithAvatar  ; preserves X, returns C
    bcc @noPush
    lda Zp_AvatarState_bAvatar
    and #<~bAvatar::Jumping
    sta Zp_AvatarState_bAvatar
    jsr FuncA_Actor_GetSteamAccel  ; preserves X, returns T0
    lda Zp_AvatarVelY_i16 + 0
    sub T0  ; accel
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
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
.ENDPROC

;;; Determines the acceleration that the specified steam actor should apply to
;;; the player avatar, based on its age.
;;; @param X The actor index.
;;; @return T0 The steam's acceleration, in subpixels per frame per frame.
;;; @preserve X
.PROC FuncA_Actor_GetSteamAccel
    ldy Ram_ActorState1_byte_arr, x  ; steam age in frames
    lda #kSteamMaxAccel
    cpy #kSteamNumFrames / 4
    blt @finish
    div #2
    cpy #kSteamNumFrames / 2
    blt @finish
    div #2
    cpy #kSteamNumFrames * 3 / 4
    blt @finish
    div #2
    @finish:
    sta T0
    rts
.ENDPROC

;;; Performs per-frame updates for a horizontal steam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeSteamHorz := FuncA_Actor_IncrementSteamAge

;;; Performs per-frame updates for an upward steam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeSteamUp := FuncA_Actor_IncrementSteamAge

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a horizontal steam projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjSteamHorz
.PROC FuncA_Objects_DrawActorProjSteamHorz
    ;; TODO: set the actual correct first tile ID
    lda #$50  ; param: first tile ID
    ldy #kPaletteObjSteam  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
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
.EXPORT FuncA_Objects_DrawActorSmokeSteamHorz := \
    FuncA_Objects_DrawActorProjSteamHorz
.LINECONT -

;;; Draws an upward steam smoke actor.
;;; @param X The actor index.
;;; @preserve X
.LINECONT +
.EXPORT FuncA_Objects_DrawActorSmokeSteamUp := \
    FuncA_Objects_DrawActorProjSteamUp
.LINECONT -

;;;=========================================================================;;;
