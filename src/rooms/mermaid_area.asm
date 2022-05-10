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

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_AreaName_u8_arr
.PROC DataC_Mermaid_AreaName_u8_arr
    .byte "Mermaid Vale", $ff
.ENDPROC

.EXPORT DataC_Mermaid_AreaCells_u8_arr2_arr
.PROC DataC_Mermaid_AreaCells_u8_arr2_arr
    .byte  9, 13
    .byte  9, 14
    .byte  9, 15
    .byte  9, 16
    .byte 10,  9
    .byte 10, 10
    .byte 10, 11
    .byte 10, 12
    .byte 10, 13
    .byte 10, 14
    .byte 10, 15
    .byte 10, 16
    .byte 11, 11
    .byte 11, 12
    .byte 11, 13
    .byte 11, 14
    .byte $ff
.ENDPROC

;;;=========================================================================;;;
