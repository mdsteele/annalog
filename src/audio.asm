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
.INCLUDE "cpu.inc"
.INCLUDE "macros.inc"

;;;=========================================================================;;;

;;; The audio driver keeps various state variables for each APU channel in RAM.
;;; These variables are broken up among several different arrays of 4-byte
;;; structs.  The reason for doing this is to match the 4-byte offset between
;;; corresponding APU hardware registers for each channel (see sChanRegs in
;;; apu.inc); this allows us to use a single index register (storing 4 times
;;; the channel number) to index into both the hardware registers and all of
;;; these different RAM arrays, which in turn allows us to easily use the same
;;; code to drive all five APU channels.

;;; Pointers to the next byte to execute within the current chain and current
;;; phrase for a given APU channel.
.STRUCT sChanNext
    ;; A pointer to the next byte in the current chain to execute once the
    ;; current phrase finishes.
    ChainNext_u8_ptr .addr
    ;; A pointer to the next byte in the current phrase to execute once the
    ;; current note finishes.
    PhraseNext_ptr   .addr
.ENDSTRUCT

;;; Assert that all the channel structs we use are exactly four bytes.  This
;;; allows us to use four times the channel number as a byte index into any the
;;; struct arrays.
.ASSERT .sizeof(sChanRegs)  = 4, error
.ASSERT .sizeof(sChanNext)  = 4, error
.ASSERT .sizeof(sChanState) = 4, error

;;;=========================================================================;;;

.ZEROPAGE

;;; Stores commands that will be sent to the audio driver the next time that
;;; Func_ProcessFrame is called.  This can be safely written to on the main
;;; thread.
.EXPORTZP Zp_Next_sAudioCtrl
Zp_Next_sAudioCtrl: .tag sAudioCtrl

;;; A copy of the currently-playing music struct.  Storing this in the zero
;;; page allows us to use the Zero Page Indirect Y-Indexed addressing mode to
;;; index into the various arrays that this struct has pointers to.
Zp_Current_sMusic: .tag sMusic

;;; Music "next byte" pointers for all the different APU channels.  This array
;;; uses a bunch of space in the zero page, but doing so allows us to use the
;;; X-Indexed Zero Page Indirect addressing mode to read these next bytes while
;;; indexing by APU channel number.
Zp_Music_sChanNext_arr: .res .sizeof(sChanNext) * kNumApuChannels

;;; If true ($ff), then Func_AudioUpdate will perform audio playback; if false
;;; ($00), then Func_AudioUpdate is a no-op.  Invariant: all APU channels are
;;; disabled when this is false.
Zp_AudioEnabled_bool: .res 1

;;; Master volume that is applied to all channels in conjunction with their
;;; individual volume envelopes.  The bottom four bits of this variable are
;;; always zero.
Zp_MasterVolume_u8: .res 1

;;; This must be all zero bits except for bMusic::FlagMask; those bits indicate
;;; the current music flag value.
Zp_MusicFlag_bMusic: .res 1

;;; The current index into Opcodes_bMusic_arr_ptr for the current music.
Zp_MusicOpcodeIndex_u8: .res 1

;;; Temporary variable used by Func_AudioUpdate to keep track of whether any
;;; music notes have been played yet this frame.
Zp_MusicMadeProgress_bool: .res 1

