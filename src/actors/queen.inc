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

;;; State bytes for queen NPCs:
;;;   * Param: Unused
;;;   * Flags: The FlipH bit is set if the NPC is facing left, or cleared if
;;;     they are facing right.  However, if State2 is false ($00), then this
;;;     bit is ignored and instead the NPC automatically faces toward the
;;;     player avatar.
;;;   * State1: Unused.
;;;   * State2: Boolean; if true ($ff), the NPC uses Ram_ActorFlags_bObj_arr
;;;     unchanged; if false ($00), the NPC is automatically drawn facing the
;;;     player avatar.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;;=========================================================================;;;

;;; The first tile ID for mermaid queen NPCs.
kTileIdObjMermaidQueenFirst = $b0

;;; OBJ palette numbers to use for drawing queen NPC actors.
kPaletteObjMermaidQueenBody = 0
kPaletteObjMermaidQueenHead = 1

;;;=========================================================================;;;
