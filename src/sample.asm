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

.INCLUDE "apu.inc"
.INCLUDE "audio.inc"
.INCLUDE "macros.inc"
.INCLUDE "sample.inc"
.INCLUDE "sound.inc"

.IMPORT Ram_Sound_sChanSfx_arr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRGE_Sample"

;;; Delta modulated sample data for eSample::Harm.
.ALIGN kDmcSampleAlign
.PROC Data_SampleHarm_arr
:   .incbin "out/data/samples/harm.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC

;;; Delta modulated sample data for eSample::Jump.
.ALIGN kDmcSampleAlign
.PROC Data_SampleJump_arr
:   .incbin "out/data/samples/jump.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; The DMC sample rate (0-$f) to use for each sample.
.PROC Data_SampleRate_u8_arr
    D_ENUM eSample
    d_byte Harm, $e
    d_byte Jump, $f
    D_END
.ENDPROC

;;; The encoded start address for each sample.
.PROC Data_SampleStart_u8_arr
    D_ENUM eSample
    d_byte Harm, <(Data_SampleHarm_arr >> 6)
    d_byte Jump, <(Data_SampleJump_arr >> 6)
    D_END
.ENDPROC

;;; The encoded byte length for each sample.
.PROC Data_SampleLength_u8_arr
    D_ENUM eSample
    d_byte Harm, .sizeof(Data_SampleHarm_arr) >> 4
    d_byte Jump, .sizeof(Data_SampleJump_arr) >> 4
    D_END
.ENDPROC

;;; The number of frames to play each sample for.
.PROC Data_SampleFrames_u8_arr
    D_ENUM eSample
    d_byte Harm, 5
    d_byte Jump, 9
    D_END
.ENDPROC

;;; SFX function for playing delta modulated samples on the DMC.  When starting
;;; this sound, Param1_byte should hold the eSample value, and Timer_u8 should
;;; be initialized to zero.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X
.EXPORT Func_SfxSample
.PROC Func_SfxSample
    ldy Ram_Sound_sChanSfx_arr + sChanSfx::Param1_byte, x
    lda Ram_Sound_sChanSfx_arr + sChanSfx::Timer_u8, x
    beq _Initialize
    cmp Data_SampleFrames_u8_arr, y
    blt _Continue
    sec  ; set C to indicate that the sound is finished
    rts
_Initialize:
    lda Data_SampleRate_u8_arr, y
    sta Hw_DmcFlags_wo
    lda #$40
    sta Hw_DmcLevel_wo
    lda Data_SampleStart_u8_arr, y
    sta Hw_DmcSampleStart_wo
    lda Data_SampleLength_u8_arr, y
    sta Hw_DmcSampleLength_wo
_Continue:
    inc Ram_Sound_sChanSfx_arr + sChanSfx::Timer_u8, x
    clc  ; clear C to indicate that the sound is still going
    rts
.ENDPROC

;;; Starts playing a delta modulated sample sound effect on the DMC.
;;; @param A The eSample value for the sample to play.
;;; @preserve X, Y, Zp_Tmp*
.EXPORT Func_PlaySfxSample
.PROC Func_PlaySfxSample
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::Param1_byte
    lda #0
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::Timer_u8
    lda #eSound::Sample
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::Sfx_eSound
    rts
.ENDPROC

;;;=========================================================================;;;
