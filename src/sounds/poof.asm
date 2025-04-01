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
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Func_PlaySfxOnNoiseChannel
.IMPORT Func_PlaySfxOnPulse2Channel

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the pulse channel portion of the "poof" sound effect.
.PROC Data_PoofPulse_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty12 | bEnvelope::NoLength | \
                bEnvelope::ConstVol | 8), \
               (pulse_sweep +5, 0), $0110
    sfx_Wait 12
    sfx_End
    .linecont -
.ENDPROC

;;; SFX data for the noise channel portion of the "poof" sound effect.
.PROC Data_PoofNoise_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 3, $0001
    sfx_Wait 15
    sfx_End
.ENDPROC

;;; Starts playing the sound for a poof of smoke e.g. when an upgrade spawns,
;;; or a chain is broken, or an egg hatches.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxPoof
.PROC Func_PlaySfxPoof
    ldya #Data_PoofPulse_sSfx
    jsr Func_PlaySfxOnPulse2Channel  ; preserves X and T0+
    ldya #Data_PoofNoise_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
