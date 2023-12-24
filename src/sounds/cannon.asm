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

;;; SFX sequence data for the "cannon fire" sound effect.
.PROC Data_CannonFire_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 3
    d_byte Env_bEnvelope, bEnvelope::NoLength | bEnvelope::ConstVol | 8
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000d
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 8
    d_byte Env_bEnvelope, bEnvelope::NoLength | bEnvelope::ConstVol | 4
    d_byte Sweep_byte, 0
    d_word Timer_u16, $000f
    D_END
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing the sound for when a cannon machine fires a grenade.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxCannonFire
.PROC FuncA_Machine_PlaySfxCannonFire
    ldx #eChan::Noise
    ldya #Data_CannonFire_sSfxSeq_arr
    jmp Func_PlaySfxSequence  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
