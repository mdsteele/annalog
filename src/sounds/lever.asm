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

;;; The duration of the rocket launch sound, in frames.
kSfxLaunchDurationFrames = $1c

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "lever off" sound effect.
;;; @thread AUDIO
.PROC Data_LeverOff_sSfx
    sfx_SetEnvTimer (bEnvelope::NoLength | 0), $0008
    sfx_Wait 3
    sfx_End
.ENDPROC

;;; SFX data for the "lever on" sound effect.
;;; @thread AUDIO
.PROC Data_LeverOn_sSfx
    sfx_SetEnvTimer (bEnvelope::NoLength | 0), $0006
    sfx_Wait 3
    sfx_End
.ENDPROC

;;; Starts playing the sound for flipping a lever to the off position.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxLeverOff
.PROC Func_PlaySfxLeverOff
    ldya #Data_LeverOff_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;; Starts playing the sound for flipping a lever to the on position.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxLeverOn
.PROC Func_PlaySfxLeverOn
    ldya #Data_LeverOn_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
