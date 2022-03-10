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

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_AreaName_u8_arr
.PROC DataC_Prison_AreaName_u8_arr
    .byte "Prison Caves", $ff
.ENDPROC

.EXPORT DataC_Prison_AreaCells_u8_arr2_arr
.PROC DataC_Prison_AreaCells_u8_arr2_arr
    .byte 1, 5
    .byte 2, 1
    .byte 2, 2
    .byte 2, 3
    .byte 2, 4
    .byte 2, 5
    .byte 2, 6
    .byte 2, 7
    .byte 2, 8
    .byte 3, 1
    .byte 3, 2
    .byte 3, 3
    .byte 3, 4
    .byte $ff
.ENDPROC

;;;=========================================================================;;;
