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
.INCLUDE "music.inc"
.INCLUDE "sound.inc"

.IMPORT Data_Empty_bChain_arr
.IMPORT Data_Empty_sPhrase
.IMPORT Data_Music_sMusic_ptr_0_arr
.IMPORT Data_Music_sMusic_ptr_1_arr
.IMPORT Func_AudioCallInstrument
.IMPORT Func_AudioCallSfx

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
    ;; A pointer to the next item in the current chain to execute once the
    ;; current phrase finishes.
    Next_bChain_ptr .addr
    ;; A pointer to the next note in the current phrase to execute once the
    ;; current note finishes.
    PhraseNext_ptr  .addr
.ENDSTRUCT

;;; Assert that all the channel structs we use are exactly four bytes.  This
;;; allows us to use four times the channel number as a byte index into any the
;;; struct arrays.
.ASSERT .sizeof(sChanCtrl) = 4, error
.ASSERT .sizeof(sChanNext) = 4, error
.ASSERT .sizeof(sChanNote) = 4, error
.ASSERT .sizeof(sChanRegs) = 4, error
.ASSERT .sizeof(sChanSfx)  = 4, error

;;;=========================================================================;;;

.ZEROPAGE

;;; Stores commands that will be sent to the audio driver the next time that
;;; Func_ProcessFrame is called.  The main thread can read/write these freely;
;;; the audio thread will only read/write these during a call to
;;; Func_ProcessFrame.
.EXPORTZP Zp_Next_sAudioCtrl
Zp_Next_sAudioCtrl: .tag sAudioCtrl
.EXPORTZP Zp_Next_sChanSfx_arr
Zp_Next_sChanSfx_arr: .res .sizeof(sChanSfx) * kNumApuChannels

;;; The current settings for whether audio is enabled.
.EXPORTZP Zp_Current_bAudio
Zp_Current_bAudio: .res 1

;;; The currently-playing music.
Zp_Current_eMusic: .res 1

;;; A copy of the currently-playing music struct.  Storing this in the zero
;;; page allows us to use the Zero Page Indirect Y-Indexed addressing mode to
;;; index into the various arrays that this struct has pointers to.
Zp_Current_sMusic: .tag sMusic

;;; Music "next byte" pointers for all the different APU channels.  This array
;;; uses a bunch of space in the zero page, but doing so allows us to use the
;;; X-Indexed Zero Page Indirect addressing mode to read these next bytes while
;;; indexing by APU channel number.
Zp_Music_sChanNext_arr: .res .sizeof(sChanNext) * kNumApuChannels

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

;;; Temporary variables that any audio-thread function can use, including
;;; custom instrument and SFX functions.
.EXPORTZP Zp_AudioTmp_byte
Zp_AudioTmp_byte: .res 1
.EXPORTZP Zp_AudioTmp_ptr
Zp_AudioTmp_ptr: .res kSizeofAddr

;;;=========================================================================;;;

.SEGMENT "RAM_Audio"

;;; Music/SFX channel state for all the different APU channels.
.EXPORT Ram_Audio_sChanCtrl_arr
Ram_Audio_sChanCtrl_arr: .res .sizeof(sChanCtrl) * kNumApuChannels
.EXPORT Ram_Audio_sChanNote_arr
Ram_Audio_sChanNote_arr: .res .sizeof(sChanNote) * kNumApuChannels
.EXPORT Ram_Audio_sChanSfx_arr
Ram_Audio_sChanSfx_arr: .res .sizeof(sChanSfx) * kNumApuChannels

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mutes all APU channels, resets APU registers, disables APU IRQs, and
;;; initializes audio driver RAM.
;;; @thread RESET, NMI
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
    ;; Reset all APU channel registers by writing zero to all of them (except
    ;; for Hw_DmcLevel_wo, which we set to the mid-level value of $40 out of
    ;; $7f to avoid popping noises).  The fact that we zero Hw_DmcFlags_wo here
    ;; also has the effect of disabling DMC channel IRQs.
    ldx #.sizeof(sChanRegs) * kNumApuChannels - 1
    @loop:
    cpx #Hw_DmcLevel_wo - Hw_Channels_sChanRegs_arr5
    beq @continue  ; don't zero Hw_DmcLevel_wo
    sta Hw_Channels_sChanRegs_arr5, x  ; A is still zero
    @continue:
    dex
    bpl @loop
    lda #$40
    sta Hw_DmcLevel_wo
    ;; Disable audio and reset music flag.
    sta Zp_Current_bAudio
    sta Zp_MusicFlag_bMusic
