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

;;; SFX sequence data for the "break flower" sound effect.
.PROC Data_BreakFlower_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 2
    d_byte Env_bEnvelope, bEnvelope::NoLength | 2
    d_byte Sweep_byte, 0
    d_word Timer_u16, $f883
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 2
    d_byte Env_bEnvelope, bEnvelope::NoLength | 2
    d_byte Sweep_byte, 0
    d_word Timer_u16, $f885
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 7
    d_byte Env_bEnvelope, bEnvelope::NoLength | 2
    d_byte Sweep_byte, 0
    d_word Timer_u16, $f88a
    D_END
    .byte 0
.ENDPROC

;;; SFX sequence data for the "pick up flower" sound effect.
.PROC Data_PickUpFlower_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $00d2
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $00a9
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $009f
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 9
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $008e
    D_END
    .byte 0
.ENDPROC

;;; Starts playing the sound for when the player avatar breaks a flower.
;;; @preserve X, Y, T0+
.EXPORT Func_PlaySfxBreakFlower
.PROC Func_PlaySfxBreakFlower
    txa
    pha
    tya
    pha
    ldx #eChan::Noise
    ldya #Data_BreakFlower_sSfxSeq_arr
    jsr Func_PlaySfxSequence  ; preserves T0+
    pla
    tay
    pla
    tax
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Starts playing the sound for when the player avatar picks up a flower.
;;; @preserve T0+
.EXPORT FuncA_Avatar_PlaySfxPickUpFlower
.PROC FuncA_Avatar_PlaySfxPickUpFlower
    ldx #eChan::Pulse1
    ldya #Data_PickUpFlower_sSfxSeq_arr
    jmp Func_PlaySfxSequence  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
