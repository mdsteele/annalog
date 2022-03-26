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

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_AreaName_u8_arr
.PROC DataC_Town_AreaName_u8_arr
    .byte "Bartik Town", $ff
.ENDPROC

.EXPORT DataC_Town_AreaCells_u8_arr2_arr
.PROC DataC_Town_AreaCells_u8_arr2_arr
    .byte 0, 11
    .byte 0, 12
    .byte 0, 13
    .byte 0, 14
    .byte $ff
.ENDPROC

;;;=========================================================================;;;
