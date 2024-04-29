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

;;; State bytes for solifuge baddies:
;;;   * Param: Unused.
;;;   * Flags: The FlipH bit is set if the solifuge is accelerating to the
;;;     left, or cleared if the solifuge is accelerating to the right.
;;;   * State1: The current bBadSolifuge value, indicating what mode the
;;;     solifuge is in.
;;;   * State2: If the solifuge is jumping, this holds the terrain block row it
;;;     was in before it jumped.
;;;   * State3: An animation counter that increments each frame (wrapping
;;;     around after 255).
;;;   * State4: Unused.

;;; State bits for a solifuge baddie actor.
.SCOPE bBadSolifuge
    Steamed = %10000000  ; if set, the solifuge got blown upwards by steam
    Jumping = %01000000  ; if set, the solifuge is jumping
.ENDSCOPE

;;;=========================================================================;;;