;;; A mirror of Hw_ApuStatus_rw that stores which APU channels are currently
;;; enabled.  Hw_ApuStatus_rw has different behavior on read and write (see
;;; https://www.nesdev.org/wiki/APU), so we can't just read it to find out what
;;; we last wrote there, so we use this variable instead.
Zp_ActiveChannels_bApuStatus: .res 1

;;; Temporary variable that stores the bApuStatus bit for the APU channel we're
;;; currently updating.
Zp_CurrentChannel_bApuStatus: .res 1

;;; Temporary variables that any audio-thread function can use.
Zp_AudioTmp1_byte: .res 1
Zp_AudioTmp2_byte: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Audio"

;;; Music channel state for all the different APU channels.
.EXPORT Ram_Music_sChanState_arr
Ram_Music_sChanState_arr: .res .sizeof(sChanState) * kNumApuChannels

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; A sMusic struct that just plays silence.
.EXPORT Data_Empty_sMusic
.PROC Data_Empty_sMusic
    D_STRUCT sMusic
    d_addr Opcodes_bMusic_arr_ptr, _Opcodes_bMusic_arr
    d_addr Instruments_func_ptr_arr_ptr, 0
    d_addr Parts_sPart_arr_ptr, 0
    d_addr Phrases_sPhrase_ptr_arr_ptr, 0
    D_END
_Opcodes_bMusic_arr:
    .byte $00  ; STOP opcode
.ENDPROC

;;; A music chain that contains no phrases.
.EXPORT Data_EmptyChain_u8_arr
.PROC Data_EmptyChain_u8_arr
    .byte $ff  ; end-of-chain
.ENDPROC

;;; A sPhrase struct that contains no notes.
.PROC Data_Empty_sPhrase
    .byte $00
.ENDPROC

;;; The default instrument for music channels that don't specify one.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_DefaultInstrument
    lda #$3f
    rts
.ENDPROC

;;; Mutes all APU channels, resets APU registers, disables APU IRQs, and
;;; initializes audio driver RAM.
;;; @prereq Caller is within the Reset or NMI handler.
.EXPORT Func_AudioReset
.PROC Func_AudioReset
    ;; Disable APU counter IRQs.
    lda #bApuCount::DisableIrq
    sta Hw_ApuCount_wo
    ;; Silence all APU channels.
    lda #0
    sta Zp_ActiveChannels_bApuStatus
    sta Hw_ApuStatus_rw
    ;; Zero APU channel registers ($4000-$4013).  This will also disable DMC
    ;; channel IRQs.
    ldx #.sizeof(sChanRegs) * kNumApuChannels - 1
    @loop:
    sta Hw_Channels_sChanRegs_arr5, x
    dex
    bpl @loop
    ;; Disable audio and reset music flag.
    sta Zp_AudioEnabled_bool
    sta Zp_MusicFlag_bMusic
_HaltMusic:
    ldy #.sizeof(sMusic) - 1
    @loop:
    lda Data_Empty_sMusic, y
    sta Zp_Current_sMusic, y
    dey
    .assert .sizeof(sMusic) <= $80, error
    bpl @loop
    jsr Func_AudioRestartMusic
_HaltSfx:
    ;; TODO: Implement SFX
    rts
.ENDPROC

;;; Reads from Zp_Next_sAudioCtrl and updates the audio driver accordingly.
;;; @prereq Caller is within the NMI handler, and Func_ProcessFrame is pending.
.EXPORT Func_AudioSync
.PROC Func_AudioSync
    lda <(Zp_Next_sAudioCtrl + sAudioCtrl::Enable_bool)
    bmi _Enable
_Disable:
    bit Zp_AudioEnabled_bool
    jmi Func_AudioReset
    rts
_Enable:
    sta Zp_AudioEnabled_bool
    lda <(Zp_Next_sAudioCtrl + sAudioCtrl::MasterVolume_u8)
    and #$f0
    sta Zp_MasterVolume_u8
_SyncMusicFlag:
    lda <(Zp_Next_sAudioCtrl + sAudioCtrl::MusicFlag_bMusic)
    .assert bMusic::UsesFlag = bProc::Negative, error
    bpl @done
    and #bMusic::FlagMask
    sta Zp_MusicFlag_bMusic
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::MusicFlag_bMusic)
    @done:
_StartMusic:
    ;; Check if we should start playing a new song.
    lda <(Zp_Next_sAudioCtrl + sAudioCtrl::Song_sMusic_ptr + 0)
    beq @done
    ;; Copy the sMusic struct for the song into Zp_Current_sMusic.
    ldy #.sizeof(sMusic) - 1
    @loop:
    lda (Zp_Next_sAudioCtrl + sAudioCtrl::Song_sMusic_ptr), y
    sta Zp_Current_sMusic, y
    dey
    .assert .sizeof(sMusic) <= $80, error
    bpl @loop
    ;; Null out the Song_sMusic_ptr so we don't restart again next frame.
    lda #0
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::Song_sMusic_ptr + 0)
    sta <(Zp_Next_sAudioCtrl + sAudioCtrl::Song_sMusic_ptr + 1)
    ;; Start the music from the beginning.
    jsr Func_AudioRestartMusic
    @done:
_StartSfx:
    ;; TODO: Implement SFX
    rts
.ENDPROC

