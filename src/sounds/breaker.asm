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

.IMPORT Func_PlaySfxOnNoiseChannel
.IMPORT Ram_Audio_sChanSfx_arr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "flip breaker" sound effect.
.PROC Data_FlipBreaker_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 3, $0002
    sfx_Wait 8
    sfx_SetEnvTimer bEnvelope::NoLength | 5, $008d
    sfx_Wait 16
    sfx_End
.ENDPROC

;;; SFX data for the "rumbling" sound effect.
.PROC Data_Rumbling_sSfx
    sfx_SetEnvTimer bEnvelope::NoLength | 0, $008e
    sfx_Func _WaitForParam1Frames
    sfx_End
_WaitForParam1Frames:
    cpy Ram_Audio_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Starts playing the sound for when a breaker device is activated.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxFlipBreaker
.PROC FuncA_Cutscene_PlaySfxFlipBreaker
    ldya #Data_FlipBreaker_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when a breaker device rises from the floor.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxFinalTerminalRising
.PROC FuncA_Cutscene_PlaySfxFinalTerminalRising
    lda #kBreakerRisingDeviceAnimStart  ; param: num frames
    fall FuncA_Cutscene_PlaySfxRumbling  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when something big and heavy is rising from
;;; the ground.
;;; @param A The number of frames to play the sound for.
;;; @preserve T0+
.EXPORT FuncA_Cutscene_PlaySfxRumbling
.PROC FuncA_Cutscene_PlaySfxRumbling
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte  ; frames
    ldya #Data_Rumbling_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Starts playing the sound for when a breaker device rises from the floor.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxBreakerRising
.PROC FuncA_Room_PlaySfxBreakerRising
    lda #kBreakerRisingDeviceAnimStart
    fall FuncA_Room_PlaySfxRumbling  ; preserves T0+
.ENDPROC

;;; Starts playing the sound for when something big and heavy is rising from
;;; the ground.
;;; @param A The number of frames to play the sound for.
;;; @preserve T0+
.EXPORT FuncA_Room_PlaySfxRumbling
.PROC FuncA_Room_PlaySfxRumbling
    sta Zp_Next_sChanSfx_arr + eChan::Noise + sChanSfx::Param1_byte  ; frames
    ldya #Data_Rumbling_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
