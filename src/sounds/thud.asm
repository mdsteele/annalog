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

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX sequence data for the "small thud" sound effect.
.PROC Data_ThudSmall_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 6
    d_byte Env_bEnvelope, bEnvelope::NoLength | 1
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000c
    D_END
    .byte 0
.ENDPROC

;;; SFX sequence data for the "big thud" sound effect.
.PROC Data_ThudBig_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 24
    d_byte Env_bEnvelope, bEnvelope::NoLength | 5
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000d
    D_END
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when smaller heavy object (like a crate) falls
;;; on the floor.
;;; @preserve X, T0+
.EXPORT FuncA_Room_PlaySfxThudSmall
.PROC FuncA_Room_PlaySfxThudSmall
    txa
    pha
    ldya #Data_ThudSmall_sSfxSeq_arr
    jsr Func_PlaySfxSequenceNoise  ; preserves T0+
    pla
    tax
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing the sound for when bigger heavy object falls on the floor.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxThudBig
.PROC FuncA_Machine_PlaySfxThudBig
    ldya #Data_ThudBig_sSfxSeq_arr
    jmp Func_PlaySfxSequenceNoise  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
