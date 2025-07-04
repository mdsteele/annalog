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

.INCLUDE "../src/audio.inc"
.INCLUDE "../src/macros.inc"
.INCLUDE "../src/music.inc"

.IMPORT Func_AudioReset
.IMPORT Func_AudioSync
.IMPORT Func_AudioUpdate
.IMPORTZP Zp_Next_sAudioCtrl

;;;=========================================================================;;;

kVersion       = 1      ; version number; 1 = NSF, 2 = NSF2
kNumSongs      = eMusic::NUM_VALUES - 1  ; (exclude eMusic::Silence)
kFirstSong     = 1
kDataLoadAddr  = $8000
kDataInitAddr  = Func_NsfInit
kDataPlayAddr  = Func_AudioUpdate
kPlaySpeedNtsc = 16639  ; this value recommended by https://nesdev.org/wiki/NSF
kPlaySpeedPal  = 19997  ; this value recommended by https://nesdev.org/wiki/NSF
kRegion        = 0      ; 0 = NTSC, 1 = PAL, 2 = both
kSoundChip     = 0      ; 0 = no extra sound chips

;;;=========================================================================;;;

.SEGMENT "HEADER"

.SCOPE NsfHeader
    .byte "NESM", $1a  ; magic number
    .byte kVersion
    .byte kNumSongs
    .byte kFirstSong
    .addr kDataLoadAddr
    .addr kDataInitAddr
    .addr kDataPlayAddr
    .scope Title
    .byte "Annalog", 0
    .res 24
    .endscope
    .assert .sizeof(Title) = $20, error
    .scope Artist
    .byte "Jon Moran and Matthew Steele", 0
    .res 3
    .endscope
    .assert .sizeof(Artist) = $20, error
    .scope Copyright
    .byte "2025 Matthew D. Steele", 0
    .res 9
    .endscope
    .assert .sizeof(Copyright) = $20, error
    .word kPlaySpeedNtsc
    .scope BankSwitchInit
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .endscope
    .assert .sizeof(BankSwitchInit) = $08, error
    .word kPlaySpeedPal
    .byte kRegion
    .byte kSoundChip
    .res 4
.ENDSCOPE
.ASSERT .sizeof(NsfHeader) = $80, error

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Called by the NSF driver to start a new song playing.
;;; @param A The song number to start playing.
;;; @param X The region (0 for NTSC, 1 for PAL).
.PROC Func_NsfInit
    pha  ; song number
    jsr Func_AudioReset
    pla  ; song number
    tay  ; song number
    .assert eMusic::Silence = 0, error
    iny
    sty Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    lda #bAudio::Enable
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
    jmp Func_AudioSync
.ENDPROC

;;; Stub implementation.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.EXPORT Func_AudioCallSfx
.PROC Func_AudioCallSfx
    sec  ; set C to indicate that the sound is finished
    rts
.ENDPROC

;;;=========================================================================;;;