_HaltMusic:
    .assert eMusic::Silence = 0, error
    tax  ; param: eMusic to play (A is zero, so this is eMusic::Silence)
    jsr Func_AudioRestartMusic
_HaltSfx:
    lda #0
    ldx #.sizeof(sChanSfx) * kNumApuChannels - 1
    @loop:
    sta Ram_Audio_sChanSfx_arr, x
    dex
    .assert .sizeof(sChanSfx) * kNumApuChannels <= $80, error
    bpl @loop
    rts
.ENDPROC

;;; Reads from Zp_Next_sAudioCtrl and updates the audio driver accordingly.
;;; @thread NMI
;;; @prereq Caller is within the NMI handler, and Func_ProcessFrame is pending.
.EXPORT Func_AudioSync
.PROC Func_AudioSync
    lda Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
    .assert bAudio::Enable = $80, error
    bmi _Enable
_Disable:
    ;; If audio wasn't already disabled, reset audio.
    bit Zp_Current_bAudio
    .assert bAudio::Enable = bProc::Negative, error
    bmi Func_AudioReset
    rts
_Enable:
    sta Zp_Current_bAudio
_SyncMusicFlag:
    lda Zp_Next_sAudioCtrl + sAudioCtrl::MusicFlag_bMusic
    .assert bMusic::UsesFlag = bProc::Negative, error
    bpl @done
    and #bMusic::FlagMask
    sta Zp_MusicFlag_bMusic
    @done:
    lda Zp_MusicFlag_bMusic
    sta Zp_Next_sAudioCtrl + sAudioCtrl::MusicFlag_bMusic
_StartMusic:
    ldx Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic  ; param: eMusic to play
    cpx Zp_Current_eMusic
    beq @done
    jsr Func_AudioRestartMusic
    @done:
