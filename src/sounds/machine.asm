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
.INCLUDE "../macros.inc"
.INCLUDE "../sound.inc"

.IMPORT Func_PlaySfxBytecodePulse2

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "machine end" sound effect.
.PROC Data_MachineEnd_sSfx
    sfx_SetAll bEnvelope::Duty12 | bEnvelope::NoLength | 3, 0, $0120
    sfx_Wait 8
    sfx_SetTimerHi $01
    sfx_Wait 16
    sfx_End
.ENDPROC

;;; SFX data for the "machine error" sound effect.
.PROC Data_MachineError_sSfx
    sfx_SetAll        bEnvelope::Duty14 | bEnvelope::NoLength | 4, 0, $0340
    sfx_Wait 8
    sfx_SetEnvTimerHi bEnvelope::Duty18 | bEnvelope::NoLength | 4,    $03
    sfx_Wait 8
    sfx_SetEnvTimerHi bEnvelope::Duty14 | bEnvelope::NoLength | 4,    $03
    sfx_Wait 8
    sfx_End
.ENDPROC

;;; SFX data for the "machine sync" sound effect.
.PROC Data_MachineSync_sSfx
    sfx_SetAll      bEnvelope::Duty18 | bEnvelope::NoLength | 3, 0, $0120
    sfx_Wait 5
    sfx_SetEnvTimer bEnvelope::Duty14 | bEnvelope::NoLength | 3,    $00e0
    sfx_Wait 10
    sfx_End
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing the sound for when a machine executes an END instruction.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxEnd
.PROC FuncA_Machine_PlaySfxEnd
    ldya #Data_MachineEnd_sSfx
    jmp Func_PlaySfxBytecodePulse2  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when a machine encounters an error.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxError
.PROC FuncA_Machine_PlaySfxError
    ldya #Data_MachineError_sSfx
    jmp Func_PlaySfxBytecodePulse2  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when all machines SYNC up.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxSync
.PROC FuncA_Machine_PlaySfxSync
    ldya #Data_MachineSync_sSfx
    jmp Func_PlaySfxBytecodePulse2  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
