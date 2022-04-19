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

.INCLUDE "../src/apu.inc"
.INCLUDE "../src/audio.inc"
.INCLUDE "../src/macros.inc"

.IMPORT Data_EmptyChain_u8_arr
.IMPORT Exit_Success
.IMPORT Func_AudioReset
.IMPORT Func_AudioSync
.IMPORT Func_AudioUpdate
.IMPORT Func_ExpectAEqualsY
.IMPORTZP Zp_Next_sAudioCtrl

;;;=========================================================================;;;

.LINECONT +
Hw_Pulse1TimerLo_wo = Hw_Channels_sChanRegs_arr5 + \
    .sizeof(sChanRegs) * 0 + sChanRegs::TimerLo_wo
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "APU"

.ASSERT * = Hw_Channels_sChanRegs_arr5, error
.RES $20
.ASSERT * > Hw_Channels_sChanRegs_arr5 + .sizeof(sChanRegs) * 5, error
.ASSERT * > Hw_ApuStatus_rw, error
.ASSERT * > Hw_ApuCount_wo, error

;;;=========================================================================;;;

.PROC Data_Test_sMusic
    D_STRUCT sMusic
    d_addr Opcodes_bMusic_arr_ptr, _Opcodes_bMusic_arr
    d_addr Instruments_sInstrument_ptr_arr_ptr, 0
    d_addr Parts_sPart_arr_ptr, _Parts_sPart_arr
    d_addr Phrases_sPhrase_ptr_arr_ptr, _Phrases_sPhrase_ptr_arr
    D_END
_Opcodes_bMusic_arr:
    .byte bMusic::JumpMask & 2  ; JUMP +2
    .byte bMusic::UsesFlag | bMusic::FlagMask  ; SETF 1
    .byte bMusic::IsPlay | 0  ; PLAY 0
    .byte bMusic::IsPlay | 1  ; PLAY 1
    .byte bMusic::UsesFlag | (bMusic::JumpMask & -3)  ; BFEQ 0, -3
    .byte $00  ; STOP
_Parts_sPart_arr:
    ;; Part 0:
    D_STRUCT sPart
    d_addr Chain1_u8_arr_ptr, _Chain0_u8_arr
    d_addr Chain2_u8_arr_ptr, Data_EmptyChain_u8_arr
    d_addr ChainT_u8_arr_ptr, Data_EmptyChain_u8_arr
    d_addr ChainN_u8_arr_ptr, Data_EmptyChain_u8_arr
    d_addr ChainD_u8_arr_ptr, Data_EmptyChain_u8_arr
    D_END
    ;; Part 1:
    D_STRUCT sPart
    d_addr Chain1_u8_arr_ptr, _Chain1_u8_arr
    d_addr Chain2_u8_arr_ptr, Data_EmptyChain_u8_arr
    d_addr ChainT_u8_arr_ptr, Data_EmptyChain_u8_arr
    d_addr ChainN_u8_arr_ptr, Data_EmptyChain_u8_arr
    d_addr ChainD_u8_arr_ptr, Data_EmptyChain_u8_arr
    D_END
_Chain0_u8_arr:
    .byte 0
    .byte $ff  ; end-of-chain
_Chain1_u8_arr:
    .byte 1
    .byte $ff  ; end-of-chain
_Phrases_sPhrase_ptr_arr:
    .addr _Phrase0_sPhrase
    .addr _Phrase1_sPhrase
_Phrase0_sPhrase:
    .byte $c0, $aa, 0  ; TONE
    .byte $00  ; DONE
_Phrase1_sPhrase:
    .byte $c0, $bb, 0  ; TONE
    .byte $00  ; DONE
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
ResetAudio:
    jsr Func_AudioReset
    lda Hw_ApuCount_wo
    ldy #bApuCount::DisableIrq
    jsr Func_ExpectAEqualsY
    lda Hw_ApuStatus_rw
    ldy #$00
    jsr Func_ExpectAEqualsY
EnableAndStartMusic:
    lda #$ff
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::Enable_bool)
    lda #$0f
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::MasterVolume_u4)
    lda #bMusic::UsesFlag
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::MusicFlag_bMusic)
    ldax #Data_Test_sMusic
    stax <(Zp_Next_sAudioCtrl + sAudioCtrl::Song_sMusic_ptr)
    jsr Func_AudioSync
PlayMusic:
    ;; First frame:
    jsr Func_AudioUpdate
    lda Hw_ApuStatus_rw
    ldy #bApuStatus::Pulse1
    jsr Func_ExpectAEqualsY
    lda Hw_Pulse1TimerLo_wo
    ldy #$aa
    jsr Func_ExpectAEqualsY
    ;; Second frame:
    jsr Func_AudioUpdate
    lda Hw_ApuStatus_rw
    ldy #bApuStatus::Pulse1
    jsr Func_ExpectAEqualsY
    lda Hw_Pulse1TimerLo_wo
    ldy #$bb
    jsr Func_ExpectAEqualsY
    ;; Third frame:
    jsr Func_AudioUpdate
    lda Hw_ApuStatus_rw
    ldy #bApuStatus::Pulse1
    jsr Func_ExpectAEqualsY
    lda Hw_Pulse1TimerLo_wo
    ldy #$aa
    jsr Func_ExpectAEqualsY
    ;; Fourth frame:
    jsr Func_AudioUpdate
    lda Hw_ApuStatus_rw
    ldy #bApuStatus::Pulse1
    jsr Func_ExpectAEqualsY
    lda Hw_Pulse1TimerLo_wo
    ldy #$bb
    jsr Func_ExpectAEqualsY
    ;; Fifth frame:
    jsr Func_AudioUpdate
    lda Hw_ApuStatus_rw
    ldy #0
    jsr Func_ExpectAEqualsY
DisableAudio:
    lda #$00
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::Enable_bool)
    jsr Func_AudioSync
    lda Hw_ApuStatus_rw
    ldy #0
    jsr Func_ExpectAEqualsY
    jmp Exit_Success

;;;=========================================================================;;;
