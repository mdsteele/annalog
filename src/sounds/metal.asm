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

.IMPORT Func_PlaySfxSequenceNoise
.IMPORT Func_PlaySfxSequencePulse2

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX sequence data for the "metallic clang" sound effect.
.PROC Data_MetallicClang_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 4
    d_byte Env_bEnvelope, bEnvelope::Duty18 | bEnvelope::NoLength | 7
    d_byte Sweep_byte, pulse_sweep +0, 0
    d_word Timer_u16, $00f7
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 40
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 9
    d_byte Sweep_byte, pulse_sweep +0, 0
    d_word Timer_u16, $00f5
    D_END
    .byte 0
.ENDPROC

;;; SFX sequence data for the "metallic ding" sound effect.
.PROC Data_MetallicDing_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 4
    d_byte Env_bEnvelope, bEnvelope::NoLength | 1
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0081
    D_END
    .byte 0
.ENDPROC

;;; Starts playing a metallic "ding" sound.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxMetallicDing
.PROC Func_PlaySfxMetallicDing
    txa
    pha
    ldya #Data_MetallicDing_sSfxSeq_arr
    jsr Func_PlaySfxSequenceNoise  ; preserves T0+
    pla
    tax
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing a metallic "clang" sound.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxMetallicClang
.PROC FuncA_Room_PlaySfxMetallicClang
    ldya #Data_MetallicClang_sSfxSeq_arr
    jmp Func_PlaySfxSequencePulse2  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
