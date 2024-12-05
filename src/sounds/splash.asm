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

;;; SFX data for the "splash" sound effect.
.PROC Data_Splash_sSfx
    sfx_SetEnvTimer (bEnvelope::ConstVol | bEnvelope::NoLength | 1), $0002
    sfx_Func _EnvUp
    sfx_Func _EnvDown
    sfx_End
_EnvUp:
    iny
    cpy #10
    tya
    bne _SetEnv  ; unconditional
_EnvDown:
    tya
    div #2
    rsub #9
    cpy #20
_SetEnv:
    ora #bEnvelope::ConstVol | bEnvelope::NoLength
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Starts playing the sound for when the player avatar splashes into water.
;;; @preserve X, T0+
.EXPORT FuncA_Avatar_PlaySfxSplash
.PROC FuncA_Avatar_PlaySfxSplash
    ldya #Data_Splash_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
