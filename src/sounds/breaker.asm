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
.INCLUDE "../devices/breaker.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Func_PlaySfxSequenceNoise

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX sequence data for the "flip breaker" sound effect.
.PROC Data_FlipBreaker_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 8
    d_byte Env_bEnvelope, bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0002
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 16
    d_byte Env_bEnvelope, bEnvelope::NoLength | 5
    d_byte Sweep_byte, 0
    d_word Timer_u16, $008d
    D_END
    .byte 0
.ENDPROC

;;; SFX sequence data for the "breaker rising" sound effect.
.PROC Data_BreakerRising_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, kBreakerRisingDeviceAnimStart
    d_byte Env_bEnvelope, bEnvelope::NoLength | 0
    d_byte Sweep_byte, 0
    d_word Timer_u16, $008e
    D_END
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Starts playing the sound for when a breaker device is activated.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxFlipBreaker
.PROC FuncA_Cutscene_PlaySfxFlipBreaker
    ldya #Data_FlipBreaker_sSfxSeq_arr
    jmp Func_PlaySfxSequenceNoise  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when a breaker device rises from the floor.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxBreakerRising
.PROC FuncA_Cutscene_PlaySfxBreakerRising
    ldya #Data_BreakerRising_sSfxSeq_arr
    jmp Func_PlaySfxSequenceNoise  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when a breaker device rises from the floor.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxBreakerRising
.PROC FuncA_Room_PlaySfxBreakerRising
    ldya #Data_BreakerRising_sSfxSeq_arr
    jmp Func_PlaySfxSequenceNoise  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
