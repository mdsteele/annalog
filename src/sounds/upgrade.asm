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

;;; SFX sequence data for pulse channel portion of the "spawn upgrade" sound
;;; effect.
.PROC Data_SpawnUpgradePulse_sSfxSeq_arr
    .linecont +
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 12
    d_byte Env_bEnvelope, \
           bEnvelope::Duty12 | bEnvelope::NoLength | bEnvelope::ConstVol | 8
    d_byte Sweep_byte, pulse_sweep +5, 0
    d_word Timer_u16, $0110
    D_END
    .byte 0
    .linecont -
.ENDPROC

;;; SFX sequence data for pulse channel portion of the "spawn upgrade" sound
;;; effect.
.PROC Data_SpawnUpgradeNoise_sSfxSeq_arr
    D_STRUCT sSfxSeq
    d_byte Duration_u8, 15
    d_byte Env_bEnvelope, bEnvelope::NoLength | 3
    d_byte Sweep_byte, 0
    d_word Timer_u16, $0001
    D_END
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when an upgrade is spawned.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxSpawnUpgrade
.PROC FuncA_Room_PlaySfxSpawnUpgrade
    ldx #eChan::Pulse2
    ldya #Data_SpawnUpgradePulse_sSfxSeq_arr
    jsr Func_PlaySfxSequence  ; preserves T0+
    ldx #eChan::Noise
    ldya #Data_SpawnUpgradeNoise_sSfxSeq_arr
    jmp Func_PlaySfxSequence  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
