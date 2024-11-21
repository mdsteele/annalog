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
.INCLUDE "sound.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT Func_Noop
.IMPORT Func_SfxDialogText
.IMPORT Func_SfxExplode
.IMPORT Ram_Audio_sChanCtrl_arr
.IMPORT Ram_Audio_sChanSfx_arr
.IMPORTZP Zp_AudioTmp_byte
.IMPORTZP Zp_AudioTmp_ptr
.IMPORTZP Zp_Next_sChanSfx_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; SFX function for playing sSfx operations.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.PROC Func_SfxBytecode
_ExecuteNext:
    lda Ram_Audio_sChanSfx_arr + sChanSfx::Param1_byte, x
    sta Zp_AudioTmp_ptr + 0
    lda Ram_Audio_sChanSfx_arr + sChanSfx::Param2_byte, x
    sta Zp_AudioTmp_ptr + 1
    ldy #0
    lda (Zp_AudioTmp_ptr), y  ; opcode
    bmi _CallFunc
    beq _EndSound
_WaitOrSet:
    iny  ; now Y is 1
    .assert bSfxOp::Set = 1 << 6, error
    bit Data_PowersOfTwo_u8_arr8 + 6
    bne _SetRegisters
_WaitFrames:
    cmp Ram_Audio_sChanCtrl_arr + sChanCtrl::SfxRepeat_u8, x
    beq _AdvanceByY
    inc Ram_Audio_sChanCtrl_arr + sChanCtrl::SfxRepeat_u8, x
    clc  ; clear C to indicate that the sound is still going
    rts
_SetRegisters:
    sta Zp_AudioTmp_byte  ; opcode
    ;; Set Envelope if that bit is set in the opcode.
    lsr Zp_AudioTmp_byte  ; opcode
    bcc @doneEnvelope
    lda (Zp_AudioTmp_ptr), y
    iny
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Envelope_wo, x
    @doneEnvelope:
    ;; Set Sweep if that bit is set in the opcode.
    lsr Zp_AudioTmp_byte  ; opcode
    bcc @doneSweep
    lda (Zp_AudioTmp_ptr), y
    iny
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::Sweep_wo, x
    @doneSweep:
    ;; Set TimerLo if that bit is set in the opcode.
    lsr Zp_AudioTmp_byte  ; opcode
    bcc @doneTimerLo
    lda (Zp_AudioTmp_ptr), y
    iny
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerLo_wo, x
    @doneTimerLo:
    ;; Set TimerHi if that bit is set in the opcode.
    lsr Zp_AudioTmp_byte  ; opcode
    bcc @doneTimerHi
    lda (Zp_AudioTmp_ptr), y
    iny
    sta Hw_Channels_sChanRegs_arr5 + sChanRegs::TimerHi_wo, x
    @doneTimerHi:
_AdvanceByY:
    tya
_AdvanceByA:
    ;; Add A to the param pointer, and reset repeat count to zero.
    add Ram_Audio_sChanSfx_arr + sChanSfx::Param1_byte, x
    sta Ram_Audio_sChanSfx_arr + sChanSfx::Param1_byte, x
    lda #0
    sta Ram_Audio_sChanCtrl_arr + sChanCtrl::SfxRepeat_u8, x
    adc Ram_Audio_sChanSfx_arr + sChanSfx::Param2_byte, x
    sta Ram_Audio_sChanSfx_arr + sChanSfx::Param2_byte, x
    jmp _ExecuteNext
_EndSound:
    sec  ; set C to indicate that the sound is finished
    rts
_CallFunc:
    pha  ; func addr (hi)
    iny  ; now Y is 1
    lda (Zp_AudioTmp_ptr), y  ; func addr (lo)
    sta Zp_AudioTmp_ptr + 0
    pla  ; func addr (hi)
    sta Zp_AudioTmp_ptr + 1
    ldy Ram_Audio_sChanCtrl_arr + sChanCtrl::SfxRepeat_u8, x  ; param: count
    inc Ram_Audio_sChanCtrl_arr + sChanCtrl::SfxRepeat_u8, x
    jsr _CallAudioTmpPtr  ; preserves X and T0+, returns C
    lda #2  ; byte offset
    bcs _AdvanceByA
    rts  ; C is clear, so sound will continue
_CallAudioTmpPtr:
    jmp (Zp_AudioTmp_ptr)
.ENDPROC

;;; Starts playing a sSfx-based sound effect on the Noise channel.
;;; @param YA The sSfx pointer.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxBytecodeNoise
.PROC Func_PlaySfxBytecodeNoise
    ldx #eChan::Noise  ; param: eChan value
    .assert eChan::Noise > 0, error
    bne Func_PlaySfxBytecode  ; unconditional; preserves T0+
.ENDPROC

;;; Starts playing a sSfx-based sound effect on the Pulse2 channel.
;;; @param YA The sSfx pointer.
;;; @preserve X, T0+
.EXPORT Func_PlaySfxBytecodePulse2
.PROC Func_PlaySfxBytecodePulse2
    ldx #eChan::Pulse2  ; param: eChan value
    fall Func_PlaySfxBytecode  ; preserves T0+
.ENDPROC

;;; Starts playing a sSfxSeq-based sound effect.
;;; @param X The eChan value for channel to play the sound on.
;;; @param YA The sSfx pointer.
;;; @preserve T0+
.EXPORT Func_PlaySfxBytecode
.PROC Func_PlaySfxBytecode
    sta Zp_Next_sChanSfx_arr + sChanSfx::Param1_byte, x
    sty Zp_Next_sChanSfx_arr + sChanSfx::Param2_byte, x
    lda #eSound::Bytecode
    sta Zp_Next_sChanSfx_arr + sChanSfx::Sfx_eSound, x
    rts
.ENDPROC

;;; Calls the SFX function for the specified sound on the specified APU
;;; channel.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @param Y The eSound value for the SFX function to call.
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.EXPORT Func_AudioCallSfx
.PROC Func_AudioCallSfx
    lda Data_Sfx_func_ptr_0_arr, y
    sta Zp_AudioTmp_ptr + 0
    lda Data_Sfx_func_ptr_1_arr, y
    sta Zp_AudioTmp_ptr + 1
    jmp (Zp_AudioTmp_ptr)
.ENDPROC

;;; Maps from eSound enum values to SFX function pointers.  An SFX function is
;;; called each frame that the sound effect is active to update the channel's
;;; APU registers.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.REPEAT 2, table
    D_TABLE_LO table, Data_Sfx_func_ptr_0_arr
    D_TABLE_HI table, Data_Sfx_func_ptr_1_arr
    D_TABLE .enum, eSound
    d_entry table, None,       Func_Noop
    d_entry table, Bytecode,   Func_SfxBytecode
    d_entry table, DialogText, Func_SfxDialogText
    d_entry table, Explode,    Func_SfxExplode
    D_END
.ENDREPEAT

;;;=========================================================================;;;
