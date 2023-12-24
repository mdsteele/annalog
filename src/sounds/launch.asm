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
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

;;; The duration of the rocket launch sound, in frames.
kSfxLaunchDurationFrames = $1c

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX function for a rocket launch sound.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.EXPORT Func_SfxLaunch
.PROC Func_SfxLaunch
    lda Ram_Sound_sChanSfx_arr + eChan::Noise + sChanSfx::Timer_u8
    bne _Continue
    sec  ; set C to indicate that the sound is finished
    rts
_Continue:
    pha
    div #2
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    sta Hw_NoiseEnvelope_wo
    pla
    rsub #kSfxLaunchDurationFrames
    cmp #$0f
    blt @setPeriod
    lda #$0f
    @setPeriod:
    sta Hw_NoisePeriod_wo
    lda #0
    sta Hw_NoiseLength_wo
    dec Ram_Sound_sChanSfx_arr + eChan::Noise + sChanSfx::Timer_u8
    clc  ; clear C to indicate that the sound is still going
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing a rocket launch sound.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Machine_PlaySfxLaunch
.PROC FuncA_Machine_PlaySfxLaunch
    lda #kSfxLaunchDurationFrames
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Timer_u8
    lda #eSound::Launch
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Sfx_eSound
    rts
.ENDPROC

;;;=========================================================================;;;
