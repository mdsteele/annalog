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

;;; State bytes for jelly baddies:
;;;   * Param: The initial bBadJelly value.
;;;   * Flags: Unused.
;;;   * State1: The current bBadJelly value.
;;;   * State2: An animation timer that ticks up each frame.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; Tile IDs for drawing bird baddie actors.
kTileIdObjBadJellyFirst = $87

;;;=========================================================================;;;

;;; Flags for the param byte for jelly baddie actors.
.SCOPE bBadJelly
    TurnCcw   = %10000000  ; if set, turn counterclockwise
    TurnCw    = %01000000  ; if set, turn clockwise
    DirMask   = %00000011  ; bits used for eDir value
.ENDSCOPE

;;;=========================================================================;;;
