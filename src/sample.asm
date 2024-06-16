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

.IMPORT Data_SampleKickDrum_arr657
.IMPORT Ram_Sound_sChanSfx_arr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRGE_SfxSample"

;;; Delta modulated sample data for eSample::Boss*.
.PROC Data_SampleBoss_arr
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/sfx_boss.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC

;;; We have some space before the next sample can begin, room enough for some
;;; other data.
SampleGap1:
kSampleGap1Size = kDmcSampleAlign - (* .mod kDmcSampleAlign)

;;; The DMC sample rate (0-$f) to use for each sample.
.PROC Data_SampleRate_u8_arr
    D_ARRAY .enum, eSample
    d_byte BossRoar1,  $1
    d_byte BossRoar2,  $2
    d_byte BossRoar3,  $3
    d_byte BossRoar4,  $4
    d_byte BossRoar5,  $5
    d_byte BossRoar6,  $6
    d_byte BossRoar7,  $7
    d_byte BossRoar8,  $8
    d_byte BossHurtD,  $d
    d_byte BossHurtE,  $e
    d_byte BossHurtF,  $f
    d_byte Harm,       $e
    d_byte JumpAnna,   $f
    d_byte JumpGronta, $e
    d_byte KickDrum,   $e
    D_END
.ENDPROC

;;; The encoded start address for each sample.
.PROC Data_SampleStart_u8_arr
    D_ARRAY .enum, eSample
    d_byte BossRoar1,  <(Data_SampleBoss_arr >> 6)
    d_byte BossRoar2,  <(Data_SampleBoss_arr >> 6)
    d_byte BossRoar3,  <(Data_SampleBoss_arr >> 6)
    d_byte BossRoar4,  <(Data_SampleBoss_arr >> 6)
    d_byte BossRoar5,  <(Data_SampleBoss_arr >> 6)
    d_byte BossRoar6,  <(Data_SampleBoss_arr >> 6)
    d_byte BossRoar7,  <(Data_SampleBoss_arr >> 6)
    d_byte BossRoar8,  <(Data_SampleBoss_arr >> 6)
    d_byte BossHurtD,  <(Data_SampleBoss_arr >> 6)
    d_byte BossHurtE,  <(Data_SampleBoss_arr >> 6)
    d_byte BossHurtF,  <(Data_SampleBoss_arr >> 6)
    d_byte Harm,       <(Data_SampleHarm_arr >> 6)
    d_byte JumpAnna,   <(Data_SampleJump_arr >> 6)
    d_byte JumpGronta, <(Data_SampleJump_arr >> 6)
    d_byte KickDrum,   <(Data_SampleKickDrum_arr657 >> 6)
    D_END
.ENDPROC

;;; Align to the next sample, and make sure we didn't overshoot the gap.
.ALIGN kDmcSampleAlign
.ASSERT * - SampleGap1 = kSampleGap1Size, error

;;; Delta modulated sample data for eSample::Harm.
.PROC Data_SampleHarm_arr
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/sfx_harm.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC

;;; We have some space before the next sample can begin, room enough for a
;;; function.
SampleGap2:
kSampleGap2Size = kDmcSampleAlign - (* .mod kDmcSampleAlign)

;;; Starts playing a delta modulated sample sound effect on the DMC.
;;; @param A The eSample value for the sample to play.
;;; @preserve X, Y, T0+
.EXPORT Func_PlaySfxSample
.PROC Func_PlaySfxSample
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::Param1_byte
    lda #0
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::Timer_u8
    lda #eSound::Sample
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::Sfx_eSound
    rts
.ENDPROC

;;; Align to the next sample, and make sure we didn't overshoot the gap.
.ALIGN kDmcSampleAlign
.ASSERT * - SampleGap2 = kSampleGap2Size, error

;;; Delta modulated sample data for eSample::Jump.
.PROC Data_SampleJump_arr
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/sfx_jump.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; The encoded byte length for each sample.
.PROC Data_SampleLength_u8_arr
    D_ARRAY .enum, eSample
    d_byte BossRoar1,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossRoar2,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossRoar3,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossRoar4,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossRoar5,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossRoar6,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossRoar7,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossRoar8,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossHurtD,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossHurtE,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossHurtF,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte Harm,       .sizeof(Data_SampleHarm_arr) >> 4
    d_byte JumpAnna,   .sizeof(Data_SampleJump_arr) >> 4
    d_byte JumpGronta, .sizeof(Data_SampleJump_arr) >> 4
    d_byte KickDrum,   657 >> 4
    D_END
.ENDPROC

;;; The number of frames to play each sample for.
.PROC Data_SampleFrames_u8_arr
    D_ARRAY .enum, eSample
    d_byte BossRoar1, 127
    d_byte BossRoar2, 117
    d_byte BossRoar3, 110
    d_byte BossRoar4,  98
    d_byte BossRoar5,  88
    d_byte BossRoar6,  77
    d_byte BossRoar7,  72
    d_byte BossRoar8,  65
    d_byte BossHurtD,  29
    d_byte BossHurtE,  24
    d_byte BossHurtF,  19
    d_byte Harm,        5
    d_byte JumpAnna,    9
    d_byte JumpGronta, 12
    d_byte KickDrum,   13
    D_END
.ENDPROC

;;; SFX function for playing delta modulated samples on the DMC.  When starting
;;; this sound, Param1_byte should hold the eSample value, and Timer_u8 should
;;; be initialized to zero.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
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

;;;=========================================================================;;;
