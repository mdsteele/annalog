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
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Ram_Sound_sChanSfx_arr
.IMPORTZP Zp_Next_sAudioCtrl

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX function for an explosion sound.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X
.EXPORT Func_SfxExplode
.PROC Func_SfxExplode
    lda Ram_Sound_sChanSfx_arr + eChan::Noise + sChanSfx::Timer_u8
    bne _Continue
    sec  ; set C to indicate that the sound is finished
    rts
_Continue:
    bit Ram_Sound_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte
    bpl @noDivEnv
    div #2
    @noDivEnv:
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    sta Hw_NoiseEnvelope_wo
    bvs @noModTimer
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
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_PlaySfxExplodeSmall
.PROC Func_PlaySfxExplodeSmall
    lda #$0f
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Timer_u8
    lda #$00
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Param1_byte
    lda #eSound::Explode
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Sfx_eSound
    rts
.ENDPROC

;;; Starts playing an big explosion sound.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_PlaySfxExplodeBig
.PROC Func_PlaySfxExplodeBig
    lda #$1f
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Timer_u8
    lda #$80
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Param1_byte
    lda #eSound::Explode
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Sfx_eSound
    rts
.ENDPROC

;;; Starts playing a explosion sound where something is breaking into pieces.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_PlaySfxExplodeFracture
.PROC Func_PlaySfxExplodeFracture
    lda #$1f
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Timer_u8
    lda #$c0
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Param1_byte
    lda #eSound::Explode
    sta Zp_Next_sAudioCtrl + sAudioCtrl::SfxN_sChanSfx + sChanSfx::Sfx_eSound
    rts
.ENDPROC

;;;=========================================================================;;;
