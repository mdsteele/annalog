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
.INCLUDE "../menu.inc"

;;;=========================================================================;;;

.SEGMENT "PRGA_Console"

;;; BG tile IDs for numbers, from 0 through 15.
.EXPORT DataA_Console_NumberLabels_u8_arr
.PROC DataA_Console_NumberLabels_u8_arr
    .byte "0123456789", $1a, $1b, $1c, $1d, $1e, $1f
.ENDPROC
.ASSERT .sizeof(DataA_Console_NumberLabels_u8_arr) = kMaxMenuItems, error

;;;=========================================================================;;;
