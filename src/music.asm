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
.INCLUDE "music.inc"

.IMPORT Data_EmptyChain_u8_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Maps from eMusic enum values to sMusic struct pointers.
.EXPORT Data_Music_sMusic_ptr_0_arr
.EXPORT Data_Music_sMusic_ptr_1_arr
.REPEAT 2, table
    D_TABLE_LO table, Data_Music_sMusic_ptr_0_arr
    D_TABLE_HI table, Data_Music_sMusic_ptr_1_arr
    D_TABLE eMusic
    d_entry table, Silence, Data_Silence_sMusic
    d_entry table, Title,   Data_Title_Placeholder_sMusic
    D_END
.ENDREPEAT

;;; A sMusic struct that just plays silence.
.PROC Data_Silence_sMusic
    D_STRUCT sMusic
    d_addr Opcodes_bMusic_arr_ptr, _Opcodes_bMusic_arr
    d_addr Parts_sPart_arr_ptr, 0
    d_addr Phrases_sPhrase_ptr_arr_ptr, 0
    D_END
_Opcodes_bMusic_arr:
    .byte $00  ; STOP opcode
.ENDPROC

;;; TODO: Remove this once music generation is implemented.
.PROC Data_Title_Placeholder_sMusic
    D_STRUCT sMusic
    d_addr Opcodes_bMusic_arr_ptr, _Opcodes_bMusic_arr
    d_addr Parts_sPart_arr_ptr, _Parts_sPart_arr
    d_addr Phrases_sPhrase_ptr_arr_ptr, _Phrases_sPhrase_ptr_arr
    D_END
_Opcodes_bMusic_arr:
    .byte bMusic::IsPlay | 0     ; PLAY 0
    .byte bMusic::JumpMask & -1  ; JUMP -1
_Parts_sPart_arr:
    D_STRUCT sPart
    d_addr Chain1_u8_arr_ptr, _Chain1A_u8_arr
    d_addr Chain2_u8_arr_ptr, Data_EmptyChain_u8_arr
    d_addr ChainT_u8_arr_ptr, Data_EmptyChain_u8_arr
    d_addr ChainN_u8_arr_ptr, _ChainNA_u8_arr
    d_addr ChainD_u8_arr_ptr, Data_EmptyChain_u8_arr
    D_END
_Chain1A_u8_arr:
    .byte 0
    .byte $ff  ; end-of-chain
_ChainNA_u8_arr:
    .byte 1, 1, 1, 1
    .byte $ff  ; end-of-chain
_Phrases_sPhrase_ptr_arr:
    .addr _Phrase0_sPhrase
    .addr _Phrase1_sPhrase
_Phrase0_sPhrase:
    .byte bNote::NotRest | eInst::RampUp, 0  ; INST
    .byte $c1, $00, 15  ; TONE
    .byte 15  ; REST
    .byte $c3, $00, 30  ; TONE
    .byte $c2, $00, 30  ; TONE
    .byte $c3, $00, 30  ; TONE
    .byte $00  ; DONE
_Phrase1_sPhrase:
    .byte bNote::NotRest | eInst::RampDown, 0  ; INST
    .byte $c0, $09, 15  ; TONE
    .byte $c0, $00, 15  ; TONE
    .byte $00  ; DONE
.ENDPROC

;;;=========================================================================;;;
