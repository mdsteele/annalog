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
    D_TABLE eInst
    d_entry table, Constant,        Func_InstrumentConstant
    d_entry table, PulseBasic,      Func_InstrumentPulseBasic
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

;;; A basic instrument for the pulse channels.  The bottom four bits of the
;;; instrument param specify the max volume, which fades out at the end of the
;;; note.  The top two bits of the instrument param specify the pulse duty.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_InstrumentPulseBasic
    ldy Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    ;; Calculate volume:
    tya  ; instrument param
    and #bEnvelope::VolMask
    sta Zp_AudioTmp1_byte  ; max volume
    lda Ram_Music_sChanNote_arr + sChanNote::DurationFrames_u8, x
    sub Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    mul #2
    bcs @useMaxVolume
    cmp Zp_AudioTmp1_byte  ; max volume
    bge @useMaxVolume
    sta Zp_AudioTmp1_byte  ; volume
    @useMaxVolume:
    ;; Combine volume with other envelope bits:
    tya  ; instrument param
    and #bEnvelope::DutyMask
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    ora Zp_AudioTmp1_byte  ; volume
    rts
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
    ldy Ram_Music_sChanInst_arr + sChanInst::Param_byte, x
    ;; Calculate volume:
    tya  ; instrument param
    and #bEnvelope::VolMask
    sub Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    bge @setVolume
    lda #$00
    @setVolume:
    sta Zp_AudioTmp1_byte  ; volume
    ;; Combine volume with other envelope bits:
    tya  ; instrument param
    and #bEnvelope::DutyMask
    ora #bEnvelope::NoLength | bEnvelope::ConstVol
    ora Zp_AudioTmp1_byte  ; volume
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
    .assert * = Func_InstrumentTriangleVibrato, error, "fallthrough"
.ENDPROC

.PROC Func_InstrumentTriangleVibrato
_Vibrato:
    lda Ram_Music_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    and #$07
    tay
    lda Ram_Music_sChanNote_arr + sChanNote::TimerLo_byte, x
    add _Delta_i16_0_arr8, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda Ram_Music_sChanNote_arr + sChanNote::TimerHi_byte, x
    adc _Delta_i16_1_arr8, y
    and #$07
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
_Envelope:
    lda #$ff
    rts
_Delta_i16_0_arr8:
    .byte <0, <2, <3, <2, <0, <-2, <-3, <-2
_Delta_i16_1_arr8:
    .byte >0, >2, >3, >2, >0, >-2, >-3, >-2
.ENDPROC

;;;=========================================================================;;;
