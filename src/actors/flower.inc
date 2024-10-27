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

;;; State bytes for flower baddies:
;;;   * Param: Unused.
;;;   * Flags: Unused.
;;;   * State1: The eBadFlower value for the flower's current behavior mode.
;;;   * State2: A timer for the current mode that increments or decrements each
;;;     frame, depending on the mode.
;;;   * State3: The current animation pose (0-4).
;;;   * State4: Unused.

;;; Tile IDs for drawing flower baddie actors.
kTileIdObjBadFlowerFirst = $e0

;;;=========================================================================;;;

;;; Possible values for a flower baddie actor's State1 byte.
.ENUM eBadFlower
    Dormant
    Growing
    Ready
    Attacking
    Shrinking
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;