_StartSfx:
    ;; Loop over all APU channels.
    lda #bApuStatus::Dmc
    sta Zp_CurrentChannel_bApuStatus
    ldx #eChan::Dmc
    @loop:
    ;; Check if there's an SFX to start on this channel.  If not, continue to
    ;; the next channel.
    lda Zp_Next_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    beq @continue
    ;; Otherwise, copy this sChanSfx struct into Ram_Audio_sChanSfx_arr.
    sta Ram_Audio_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    lda Zp_Next_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 0, x
    sta Ram_Audio_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 0, x
    lda Zp_Next_sChanSfx_arr + sChanSfx::Param1_byte, x
    sta Ram_Audio_sChanSfx_arr + sChanSfx::Param1_byte, x
    lda Zp_Next_sChanSfx_arr + sChanSfx::Param2_byte, x
    sta Ram_Audio_sChanSfx_arr + sChanSfx::Param2_byte, x
    ;; Null out the hi byte of the NextOp_sSfx_ptr field in Zp_Next_sAudioCtrl,
    ;; so we don't restart this SFX again next frame, and reset the repeat
    ;; counter.
    lda #0
    sta Zp_Next_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    sta Ram_Audio_sChanCtrl_arr + sChanCtrl::SfxRepeat_u8, x
    ;; Disable the channel that the sound is about to play on, so as to reset
    ;; its state (it'll get enabled again when we call the SFX function).
    jsr Func_DisableCurrentChannel  ; preserves X
    ;; Continue to the next channel.
    @continue:
    .repeat .sizeof(sChanSfx)
    dex
    .endrepeat
    lsr Zp_CurrentChannel_bApuStatus
    bne @loop
    @done:
    rts
.ENDPROC

;;; Sets audio RAM to start playing the specific music from the beginning.
;;; @thread RESET, NMI
;;; @param X The eMusic value to start playing.
.PROC Func_AudioRestartMusic
    stx Zp_Current_eMusic
_CopyMusicStruct:
    lda Data_Music_sMusic_ptr_0_arr, x
    sta Zp_AudioTmp_ptr + 0
    lda Data_Music_sMusic_ptr_1_arr, x
    sta Zp_AudioTmp_ptr + 1
    ldy #.sizeof(sMusic) - 1
    @loop:
    lda (Zp_AudioTmp_ptr), y
    sta Zp_Current_sMusic, y
    dey
    .assert .sizeof(sMusic) <= $80, error
    bpl @loop
_ResetChannels:
    lda #0
    sta Zp_MusicOpcodeIndex_u8
    tax  ; now X is zero
    @loop:
    ;; At this point, A is still zero.
    sta Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    sta Ram_Audio_sChanNote_arr + sChanNote::DurationFrames_u8, x
    sta Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    sta Ram_Audio_sChanNote_arr + sChanNote::TimerHi_byte, x
    sta Ram_Audio_sChanCtrl_arr + sChanCtrl::Instrument_eInst, x
    sta Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    sta Ram_Audio_sChanCtrl_arr + sChanCtrl::ChainRepeat_u8, x
    .assert Data_Empty_bChain_arr = Data_Empty_sPhrase, error
    ldy #<Data_Empty_bChain_arr
    sty Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 0, x
    sty Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    ldy #>Data_Empty_bChain_arr
    sty Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 1, x
    sty Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    .repeat .sizeof(sChanNext)
    inx
    .endrepeat
    cpx #.sizeof(sChanNext) * kNumApuChannels
    blt @loop
    rts
.ENDPROC

;;; Updates audio playback.  This should be called once per frame.  If audio is
;;; disabled, this is a no-op.
;;; @thread AUDIO
.EXPORT Func_AudioUpdate
.PROC Func_AudioUpdate
    bit Zp_Current_bAudio
    .assert bAudio::Enable = bProc::Negative, error
    bmi _Enabled
    rts
_Enabled:
    jsr Func_AudioContinueAllSfx
    fall Func_AudioContinueMusic
.ENDPROC

;;; Continues playing the current music.
;;; @thread AUDIO
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
    sta Zp_AudioTmp_byte
    mul #4
    adc Zp_AudioTmp_byte
    tay  ; byte offset for part in Parts_sPart_arr_ptr
    ;; Read in the sPart struct and populate Zp_Music_sChanNext_arr.
    ldx #0
    @loop:
    .assert sChanNext::Next_bChain_ptr = 0, error
    lda (Zp_Current_sMusic + sMusic::Parts_sPart_arr_ptr), y
    sta Zp_Music_sChanNext_arr, x
    inx
    iny
    lda (Zp_Current_sMusic + sMusic::Parts_sPart_arr_ptr), y
    sta Zp_Music_sChanNext_arr, x
    inx
    iny
    .assert sChanNext::PhraseNext_ptr = 2, error
    lda #<Data_Empty_sPhrase
    sta Zp_Music_sChanNext_arr, x
    inx
    lda #>Data_Empty_sPhrase
    sta Zp_Music_sChanNext_arr, x
    inx
    .assert .sizeof(sChanNext) = 4, error
    cpx #.sizeof(sChanNext) * kNumApuChannels
    blt @loop
    jmp _ContinueCurrentPart
.ENDPROC

;;; Continues playing the current music part.  If any notes/rests were played
;;; this frame, sets Zp_MusicMadeProgress_bool to true ($ff).  Otherwise,
;;; leaves Zp_MusicMadeProgress_bool unchanged, and the part is now finished.
;;; @thread AUDIO
.PROC Func_AudioContinuePart
    ;; Loop over APU channels, and continue music chain for each.
    .assert bApuStatus::Dmc = $10, error
    lda #bApuStatus::Dmc
    sta Zp_CurrentChannel_bApuStatus
    ldx #.sizeof(sChanNext) * (kNumApuChannels - 1)
    @loop:
    jsr Func_AudioContinueChain  ; preserves X
    .repeat .sizeof(sChanSfx)
    dex
    .endrepeat
    lsr Zp_CurrentChannel_bApuStatus
    bne @loop
    rts
.ENDPROC

;;; Continues playing the current music chain for one APU channel.  If any
;;; notes/rests were played this frame, sets Zp_MusicMadeProgress_bool to true
;;; ($ff).  Otherwise, leaves Zp_MusicMadeProgress_bool unchanged, and the
;;; chain is now finished.
;;; @thread AUDIO
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @preserve X
.PROC Func_AudioContinueChain
_ContinuePhrase:
    jsr Func_AudioContinuePhrase  ; preserves X, clears C if progress was made
    bcs _ReadNextItem
    lda #$ff
    sta Zp_MusicMadeProgress_bool
    rts
_FinishRepeat:
    lda #0
    sta Ram_Audio_sChanCtrl_arr + sChanCtrl::ChainRepeat_u8, x
    inc Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 0, x
    bne _ReadNextItem
    inc Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 1, x
    bne _ReadNextItem  ; unconditional
_StartRepeat:
    inc Ram_Audio_sChanCtrl_arr + sChanCtrl::ChainRepeat_u8, x
    cmp Ram_Audio_sChanCtrl_arr + sChanCtrl::ChainRepeat_u8, x
    beq _FinishRepeat
    ;; Decrement the channel's Next_bChain_ptr.
    lda Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 0, x
    bne @decLo
    dec Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 1, x
    @decLo:
    dec Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 0, x
_ReadNextItem:
    lda (Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr, x)
    beq _ChainFinished
    bpl _StartRepeat
_StartNextPhrase:
    ;; Initialize the next phrase.
    mul #2
    tay
    lda (Zp_Current_sMusic + sMusic::Phrases_sPhrase_ptr_arr_ptr), y
    sta Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    iny
    lda (Zp_Current_sMusic + sMusic::Phrases_sPhrase_ptr_arr_ptr), y
    sta Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    ;; Increment the channel's Next_bChain_ptr.
    inc Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 0, x
    bne _ContinuePhrase
    inc Zp_Music_sChanNext_arr + sChanNext::Next_bChain_ptr + 1, x
    bne _ContinuePhrase  ; unconditional
_ChainFinished:
    rts
.ENDPROC

;;; Continues playing the current music phrase for one APU channel.  If any
;;; notes/rests were played this frame, clears the C (carry) flag.  Otherwise,
;;; sets the C flag, and the phrase is now finished.
;;; @thread AUDIO
;;; @prereq Zp_CurrentChannel_bApuStatus is initialized.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if no note/rest was played, and the phrase is now finished.
;;; @preserve X
.PROC Func_AudioContinuePhrase
    lda Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    cmp Ram_Audio_sChanNote_arr + sChanNote::DurationFrames_u8, x
    bge _StartNextNote
_ContinueNote:
    ;; If this channel is playing SFX, then don't play music on this channel.
    lda Ram_Audio_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    bne _IncrementFramesAndReturn  ; a sound is playing
    ;; Otherwise, if the channel is disabled, then we're playing a rest (rather
    ;; than a tone).
    lda Zp_CurrentChannel_bApuStatus
    and Zp_ActiveChannels_bApuStatus
    beq _IncrementFramesAndReturn
