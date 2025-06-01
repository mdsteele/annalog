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
.INCLUDE "cpu.inc"
.INCLUDE "inst.inc"
.INCLUDE "macros.inc"
.INCLUDE "music.inc"

.IMPORT Ram_Audio_sChanCtrl_arr
.IMPORT Ram_Audio_sChanNote_arr
.IMPORTZP Zp_AudioTmp_byte
.IMPORTZP Zp_AudioTmp_ptr
.IMPORTZP Zp_Current_bAudio

;;;=========================================================================;;;

;;; Ensure that all the eInst values fit in the bNote instrument mask.
.ASSERT eInst::NUM_VALUES <= bNote::InstMask + 1, error

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Maps from eInst enum values to instrument function pointers.  Each
;;; instrument function returns the envelope byte to set (not taking master
;;; volume into account), and can optionally update other APU registers for
;;; the channel.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.REPEAT 2, table
    D_TABLE_LO table, Data_Instruments_func_ptr_0_arr
    D_TABLE_HI table, Data_Instruments_func_ptr_1_arr
    D_TABLE .enum, eInst
    d_entry table, Constant,        Func_InstrumentConstant
    d_entry table, NoiseSnare,      Func_InstrumentNoiseSnare
    d_entry table, PulseBasic,      Func_InstrumentPulseBasic
    d_entry table, PulseEcho,       Func_InstrumentPulseEcho
    d_entry table, PulsePiano,      Func_InstrumentPulsePiano
    d_entry table, PulsePluck,      Func_InstrumentPulsePluck
    d_entry table, PulseVibrato,    Func_InstrumentPulseVibrato
    d_entry table, PulseViolin,     Func_InstrumentPulseViolin
    d_entry table, Staccato,        Func_InstrumentStaccato
    d_entry table, TriangleDrum,    Func_InstrumentTriangleDrum
    d_entry table, TriangleQuiver,  Func_InstrumentTriangleQuiver
    d_entry table, TriangleSlide,   Func_InstrumentTriangleSlide
    d_entry table, TriangleVibrato, Func_InstrumentTriangleVibrato
    D_END
.ENDREPEAT

