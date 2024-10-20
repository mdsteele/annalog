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

;;; State bytes for beetle and hothead baddies:
;;;   * Param: The initial flags to set (0 or bObj::FlipH and/or bObj::FlipV).
;;;   * Flags: The meaning of these depends on if the baddie is crawling
;;;     horizontally (on a floor or ceiling) or vertically (on a wall):
;;;       * If the baddie is crawling horizontally, then the bObj::FlipH bit is
;;;         set if the baddie is facing left, or cleared if it is facing right;
;;;         and the bObj::FlipV bit is set if the baddie is crawling
;;;         upside-down on the ceiling, or cleared if it is crawling
;;;         right-side-up on the floor.
;;;       * If the baddie is crawling vertically, then the bObj::FlipH bit is
;;;         set if the baddie is just to the left of the wall, or cleared if it
;;;         is just to the right of the wall; and the bObj::FlipV bit is set if
;;;         the baddie is crawling downwards, or cleared if it is crawling
;;;         upwards.
;;;   * State1: Toggles between 1 and 0 each frame; used to make baddie move
;;;     by one pixel every other frame.
;;;   * State2: Unused for beetles; for hotheads, this is the number of
;;;     cooldown frames before it can drop another ember.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; Tile IDs for drawing beetle actors.
kTileIdObjBadBeetleFirst = $c0
kTileIdObjBadBeetleHorzFirst = kTileIdObjBadBeetleFirst + $00
kTileIdObjBadBeetleVertFirst = kTileIdObjBadBeetleFirst + $08

;;; Tile IDs for drawing hothead actors.
kTileIdObjBadHotheadFirst = $a0
kTileIdObjBadHotheadHorzFirst = kTileIdObjBadHotheadFirst + $00
kTileIdObjBadHotheadVertFirst = kTileIdObjBadHotheadFirst + $08

;;;=========================================================================;;;
