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

;;; State bytes for slime baddies:
;;;   * Param: The initial flags to set (0 or bObj::FlipH).
;;;   * Flags: The bObj::FlipH bit is set if the slime is moving left, or
;;;     cleared if it is moving right.
;;;   * State1: A cooldown timer that decrements each frame when nonzero.  When
;;;     zero, the slime can drop a spike.
;;;   * State2: A counter that increments each frame, to drive the slime's
;;;     animation.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; Tile IDs for drawing slime baddie actors.
kTileIdObjBadSlimeFirst = $a8

;;;=========================================================================;;;
