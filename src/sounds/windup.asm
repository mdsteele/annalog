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

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "quick windup" sound effect.
;;; @thread AUDIO
.PROC Data_QuickWindup_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty18 | bEnvelope::NoLength | \
                bEnvelope::ConstVol | 15), \
               (pulse_sweep -3, 0), $0280
    sfx_Wait 30
    sfx_End
    .linecont -
.ENDPROC

;;; SFX data for the "slow windup" sound effect.
;;; @thread AUDIO
.PROC Data_SlowWindup_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty18 | bEnvelope::NoLength | \
                bEnvelope::ConstVol | 15), \
               (pulse_sweep -2, 1), $0280
    sfx_Wait 85
    sfx_End
    .linecont -
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Starts playing the sound for when the activated core winds up a laser beam.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxQuickWindup
.PROC FuncA_Cutscene_PlaySfxQuickWindup
    ldya #Data_QuickWindup_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when a boss winds up a big attack.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxSlowWindup
.PROC FuncA_Room_PlaySfxSlowWindup
    ldya #Data_SlowWindup_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
