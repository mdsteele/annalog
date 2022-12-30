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

.IMPORT FuncA_Actor_IsCollidingWithAvatar
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16

;;;=========================================================================;;;

;;; The acceleration applied to the player avatar when being pushed by steam,
;;; in subpixels per frame per frame.
kSteamAccel = 220

;;; How long a steam actor animates before disappearing, in frames.
kSteamNumFrames = 32

;;; The OBJ palette number to use for drawing steam projectile actors.
kPaletteObjSteam = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a horizontal steam projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The facing direction (either 0 or bObj::FlipH).
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorProjSteamHorz
.PROC Func_InitActorProjSteamHorz
    pha  ; facing dir
    ldy #eActor::ProjSteamHorz  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X
    pla  ; facing dir
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;; Initializes the specified actor as an upward steam projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorProjSteamUp
.PROC Func_InitActorProjSteamUp
    ldy #eActor::ProjSteamUp  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X
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
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @pushRight
    @pushLeft:
    lda Zp_AvatarVelX_i16 + 0
    sub #<kSteamAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    sbc #>kSteamAccel
    sta Zp_AvatarVelX_i16 + 1
    jmp FuncA_Actor_IncrementSteamAge  ; preserves X
    @pushRight:
    lda Zp_AvatarVelX_i16 + 0
    add #<kSteamAccel
    sta Zp_AvatarVelX_i16 + 0
    lda Zp_AvatarVelX_i16 + 1
    adc #>kSteamAccel
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
    lda Zp_AvatarVelY_i16 + 0
    sub #<kSteamAccel
    sta Zp_AvatarVelY_i16 + 0
    lda Zp_AvatarVelY_i16 + 1
    sbc #>kSteamAccel
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
    .assert * = FuncA_Actor_IncrementSteamAge, error, "fallthrough"
.ENDPROC

;;; Increments the state byte for the specified steam actor, and removes the
;;; steam when the state byte reaches kSteamNumFrames.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_IncrementSteamAge
    inc Ram_ActorState1_byte_arr, x
    lda Ram_ActorState1_byte_arr, x
    cmp #kSteamNumFrames
    blt @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
.ENDPROC

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
    ;; TODO: set the actual correct first tile ID
    lda #$40  ; param: first tile ID
    ldy #kPaletteObjSteam  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
