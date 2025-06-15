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

;;; State bytes for spine projectiles:
;;;   * Flags: A combination of bObj::FlipH and FlipV, depending on the angle
;;;     that the spine was fired at.
;;;   * State1: The absolute angle that the spine was fired at, in increments
;;;     of tau/256.
;;;   * State2: Counter that starts at zero and increments every frame; if it
;;;     wraps back around to zero before the spine hits anything, then the
;;;     spine is removed.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; Tile IDs for drawing spine projectile actors.
kTileIdObjProjSpineFirst = $89

;;;=========================================================================;;;
