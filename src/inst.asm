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
.INCLUDE "inst.inc"
.INCLUDE "macros.inc"
.INCLUDE "music.inc"

.IMPORT Ram_Music_sChanInst_arr
.IMPORT Ram_Music_sChanNote_arr
.IMPORTZP Zp_AudioTmp1_byte
.IMPORTZP Zp_AudioTmp2_byte

;;;=========================================================================;;;

;;; Ensure that all the eInst values fit in the bNote instrument mask.
.ASSERT eInst::NUM_VALUES <= bNote::InstMask + 1, error

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Calls the current instrument function for the specified music channel.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.EXPORT Func_AudioCallInstrument
.PROC Func_AudioCallInstrument
    ldy Ram_Music_sChanInst_arr + sChanInst::Instrument_eInst, x
    lda Data_Instruments_func_ptr_0_arr, y
    sta Zp_AudioTmp1_byte
    lda Data_Instruments_func_ptr_1_arr, y
    sta Zp_AudioTmp2_byte
    .assert Zp_AudioTmp1_byte + 1 = Zp_AudioTmp2_byte, error
    jmp (Zp_AudioTmp1_byte)
.ENDPROC

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
    d_entry table, PulseBasic,      Func_InstrumentPulseBasic
    d_entry table, PulseEcho,       Func_InstrumentPulseEcho
    d_entry table, PulsePiano,      Func_InstrumentPulsePiano
    d_entry table, PulsePluck,      Func_InstrumentPulsePluck
    d_entry table, PulseVibrato,    Func_InstrumentPulseVibrato
    d_entry table, RampUp,          Func_InstrumentRampUp
    d_entry table, Staccato,        Func_InstrumentStaccato
    d_entry table, TriangleDrum,    Func_InstrumentTriangleDrum
    d_entry table, TriangleSlide,   Func_InstrumentTriangleSlide
    d_entry table, TriangleVibrato, Func_InstrumentTriangleVibrato
    D_END
.ENDREPEAT

;;; An instrument that sets a constant duty/envelope byte.  This is the default
;;; instrument for music channels that don't specify one.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentConstant
    lda Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    rts
.ENDPROC

