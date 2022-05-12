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

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_AreaName_u8_arr
.PROC DataC_Garden_AreaName_u8_arr
    .byte "Vine Garden", $ff
.ENDPROC

.EXPORT DataC_Garden_AreaCells_u8_arr2_arr
.PROC DataC_Garden_AreaCells_u8_arr2_arr
    .byte  6,  6
    .byte  7,  6
    .byte  7,  7
    .byte  7,  8
    .byte  7,  9
    .byte  8,  6
    .byte  8,  7
    .byte  8,  8
    .byte  8,  9
    .byte  8, 10
    .byte  8, 11
    .byte  9,  6
    .byte  9,  7
    .byte  9,  8
    .byte  9,  9
    .byte  9, 10
    .byte  9, 11
    .byte 10,  6
    .byte 10,  7
    .byte 10,  8
    .byte $ff
.ENDPROC

;;;=========================================================================;;;
