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

;;; State bytes for fireball projectiles:
;;;   * State1: The absolute angle that the fireball was fired/reflected at, in
;;;     increments of tau/256.
;;;   * State2: The current age of the fireball, in frames.  This increments
;;;     each frame, and if it wraps back around to zero before the fireball
;;;     hits anything, then the fireball is removed.
;;;   * State3: The number of frames until the fireball can hit a mirror again.
;;;     This is set to a nonzero value when the fireball hits a mirror (so that
;;;     it can't immediately hit the same mirror again), and decrements each
;;;     frame when nonzero.

;;; The first tile ID for the fireball actor animation.
kTileIdObjFireballFirst = $9a

;;;=========================================================================;;;
