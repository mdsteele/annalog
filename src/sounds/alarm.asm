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

.SEGMENT "PRG8"

;;; SFX data for the "alarm" sound effect.
.PROC Data_Alarm_sSfx
    .linecont +
    sfx_SetAll (bEnvelope::Duty14 | bEnvelope::NoLength | \
                bEnvelope::ConstVol | 12), \
               (pulse_sweep -2, 0), $0120
    sfx_Wait 28
    sfx_SetTimer $0120
    sfx_Wait 28
    sfx_SetTimer $0120
    sfx_Wait 28
    sfx_End
    .linecont -
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when an alarm goes off in the Shadow Labs.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxAlarm
.PROC FuncA_Room_PlaySfxAlarm
    ldya #Data_Alarm_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
