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

;;; State bytes for lavaball baddies:
;;;   * Param: Controls the jump height (1-9).
;;;   * Flags: The bObj::FlipV bit is set if the lavaball is falling, or
;;;     cleared if it is rising.  The bObj::Pri bit is set if the lavaball is
;;;     just above the surface of the lava (so that it will appear behind the
;;;     lava, but in front of any background terrain higher up in the room).
;;;   * State1: Controls the jump height (1-9).
;;;   * State2: The number of frames until the next time the lavaball jumps, or
;;;     zero if the lavaball is currently jumping.
;;;   * State3: An animation counter that increments each frame.
;;;   * State4: Unused.

;;; The starting Y-position of a lavaball baddie in short/tall rooms.
kLavaballStartYShort = $d4
kLavaballStartYTall = $164

;;; Tile IDs for drawing lavaball baddie actors.
kTileIdObjBadLavaballFirst = $c0

;;;=========================================================================;;;
