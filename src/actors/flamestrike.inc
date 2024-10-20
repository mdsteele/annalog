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

;;; State bytes for flamestrike projectiles:
;;;   * Flags: The bObj::FlipH bit is set if the flame will sweep left, or
;;;     cleared if it will sweep right.
;;;   * State1: The eProjFlamestrike value for the projectile's current
;;;     behavior mode.
;;;   * State2: The current visual height of the flamestrike, in tiles.
;;;   * State3: A timer that counts up or down each frame, depending on the
;;;     current mode.
;;;   * State4: Unused.

;;; Possible values for a flamestrike projectile actor's State1 byte.
.ENUM eProjFlamestrike
    Descending  ; descending from the boss's mouth
    Paused      ; paused before sweeping sideways
    Sweeping    ; sweeping sideways
    NUM_VALUES
.ENDENUM

;;; The first tile ID for drawing flamestrike projectile actors.
kTileIdObjProjFlamestrikeFirst = $d6

;;;=========================================================================;;;
