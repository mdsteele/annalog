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

;;; Audio channels.  The numerical values are multiples of four, so they can be
;;; used as indices into arrays of sChan* structs (which are all four-byte
;;; structs).
.ENUM eChan
    Pulse1   =  0
    Pulse2   =  4
    Triangle =  8
    Noise    = 12
    Dmc      = 16
.ENDENUM

;;; Music note state variables for a given APU channel.
.STRUCT sChanNote
    ;; How many frames of the current tone/rest have elapsed so far.
    ElapsedFrames_u8   .byte
    ;; The length of the current tone/rest, in frames.
    DurationFrames_u8  .byte
    ;; The values written to the TimerLo/TimerHi APU registers for this note.
    ;; Instrument functions may read these values e.g. to implement vibrato.
    ;; Nothing else reads these, so instrument functions may also override
    ;; these values if desired.
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
    ;; Currently-unused padding byte.
    Unused           .byte
    ;; How many times the same chain repeat has been reached in a row.
    RepeatCount_u8   .byte
.ENDSTRUCT

;;; SFX state variables for a given APU channel.
.STRUCT sChanSfx
    ;; Indicates which SFX function to call each frame while the sound is
    ;; active.
    Sfx_eSound  .byte
    ;; Typically used as a frame timer to track how long the sound effect
    ;; should play, but the SFX function can use this however it wants.
    Timer_u8    .byte
    ;; Arbitrary parameter/state bytes that can be used by the SFX function.
    Param1_byte .byte
    Param2_byte .byte
.ENDSTRUCT

;;;=========================================================================;;;

;;; Flags for controlling whether audio is enabled.
.SCOPE bAudio
    ;; Controls whether audio is enabled.  When audio is disabled, all music
    ;; and sound effects are stopped, all APU channels are muted, and the audio
    ;; driver will not read any more audio data until audio is re-enabled.
    ;; Note that since this game generally stores music data in PRGC, it is
    ;; only safe to switch PRGC banks when audio is disabled.
    Enable      = %10000000
    ;; Controls the music volume.  When this bit is set, certain music
    ;; instruments will play at reduced volume or not at all.  Sound effects
    ;; are unaffected.
    ReduceMusic = %01000000
.ENDSCOPE

;;; Instructions to be sent to the audio driver the next time Func_ProcessFrame
;;; is called.
.STRUCT sAudioCtrl
    ;; Controls whether audio is enabled.  When audio is disabled, all music
    ;; and sound effects are stopped, all APU channels are muted, and the audio
    ;; driver will not read any more audio data until audio is re-enabled.
    ;; Note that since this game generally stores music data in PRGC, it is
    ;; only safe to switch PRGC banks when audio is disabled.
    Next_bAudio      .byte
    ;; Controls which music to play.  When Func_ProcessFrame is called, if this
    ;; is different than the currently-playing music (and audio is enabled),
    ;; then the current music will be stopped, and this music will be started
    ;; from the beginning.
    Music_eMusic     .byte
    ;; Controls the music flag.  If bMusic::UsesFlag is set, then the music
    ;; flag will be set to this & bMusic::FlagMask when Func_ProcessFrame is
    ;; called; otherwise, the music flag will be unchanged.  Either way, this
    ;; field will be updated to the (new) current value of the of the music
    ;; flag when Func_ProcessFrame is called.
    MusicFlag_bMusic .byte
.ENDSTRUCT

;;;=========================================================================;;;
