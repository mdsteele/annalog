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

.IMPORT Func_PlaySfxBytecode

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "quest marker" sound effect.
.PROC Data_QuestMarker_sSfx
    sfx_SetAll bEnvelope::Duty14 | bEnvelope::NoLength | 4, 0, $011c
    sfx_Wait 5
    sfx_SetTimer $0152
    sfx_Wait 5
    sfx_SetTimer $011c
    sfx_Wait 5
    sfx_SetTimer $0152
    sfx_Wait 5
    sfx_SetTimer $00d5
    sfx_Wait 15
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Starts playing the jingle sound for when a quest marker is added to the
;;; minimap.
;;; @preserve T0+
.EXPORT FuncA_Dialog_PlaySfxQuestMarker
.PROC FuncA_Dialog_PlaySfxQuestMarker
    ldx #eChan::Pulse1
    ldya #Data_QuestMarker_sSfx
    jmp Func_PlaySfxBytecode  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
