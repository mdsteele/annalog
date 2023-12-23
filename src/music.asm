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

.IMPORT DataC_Boss_BossPlaceholder_sMusic
.IMPORT DataC_Core_Boss2_sMusic
.IMPORT DataC_Crypt_Crypt_sMusic
.IMPORT DataC_Mine_MinePlaceholder_sMusic
.IMPORT DataC_Prison_Prison1_sMusic
.IMPORT DataC_Prison_Prison2_sMusic
.IMPORT DataC_Temple_TemplePlaceholder_sMusic
.IMPORT Data_Credits_sMusic
.IMPORT Data_Empty_bMusic_arr
.IMPORT Data_Title_Placeholder_sMusic

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Maps from eMusic enum values to sMusic struct pointers.
.EXPORT Data_Music_sMusic_ptr_0_arr
.EXPORT Data_Music_sMusic_ptr_1_arr
.REPEAT 2, table
    D_TABLE_LO table, Data_Music_sMusic_ptr_0_arr
    D_TABLE_HI table, Data_Music_sMusic_ptr_1_arr
    D_TABLE .enum, eMusic
    d_entry table, Silence, Data_Silence_sMusic
    d_entry table, Boss1,   DataC_Boss_BossPlaceholder_sMusic
    d_entry table, Boss2,   DataC_Core_Boss2_sMusic
    d_entry table, Credits, Data_Credits_sMusic
    d_entry table, Crypt,   DataC_Crypt_Crypt_sMusic
    d_entry table, Mine,    DataC_Mine_MinePlaceholder_sMusic
    d_entry table, Prison1, DataC_Prison_Prison1_sMusic
    d_entry table, Prison2, DataC_Prison_Prison2_sMusic
    d_entry table, Temple,  DataC_Temple_TemplePlaceholder_sMusic
    d_entry table, Title,   Data_Title_Placeholder_sMusic
    D_END
.ENDREPEAT

;;; A sMusic struct that just plays silence.
.PROC Data_Silence_sMusic
    D_STRUCT sMusic
    d_addr Opcodes_bMusic_arr_ptr, Data_Empty_bMusic_arr
    d_addr Parts_sPart_arr_ptr, 0
    d_addr Phrases_sPhrase_ptr_arr_ptr, 0
    D_END
.ENDPROC

;;;=========================================================================;;;
