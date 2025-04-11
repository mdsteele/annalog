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
.INCLUDE "../breaker.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Func_PlaySfxOnPulse2Channel
.IMPORTZP Zp_AudioTmp_byte

;;;=========================================================================;;;

;;; The initial envelope volume (before fading out) to use for circuit sound
;;; effects.
kCircuitBaseVol = 9

;;; How many frames it takes to fade out the volume of a circuit sound effect
;;; by one step.
.DEFINE kCircuitFadeOutSlowdown 8

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "circuit trace" sound effect.
.PROC Data_CircuitTrace_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty18 | bEnvelope::NoLength | \
                bEnvelope::ConstVol | kCircuitBaseVol), \
               (pulse_sweep -1, 3), $07ff
    sfx_Func _RampUp
    sfx_Func Func_SfxCircuit_FadeOut
    sfx_End
    .linecont -
_RampUp:
    jsr Func_SfxCircuit_ModulateDutyAtBaseVolume  ; preserves X and Y
    cpy #kCircuitTraceFrames - kCircuitFadeOutSlowdown * kCircuitBaseVol
    rts
.ENDPROC

;;; SFX data for the "circuit power up" sound effect.
.PROC Data_CircuitPowerUp_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty18 | bEnvelope::NoLength | \
                bEnvelope::ConstVol | kCircuitBaseVol), \
               (pulse_sweep -2, 2), $0700
    sfx_Func _RampUp
    sfx_SetSweep kNoSweep
    sfx_Func _Steady
    sfx_Func Func_SfxCircuit_FadeOut
    sfx_End
    .linecont -
_RampUp:
    jsr Func_SfxCircuit_ModulateDutyAtBaseVolume  ; preserves X and Y
    cpy #64
    rts
_Steady:
    jsr Func_SfxCircuit_ModulateDutyAtBaseVolume  ; preserves X and Y
    cpy #30
    rts
.ENDPROC

;;; An sfx_Func to fade out a circuit sound effect over time.
;;; @param Y The sfx_Func loop index.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @preserve X, Y, T0+
.PROC Func_SfxCircuit_FadeOut
    tya  ; loop index
    div #kCircuitFadeOutSlowdown
    rsub #kCircuitBaseVol
    jsr Func_SfxCircuit_ModulateDutyWithVolume  ; preserves X and Y
    cpy #kCircuitFadeOutSlowdown * (kCircuitBaseVol - 1)
    rts
.ENDPROC

;;; Modulates the duty cycle of a circuit sound effect between 1/8 and 1/4,
;;; using kCircuitBaseVol as the envelope volume.
;;; @param Y The sfx_Func loop index.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @preserve X, Y, T0+
.PROC Func_SfxCircuit_ModulateDutyAtBaseVolume
    lda #kCircuitBaseVol  ; param: volume
    fall Func_SfxCircuit_ModulateDutyWithVolume  ; preserves X, Y, and T0+
.ENDPROC

;;; Modulates the duty cycle of a circuit sound effect between 1/8 and 1/4,
;;; using the specified envelope volume.
;;; @param A The volume to use (0-15).
;;; @param Y The sfx_Func loop index.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @preserve X, Y, T0+
.PROC Func_SfxCircuit_ModulateDutyWithVolume
    sta Zp_AudioTmp_byte  ; volume
    tya  ; loop index
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

;;; Starts playing the sound for when tracing a core circuit.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxCircuitTrace
.PROC FuncA_Cutscene_PlaySfxCircuitTrace
    ldya #Data_CircuitTrace_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when a core circuit powers up.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxCircuitPowerUp
.PROC FuncA_Cutscene_PlaySfxCircuitPowerUp
    ldya #Data_CircuitPowerUp_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
