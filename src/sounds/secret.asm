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

.IMPORT Func_PlaySfxOnPulse1Channel

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "secret unlocked" sound effect.
;;; @thread AUDIO
.PROC Data_SecretUnlocked_sSfx
    sfx_SetAll bEnvelope::Duty14 | bEnvelope::NoLength | 4, kNoSweep, $013f
    sfx_Wait 7
    sfx_SetTimer $0167
    sfx_Wait 7
    sfx_SetTimer $01df
    sfx_Wait 7
    sfx_SetTimer $0280
    sfx_Wait 7
    sfx_SetEnvTimer bEnvelope::Duty18 | bEnvelope::NoLength | 4, $012d
    sfx_Wait 7
    sfx_SetTimer $013f
    sfx_Wait 7
    sfx_SetEnvTimer bEnvelope::Duty18 | bEnvelope::NoLength | 6, $0167
    sfx_Wait 28
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Starts playing the jingle sound for when a puzzle is solved or a secret is
;;; unlocked.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxSecretUnlocked
.PROC Func_PlaySfxSecretUnlocked
    ldya #Data_SecretUnlocked_sSfx
    jmp Func_PlaySfxOnPulse1Channel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
