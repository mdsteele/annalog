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

;;; State bytes for toddler NPCs:
;;;   * Param: The bNpcToddler parameter.
;;;   * Flags: The bObj::FlipH bit is set if the toddler is facing left, or
;;;     cleared if they are facing right.  The Pri bit is set if the toddler
;;;     should appear behind the background.
;;;   * State1: How many more frames until the toddler turns around.
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The first tile ID for toddler NPC actors.
kTileIdObjToddlerFirst = $80

;;;=========================================================================;;;

;;; Flags for the param byte for toddler NPC actors.
.SCOPE bNpcToddler
    Pri      = %10000000  ; if set, draw this actor behind the background
    DistMask = %00111111  ; bits used for how far to walk
.ENDSCOPE

;;;=========================================================================;;;
