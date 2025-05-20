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

.SEGMENT "PRGC_Prison"

;;; SFX data for the "prison gate" sound effect.
;;; @thread AUDIO
.PROC DataC_Prison_Gate_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 0, $0002
    sfx_Wait 2
    sfx_End
.ENDPROC

;;; Starts playing the sound for when a prison gate platform opens/closes.
;;; @preserve X, T0+
.EXPORT FuncC_Prison_PlaySfxPrisonGate
.PROC FuncC_Prison_PlaySfxPrisonGate
    ldya #DataC_Prison_Gate_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
