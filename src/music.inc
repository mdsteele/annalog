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

;;; Music songs that can be played.
.ENUM eMusic
    Silence
    Boss1
    Boss2
    Calm
    Credits
    Crypt
    Mine
    Prison
    Temple
    Title
    Upgrade
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Each note in a phrase is one or more bytes, using the following encoding:
;;;   * DONE (1 byte) [%00000000].  This marks the end of the phrase.
;;;   * REST (1 byte) [%0xxxxxxx].  Silences this channel for 1 + %0xxxxxxx
;;;     frames (0-127).  Multiple REST notes in a row can be used to silence
;;;     the channel for longer durations.
;;;   * INST (2 bytes) [%10xxxxxx %yyyyyyyy].  Sets this channel to use the
;;;     instrument with eInst value %00xxxxxx (0-63), and sets %yyyyyyyy as the
;;;     instrument-specific parameter byte.  The chosen instrument will persist
;;;     across phrases and parts, until the next INST note is executed.
;;;   * TONE (3 bytes) [%11qqqwww %xxxxyyyy %zzzzzzzz].  Plays a sound for
;;;     %zzzzzzzz frames (1-255), with attributes depending on the channel:
;;;       * On the pulse and triangle channels, the tone will have a frequency
;;;         value of %00000www.xxxxyyyy (0-2047), and the %qqq bits must be 0.
;;;       * On the noise channel, the tone will have a period value of %yyyy,
;;;         and will buzz if the high bit of %xxxx is set, and the %qqqwww bits
;;;         must be 0.
;;;       * On the DMC channel, the sample starts at address %11xxxxyy.yy000000
;;;         and has a length of %000000qq.qwww0001 bytes.
;;;     Other characteristics of the sound (such as volume, duty cycle, and/or
;;;     sample rate) will be controlled by the current instrument.
.SCOPE bNote
    NotRest  = %10000000  ; this bit is set for all notes other than REST/DONE
    RestMask = %01111111  ; mask for duration of a REST note
    IsTone   = %01000000  ; on non-REST notes, this bit is set only for TONE
    InstMask = %00111111  ; mask for instrument number of an INST note
    ToneMask = %00111111  ; mask for data for first byte of a TONE note
.ENDSCOPE

;;; A variable-length sequence of notes, terminated by a $00 byte (i.e. a DONE
;;; note).  Each note is one or more bytes, the first of which uses bNote
;;; constants to specify the kind of note.
.STRUCT sPhrase
    ;; variable-length
.ENDSTRUCT

;;; Each item in a chain a byte in one of the following forms:
;;;   * PHRA [%1xxxxxxx].  Plays phrase number %xxxxxxx.
;;;   * REPT [%0xxxxxxx].  Repeats the previous item (which must be a PHRA) for
;;;     a total of %xxxxxxx times.
;;;   * HALT [%00000000].  This marks the end of the chain.
.SCOPE bChain
    IsPhrase = %10000000  ; if this bit is set, this is a PHRA item
.ENDSCOPE

;;; One section of a song.  A part consists of one chain for each APU channel,
;;; which all play in parallel.  However, these chains need not all be the same
;;; duration (and indeed, some can just be empty); the part will only end once
;;; all chains have halted.
.STRUCT sPart
    ;; Chains for each APU channel.  Each chain is a sequence of bChain bytes,
    ;; terminated by $00 (HALT).
    Chain1_bChain_arr_ptr .addr
    Chain2_bChain_arr_ptr .addr
    ChainT_bChain_arr_ptr .addr
    ChainN_bChain_arr_ptr .addr
    ChainD_bChain_arr_ptr .addr
.ENDSTRUCT

;;; Bit flags for music opcodes.  A music opcode byte can take one of the
;;; following forms:
;;;   * STOP [%00000000].  Ends the song.  Func_AudioUpdate won't play any more
;;;     music until a new song is started (but note that it's still not safe to
;;;     switch PRGC banks until audio is actually disabled).
;;;   * JUMP [%00xxxxxx].  Jumps forward/backward by %xxxxxx opcodes from this
;;;     one (signed).  For example, a JUMP value of 2 would skip the next
;;;     opcode, and proceed to the one after.
;;;   * SETF [%1y000000].  Sets the music flag bit to %y (then proceeds to the
;;;     next opcode).
;;;   * BFEQ [%1yxxxxxx].  If the music flag bit is equal to %y, jumps
;;;     forward/backward by %xxxxxx opcodes from this one (signed).  Otherwise,
;;;     does nothing (and proceeds to the next opcode).
;;;   * PLAY [%010xxxxx].  Starts playing part number %xxxxx (0-31).  The next
;;;     opcode will be executed once that part has finished playing.
.SCOPE bMusic
    UsesFlag = %10000000  ; set for flag-related opcodes
    FlagMask = %01000000  ; mask for flag value
    IsPlay   = %01000000  ; on non-flag opcodes, this bit is set only for PLAY
    JumpMask = %00111111  ; mask for signed jump offset on relevant opcodes
    PlayMask = %00011111  ; mask for part number on PLAY opcode
.ENDSCOPE

;;; A song that can be played by the audio driver.  Only one song can play at
;;; once.
.STRUCT sMusic
    ;; A pointer to an array of music opcodes for this song.  This controls
    ;; which parts are played, and in what order.
    Opcodes_bMusic_arr_ptr       .addr
    ;; A pointer to an array of parts that can appear in this song.  Each song
    ;; plays some sequence of parts in some order, possibly looping, and/or
    ;; possibly dynamically affected by the global music flag.
    Parts_sPart_arr_ptr          .addr
    ;; An array of note phrases that can be used by parts in this song.
    Phrases_sPhrase_ptr_arr_ptr  .addr
.ENDSTRUCT

;;;=========================================================================;;;
