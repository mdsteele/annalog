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

;;; State bytes for rodent baddies:
;;;   * Param: Unused.
;;;   * Flags: The meaning of these depends on if the rodent is running
;;;     horizontally (on a floor or ceiling) or vertically (on a wall):
;;;       * If the rodent is running horizontally, then the bObj::FlipH bit is
;;;         set if the rodent is facing left, or cleared if it is facing right;
;;;         and the bObj::FlipV bit is set if the rodent is running
;;;         upside-down on the ceiling, or cleared if it is running
;;;         right-side-up on the floor.
;;;       * If the rodent is running vertically, then the bObj::FlipH bit is
;;;         set if the rodent is just to the left of the wall, or cleared if it
;;;         is just to the right of the wall; and the bObj::FlipV bit is set if
;;;         the rodent is running downwards, or cleared if it is running
;;;         upwards.
;;;   * State1: The current eBadRodent state value.
;;;   * State2: A timer that counts up/down each frame, depending on the
;;;     current eBadRodent value.
;;;   * State3: An animation timer that ticks up each frame.
;;;   * State4: Unused.

;;; Tile IDs for drawing rodent baddie actors.
kTileIdObjBadRodentFirst = $9a

;;;=========================================================================;;;
