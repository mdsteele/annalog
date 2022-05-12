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

.INCLUDE "../charmap.inc"

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_AreaName_u8_arr
.PROC DataC_Crypt_AreaName_u8_arr
    .byte "Deep Crypt", $ff
.ENDPROC

.EXPORT DataC_Crypt_AreaCells_u8_arr2_arr
.PROC DataC_Crypt_AreaCells_u8_arr2_arr
    .byte  7,  0
    .byte  7,  2
    .byte  8,  0
    .byte  8,  1
    .byte  8,  2
    .byte  9,  0
    .byte  9,  1
    .byte  9,  2
    .byte  9,  3
    .byte 10,  0
    .byte 10,  1
    .byte 10,  2
    .byte 10,  3
    .byte 10,  4
    .byte 11,  0
    .byte 11,  1
    .byte $ff
.ENDPROC

;;;=========================================================================;;;