;;; Sets audio RAM to start playing from the beginning of Zp_Current_sMusic.
.PROC Func_AudioRestartMusic
    ldx #0
    stx Zp_MusicOpcodeIndex_u8
    @loop:
    lda #<Data_EmptyChain_u8_arr
    sta Zp_Music_sChanNext_arr + sChanNext::ChainNext_u8_ptr + 0, x
    lda #>Data_EmptyChain_u8_arr
    sta Zp_Music_sChanNext_arr + sChanNext::ChainNext_u8_ptr + 1, x
    lda #<Data_Empty_sPhrase
    sta Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    lda #>Data_Empty_sPhrase
    sta Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    lda #0
    sta Ram_Music_sChanState_arr + sChanState::NoteDuration_u8, x
    sta Ram_Music_sChanState_arr + sChanState::NoteFrames_u8, x
    lda #<Func_DefaultInstrument
    sta Ram_Music_sChanState_arr + sChanState::Instrument_func_ptr + 0, x
    lda #>Func_DefaultInstrument
    sta Ram_Music_sChanState_arr + sChanState::Instrument_func_ptr + 1, x
    .repeat .sizeof(sChanNext)
    inx
    .endrepeat
    cpx #.sizeof(sChanNext) * kNumApuChannels
    blt @loop
    rts
.ENDPROC

;;; Updates audio playback.  This should be called once per frame.  If audio is
;;; disabled, this is a no-op.
;;; @prereq Caller is within the NMI handler.
.EXPORT Func_AudioUpdate
.PROC Func_AudioUpdate
    bit Zp_AudioEnabled_bool
    bmi _Enabled
    rts
_Enabled:
    jsr Func_AudioContinueSfx
    .assert * = Func_AudioContinueMusic, error, "fallthrough"
.ENDPROC

;;; Continues playing the current music.
.PROC Func_AudioContinueMusic
    lda #0
    sta Zp_MusicMadeProgress_bool
_ContinueCurrentPart:
    ;; Continue playing the current part.  If we make any progress (i.e. play
    ;; any notes/rests), then we're done; otherwise, the part is finished and
    ;; we should proceed to the next opcode.
    jsr Func_AudioContinuePart
    bit Zp_MusicMadeProgress_bool
    bpl _ExecNextOpcode
    rts
_IncOpcodeIndexAndContinue:
    inc Zp_MusicOpcodeIndex_u8
_ExecNextOpcode:
    ldy Zp_MusicOpcodeIndex_u8
    lda (Zp_Current_sMusic + sMusic::Opcodes_bMusic_arr_ptr), y
    tay  ; opcode
    .assert bMusic::UsesFlag = bProc::Negative, error
    bmi _OpcodeFlag
    and #bMusic::IsPlay
    bne _OpcodePlay
_OpcodeJumpOrStop:
    tya  ; opcode
    and #bMusic::JumpMask
    bne _PerformJump
    rts
_PerformJump:
    tax  ; nonzero 6-bit signed jump offset
    and #%00100000
    beq @positive
    txa  ; negative 6-bit signed jump offset
    ora #%11000000
    bmi @jump  ; unconditional
    @positive:
    txa  ; positive 6-bit signed jump offset
    @jump:
    add Zp_MusicOpcodeIndex_u8
    sta Zp_MusicOpcodeIndex_u8
    jmp _ExecNextOpcode
_OpcodeFlag:
    and #bMusic::JumpMask
    beq _OpcodeSetf
_OpcodeBfeq:
    tax  ; nonzero 6-bit signed jump offset
    tya  ; opcode
    and #bMusic::FlagMask
    eor Zp_MusicFlag_bMusic
    bne _IncOpcodeIndexAndContinue
    txa  ; nonzero 6-bit signed jump offset
    bne _PerformJump  ; unconditional
_OpcodeSetf:
    tya  ; opcode
    and #bMusic::FlagMask
    sta Zp_MusicFlag_bMusic
    .assert bMusic::FlagMask & bProc::Negative = 0, error
    bpl _IncOpcodeIndexAndContinue  ; unconditional