;;; An instrument for the pulse channels that applies vibrato, as well as the
;;; same duty/envelope characteristics as the PulseBasic instrument.  The
;;; instrument param works the same as for PulseBasic.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulseVibrato
_Vibrato:
    lda Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    and #$07
    tay
    lda Ram_Music_sChanNote_arr + sChanNote::TimerLo_byte, x
    add Data_VibratoDelta_i16_0_arr8, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    ;; Note that we intentionally *don't* carry the addition over into TimerHi
    ;; here, because for pulse channels, writing to the TimerHi register resets
    ;; the pulse phase, which adds an undesirable clicking noise (see
    ;; https://www.nesdev.org/wiki/APU).  As long as we avoid using this
    ;; instrument for pitches right next to a TimerLo carry boundary, then
    ;; TimerHi wouldn't change anyway, and everything will sound fine.
_Envelope:
    fall Func_InstrumentPulseBasic
.ENDPROC

;;; A basic instrument for the pulse channels.  The bottom four bits of the
;;; instrument param specify the max volume, which fades out at the end of the
;;; note.  The top two bits of the instrument param specify the pulse duty.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulseBasic
    lda Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    and #bEnvelope::VolMask
    sta Zp_AudioTmp1_byte  ; max volume
    lda Ram_Music_sChanNote_arr + sChanNote::DurationFrames_u8, x
    sub Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    mul #2
    bcs @useMaxVolume
    cmp Zp_AudioTmp1_byte  ; max volume
    blt Func_CombineVolumeWithDuty
    @useMaxVolume:
    lda Zp_AudioTmp1_byte  ; max volume
    bpl Func_CombineVolumeWithDuty  ; unconditional
.ENDPROC

;;; An instrument for the pulse channels that plays briefly at full volume,
;;; then cuts to half volume for the rest of the note.  The bottom four bits of
;;; the instrument param specify the initial volume.  The top two bits of the
;;; instrument param specify the pulse duty.  Bits 4 and 5 control the duration
;;; of the full-volume portion of the note.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulseEcho
    lda Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    and #bEnvelope::VolMask
    tay  ; max volume
    lda Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    and #%00110000
    ora #%00001100
    div #4
    cmp Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
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
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulsePluck
    lda Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    and #bEnvelope::VolMask
    sta Zp_AudioTmp1_byte  ; max volume
    lda Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    cmp #2
    bge _Decay
_Pluck:
    lda Zp_AudioTmp1_byte  ; max volume
    ora #bEnvelope::Duty12 | bEnvelope::NoLength | bEnvelope::ConstVol
    rts
_Decay:
    div #2
    rsub Zp_AudioTmp1_byte  ; max volume
    blt Func_InstrumentSilent
    fall Func_CombineVolumeWithDuty
.ENDPROC

;;; Combines the given volume value with the pulse duty bits from the
;;; instrument param to produce a final duty/envelope byte.
;;; @param A The volume value (0-15).
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_CombineVolumeWithDuty
    sta Zp_AudioTmp1_byte  ; volume
    lda Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    and #bEnvelope::DutyMask
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    ora Zp_AudioTmp1_byte  ; volume
    rts
.ENDPROC

;;; An instrument that ramps up volume quickly, then decays slowly, all with
;;; slight vibrato.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulsePiano
_Vibrato:
    lda Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    and #$03
    tay
    lda Ram_Music_sChanNote_arr + sChanNote::TimerLo_byte, x
    add _VibratoDelta_i8_arr4, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    ;; Note that we intentionally *don't* carry the addition over into TimerHi
    ;; here, because for pulse channels, writing to the TimerHi register resets
    ;; the pulse phase, which adds an undesirable clicking noise (see
    ;; https://www.nesdev.org/wiki/APU).  As long as we avoid using this
    ;; instrument for pitches right next to a TimerLo carry boundary, then
    ;; TimerHi wouldn't change anyway, and everything will sound fine.
_Envelope:
    lda Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    and #bEnvelope::VolMask
    sta Zp_AudioTmp1_byte  ; max volume
    div #2
    rsub Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    bge @decay
    @attack:
    lda Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    sec
    rol a
    bne Func_CombineVolumeWithDuty  ; unconditional
    @decay:
    div #8
    rsub Zp_AudioTmp1_byte  ; max volume
    blt Func_InstrumentSilent
    bge Func_CombineVolumeWithDuty  ; unconditional
_VibratoDelta_i8_arr4:
    .byte <0, <1, <0, <-1
.ENDPROC

.PROC Func_InstrumentRampUp
    lda Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    cmp #$0f
    blt @setDuty
    lda #$0f
    @setDuty:
    ora #$b0
    rts
.ENDPROC

;;; An instrument for the pulse and noise channels.  The bottom four bits of
;;; the instrument param specify the initial volume, which starts fading out
;;; immediately.  The top two bits of the instrument param specify the pulse
;;; duty (ignored for the noise channel).
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentStaccato
    lda Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    and #bEnvelope::VolMask
    sub Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    bge Func_CombineVolumeWithDuty
    fall Func_InstrumentSilent
.ENDPROC

;;; An instrument for the pulse and noise channels that silences the channel.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentSilent
    lda #bEnvelope::NoLength | bEnvelope::ConstVol
    rts
.ENDPROC

;;; An instrument for playing bass drum sounds on the triangle channel.  Each
;;; frame, this increases the timer value (thus lowering the frequency) by the
;;; instrument param.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentTriangleDrum
_Pitch:
    lda Ram_Music_sChanNote_arr + sChanNote::TimerLo_byte, x
    add Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    sta Ram_Music_sChanNote_arr + sChanNote::TimerLo_byte, x
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda Ram_Music_sChanNote_arr + sChanNote::TimerHi_byte, x
    adc #0
    and #$07
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    sta Ram_Music_sChanNote_arr + sChanNote::TimerHi_byte, x
_Envelope:
    lda #$ff
    rts
.ENDPROC

;;; An instrument for the triangle channel that slides down in pitch with
;;; vibrato.  The instrument param is ignored.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentTriangleSlide
_Slide:
    lda Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    and #$01
    beq @done
    lda Ram_Music_sChanNote_arr + sChanNote::TimerLo_byte, x
    add #1
    sta Ram_Music_sChanNote_arr + sChanNote::TimerLo_byte, x
    lda Ram_Music_sChanNote_arr + sChanNote::TimerHi_byte, x
    adc #0
    and #$07
    sta Ram_Music_sChanNote_arr + sChanNote::TimerHi_byte, x
    @done:
_Vibrato:
    fall Func_InstrumentTriangleVibrato
.ENDPROC

;;; An instrument for the triangle channel that applies vibrato.  The
;;; instrument param is ignored.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentTriangleVibrato
_Vibrato:
    lda Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    and #$07
    tay
    lda Ram_Music_sChanNote_arr + sChanNote::TimerLo_byte, x
    add Data_VibratoDelta_i16_0_arr8, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda Ram_Music_sChanNote_arr + sChanNote::TimerHi_byte, x
    adc Data_VibratoDelta_i16_1_arr8, y
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

;;;=========================================================================;;;

.SEGMENT "PRGE_InstSample"

.EXPORT Data_SampleKickDrum_arr657
.PROC Data_SampleKickDrum_arr657
:   .assert * .mod kDmcSampleAlign = 0, error
    .incbin "out/samples/inst_kick.dm"
    .assert (* - :-) .mod 16 = 1, error
.ENDPROC
.ASSERT .sizeof(Data_SampleKickDrum_arr657) = 657, error

;;;=========================================================================;;;
