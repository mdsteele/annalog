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

.IMPORT Func_PlaySfxOnPulse2Channel
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "drip" sound effect.
;;; @thread AUDIO
.PROC Data_Drip_sSfx
    sfx_SetEnv $ff
    sfx_Func _SetTimer
    sfx_End
_SetTimer:
    cpy #3
    bge @done
    lda _TimerLo_u8_arr3, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda #0
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    @done:
    rts
_TimerLo_u8_arr3:
    .byte $38, $80, $a0
.ENDPROC

;;; SFX data for the "drop" sound effect.
;;; @thread AUDIO
.PROC Data_Drop_sSfx
    .linecont +
    sfx_SetAll bEnvelope::Duty12 | bEnvelope::NoLength | 4, \
               (pulse_sweep +3, 0), $0070
    sfx_Wait 20
    sfx_End
    .linecont -
.ENDPROC

;;; Starts playing the sound for dripping acid.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxDrip
.PROC Func_PlaySfxDrip
    ldya #Data_Drip_sSfx
    stya Zp_Next_sChanSfx_arr + eChan::Triangle + sChanSfx::NextOp_sSfx_ptr
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Starts playing the sound for dropping a spike.
;;; @preserve X, T0+
.EXPORT FuncA_Actor_PlaySfxDrop
.PROC FuncA_Actor_PlaySfxDrop
    ldya #Data_Drop_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;
