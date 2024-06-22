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

;;; SFX sequence data for the "flop down" sound effect.
.PROC Data_FlopDown_sSfxSeq_arr
    .linecont +
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 6
    d_byte Env_bEnvelope, \
           bEnvelope::Duty14 | bEnvelope::NoLength | bEnvelope::ConstVol | 12
    d_byte Sweep_byte, pulse_sweep +6, 0
    d_word Timer_u16, $0120
    D_END
    .byte 0
    .linecont -
.ENDPROC

;;; Starts playing the sound for when the player avatar flops face down on the
;;; ground.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxFlopDown
.PROC Func_PlaySfxFlopDown
    txa
    pha
    ldx #eChan::Pulse2
    ldya #Data_FlopDown_sSfxSeq_arr
    jsr Func_PlaySfxSequence  ; preserves T0+
    pla
    tax
    rts
.ENDPROC

;;;=========================================================================;;;
