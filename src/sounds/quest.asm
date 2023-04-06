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
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

;;; The eChan value for the channel that Quest Marker sounds play on.
kChannel = eChan::Pulse2

;;; How slowly the envelope volume decreases (0-15).
kQuestEnvPeriod = 4

;;;=========================================================================;;;

.Segment "PRG8"

;;; SFX function for the quest marker jingle.  When starting this sound,
;;; Timer_u8 and Param1_byte should be initialized to zero.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.EXPORT Func_SfxQuest
.PROC Func_SfxQuest
    lda Ram_Sound_sChanSfx_arr + kChannel + sChanSfx::Timer_u8
    beq _StartNote
_ContinueNote:
    dec Ram_Sound_sChanSfx_arr + kChannel + sChanSfx::Timer_u8
    clc  ; clear C to indicate that the sound is still going
    rts
_StartNote:
    ldy Ram_Sound_sChanSfx_arr + kChannel + sChanSfx::Param1_byte
    cpy #5
    bge _SoundFinished
    inc Ram_Sound_sChanSfx_arr + kChannel + sChanSfx::Param1_byte
    lda _NoteDuration_u8_arr5, y
    sta Ram_Sound_sChanSfx_arr + kChannel + sChanSfx::Timer_u8
    lda #bEnvelope::Duty14 | bEnvelope::NoLength | kQuestEnvPeriod
    sta Hw_Channels_sChanRegs_arr5 + kChannel + sChanRegs::Envelope_wo
    lda #0
    sta Hw_Channels_sChanRegs_arr5 + kChannel + sChanRegs::Sweep_wo
    lda _NoteFreq_u16_0_arr5, y
    sta Hw_Channels_sChanRegs_arr5 + kChannel + sChanRegs::TimerLo_wo
    lda _NoteFreq_u16_1_arr5, y
    sta Hw_Channels_sChanRegs_arr5 + kChannel + sChanRegs::TimerHi_wo
    clc  ; clear C to indicate that the sound is still going
    rts
_SoundFinished:
    sec  ; set C to indicate that the sound is finished
    rts
_NoteDuration_u8_arr5: .byte 4, 4, 4, 4, 16
_NoteFreq_u16_0_arr5: .byte $1c, $52, $1c, $52, $d5
_NoteFreq_u16_1_arr5: .byte $01, $01, $01, $01, $00
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Starts playing the jingle sound for when a quest marker is added to the
;;; minimap.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Dialog_PlaySfxQuestMarker
.PROC FuncA_Dialog_PlaySfxQuestMarker
    lda #0
    sta Zp_Next_sChanSfx_arr + kChannel + sChanSfx::Timer_u8
    sta Zp_Next_sChanSfx_arr + kChannel + sChanSfx::Param1_byte
    lda #eSound::Quest
    sta Zp_Next_sChanSfx_arr + kChannel + sChanSfx::Sfx_eSound
    rts
.ENDPROC

;;;=========================================================================;;;
