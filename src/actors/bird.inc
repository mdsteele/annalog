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

;;; State bytes for bird baddies:
;;;   * Param: The bBadBird value specifying the bird's initial facing
;;;     direction and max look-ahead distance.
;;;   * Flags: The bObj::FlipH bit is set if the bird is facing left, or
;;;     cleared if it is facing right.
;;;   * State1: The maximum number of pixels to look ahead horizontally for the
;;;     player avatar.
;;;   * State2: If the bird is standing still, this is the cooldown
;;;     (decremented each frame) until it can fly again.  If the bird is
;;;     flying, this is an animation counter (incremented each from).
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; Tile IDs for drawing bird baddie actors.
kTileIdObjBadBirdFirst = $c0

;;;=========================================================================;;;

;;; Flags for the param byte for bird baddie actors.
.SCOPE bBadBird
    FlipH    = %10000000  ; if set, the actor is initially facing left
    DistMask = %01111111  ; bits used for max look-ahead distance
.ENDSCOPE

;;;=========================================================================;;;
