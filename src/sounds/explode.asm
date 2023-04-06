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

.INCLUDE "../apu.inc"
.INCLUDE "../audio.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Ram_Sound_sChanSfx_arr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

;;; Bitfield used for Param1_byte for the eSound::Explode SFX function.
.SCOPE bSfxExplode
    DivEnv   = %10000000  ; if set, halve Timer_u8 before setting envelope
    ModTimer = %01000000  ; if set, mod Timer_u8 by 2 before indexing period
.ENDSCOPE

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX function for an explosion sound.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.EXPORT Func_SfxExplode
.PROC Func_SfxExplode
    lda Ram_Sound_sChanSfx_arr + eChan::Noise + sChanSfx::Timer_u8
    bne _Continue
    sec  ; set C to indicate that the sound is finished
    rts
_Continue:
    bit Ram_Sound_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte
    .assert bSfxExplode::DivEnv = bProc::Negative, error
    bpl @noDivEnv
    div #2
    @noDivEnv:
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    sta Hw_NoiseEnvelope_wo
    .assert bSfxExplode::ModTimer = bProc::Overflow, error
    bvc @noModTimer
    and #$01
    tay
    bpl @loadTimer  ; unconditional
    @noModTimer:
    ldy Ram_Sound_sChanSfx_arr + eChan::Noise + sChanSfx::Timer_u8
    @loadTimer:
    lda _NoisePeriod_u8_arr, y
    sta Hw_NoisePeriod_wo
    lda #0
    sta Hw_NoiseLength_wo
    dec Ram_Sound_sChanSfx_arr + sChanSfx::Timer_u8, x
    clc  ; clear C to indicate that the sound is still going
    rts
_NoisePeriod_u8_arr:
    .byte $0f, $0d, $89, $0f, $85, $ba, $89, $02
    .byte $85, $b9, $00, $85, $83, $89, $0f, $0c
    .byte $8b, $88, $82, $80, $89, $03, $0c, $02
    .byte $00, $8d, $06, $00, $8e, $06, $00, $89
.ENDPROC

;;; Starts playing a small explosion sound.
;;; @preserve X, Y, T0+
.EXPORT Func_PlaySfxExplodeSmall
.PROC Func_PlaySfxExplodeSmall
    lda #bSfxExplode::ModTimer
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte
    lda #$0f
    bne Func_PlaySfxExplode  ; unconditional
.ENDPROC

;;; Starts playing an big explosion sound.
;;; @preserve X, Y, T0+
.EXPORT Func_PlaySfxExplodeBig
.PROC Func_PlaySfxExplodeBig
    lda #bSfxExplode::DivEnv | bSfxExplode::ModTimer
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte
    bne Func_PlaySfxExplodeLong  ; unconditional
.ENDPROC

;;; Starts playing a explosion sound where something is breaking into pieces.
;;; @preserve X, Y, T0+
.EXPORT Func_PlaySfxExplodeFracture
.PROC Func_PlaySfxExplodeFracture
    lda #bSfxExplode::DivEnv
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte
    .assert * = Func_PlaySfxExplodeLong, error, "fallthrough"
.ENDPROC

;;; Starts playing a explosion sound with a longer duration.
;;; @prereq The Param1_byte is already initialized.
;;; @preserve X, Y, T0+
.PROC Func_PlaySfxExplodeLong
    lda #$1f
    .assert * = Func_PlaySfxExplode, error, "fallthrough"
.ENDPROC

;;; Starts playing a explosion sound.
;;; @prereq The Param1_byte is already initialized.
;;; @param A The value to set for Timer_u8.
;;; @preserve X, Y, T0+
.PROC Func_PlaySfxExplode
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Timer_u8
    lda #eSound::Explode
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Sfx_eSound
    rts
.ENDPROC

;;;=========================================================================;;;