_OpcodePlay:
    ;; Increment the opcode index, so that when this part finishes we'll move
    ;; on to the next opcode.
    inc Zp_MusicOpcodeIndex_u8
    tya  ; opcode
    and #bMusic::PlayMask  ; part number
    ;; Multiply the part number by .sizeof(sPart) to get a byte offset into
    ;; the current song's Parts_sPart_arr_ptr.
    .assert .sizeof(sPart) = 10, error
    mul #2
    sta Zp_AudioTmp1_byte
    mul #4
    adc Zp_AudioTmp1_byte
    tay  ; byte offset for part in Parts_sPart_arr_ptr
    ;; Read in the sPart struct and populate Zp_Music_sChanNext_arr.
    ldx #0
    @loop:
    .assert sChanNext::ChainNext_u8_ptr = 0, error
    lda (Zp_Current_sMusic + sMusic::Parts_sPart_arr_ptr), y
    sta Zp_Music_sChanNext_arr, x
    inx
    iny
    lda (Zp_Current_sMusic + sMusic::Parts_sPart_arr_ptr), y
    sta Zp_Music_sChanNext_arr, x
    inx
    .assert sChanNext::PhraseNext_ptr = 2, error
    lda #<Data_Empty_sPhrase
    sta Zp_Music_sChanNext_arr, x
    inx
    lda #>Data_Empty_sPhrase
    sta Zp_Music_sChanNext_arr, x
    inx
    .assert .sizeof(sChanNext) = 4, error
    iny
    cpy #.sizeof(sPart)
    blt @loop
    jmp _ContinueCurrentPart
.ENDPROC

;;; Continues playing the current music part.  If any notes/rests were played
;;; this frame, sets Zp_MusicMadeProgress_bool to true ($ff).  Otherwise,
;;; leaves Zp_MusicMadeProgress_bool unchanged, and the part is now finished.
.PROC Func_AudioContinuePart
    ;; Loop over APU channels, and continue music chain for each.
    .assert bApuStatus::Dmc = $10, error
    lda #bApuStatus::Dmc
    sta Zp_CurrentChannel_bApuStatus
    ldx #.sizeof(sChanNext) * (kNumApuChannels - 1)
    @loop:
    jsr Func_AudioContinueChain  ; preserves X
    lsr Zp_CurrentChannel_bApuStatus
    beq @done
    txa
    sub #.sizeof(sChanNext)
    tax
    .assert .sizeof(sChanNext) * kNumApuChannels <= $80, error
    bpl @loop  ; unconditional
    @done:
    rts
.ENDPROC

;;; Continues playing the current music chain for one APU channel.  If any
;;; notes/rests were played this frame, sets Zp_MusicMadeProgress_bool to true
;;; ($ff).  Otherwise, leaves Zp_MusicMadeProgress_bool unchanged, and the
;;; chain is now finished.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @preserve X
.PROC Func_AudioContinueChain
_ContinuePhrase:
    jsr Func_AudioContinuePhrase  ; preserves X, clears C if progress was made
    bcs _StartNextPhrase
    lda #$ff
    sta Zp_MusicMadeProgress_bool
    rts
_StartNextPhrase:
    lda (Zp_Music_sChanNext_arr + sChanNext::ChainNext_u8_ptr, x)
    bmi _ChainFinished
    ;; Initialize the next phrase.
    mul #2
    tay
    lda (Zp_Current_sMusic + sMusic::Phrases_sPhrase_ptr_arr_ptr), y
    sta Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    iny
    lda (Zp_Current_sMusic + sMusic::Phrases_sPhrase_ptr_arr_ptr), y
    sta Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    ;; Increment the channel's ChainNext_u8_ptr.
    inc Zp_Music_sChanNext_arr + sChanNext::ChainNext_u8_ptr + 0, x
    bne _ContinuePhrase
    inc Zp_Music_sChanNext_arr + sChanNext::ChainNext_u8_ptr + 1, x
    bne _ContinuePhrase  ; unconditional
_ChainFinished:
    rts
.ENDPROC

;;; Continues playing the current music phrase for one APU channel.  If any
;;; notes/rests were played this frame, clears the C (carry) flag.  Otherwise,
;;; sets the C flag, and the phrase is now finished.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if no note/rest was played, and the phrase is now finished.
;;; @preserve X
.PROC Func_AudioContinuePhrase
    lda Ram_Music_sChanState_arr + sChanState::NoteFrames_u8, x
    cmp Ram_Music_sChanState_arr + sChanState::NoteDuration_u8, x
    bge _StartNextNote
_ContinueNote:
    ;; TODO: Jump to _IncrementFramesAndReturn if this channel is playing SFX.
    ;;
    ;; If the channel is disabled, then we're playing a rest (rather than a
    ;; tone).
    lda Zp_CurrentChannel_bApuStatus
    and Zp_ActiveChannels_bApuStatus
    beq _IncrementFramesAndReturn
