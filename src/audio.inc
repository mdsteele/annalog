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

;;; Music note state variables for a given APU channel.
.STRUCT sChanNote
    ;; How many frames of the current tone/rest have elapsed so far.
    ElapsedFrames_u8   .byte
    ;; The length of the current tone/rest, in frames.
    DurationFrames_u8  .byte
    ;; The values written to the TimerLo/TimerHi APU registers for this note.
    TimerLo_byte       .byte
    TimerHi_byte       .byte
.ENDSTRUCT

;;; Music instrument state variables for a given APU channel.
.STRUCT sChanInst
    ;; Indicates which instrument function to call each frame to update the
    ;; tone.
    Instrument_eInst .byte
    ;; Parameter byte for the instrument.
    Param_byte       .byte
    ;; Currently-unused padding bytes.
    Unused           .word
.ENDSTRUCT

;;; SFX state variables for a given APU channel.
.STRUCT sChanSfx
    ;; The SFX function to call each frame to update the channel's APU
    ;; registers for the sound effect.  If the high byte is zero, then no sound
    ;; effect is active.
    ;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
    ;; @return C Set if the sound is finished, cleared otherwise.
    ;; @preserve X
    Sfx_func_ptr .addr
    ;; Arbitrary parameter/state bytes that can be used by the Sfx_func_ptr.
    Param1_byte  .byte
    Param2_byte  .byte
.ENDSTRUCT

;;;=========================================================================;;;

;;; Instructions to be sent to the audio driver the next time Func_ProcessFrame
;;; is called.
.STRUCT sAudioCtrl
    ;; Controls whether audio is enabled.  When audio is disabled, all music
    ;; and sound effects are stopped, all APU channels are muted, and the audio
    ;; driver will not read any more audio data until audio is re-enabled.
    ;; Note that since this game generally stores music data in PRGC, it is
    ;; only safe to switch PRGC banks when audio is disabled.
    Enable_bool      .byte
    ;; Sets the master volume (0-255).  This should normally be left at 255
    ;; (full volume), but can be reduced over the course of several frames to
    ;; fade out audio before disabling it.  Note that only the top four bits
    ;; are actually used.
    MasterVolume_u8  .byte
    ;; Controls the music flag.  If bMusic::UsesFlag is set, then the music
    ;; flag will be set to this & bMusic::FlagMask when Func_ProcessFrame is
    ;; called; otherwise, the music flag will be unchanged.  Either way, this
    ;; field will be updated to the (new) current value of the of the music
    ;; flag when Func_ProcessFrame is called.
    MusicFlag_bMusic .byte
    ;; Controls which music to play.  When Func_ProcessFrame is called, if this
    ;; is different than the currently-playing music, then the current music
    ;; will be stopped, and this music will be started from the beginning.
    Music_eMusic     .byte
    ;; For each of these sChanSfx structs, if the high byte of the Sfx_func_ptr
    ;; is nonzero, then the audio driver will start playing that SFX.
    Sfx1_sChanSfx    .tag sChanSfx
    Sfx2_sChanSfx    .tag sChanSfx
    SfxT_sChanSfx    .tag sChanSfx
    SfxN_sChanSfx    .tag sChanSfx
    SfxD_sChanSfx    .tag sChanSfx
.ENDSTRUCT

;;;=========================================================================;;;
