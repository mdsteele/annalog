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

;;; State bytes for axe projectiles and smoke:
;;;   * Flags: The bObj::FlipH bit is set if the axe is spinning
;;;     counterclockwise, or cleared if it is spinning clockwise.
;;;   * State1: For ProjAxeBoomer and SmokeAxe, this is the current age of the
;;;     projectile, in frames.  For ProjAxeSmash, this is unused.
;;;   * State2: For ProjAxeBoomer and SmokeAxe, this is unused.  For AxeSmash,
;;;     this is the platform index to home in on.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; The first tile ID for drawing axe projectile and smoke actors.
kTileIdObjProjAxeFirst = $d8

;;;=========================================================================;;;
