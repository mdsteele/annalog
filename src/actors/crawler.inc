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
