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

.IMPORT Ram_Sound_sChanSfx_arr
.IMPORTZP Zp_AudioTmp1_byte
.IMPORTZP Zp_AudioTmp2_byte
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX function for playing sSfxSeq-based sound effects.  When starting this
;;; sound, Timer_u8 should be initialized to zero, and Param1_byte and
;;; Param2_byte should store the lo/hi bytes of the sSfxSeq_arr_ptr.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.EXPORT Func_SfxSequence
.PROC Func_SfxSequence
    lda Ram_Sound_sChanSfx_arr + sChanSfx::Timer_u8, x
    bne _ContinueSeqEntry
_StartSeqEntry:
    lda Ram_Sound_sChanSfx_arr + sChanSfx::Param1_byte, x
    sta Zp_AudioTmp1_byte
    lda Ram_Sound_sChanSfx_arr + sChanSfx::Param2_byte, x
    sta Zp_AudioTmp2_byte
    .assert Zp_AudioTmp1_byte + 1 = Zp_AudioTmp2_byte, error
    ldy #0
    ;; Read duration value.  If it's zero, the sound is done.  Otherwise, it
    ;; becomes the new Timer_u8 value.
    .assert sSfxSeq::Duration_u8 = 0, error
    lda (Zp_AudioTmp1_byte), y
    beq _SoundFinished
    iny
    sta Ram_Sound_sChanSfx_arr + sChanSfx::Timer_u8, x
    ;; Read envelope value and write it to the APU.
    .assert sSfxSeq::Env_bEnvelope = 1, error
    lda (Zp_AudioTmp1_byte), y
    iny
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    ;; Read sweep value and write it to the APU.
    .assert sSfxSeq::Sweep_byte = 2, error
    lda (Zp_AudioTmp1_byte), y
    iny
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Sweep_wo, x
    ;; Read timer value and write it to the APU.
    .assert sSfxSeq::Timer_u16 = 3, error
    lda (Zp_AudioTmp1_byte), y
    iny
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda (Zp_AudioTmp1_byte), y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    ;; Update the SFX params to point to the next sSfxSeq struct.
    .assert .sizeof(sSfxSeq) = 5, error
    tya  ; we skipped an INY, so Y is currently (.sizeof(sSfxSeq) - 1)
    sec  ; set carry to make up for the INY we skipped
    adc Zp_AudioTmp1_byte
    sta Ram_Sound_sChanSfx_arr + sChanSfx::Param1_byte, x
    lda #0
    adc Zp_AudioTmp2_byte
    sta Ram_Sound_sChanSfx_arr + sChanSfx::Param2_byte, x
_ContinueSeqEntry:
    dec Ram_Sound_sChanSfx_arr + sChanSfx::Timer_u8, x
    clc  ; clear C to indicate that the sound is still going
    rts
_SoundFinished:
    sec  ; set C to indicate that the sound is finished
    rts
.ENDPROC

;;; Starts playing a sSfxSeq-based sound effect.
;;; @param X The eChan value for channel to play the sound on.
;;; @param YA The sSfxSeq_arr_ptr value for the sequence.
;;; @preserve T0+
.EXPORT Func_PlaySfxSequence
.PROC Func_PlaySfxSequence
    sta Zp_Next_sChanSfx_arr + sChanSfx::Param1_byte, x
    sty Zp_Next_sChanSfx_arr + sChanSfx::Param2_byte, x
    lda #0
    sta Zp_Next_sChanSfx_arr + sChanSfx::Timer_u8, x
    lda #eSound::Sequence
    sta Zp_Next_sChanSfx_arr + sChanSfx::Sfx_eSound, x
    rts
.ENDPROC

;;;=========================================================================;;;
