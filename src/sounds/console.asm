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

.IMPORT Func_PlaySfxOnPulse2Channel

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "console turn on" sound effect.
;;; @thread AUDIO
.PROC Data_ConsoleTurnOn_sSfx
    sfx_SetAll (bEnvelope::Duty12 | bEnvelope::NoLength | 2), kNoSweep, $0340
    sfx_Wait 4
    sfx_SetTimer $02c0
    sfx_Wait 12
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Starts playing the sound for when an alarm goes off in the Shadow Labs.
;;; @preserve T0+
.EXPORT Func_PlaySfxConsoleTurnOn
.PROC Func_PlaySfxConsoleTurnOn
    ldya #Data_ConsoleTurnOn_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
