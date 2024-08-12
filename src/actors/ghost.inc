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

;;; State bytes for mermaid/orc ghost baddies:
;;;   * Param: The initial eBadGhost value to set for State1.
;;;   * Flags: The bObj::FlipH bit is set if the ghost is facing left, or
;;;     cleared if it is facing right.
;;;   * State1: The eBadGhost value for the ghost's current behavior mode.
;;;   * State2: A timer for the current mode that increments or decrements each
;;;     frame, depending on the mode.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;;=========================================================================;;;

;;; Possible values for a ghost baddie actor's State1 byte.
.ENUM eBadGhost
    Absent        ; invisible, waiting for a new mode to be set
    Idle          ; visible, waiting for a new mode to be set
    Disappearing  ; disappearing
    Reappearing   ; reappearing
    Attacking     ; visible in attack pose, waiting for a new mode to be set
    NUM_VALUES
.ENDENUM

;;; How many frames it takes a ghost baddie actor to appear or disappear.
kBadGhostAppearFrames = 45

;;;=========================================================================;;;
