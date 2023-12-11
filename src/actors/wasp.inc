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

;;; State bytes for wasp baddies:
;;;   * Param: The bBadWasp value specifying the wasp's initial position
;;;     (angle) within its circular flight path, and its per-frame angle delta.
;;;     direction and max look-ahead distance.
;;;   * Flags: Automatically set to bObj::FlipH whenever the wasp's X-velocity
;;;     is negative, or to 0 whenever the wasp's X-velocity is nonnegative.
;;;   * State1: The signed delta that gets added to the wasps flight angle each
;;;     frame.
;;;   * State2: The wasp's current angle around the circle it flies in.
;;;   * State3: Unused.

;;; Tile IDs for drawing wasp baddie actors.
kTileIdObjWaspFirst = $a8

;;;=========================================================================;;;

;;; Flags for the param byte for wasp baddie actors.
.SCOPE bBadWasp
    ThetaMask = %11110000  ; bits used for initial angle
    DeltaMask = %00001111  ; bits used for per-frame angle delta
.ENDSCOPE

;;;=========================================================================;;;
