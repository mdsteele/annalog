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

.IMPORT Func_PlaySfxSequencePulse2

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX sequence data for the "window close" sound effect.
.PROC Data_WindowClose_sSfxSeq_arr
    .linecont +
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 15
    d_byte Env_bEnvelope, \
           bEnvelope::Duty14 | bEnvelope::NoLength | bEnvelope::ConstVol | 5
    d_byte Sweep_byte, pulse_sweep +2, 0
    d_word Timer_u16, $0360
    D_END
    .byte 0
    .linecont -
.ENDPROC

;;; SFX sequence data for the "window open" sound effect.
.PROC Data_WindowOpen_sSfxSeq_arr
    .linecont +
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 15
    d_byte Env_bEnvelope, \
           bEnvelope::Duty14 | bEnvelope::NoLength | bEnvelope::ConstVol | 5
    d_byte Sweep_byte, pulse_sweep -2, 0
    d_word Timer_u16, $03ff
    D_END
    .byte 0
    .linecont -
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Starts playing the sound for closing the UI window.
;;; @preserve T0+
.EXPORT Func_PlaySfxWindowClose
.PROC Func_PlaySfxWindowClose
    ldya #Data_WindowClose_sSfxSeq_arr
    jmp Func_PlaySfxSequencePulse2  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for opening the UI window.
;;; @preserve T0+
.EXPORT Func_PlaySfxWindowOpen
.PROC Func_PlaySfxWindowOpen
    ldya #Data_WindowOpen_sSfxSeq_arr
    jmp Func_PlaySfxSequencePulse2  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
