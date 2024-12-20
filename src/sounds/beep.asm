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
.IMPORT Func_PlaySfxOnPulse1Channel
.IMPORT Func_PlaySfxOnPulse2Channel
.IMPORT Ram_Audio_sChanSfx_arr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

;;; The envelope flags (not including the volume nibble) to use in
;;; Data_Trombone_sSfx.
.LINECONT +
kTromboneEnvFlags = \
    bEnvelope::Duty18 | bEnvelope::NoLength | bEnvelope::ConstVol
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX data for the "beep" sound effect.
.PROC Data_Beep_sSfx
    sfx_SetEnvSweep bEnvelope::Duty12 | bEnvelope::NoLength | 3, kNoSweep
    sfx_Func Func_InitializeSfxBeepTimer
    sfx_Wait 15
    sfx_End
.ENDPROC

;;; SFX data for the "hi-hat" sound effect.
.PROC Data_HiHat_sSfx
    ;; TODO: Improve the hi-hat sound.
    sfx_SetEnvTimer bEnvelope::NoLength | 1, $0001
    sfx_Wait 3
    sfx_End
.ENDPROC

;;; SFX data for the "organ" sound effect.
.PROC Data_Organ_sSfx
    sfx_SetEnv $ff
    sfx_Func Func_InitializeSfxBeepTimer
    sfx_Wait 15
    sfx_End
.ENDPROC

;;; SFX data for the "trombone" sound effect.
.PROC Data_Trombone_sSfx
    sfx_SetEnvSweep kTromboneEnvFlags | 4, kNoSweep
    sfx_Func Func_InitializeSfxBeepTimer
    sfx_Wait 1
    sfx_SetEnv kTromboneEnvFlags | 8
    sfx_Wait 1
    sfx_SetEnv kTromboneEnvFlags | 12
    sfx_Wait 10
    sfx_SetEnv kTromboneEnvFlags | 8
    sfx_Wait 2
    sfx_SetEnv kTromboneEnvFlags | 4
    sfx_Wait 2
    sfx_End
.ENDPROC

;;; Sets the APU timer registers for the specified channel, using the tone
;;; value (0-9) stored in sChanSfx::Param1_byte to select one of the notes from
;;; Data_SfxBeepTimer*_u8_arr10.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @preserve X, T0+
.PROC Func_InitializeSfxBeepTimer
    ldy Ram_Audio_sChanSfx_arr + sChanSfx::Param1_byte, x  ; tone
    lda Data_SfxBeepTimerLo_u8_arr10, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda Data_SfxBeepTimerHi_u8_arr10, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    sec  ; set C to indicate that the function is finished
    rts
.ENDPROC

;;; These values represent the ten natural notes from A3 through C5.
.PROC Data_SfxBeepTimerLo_u8_arr10
    .byte $fb, $c4, $ab, $7c, $52, $3f, $1c, $fd, $e1, $d5
.ENDPROC
.PROC Data_SfxBeepTimerHi_u8_arr10
    .byte $01, $01, $01, $01, $01, $01, $01, $00, $00, $00
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

;;; Starts playing a sound for a drum machine's hi-hat.
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxHiHat
.PROC FuncA_Machine_PlaySfxHiHat
    ldya #Data_HiHat_sSfx
    jmp Func_PlaySfxOnNoiseChannel  ; preserves T0+
.ENDPROC

;;; Starts playing a sound for an organ machine's ACT opcode.
;;; @param A The tone number (0-9).
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxOrgan
.PROC FuncA_Machine_PlaySfxOrgan
    sta Zp_Next_sChanSfx_arr + eChan::Triangle + sChanSfx::Param1_byte  ; tone
    ldya #Data_Organ_sSfx
    stya Zp_Next_sChanSfx_arr + eChan::Triangle + sChanSfx::NextOp_sSfx_ptr
    rts
.ENDPROC

;;; Starts playing a sound for a trombone machine's ACT opcode.
;;; @param A The tone number (0-9).
;;; @preserve T0+
.EXPORT FuncA_Machine_PlaySfxTrombone
.PROC FuncA_Machine_PlaySfxTrombone
    sta Zp_Next_sChanSfx_arr + eChan::Pulse1 + sChanSfx::Param1_byte  ; tone
    ldya #Data_Trombone_sSfx
    jmp Func_PlaySfxOnPulse1Channel  ; preserves T0+
.ENDPROC

;;;=========================================================================;;;
