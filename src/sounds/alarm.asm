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

.IMPORT Func_PlaySfxSequence

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX sequence data for the "alarm" sound effect.
.PROC Data_Alarm_sSfxSeq_arr
    .linecont +
    .repeat 3
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 28
    d_byte Env_bEnvelope, \
           bEnvelope::Duty14 | bEnvelope::NoLength | bEnvelope::ConstVol | 12
    d_byte Sweep_byte, pulse_sweep -2, 0
    d_word Timer_u16, $0120
    D_END
    .endrepeat
    .byte 0
    .linecont -
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when an alarm goes off in the Shadow Labs.
;;; @preserve X, T0+
.EXPORT FuncA_Room_PlaySfxAlarm
.PROC FuncA_Room_PlaySfxAlarm
    ldx #eChan::Pulse2
    ldya #Data_Alarm_sSfxSeq_arr
    jmp Func_PlaySfxSequence  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
