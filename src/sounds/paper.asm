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

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "collect paper" sound effect.
;;; @thread AUDIO
.PROC Data_CollectPaper_sSfx
    sfx_SetTimer $0007
    sfx_Func _EnvUp
    sfx_SetTimerLo $8b
    sfx_Func _EnvUp
    sfx_SetTimerLo $08
    sfx_Func _EnvUp
    sfx_End
_EnvUp:
    lda _Env_bEnvelope_arr6, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    cpy #5
    rts
_Env_bEnvelope_arr6:
    .byte bEnvelope::ConstVol | bEnvelope::NoLength | 1
    .byte bEnvelope::ConstVol | bEnvelope::NoLength | 4
    .byte bEnvelope::ConstVol | bEnvelope::NoLength | 6
    .byte bEnvelope::ConstVol | bEnvelope::NoLength | 9
    .byte bEnvelope::ConstVol | bEnvelope::NoLength | 11
    .byte bEnvelope::ConstVol | bEnvelope::NoLength | 14
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; Starts playing the sound for when the player avatar collects a new paper.
;;; @preserve X, T0+
.EXPORT FuncA_Pause_PlaySfxCollectPaper
.PROC FuncA_Pause_PlaySfxCollectPaper
    ldya #Data_CollectPaper_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
