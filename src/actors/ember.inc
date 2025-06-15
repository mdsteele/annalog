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

;;; State bytes for ember projectiles:
;;;   * Flags: Toggles automatically between bObj::FlipH and zero to animate
;;;     the projectile.
;;;   * State1: Counter that starts at zero and increments every frame; if it
;;;     wraps back around to zero before the ember hits anything, then the
;;;     ember is removed.
;;;   * State2: Unused.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The OBJ tile ID for ember projectile actors.
kTileIdObjProjEmber = $87

;;;=========================================================================;;;
