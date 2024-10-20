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

;;; State bytes for rocket projectiles:
;;;   * Flags: For a horizontally-moving rocket, the bObj::FlipH bit will be
;;;     set if the rocket is moving left, or cleared if it is moving right.
;;;     For a vertically-moving rocket, the bObj::FlipV bit will be set if the
;;;     rocket is moving up, or cleared if it is moving down.
;;;   * State1: Counter that starts at zero and increments every frame; if it
;;;     wraps back around to zero before the rocket hits anything, then the
;;;     rocket is removed.
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; How many frames the room shakes for when a rocket hits the ground.
kRocketShakeFrames = 30

;;;=========================================================================;;;
