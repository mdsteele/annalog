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

.IMPORT Func_PlaySfxOnNoiseChannel
.IMPORT Ram_Audio_sChanSfx_arr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRGE_Sfx"

;;; SFX data for the "conveyor" sound effect.
;;; @thread AUDIO
.PROC Data_Conveyor_sSfx
    sfx_SetEnvTimerHi bEnvelope::NoLength | 1, $00
    sfx_Func _Delay
    sfx_SetTimerHi $00
    sfx_Func _Delay
    sfx_SetTimerHi $00
    sfx_Wait 8
    sfx_End
_Delay:
    lda Ram_Audio_sChanSfx_arr + eChan::Noise + sChanSfx::Param2_byte  ; timer
    sta Hw_Channels_sChanRegs_arr5 + eChan::Noise + sChanRegs::TimerLo_wo
    cpy Ram_Audio_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte  ; delay
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Starts playing a sound for conveyor machine shifting gears.
;;; @param A The gear value (0-9).
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxConveyor
.PROC FuncA_Machine_PlaySfxConveyor
    tay
    lda _Delay_u8_arr10, y
    beq @silent
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte  ; delay
    lda _Timer_u8_arr10, y
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Param2_byte  ; timer
    ldya #Data_Conveyor_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
    @silent:
    rts
_Delay_u8_arr10:
    .byte    0
    .byte 8, 0, 8
    .byte 6, 0, 6
    .byte 4, 0, 4
_Timer_u8_arr10:
    .byte      $00
    .byte $89, $00, $8a
    .byte $89, $00, $8a
    .byte $89, $00, $8a
.ENDPROC

;;;=========================================================================;;;
