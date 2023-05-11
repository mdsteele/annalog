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

;;; State bytes for firefly baddies:
;;;   * State1: Tthe number of cooldown frames before the firefly can shoot
;;;     another fireball.
;;;   * State2: The firefly's current angle within its sinusoidal flight
;;;     pattern.
;;;   * State3: Unused.

;;; Tile IDs for drawing firefly baddie actors.
kTileIdObjFireflyFirst = $a0

;;;=========================================================================;;;

;;; Flags for the param byte for firefly baddie actors.
.SCOPE bBadFirefly
    ThetaMask = %11110000  ; bits used for initial flight pattern angle
    FlipH     = %00000001  ; if set, face the firefly initially to the left
.ENDSCOPE

;;;=========================================================================;;;
