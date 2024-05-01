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

;;; State bytes for conveyor machines:
;;;   * GoalHorz: The current gear setting for the conveyor (0-9).
;;;   * GoalVert: Unused.
;;;   * Slowdown: Unused.
;;;   * State1: An animation counter that increments/decrements as the conveyor
;;;     belts move.
;;;   * State2: True ($ff) if the player avatar is currently standing on one of
;;;     this machine's conveyor belt platforms, false ($00) otherwise.
;;;   * State3: Unused.

;;; The size of conveyor machine's main platform, in pixels.
kConveyorMainPlatformWidthPx  = $08
kConveyorMainPlatformHeightPx = $08

;;;=========================================================================;;;
