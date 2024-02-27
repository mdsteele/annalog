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

;;; State bytes for breakfire projectiles:
;;;   * Flags: Unused.
;;;   * State1: Counter that decrements every frame until it reaches zero.  If
;;;     the breakfire would bounce after this has reached zero, it expires
;;;     instead.
;;;   * State2: Counter that starts at zero and increments every frame.  If it
;;;     somehow wraps back around to zero without the breakfire bouncing, then
;;;     the breakfire will expire.  Resets to zero when the breakfire bounces.
;;;   * State3: Unused.

;;; The first tile ID for drawing breakfire projectile actors.
kTileIdObjBreakfireFirst = $ab

;;;=========================================================================;;;
