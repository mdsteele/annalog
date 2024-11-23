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

;;; An SFX operation consists of one or more bytes, using the following
;;; encoding:
;;; * END (1 byte) [00000000].  This marks the end of the sound.
;;; * WAIT (1 byte) [00xxxxxx].  Waits for %00xxxxxx frames before executing
;;;   the next operation.
;;; * SET (1-5 bytes) [01--hlse].  Reads 0-4 more bytes after the first (one
;;;   for each bit set in the lower nibble), setting APU registers for this
;;;   channel based on which bits are set.
;;; * FUNC (2 bytes) [1xxxxxxx yyyyyyyy].  Calls the function with the given
;;;   big-endian address once each frame until it sets C, at which point the
;;;   sound proceeds to the next operation.  Passes Y to this function, where Y
;;;   is the number of times the function has previously been called in a row
;;;   (0 for the first call, 1 for the second, and so on).  The function is
;;;   free to make use of Zp_AudioTmp*, but must preserve X and T0+.
.SCOPE bSfxOp
    Set           = %01000000
    SetTimerHi    = %00001000 | Set
    SetTimerLo    = %00000100 | Set
    SetSweep      = %00000010 | Set
    SetEnv        = %00000001 | Set
    SetEnvSweep   = SetEnv | SetSweep
    SetEnvTimer   = SetEnv | SetTimer
    SetEnvTimerHi = SetEnv | SetTimerHi
    SetEnvTimerLo = SetEnv | SetTimerLo
    SetTimer      = SetTimerLo | SetTimerHi
    SetAll        = SetEnv | SetSweep | SetTimer
.ENDSCOPE

;;;=========================================================================;;;

.MACRO sfx_Func LABEL
    ;; The bSfxOp encoding above requires that the function address have a high
    ;; bit of 1 (i.e. the function must reside in the ROM region of memory).
    .assert (LABEL) >= $8000, error, "sfx_Func address must be in ROM"
    ;; Sound data may safely reside in PRG8 or PRGE (where it is always
    ;; available), or in PRGC if the sound is only used in one area of the
    ;; game.  However, it may not reside in PRGA, since there is no guarantee
    ;; which PRGA bank will be loaded when the audio thread runs.
    .assert (LABEL) < $a000 || (LABEL) >= $c000, error
    ;; Note that the function address is stored big-endian (rather than the
    ;; 6502's usual little-endian), so that the high address bit of 1 will
    ;; appear in the first byte read.
    .dbyt LABEL
.ENDMACRO

.MACRO sfx_SetTimerHi TIMERHI
    .byte bSfxOp::SetTimerHi
    .byte TIMERHI
.ENDMACRO

.MACRO sfx_SetTimerLo TIMERLO
    .byte bSfxOp::SetTimerLo
    .byte TIMERLO
.ENDMACRO

.MACRO sfx_SetTimer TIMER
    .byte bSfxOp::SetTimer
    .word TIMER
.ENDMACRO

.MACRO sfx_SetEnv ENV
    .byte bSfxOp::SetEnv
    .byte ENV
.ENDMACRO

.MACRO sfx_SetEnvSweep ENV, SWEEP
    .byte bSfxOp::SetEnvSweep
    .byte ENV
    .byte SWEEP
.ENDMACRO

.MACRO sfx_SetEnvTimerHi ENV, TIMERHI
    .byte bSfxOp::SetEnvTimerHi
    .byte ENV
    .byte TIMERHI
.ENDMACRO

.MACRO sfx_SetEnvTimerLo ENV, TIMERLO
    .byte bSfxOp::SetEnvTimerLo
    .byte ENV
    .byte TIMERLO
.ENDMACRO

.MACRO sfx_SetEnvTimer ENV, TIMER
    .byte bSfxOp::SetEnvTimer
    .byte ENV
    .word TIMER
.ENDMACRO

.MACRO sfx_SetAll ENV, SWEEP, TIMER
    .byte bSfxOp::SetAll
    .byte ENV
    .byte SWEEP
    .word TIMER
.ENDMACRO

.MACRO sfx_Wait FRAMES
    .assert (FRAMES) > 0, error, "sfx_Wait frames must be strictly positive"
    ;; A single WAIT operation can wait for at most $3f frames.  If we need to
    ;; wait for longer than that, then emit multiple multiple WAIT operations
    ;; in a row.
    .if (FRAMES) <= $3f
    .byte FRAMES
    .else
    .byte $3f
    sfx_Wait (FRAMES) - $3f
    .endif
.ENDMACRO

.MACRO sfx_End
    .byte 0
.ENDMACRO

;;;=========================================================================;;;