_ContinueTone:
    jsr Func_AudioCallInstrument  ; preserves X, returns A
    ;; TODO: Apply master volume.
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
_IncrementFramesAndReturn:
    inc Ram_Music_sChanState_arr + sChanState::NoteFrames_u8, x
    clc  ; clear C to indicate that the phrase is still going
    rts
_StartNextNote:
    ;; Read the first byte of the next note.  If it's zero, we've reached the
    ;; end of the phrase.
    lda (Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr, x)
    beq _NoteDone
    sta Zp_AudioTmp1_byte  ; first note byte
    ;; Increment the channel's PhraseNext_ptr.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne @incDone
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    @incDone:
    ;; Determine what kind of note this is.
    bit Zp_AudioTmp1_byte  ; first note byte
    .assert bNote::NotRest = bProc::Negative, error
    bpl _NoteRest
    .assert bNote::IsTone = bProc::Overflow, error
    bvc _NoteInst
_NoteTone:
    ;; Enable the channel.
    lda Zp_CurrentChannel_bApuStatus
    ora Zp_ActiveChannels_bApuStatus
    sta Zp_ActiveChannels_bApuStatus
    sta Hw_ApuStatus_rw
    ;; Reset sweep and note frames.
    lda #0
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Sweep_wo, x
    sta Ram_Music_sChanState_arr + sChanState::NoteFrames_u8, x
    ;; Read the second byte of the TONE note and use it as the TimerLo value.
    lda (Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr, x)
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    ;; Mask the first byte of the TONE note and use it as the TimerHi value.
    lda Zp_AudioTmp1_byte  ; first note byte
    and #bNote::ToneMask
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    ;; Increment the channel's PhraseNext_ptr a second time.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne @incDone2
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    @incDone2:
    ;; Read the third byte of the TONE note and use it as the note duration.
    lda (Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr, x)
    sta Ram_Music_sChanState_arr + sChanState::NoteDuration_u8, x
    ;; Increment the channel's PhraseNext_ptr a third time.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne _ContinueTone
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    bne _ContinueTone  ; unconditional
_NoteInst:
    and #bNote::InstMask
    ;; Set this channel's current instrument to entry number A in the music's
    ;; instrument array.
    mul #2
    tay
    lda (Zp_Current_sMusic + sMusic::Instruments_func_ptr_arr_ptr), y
    sta Ram_Music_sChanState_arr + sChanState::Instrument_func_ptr + 0, x
    iny
    lda (Zp_Current_sMusic + sMusic::Instruments_func_ptr_arr_ptr), y
    sta Ram_Music_sChanState_arr + sChanState::Instrument_func_ptr + 1, x
    jmp _StartNextNote
_NoteDone:
    sec  ; set C to indicate that the phrase has finished
    bcs _DisableChannel  ; unconditional
_NoteRest:
    ;; Record the rest duration.
    sta Ram_Music_sChanState_arr + sChanState::NoteDuration_u8, x
    lda #1
    sta Ram_Music_sChanState_arr + sChanState::NoteFrames_u8, x
    clc  ; clear C to indicate that the phrase is still going
_DisableChannel:
    lda Zp_CurrentChannel_bApuStatus
    eor #$ff
    and Zp_ActiveChannels_bApuStatus
    sta Zp_ActiveChannels_bApuStatus
    sta Hw_ApuStatus_rw
    rts
.ENDPROC

;;; Calls the current instrument function for the specified music channel.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return A The duty/envelope byte to use.
;;; @preserve X
.PROC Func_AudioCallInstrument
    lda Ram_Music_sChanState_arr + sChanState::Instrument_func_ptr + 0, x
    sta Zp_AudioTmp1_byte
    lda Ram_Music_sChanState_arr + sChanState::Instrument_func_ptr + 1, x
    sta Zp_AudioTmp2_byte
    .assert Zp_AudioTmp1_byte + 1 = Zp_AudioTmp2_byte, error
    jmp (Zp_AudioTmp1_byte)
.ENDPROC

;;; Continues playing any active sound effects.
.PROC Func_AudioContinueSfx
    ;; TODO: Implement SFX
    rts
.ENDPROC

;;;=========================================================================;;;
