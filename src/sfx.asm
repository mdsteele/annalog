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

.IMPORT Ram_Sound_sChanSfx_arr
.IMPORTZP Zp_Next_sAudioCtrl

;;;=========================================================================;;;

;;; The duration of a Func_SfxBeep sound, in frames.
kBeepDurationFrames = 15
;;; The initial volume of a Func_SfxBeep sound (0-15).
kBeepInitVolume = 3

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Plays a sound for the BEEP opcode.
;;; @param A The tone number (0-9).
.EXPORT Func_PlayBeepSfx
.PROC Func_PlayBeepSfx
    .linecont +
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::Sfx2_sChanSfx + \
          sChanSfx::Param1_byte)
    lda #0
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::Sfx2_sChanSfx + \
          sChanSfx::Param2_byte)
    ldax #Func_SfxBeep
    stax <(Zp_Next_sAudioCtrl + sAudioCtrl::Sfx2_sChanSfx + \
           sChanSfx::Sfx_func_ptr)
    .linecont -
    rts
.ENDPROC

;;; SFX function for the BEEP opcode.  When starting this sound, Param1_byte
;;; should hold the tone number (0-9), and Param2_byte should be initialized to
;;; zero.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X
.PROC Func_SfxBeep
    lda Ram_Sound_sChanSfx_arr + sChanSfx::Param2_byte, x
    beq _Initialize
    cmp #kBeepDurationFrames
    blt _Continue
    sec  ; set C to indicate that the sound is finished
    rts
_Initialize:
    lda #bEnvelope::Duty12 | bEnvelope::NoLength | kBeepInitVolume
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    lda #0
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Sweep_wo, x
    ldy Ram_Sound_sChanSfx_arr + sChanSfx::Param1_byte, x
    lda _TimerLo, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    lda _TimerHi, y
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
_Continue:
    inc Ram_Sound_sChanSfx_arr + sChanSfx::Param2_byte, x
    clc  ; clear C to indicate that the sound is still going
    rts
;;; These values represent the ten natural notes from A3 through C5.
_TimerLo: .byte $fb, $c4, $ab, $7c, $52, $3f, $1c, $fd, $e1, $d5
_TimerHi: .byte $01, $01, $01, $01, $01, $01, $01, $00, $00, $00
.ENDPROC

;;;=========================================================================;;;
