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

;;; The width and height of the minimap (in tiles or room screens, depending on
;;; how you're counting).
kMinimapWidth = 24
kMinimapHeight = 15

;;;=========================================================================;;;

;;; Describes a marker dot that can appear on the minimap.
.STRUCT sMarker
    ;; The minimap row where the marker appears.
    Row_u8    .byte
    ;; The minimap column where the marker appears.
    Col_u8    .byte
    ;; If zero, then this is an item marker, and will only appear if its
    ;; minimap cell has been explored.  Otherwise, this is a quest marker, and
    ;; will only appear if this flag is set (even if the cell is unexplored).
    If_eFlag  .byte
    ;; Only show the marker if this flag is NOT set.
    Not_eFlag .byte
.ENDSTRUCT

;;;=========================================================================;;;
