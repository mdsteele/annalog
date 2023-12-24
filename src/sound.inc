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

;;; SFX functions that can be played.
.ENUM eSound
    None
    Beep
    Explode
    Launch
    Quest
    Sample
    Sequence
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Sound effects that use the eSound::Sequence function can be specified as an
;;; sSfxSeq_arr that describes the APU register values to set.  The array must
;;; be terminated by a zero byte.
.STRUCT sSfxSeq
    ;; The duration of this part of the SFX sequence, in frames.  Must be
    ;; nonzero (except for the last entry in the array, where the zero byte
    ;; signals the end of the array).
    Duration_u8   .byte
    ;; The 8-bit value to set in the channel's envelope register.
    Env_bEnvelope .byte
    ;; The 8-bit value to set in the channel's sweep register.
    Sweep_byte    .byte
    ;; The 16-bit value to set in the channel's TimerLo/TimerHi registers.
    Timer_u16     .word
.ENDSTRUCT

;;;=========================================================================;;;
