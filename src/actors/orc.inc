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

;;; State bytes for orc baddies:
;;;   * State1: The eBadOrc value for the orc's current behavior mode.
;;;   * State2: A timer for the current mode that decrements each frame.
;;;   * State3: An animation counter that increments each frame.

;;; Possible values for an orc baddie actor's State1 byte.
.ENUM eBadOrc
    Standing  ; standing guard
    Chasing   ; chasing player avatar
    Pausing   ; pausing for a short time
    Jumping   ; jumping towards player avatar
    NUM_VALUES
.ENDENUM

;;; How far an orc actor's bounding box extends in each direction from the
;;; actor's center position.
kBadOrcBoundingBoxUp   = 17
kBadOrcBoundingBoxDown =  8
kBadOrcBoundingBoxSide =  6

;;; How fast an orc baddie can run/fall, in subpixels per frame.
kOrcMaxRunSpeed  = $0260
kOrcMaxFallSpeed = $0500

;;; The (signed, 16-bit) initial Y-velocity of an orc actor when jumping, in
;;; subpixels per frame.
kOrcJumpVelocity = $ffff & -600

;;; Tile IDs for drawing orc baddie actors.
kTileIdObjOrcStandingFirst = $88
kTileIdObjOrcRunningFirst = $b8

;;;=========================================================================;;;
