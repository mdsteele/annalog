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

.INCLUDE "macros.inc"
.INCLUDE "sound.inc"

.IMPORT Func_Noop
.IMPORT Func_SfxBeep
.IMPORT Func_SfxExplode
.IMPORT Func_SfxQuest
.IMPORT Func_SfxSample
.IMPORT Func_SfxSequence
.IMPORTZP Zp_AudioTmp1_byte
.IMPORTZP Zp_AudioTmp2_byte

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Calls the SFX function for the specified sound on the specified APU
;;; channel.
;;; @param X The channel number (0-4) times four (so, 0, 4, 8, 12, or 16).
;;; @param Y The eSound value for the SFX function to call.
;;; @return C Set if the sound is finished, cleared otherwise.
;;; @preserve X, T0+
.EXPORT Func_AudioCallSfx
.PROC Func_AudioCallSfx
    lda Data_Sfx_func_ptr_0_arr, y
    sta Zp_AudioTmp1_byte
    lda Data_Sfx_func_ptr_1_arr, y
    sta Zp_AudioTmp2_byte
    .assert Zp_AudioTmp1_byte + 1 = Zp_AudioTmp2_byte, error
    jmp (Zp_AudioTmp1_byte)
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
    D_TABLE eSound
    d_entry table, None,     Func_Noop
    d_entry table, Beep,     Func_SfxBeep
    d_entry table, Explode,  Func_SfxExplode
    d_entry table, Quest,    Func_SfxQuest
    d_entry table, Sample,   Func_SfxSample
    d_entry table, Sequence, Func_SfxSequence
    D_END
.ENDREPEAT

;;;=========================================================================;;;
