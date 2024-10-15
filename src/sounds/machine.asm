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

;;; SFX sequence data for the "machine end" sound effect.
.PROC Data_MachineEnd_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 8
    d_byte Env_bEnvelope, bEnvelope::Duty12 | bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0120
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 16
    d_byte Env_bEnvelope, bEnvelope::Duty12 | bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0120
    D_END
    .byte 0
.ENDPROC

;;; SFX sequence data for the "machine error" sound effect.
.PROC Data_MachineError_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 8
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 4
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0340
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 8
    d_byte Env_bEnvelope, bEnvelope::Duty18 | bEnvelope::NoLength | 4
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0340
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 8
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 4
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0340
    D_END
    .byte 0
.ENDPROC

;;; SFX sequence data for the "machine sync" sound effect.
.PROC Data_MachineSync_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 5
    d_byte Env_bEnvelope, bEnvelope::Duty18 | bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0120
    D_END
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 10
    d_byte Env_bEnvelope, bEnvelope::Duty14 | bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $00e0
    D_END
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing the sound for when a machine executes an END instruction.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxEnd
.PROC FuncA_Machine_PlaySfxEnd
    ldya #Data_MachineEnd_sSfxSeq_arr
    jmp Func_PlaySfxSequencePulse2  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when a machine encounters an error.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxError
.PROC FuncA_Machine_PlaySfxError
    ldya #Data_MachineError_sSfxSeq_arr
    jmp Func_PlaySfxSequencePulse2  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when all machines SYNC up.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxSync
.PROC FuncA_Machine_PlaySfxSync
    ldya #Data_MachineSync_sSfxSeq_arr
    jmp Func_PlaySfxSequencePulse2  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
