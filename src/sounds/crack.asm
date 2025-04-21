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

;;; SFX data for the "crack" sound effect.
;;; @thread AUDIO
.PROC Data_Crack_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 1, $000b
    sfx_Wait 6
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when an obstacle gets hit and starts to crack.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxCrack
.PROC FuncA_Room_PlaySfxCrack
    ldya #Data_Crack_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
