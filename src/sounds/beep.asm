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
.IMPORT Ram_Audio_sChanSfx_arr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "beep" sound effect.
.PROC Data_Beep_sSfx
    sfx_SetEnvSweep bEnvelope::Duty12 | bEnvelope::NoLength | 3, kNoSweep
    sfx_Func _InitializeTimer
    sfx_Wait 15
    sfx_End
_InitializeTimer:
    ldy Ram_Audio_sChanSfx_arr + sChanSfx::Param1_byte, x  ; tone
    lda _TimerLo_u8_arr10, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda _TimerHi_u8_arr10, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    sec  ; set C to indicate that the function is finished
    rts
;;; These values represent the ten natural notes from A3 through C5.
_TimerLo_u8_arr10: .byte $fb, $c4, $ab, $7c, $52, $3f, $1c, $fd, $e1, $d5
_TimerHi_u8_arr10: .byte $01, $01, $01, $01, $01, $01, $01, $00, $00, $00
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing a sound for the BEEP opcode.
;;; @param A The tone number (0-9).
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxBeep
.PROC FuncA_Machine_PlaySfxBeep
    sta Zp_Next_sChanSfx_arr + eChan::Pulse2 + sChanSfx::Param1_byte  ; tone
    ldya #Data_Beep_sSfx
    jmp Func_PlaySfxOnPulse2Channel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
