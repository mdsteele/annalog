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

;;; State bytes for firefly baddies:
;;;   * Param: The initial flags to set (0 or bObj::FlipH).
;;;   * Flags: The bObj::FlipH bit is set if the flydrop is facing left, or
;;;     cleared if it is facing right.
;;;   * State1: The number of cooldown frames before the flydrop can drop acid.
;;;   * State2: The number of cooldown frames before the flydrop can randomly
;;;     turn around again.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;; Tile IDs for drawing flydrop baddie actors.
kTileIdObjBadFlydropFirst = $80

;;;=========================================================================;;;
