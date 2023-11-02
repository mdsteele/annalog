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

.INCLUDE "avatar.inc"
.INCLUDE "cpu.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "sample.inc"

.IMPORT Func_PlaySfxSample
.IMPORT Ppu_ChrObjAnnaNormal
.IMPORT Sram_CarryingFlower_eFlag
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16

;;;=========================================================================;;;

;;; The (signed, 16-bit) initial Y-velocity to set for the player avatar when
;;; it takes damage and is temporarily stunned.
kAvatarStunVelY = $ffff & -350

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Deals damage to the player avatar, stunning them.
;;; @preserve X, Y, T0+
.EXPORT Func_HarmAvatar
.PROC Func_HarmAvatar
    lda Zp_AvatarHarmTimer_u8
    ;; If the player avatar is at full health, stun and damage them.
    beq _Harm
    ;; Otherwise, if the player avatar is no longer still invincible from the
    ;; last time they took damage, kill them.
    cmp #kAvatarHarmHealFrames - kAvatarHarmInvincibileFrames
    blt Func_KillAvatar
    rts
_Harm:
    jsr Func_DropFlower  ; preserves X, Y, and T0+
    lda #eSample::Harm  ; param: eSample to play
    jsr Func_PlaySfxSample  ; preserves X, Y, and T0+
    ;; Mark the avatar as damaged.
    lda #kAvatarHarmHealFrames
    sta Zp_AvatarHarmTimer_u8
_SetVelY:
    ;; Make the avatar go flying upwards.
    lda #<kAvatarStunVelY
    sta Zp_AvatarVelY_i16 + 0
    lda #>kAvatarStunVelY
    sta Zp_AvatarVelY_i16 + 1
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvs @done
    lda #bAvatar::Airborne
    sta Zp_AvatarState_bAvatar
    @done:
_SetVelX:
    ;; Make the avatar go flying backwards.
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipH = bProc::Overflow, error
    bvc @facingRight
    @facingLeft:
    .assert <kAvatarMaxAirSpeedHorz = 0, error
    lda #>kAvatarMaxAirSpeedHorz
    bne @setVelX  ; unconditional
    @facingRight:
    .assert <-kAvatarMaxAirSpeedHorz = 0, error
    lda #>-kAvatarMaxAirSpeedHorz
    @setVelX:
    sta Zp_AvatarVelX_i16 + 1
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    rts
.ENDPROC

;;; Kills the player avatar.
;;; @preserve X, Y, T0+
.EXPORT Func_KillAvatar
.PROC Func_KillAvatar
    lda Zp_AvatarFlags_bObj
    and #<~bObj::PaletteMask
    ora #kPaletteObjAvatarDeath
    sta Zp_AvatarFlags_bObj
    lda #kAvatarHarmDeath
    sta Zp_AvatarHarmTimer_u8
    .assert * = Func_DropFlower, error, "fallthrough"
.ENDPROC

;;; If the player avatar is carrying a flower, drops the flower.  Otherwise,
;;; does nothing.
;;; @preserve X, Y, T0+
.EXPORT Func_DropFlower
.PROC Func_DropFlower
    lda Sram_CarryingFlower_eFlag
    beq @done
    chr10_bank #<.bank(Ppu_ChrObjAnnaNormal)
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Mark the player as no longer carrying a flower.
    lda #0
    sta Sram_CarryingFlower_eFlag
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
