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
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_AvatarVelY_i16

;;;=========================================================================;;;

;;; The acceleration applied to the player avatar when being pushed by steam,
;;; in subpixels per frame per frame.
kSteamAccel = 220

;;; How long a steam actor animates before disappearing, in frames.
kSteamNumFrames = 32

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as upward steam.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitSteamUpActor
.PROC Func_InitSteamUpActor
    ldy #eActor::SteamUp  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an upward steam actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSteamUp
.PROC FuncA_Actor_TickSteamUp
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
    cmp #<-kAvatarMaxAirSpeedY
    bge @noClamp
    lda #0
    sta Zp_AvatarVelY_i16 + 0
    lda #<-kAvatarMaxAirSpeedY
    @noClamp:
    sta Zp_AvatarVelY_i16 + 1
    ;; Mark the avatar as airborne.
    lda #eAvatar::Falling
    sta Zp_AvatarMode_eAvatar
    @noPush:
_IncrementAge:
    inc Ram_ActorState_byte_arr, x
    lda Ram_ActorState_byte_arr, x
    cmp #kSteamNumFrames
    blt @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an upward steam actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawSteamUpActor
.PROC FuncA_Objects_DrawSteamUpActor
    ;; TODO: set the actual correct first tile ID
    lda #$40  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
