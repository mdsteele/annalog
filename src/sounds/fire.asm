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

;;; SFX sequence data for the "shoot fire" sound effect.
.PROC Data_ShootFire_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::NoLength | bEnvelope::ConstVol | 4
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000a
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::NoLength | bEnvelope::ConstVol | 8
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000b
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::NoLength | bEnvelope::ConstVol | 12
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000c
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::NoLength | bEnvelope::ConstVol | 8
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000d
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::NoLength | bEnvelope::ConstVol | 4
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000e
    D_END
    .byte 0
.ENDPROC

;;; Starts playing the sound for when something shoots a firey projectile.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxShootFire
.PROC Func_PlaySfxShootFire
    txa
    pha
    ldya #Data_ShootFire_sSfxSeq_arr
    jsr Func_PlaySfxSequenceNoise  ; preserves T0+
    pla
    tax
    rts
.ENDPROC

;;;=========================================================================;;;
