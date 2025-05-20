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

;;; SFX data for the "splash" sound effect.
;;; @thread AUDIO
.PROC Data_Splash_sSfx
    sfx_SetEnvTimer (bEnvelope::ConstVol | bEnvelope::NoLength | 1), $0002
    sfx_Func _EnvUp
    sfx_Func Func_EnvDownForSfxSplash
    sfx_End
_EnvUp:
    iny
    cpy #10
    tya
    bne Func_SetEnvForSfxSplash  ; unconditional; preserves C, X, and T0+
.ENDPROC

;;; SFX data for the "steam" sound effect.
;;; @thread AUDIO
.PROC Data_Steam_sSfx
    sfx_SetEnvTimer (bEnvelope::ConstVol | bEnvelope::NoLength | 2), $0004
    sfx_Func _EnvUp
    sfx_Func Func_EnvDownForSfxSplash
    sfx_End
_EnvUp:
    iny
    tya
    mul #2
    cpy #5
    jmp Func_SetEnvForSfxSplash  ; preserves C, X, and T0+
.ENDPROC

;;; sfx_Func loop function for reducing the envelope volume of a splash or
;;; steam sound effeect.
;;; @thread AUDIO
;;; @param Y The loop counter.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set when the loop is done.
;;; @preserve X, T0+
.PROC Func_EnvDownForSfxSplash
    tya
    div #2
    rsub #9
    cpy #20  ; set C if Y >= 20
    fall Func_SetEnvForSfxSplash  ; preserves C, X, and T0+
.ENDPROC

;;; Updates the Envelope_wo register for a splash or steam sound effect.
;;; @thread AUDIO
;;; @param A The volume to set (0-15).
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @preserve C, X, T0+
.PROC Func_SetEnvForSfxSplash
    ora #bEnvelope::ConstVol | bEnvelope::NoLength
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Starts playing the sound for when the player avatar splashes into water.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxSplash
.PROC Func_PlaySfxSplash
    ldya #Data_Splash_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.EXPORT FuncA_Machine_PlaySfxEmitSteam
.PROC FuncA_Machine_PlaySfxEmitSteam
    ldya #Data_Steam_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