;;; An instrument for the pulse channels that applies vibrato, as well as the
;;; same duty/envelope characteristics as the PulseBasic instrument.  The
;;; instrument param works the same as for PulseBasic.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulseVibrato
_Vibrato:
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    mod #8
    tay
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    add Data_VibratoDelta_i16_0_arr8, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    ;; Note that we intentionally *don't* carry the addition over into TimerHi
    ;; here, because for pulse channels, writing to the TimerHi register resets
    ;; the pulse phase, which adds an undesirable clicking noise (see
    ;; https://www.nesdev.org/wiki/APU).  As long as we avoid using this
    ;; instrument for pitches right next to a TimerLo carry boundary, then
    ;; TimerHi wouldn't change anyway, and everything will sound fine.
_Envelope:
    fall Func_InstrumentPulseBasic  ; preserves X
.ENDPROC

;;; A basic instrument for the pulse channels.  The bottom four bits of the
;;; instrument param specify the max volume, which fades out at the end of the
;;; note.  The top two bits of the instrument param specify the pulse duty.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulseBasic
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    and #bEnvelope::VolMask
    sta Zp_AudioTmp_byte  ; max volume
    lda Ram_Audio_sChanNote_arr + sChanNote::DurationFrames_u8, x
    sub Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    mul #2
    bcs @useMaxVolume
    cmp Zp_AudioTmp_byte  ; max volume
    blt Func_CombineVolumeWithDuty
    @useMaxVolume:
    lda Zp_AudioTmp_byte  ; max volume
    bpl Func_CombineVolumeWithDuty  ; unconditional
.ENDPROC

;;; An instrument for the pulse channels that plays briefly at full volume,
;;; then cuts to half volume for the rest of the note.  The bottom four bits of
;;; the instrument param specify the initial volume.  The top two bits of the
;;; instrument param specify the pulse duty.  Bits 4 and 5 control the duration
;;; of the full-volume portion of the note.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulseEcho
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    and #bEnvelope::VolMask
    tay  ; max volume
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    and #%00110000
    ora #%00001100
    div #4
    cmp Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    blt _Quiet
_Loud:
    tya  ; max volume
    bpl Func_CombineVolumeWithDuty  ; unconditional
_Quiet:
    tya  ; max volume
    div #2
    bpl Func_CombineVolumeWithDuty  ; unconditional
.ENDPROC

;;; An instrument for the pulse channels that makes a plucking sound.  The
;;; bottom four bits of the instrument param specify the max volume, which
;;; fades out over time.  The top two bits of the instrument param specify the
;;; pulse duty after the initial pluck.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulsePluck
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    and #bEnvelope::VolMask
    sta Zp_AudioTmp_byte  ; max volume
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    cmp #2
    bge _Decay
_Pluck:
    lda Zp_AudioTmp_byte  ; max volume
    ora #bEnvelope::Duty12 | bEnvelope::NoLength | bEnvelope::ConstVol
    rts
_Decay:
    div #2
    rsub Zp_AudioTmp_byte  ; max volume
    blt Func_InstrumentSilent
    fall Func_CombineVolumeWithDuty  ; preserves X
.ENDPROC

;;; Combines the given volume value with the pulse duty bits from the
;;; instrument param to produce a final duty/envelope byte.
;;; @thread AUDIO
;;; @param A The volume value (0-15).
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_CombineVolumeWithDuty
    bit Zp_Current_bAudio
    .assert bAudio::ReduceMusic = bProc::Overflow, error
    bvc @noReduce
    div #2
    @noReduce:
    sta Zp_AudioTmp_byte  ; volume
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    and #bEnvelope::DutyMask
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    ora Zp_AudioTmp_byte  ; volume
    rts
.ENDPROC

;;; An instrument that ramps up volume quickly, then decays slowly, all with
;;; slight vibrato.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulsePiano
_Vibrato:
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    mod #4
    tay
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    add Data_SlightVibratoDelta_i16_0_arr4, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    ;; Note that we intentionally *don't* carry the addition over into TimerHi
    ;; here, because for pulse channels, writing to the TimerHi register resets
    ;; the pulse phase, which adds an undesirable clicking noise (see
    ;; https://www.nesdev.org/wiki/APU).  As long as we avoid using this
    ;; instrument for pitches right next to a TimerLo carry boundary, then
    ;; TimerHi wouldn't change anyway, and everything will sound fine.
_Envelope:
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    and #bEnvelope::VolMask
    sta Zp_AudioTmp_byte  ; max volume
    div #2
    rsub Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    bge @decay
    @attack:
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    sec
    rol a
    bne Func_CombineVolumeWithDuty  ; unconditional
    @decay:
    div #8
    rsub Zp_AudioTmp_byte  ; max volume
    blt Func_InstrumentSilent
    bge Func_CombineVolumeWithDuty  ; unconditional
.ENDPROC

;;; An instrument for the pulse and noise channels.  The bottom four bits of
;;; the instrument param specify the initial volume, which starts fading out
;;; immediately.  The top four bits of the instrument param specify a delta to
;;; add to the noise period (mod 16) after the initial hit.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentNoiseSnare
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    cmp #2
    bne @done
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    div #$10
    add Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    mod #$10
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    @done:
    fall Func_InstrumentStaccato  ; preserves X
.ENDPROC

;;; An instrument for the pulse and noise channels.  The bottom four bits of
;;; the instrument param specify the initial volume, which starts fading out
;;; immediately.  The top two bits of the instrument param specify the pulse
;;; duty (ignored for the noise channel).
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentStaccato
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    and #bEnvelope::VolMask
    sub Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    bge Func_CombineVolumeWithDuty
    fall Func_InstrumentSilent  ; preserves X
.ENDPROC

;;; An instrument for the pulse and noise channels that silences the channel.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentSilent
    lda #bEnvelope::NoLength | bEnvelope::ConstVol
    rts
.ENDPROC

;;; An instrument that ramps up volume slowly, then decays slowly near the end
;;; of the note, all with deep vibrato.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulseViolin
_Vibrato:
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    mod #8
    tay
    lda Data_VibratoDelta_i16_0_arr8, y
    mul #2
    add Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    ;; Note that we intentionally *don't* carry the addition over into TimerHi
    ;; here, because for pulse channels, writing to the TimerHi register resets
    ;; the pulse phase, which adds an undesirable clicking noise (see
    ;; https://www.nesdev.org/wiki/APU).  As long as we avoid using this
    ;; instrument for pitches right next to a TimerLo carry boundary, then
    ;; TimerHi wouldn't change anyway, and everything will sound fine.
_Envelope:
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    and #bEnvelope::VolMask
    sta Zp_AudioTmp_byte  ; max volume
    ;; Attack:
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    div #16
    cmp Zp_AudioTmp_byte  ; max volume
    blt @setVol
    ;; Decay:
    lda Ram_Audio_sChanNote_arr + sChanNote::DurationFrames_u8, x
    sub Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    div #16
    cmp Zp_AudioTmp_byte  ; max volume
    blt @setVol
    ;; Sustain:
    lda Zp_AudioTmp_byte  ; max volume
    @setVol:
    jmp Func_CombineVolumeWithDuty
.ENDPROC

;;; An instrument for the triangle channel that applies slight vibrato.  The
;;; instrument param is ignored.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentTriangleQuiver
_Vibrato:
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    mod #4
    tay
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    add Data_SlightVibratoDelta_i16_0_arr4, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerHi_byte, x
    adc Data_SlightVibratoDelta_i16_1_arr4, y
    and #$07
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
_Envelope:
    lda #$ff
    rts
.ENDPROC

;;; A table of timer deltas to apply to instruments with vibrato, looped over
;;; an eight-frame period.
.PROC Data_VibratoDelta_i16_0_arr8
    .byte <0, <2, <3, <2, <0, <-2, <-3, <-2
.ENDPROC
.PROC Data_VibratoDelta_i16_1_arr8
    .byte >0, >2, >3, >2, >0, >-2, >-3, >-2
.ENDPROC

;;; A table of timer deltas to apply to instruments with slight vibrato, looped
;;; over a four-frame period.
.PROC Data_SlightVibratoDelta_i16_0_arr4
    .byte <0, <1, <0, <-1
.ENDPROC
.PROC Data_SlightVibratoDelta_i16_1_arr4
    .byte >0, >1, >0, >-1
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_InstSample"

.EXPORT Data_SampleKickDrum_arr657
.PROC Data_SampleKickDrum_arr657
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/inst_kick.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC
.ASSERT .sizeof(Data_SampleKickDrum_arr657) = 657, error

;;; We have some space before the next sample can begin, room enough for some
;;; other data.
SampleGap1:
kSampleGap1Size = kDmcSampleAlign - (* .mod kDmcSampleAlign)

;;; Calls the current instrument function for the specified music channel.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.EXPORT Func_AudioCallInstrument
.PROC Func_AudioCallInstrument
    ldy Ram_Audio_sChanCtrl_arr + sChanCtrl::Instrument_eInst, x
    lda Data_Instruments_func_ptr_0_arr, y
    sta Zp_AudioTmp_ptr + 0
    lda Data_Instruments_func_ptr_1_arr, y
    sta Zp_AudioTmp_ptr + 1
    jmp (Zp_AudioTmp_ptr)
.ENDPROC

;;; An instrument for playing bass drum sounds on the triangle channel.  Each
;;; frame, this increases the timer value (thus lowering the frequency) by the
;;; instrument param.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentTriangleDrum
_Pitch:
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    add Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    sta Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerHi_byte, x
    adc #0
    and #$07
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    sta Ram_Audio_sChanNote_arr + sChanNote::TimerHi_byte, x
_Envelope:
    lda #$ff
    rts
.ENDPROC

;;; Align to the next sample, and make sure we didn't overshoot the gap.
.ALIGN kDmcSampleAlign
.ASSERT * - SampleGap1 = kSampleGap1Size, error

.GLOBAL Data_SampleBongo_arr193
.PROC Data_SampleBongo_arr193
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/inst_bongo.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC
.ASSERT .sizeof(Data_SampleBongo_arr193) = 193, error

;;; We have some space before the next sample can begin, room enough for some
;;; other data.
SampleGap2:
kSampleGap2Size = kDmcSampleAlign - (* .mod kDmcSampleAlign)

;;; An instrument that sets a constant duty/envelope byte.  This is the default
;;; instrument for music channels that don't specify one.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentConstant
    lda Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    rts
.ENDPROC

;;; An instrument for the triangle channel that slides down in pitch with
;;; vibrato.  The instrument param is ignored.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentTriangleSlide
_Slide:
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    and #$01
    beq @done
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    add #1
    sta Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerHi_byte, x
    adc #0
    and #$07
    sta Ram_Audio_sChanNote_arr + sChanNote::TimerHi_byte, x
    @done:
_Vibrato:
    fall Func_InstrumentTriangleVibrato  ; preserves X
.ENDPROC

;;; An instrument for the triangle channel that applies vibrato.  The
;;; instrument param is ignored.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentTriangleVibrato
_Vibrato:
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    mod #8
    tay
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    add Data_VibratoDelta_i16_0_arr8, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda Ram_Audio_sChanNote_arr + sChanNote::TimerHi_byte, x
    adc Data_VibratoDelta_i16_1_arr8, y
    and #$07
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
_Envelope:
    lda #$ff
    rts
.ENDPROC

;;; Align to the next sample, and make sure we didn't overshoot the gap.
.ALIGN kDmcSampleAlign
.ASSERT * - SampleGap2 = kSampleGap2Size, error

.GLOBAL Data_SampleAnvil_arr881
.PROC Data_SampleAnvil_arr881
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/inst_anvil.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC
.ASSERT .sizeof(Data_SampleAnvil_arr881) = 881, error

;;;=========================================================================;;;
