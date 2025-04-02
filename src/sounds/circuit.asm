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

.IMPORT Func_PlaySfxOnPulse2Channel
.IMPORTZP Zp_AudioTmp_byte

;;;=========================================================================;;;

;;; The initial envelope volume (before fading out) to use for the "circuit
;;; power up" sound effect.
kCircuitPowerUpBaseVol = 9

;;; How many frames it takes to fade out the volume of the "circuit power up"
;;; sound effect by one step.
.DEFINE kCircuitPowerUpFadeOutSlowdown 8

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "circuit power up" sound effect.
.PROC Data_CircuitPowerUp_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty18 | bEnvelope::NoLength | \
                bEnvelope::ConstVol | kCircuitPowerUpBaseVol), \
               (pulse_sweep -2, 2), $0700
    sfx_Func _RampUp
    sfx_SetSweep kNoSweep
    sfx_Func _Steady
    sfx_Func _FadeOut
    sfx_End
    .linecont -
_RampUp:
    jsr _ModulateDutyAtBaseVolume  ; preserves X and Y
    cpy #64
    rts
_Steady:
    jsr _ModulateDutyAtBaseVolume  ; preserves X and Y
    cpy #30
    rts
_FadeOut:
    tya
    div #kCircuitPowerUpFadeOutSlowdown
    rsub #kCircuitPowerUpBaseVol
    jsr _ModulateDutyWithVolume  ; preserves X and Y
    cpy #kCircuitPowerUpFadeOutSlowdown * (kCircuitPowerUpBaseVol - 1)
    rts
_ModulateDutyAtBaseVolume:
    lda #kCircuitPowerUpBaseVol  ; param: volume
_ModulateDutyWithVolume:
    sta Zp_AudioTmp_byte  ; volume
    tya
    and #$02
    .assert bEnvelope::Duty18 = 0, error
    beq @setDuty
    lda #bEnvelope::Duty14
    @setDuty:
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    ora Zp_AudioTmp_byte
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Starts playing the sound for when a core circuit powers up.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxCircuitPowerUp
.PROC FuncA_Cutscene_PlaySfxCircuitPowerUp
    ldya #Data_CircuitPowerUp_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
