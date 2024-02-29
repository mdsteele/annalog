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

;;; State bytes for bat baddies:
;;;   * Param: The eDir value for the bat's initial flying direction.
;;;   * Flags: The bObj::FlipH bit is set if the bat is facing left, or cleared
;;;     if it is facing right.
;;;   * State1: The eDir value for the bat's current flying direction.
;;;   * State2: An animation timer that ticks up each frame.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; Tile IDs for drawing bat baddie actors.
kTileIdObjBadBatFirst = $9c

;;;=========================================================================;;;