_ContinueTone:
    jsr Func_AudioCallInstrument  ; preserves X, returns A
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
_IncrementFramesAndReturn:
    inc Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    clc  ; clear C to indicate that the phrase is still going
    rts
_StartNextNote:
    ;; Read the first byte of the next note.  If it's zero, we've reached the
    ;; end of the phrase.
    lda (Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr, x)
    beq _NoteDone
    sta Zp_AudioTmp_byte  ; first note byte
    ;; Increment the channel's PhraseNext_ptr.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne @incDone
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    @incDone:
    ;; Determine what kind of note this is.
    bit Zp_AudioTmp_byte  ; first note byte
    .assert bNote::IsToneOrSame = bProc::Negative, error
    bpl _NoteInstOrRest
_NoteToneOrSame:
    ;; If this channel is playing SFX, skip this tone.
    lda Ram_Audio_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    bne _SkipToneOrSame  ; a sound is playing
    sta Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x  ; A is zero
    ;; For non-DMC channels, we need to enable the channel *before* writing the
    ;; registers (because otherwise the writes won't take effect), and we want
    ;; to reset sweep to kNoSweep by default.  For the DMC channel, the sweep
    ;; register is used for setting the DMC level directly, and we want to
    ;; reset it back to the mid-level value of $40 out of $7f.
    cpx #eChan::Dmc
    bne @notDmc
    @isDmc:
    ;; Skip DMC notes entirely when music volume is reduced.
    bit Zp_Current_bAudio
    .assert bAudio::ReduceMusic = bProc::Overflow, error
    bvs _SkipToneOrSame
    lda #$40
    bne @setSweep  ; unconditional
    @notDmc:
    jsr Func_EnableCurrentChannel  ; preserves X and Zp_AudioTmp*
    lda #kNoSweep
    @setSweep:
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Sweep_wo, x
    ;; Read the second byte of the TONE/SAME note and use it as the TimerLo
    ;; value.
    lda (Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr, x)
    sta Ram_Audio_sChanNote_arr + sChanNote::TimerLo_byte, x
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    ;; Mask the first byte of the TONE/SAME note and use it as the TimerHi
    ;; value.
    lda Zp_AudioTmp_byte  ; first note byte
    and #bNote::ToneSameMask
    sta Ram_Audio_sChanNote_arr + sChanNote::TimerHi_byte, x
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    ;; For the DMC channel, we need to enable the channel *after* updating the
    ;; registers (because otherwise it will restart the previous sample).
    cpx #eChan::Dmc
    bne @enableDone
    jsr Func_EnableCurrentChannel  ; preserves X and Zp_AudioTmp*
    @enableDone:
    ;; Increment the channel's PhraseNext_ptr a second time.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne @incDone2
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    @incDone2:
    ;; If this is a SAME note, there's no third byte; we just reuse the
    ;; previous duration value.
    bit Zp_AudioTmp_byte  ; first note byte
    .assert bNote::IsSame = bProc::Overflow, error
    bvs _ContinueTone
    ;; Read the third byte of the TONE note and use it as the note duration.
    lda (Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr, x)
    sta Ram_Audio_sChanNote_arr + sChanNote::DurationFrames_u8, x
    ;; Increment the channel's PhraseNext_ptr a third time.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne _ContinueTone
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    bne _ContinueTone  ; unconditional
_NoteInstOrRest:
    .assert bNote::IsInst = bProc::Overflow, error
    bvc _NoteRest
_NoteInst:
    and #bNote::InstMask
    sta Ram_Audio_sChanCtrl_arr + sChanCtrl::Instrument_eInst, x
    .assert bNote::InstMask & $80 = 0, error
    ;; Read the second byte of the INST note and use it as the param byte.
    lda (Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr, x)
    sta Ram_Audio_sChanCtrl_arr + sChanCtrl::InstParam_byte, x
    ;; Increment the channel's PhraseNext_ptr a second time.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne _StartNextNote
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    bne _StartNextNote  ; unconditional
_NoteDone:
    sec  ; set C to indicate that the phrase has finished
    bcs _DisableChannelUnlessSfx  ; unconditional
_NoteRest:
    ;; Record the rest duration.
    sta Ram_Audio_sChanNote_arr + sChanNote::DurationFrames_u8, x
    lda #1
    sta Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    clc  ; clear C to indicate that the phrase is still going
_DisableChannelUnlessSfx:
    ;; Disable this channel unless it's playing SFX.
    lda Ram_Audio_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    beq Func_DisableCurrentChannel  ; preserves C and X
    rts
_SkipToneOrSame:
    lda #1
    sta Ram_Audio_sChanNote_arr + sChanNote::ElapsedFrames_u8, x
    ;; Increment the channel's PhraseNext_ptr a second time.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne @incDone2
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    @incDone2:
    ;; If this is a SAME note, there's no third byte; we just reuse the
    ;; previous duration value.
    bit Zp_AudioTmp_byte  ; first note byte
    .assert bNote::IsSame = bProc::Overflow, error
    bvs @incDone3
    ;; Read the third byte of the TONE note and use it as the note duration.
    lda (Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr, x)
    sta Ram_Audio_sChanNote_arr + sChanNote::DurationFrames_u8, x
    ;; Increment the channel's PhraseNext_ptr a third time.
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 0, x
    bne @incDone3
    inc Zp_Music_sChanNext_arr + sChanNext::PhraseNext_ptr + 1, x
    @incDone3:
    clc  ; clear C to indicate that the phrase is still going
    rts
.ENDPROC

;;; Continues playing any active sound effects.
;;; @thread AUDIO
.PROC Func_AudioContinueAllSfx
    ;; Loop over APU channels, and continue SFX for each.
    .assert bApuStatus::Dmc = $10, error
    lda #bApuStatus::Dmc
    sta Zp_CurrentChannel_bApuStatus
    ldx #eChan::Dmc
    @loop:
    jsr Func_AudioContinueOneSfx  ; preserves X
    .repeat .sizeof(sChanSfx)
    dex
    .endrepeat
    lsr Zp_CurrentChannel_bApuStatus
    bne @loop
    rts
.ENDPROC

;;; Continues playing the active SFX (if any) for the specified APU channel.
;;; @thread AUDIO
;;; @prereq Zp_CurrentChannel_bApuStatus is initialized.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @preserve X
.PROC Func_AudioContinueOneSfx
    ;; Check if there's an active SFX.  If not, we're done.
    lda Ram_Audio_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    beq _Return
    ;; For non-DMC channels, we need to enable the channel *before* calling the
    ;; SFX function (because otherwise the register writes won't take effect).
    cpx #eChan::Dmc
    beq @callSfx
    jsr Func_EnableCurrentChannel  ; preserves X
    @callSfx:
    ;; Call the SFX function and check if the sound is now finished.
    jsr Func_AudioCallSfx  ; preserves X, sets C if sound is done
    bcs _SoundFinished
    ;; For the DMC channel, we need to enable the channel *after* calling the
    ;; SFX function (because otherwise it will restart the previous sample).
    cpx #eChan::Dmc
    beq Func_EnableCurrentChannel  ; preserves X
_Return:
    rts
_SoundFinished:
    ;; Halt the SFX by nulling out the hi byte of the NextOp_sSfx_ptr field.
    lda #0
    sta Ram_Audio_sChanSfx_arr + sChanSfx::NextOp_sSfx_ptr + 1, x
    ;; Disable the channel.
    fall Func_DisableCurrentChannel  ; preserves X
.ENDPROC

;;; Disables the current APU channel.
;;; @thread AUDIO
;;; @prereq Zp_CurrentChannel_bApuStatus is initialized.
;;; @preserve C, X, Y, Zp_AudioTmp*
.PROC Func_DisableCurrentChannel
    lda Zp_CurrentChannel_bApuStatus
    eor #$ff
    and Zp_ActiveChannels_bApuStatus
    sta Zp_ActiveChannels_bApuStatus
    sta Hw_ApuStatus_rw
    rts
.ENDPROC

;;; Enables the current APU channel.
;;; @thread AUDIO
;;; @prereq Zp_CurrentChannel_bApuStatus is initialized.
;;; @preserve C, X, Y, Zp_AudioTmp*
.PROC Func_EnableCurrentChannel
    lda Zp_CurrentChannel_bApuStatus
    ora Zp_ActiveChannels_bApuStatus
    sta Zp_ActiveChannels_bApuStatus
    sta Hw_ApuStatus_rw
    rts
.ENDPROC

;;;=========================================================================;;;
