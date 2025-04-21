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

.IMPORT Data_SampleAnvil_arr881
.IMPORT Data_SampleKickDrum_arr657
.IMPORT Ram_Audio_sChanSfx_arr
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
    d_byte AnvilD,     $d
    d_byte AnvilE,     $e
    d_byte AnvilF,     $f
    d_byte BossRoar7,  $7
    d_byte BossRoar8,  $8
    d_byte BossHurtD,  $d
    d_byte BossHurtE,  $e
    d_byte BossHurtF,  $f
    d_byte Death,      $e
    d_byte Harm,       $e
    d_byte JumpAnna,   $f
    d_byte JumpGronta, $e
    d_byte KickDrum,   $e
    D_END
.ENDPROC

;;; The number of frames to play each sample for.  In general, this should be:
;;;   floor(num_bytes * 8 * 60 / samples_per_second)
;;; See https://www.nesdev.org/wiki/APU_DMC for the samples_per_second values.
.PROC Data_SampleFrames_u8_arr
    D_ARRAY .enum, eSample
    d_byte AnvilD,     19
    d_byte AnvilE,     17
    d_byte AnvilF,     12
    d_byte BossRoar7,  72
    d_byte BossRoar8,  65
    d_byte BossHurtD,  29
    d_byte BossHurtE,  24
    d_byte BossHurtF,  19
    d_byte Death,      17
    d_byte Harm,        5
    d_byte JumpAnna,    9
    d_byte JumpGronta, 12
    d_byte KickDrum,   13
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
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::Param1_byte  ; eSample
    lda #<Data_Sample_sSfx
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::NextOp_sSfx_ptr + 0
    lda #>Data_Sample_sSfx
    sta Zp_Next_sChanSfx_arr + eChan::Dmc + sChanSfx::NextOp_sSfx_ptr + 1
    rts
.ENDPROC

;;; Align to the next sample, and make sure we didn't overshoot the gap.
.ALIGN kDmcSampleAlign
.ASSERT * - SampleGap2 = kSampleGap2Size, error

;;; Delta modulated sample data for eSample::Jump*.
.PROC Data_SampleJump_arr
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/sfx_jump.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC

;;; We have some space before the next sample can begin, room enough for a
;;; function.
SampleGap3:
kSampleGap3Size = kDmcSampleAlign - (* .mod kDmcSampleAlign)

;;; @thread AUDIO
.PROC Data_Sample_sSfx
    sfx_Func _Initialize
    sfx_Func _Wait
    sfx_End
_Initialize:
    ldy Ram_Audio_sChanSfx_arr + eChan::Dmc + sChanSfx::Param1_byte  ; eSample
    lda Data_SampleRate_u8_arr, y
    sta Hw_DmcFlags_wo
    lda #$40
    sta Hw_DmcLevel_wo
    lda Data_SampleStart_u8_arr, y
    sta Hw_DmcSampleStart_wo
    lda Data_SampleLength_u8_arr, y
    sta Hw_DmcSampleLength_wo
    sec  ; set C to indicate that the function is finished
    rts
_Wait:
    tya  ; repeat count
    ldy Ram_Audio_sChanSfx_arr + eChan::Dmc + sChanSfx::Param1_byte  ; eSample
    cmp Data_SampleFrames_u8_arr, y
    rts
.ENDPROC

;;; Align to the next sample, and make sure we didn't overshoot the gap.
.ALIGN kDmcSampleAlign
.ASSERT * - SampleGap3 = kSampleGap3Size, error

;;; Delta modulated sample data for eSample::Death.
.PROC Data_SampleDeath_arr
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/sfx_death.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; The encoded start address for each sample.
.PROC Data_SampleStart_u8_arr
    D_ARRAY .enum, eSample
    d_byte AnvilD,     <(Data_SampleAnvil_arr881 >> 6)
    d_byte AnvilE,     <(Data_SampleAnvil_arr881 >> 6)
    d_byte AnvilF,     <(Data_SampleAnvil_arr881 >> 6)
    d_byte BossRoar7,  <(Data_SampleBoss_arr >> 6)
    d_byte BossRoar8,  <(Data_SampleBoss_arr >> 6)
    d_byte BossHurtD,  <(Data_SampleBoss_arr >> 6)
    d_byte BossHurtE,  <(Data_SampleBoss_arr >> 6)
    d_byte BossHurtF,  <(Data_SampleBoss_arr >> 6)
    d_byte Death,      <(Data_SampleDeath_arr >> 6)
    d_byte Harm,       <(Data_SampleHarm_arr >> 6)
    d_byte JumpAnna,   <(Data_SampleJump_arr >> 6)
    d_byte JumpGronta, <(Data_SampleJump_arr >> 6)
    d_byte KickDrum,   <(Data_SampleKickDrum_arr657 >> 6)
    D_END
.ENDPROC

;;; The encoded byte length for each sample.
.PROC Data_SampleLength_u8_arr
    D_ARRAY .enum, eSample
    d_byte AnvilD,     881 >> 4
    d_byte AnvilE,     881 >> 4
    d_byte AnvilF,     881 >> 4
    d_byte BossRoar7,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossRoar8,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossHurtD,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossHurtE,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte BossHurtF,  .sizeof(Data_SampleBoss_arr) >> 4
    d_byte Death,      .sizeof(Data_SampleDeath_arr) >> 4
    d_byte Harm,       .sizeof(Data_SampleHarm_arr) >> 4
    d_byte JumpAnna,   .sizeof(Data_SampleJump_arr) >> 4
    d_byte JumpGronta, .sizeof(Data_SampleJump_arr) >> 4
    d_byte KickDrum,   657 >> 4
    D_END
.ENDPROC

;;;=========================================================================;;;
