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

;;; State bytes for fireball/fireblast projectiles:
;;;   * Flags: Unused.
;;;   * State1: The absolute angle that the projectile was fired/reflected at,
;;;     in increments of tau/256.
;;;   * State2: The current age of the projectile, in frames.  This increments
;;;     each frame, and if it wraps back around to zero before the projectile
;;;     hits anything, then the projectile will turn to smoke.
;;;   * State3: For fireblasts only, the number of frames until the projectile
;;;     can hit a mirror again.  This is set to a nonzero value when the
;;;     fireblast hits a mirror (so that it can't immediately hit the same
;;;     mirror again), and decrements each frame when nonzero.

;;; Tile IDs for drawing fireball/fireblast projectile actors.
kTileIdObjFireballFirst  = $c0
kTileIdObjFireblastFirst = $9a

;;;=========================================================================;;;
