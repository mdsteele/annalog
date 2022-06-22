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

;;; How many frames it takes a winch machine to move up one pixel.
kWinchMoveUpSlowdown = 3

;;; How many frames the a machine spends per move operation when not resetting.
kWinchMoveUpCooldown = 16 * kWinchMoveUpSlowdown
kWinchMoveDownCooldown = 16
kWinchMoveHorzCooldown = 16

;;; The terminal velocity for a falling winch load, in pixels per frame.
.DEFINE kWinchMaxFallSpeed 5

;;; How many times a winch load has to drop onto a breakable floor in order to
;;; destroy it.
kNumWinchHitsToBreakFloor = 3

;;;=========================================================================;;;
