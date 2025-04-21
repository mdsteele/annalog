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

.SEGMENT "PRG8"

;;; SFX data for the "wing flap" sound effect.
;;; @thread AUDIO
.PROC Data_WingFlap_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | bEnvelope::ConstVol | 1, $0001
    sfx_Func _RampUp
    sfx_End
_RampUp:
    iny
    tya
    mul #2
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    cpy #7
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Starts playing a "wing flap" sound.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_PlaySfxWingFlap
.PROC FuncA_Actor_PlaySfxWingFlap
    ldya #Data_WingFlap_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
