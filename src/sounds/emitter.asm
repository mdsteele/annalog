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

.IMPORT Func_PlaySfxOnNoiseChannel
.IMPORT Func_PlaySfxOnPulse2Channel

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "emitter beam" sound effect.
;;; @thread AUDIO
.PROC Data_EmitterBeam_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty18 | bEnvelope::NoLength | 0), \
               (pulse_sweep +4, 0), $00cc
    sfx_Wait 12
    sfx_End
    .linecont -
.ENDPROC

;;; SFX data for the "emitter forcefield" sound effect.
;;; @thread AUDIO
.PROC Data_EmitterForcefield_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 5, $0086
    sfx_Wait 5
    sfx_SetTimerLo $87
    sfx_Wait 15
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing the sound for when an emitter machine shoots a beam.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxEmitterBeam
.PROC FuncA_Machine_PlaySfxEmitterBeam
    ldya #Data_EmitterBeam_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when an emitter machine creates a forcefield.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxEmitterForcefield
.PROC FuncA_Machine_PlaySfxEmitterForcefield
    ldya #Data_EmitterForcefield_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
