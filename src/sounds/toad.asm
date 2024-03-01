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

;;; SFX sequence data for the "toad jump" sound effect.
.PROC Data_ToadJump_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 24
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 5
    d_byte Sweep_byte, pulse_sweep -2, 0
    d_word Timer_u16, $03e0
    D_END
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Starts playing the sound for when an actor jumps.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_PlaySfxToadJump
.PROC FuncA_Actor_PlaySfxToadJump
    txa
    pha
    ldx #eChan::Pulse2
    ldya #Data_ToadJump_sSfxSeq_arr
    jsr Func_PlaySfxSequence  ; preserves T0+
    pla
    tax
    rts
.ENDPROC

;;;=========================================================================;;;
