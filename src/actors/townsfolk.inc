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

;;; State bytes for adult/mermaid NPCs:
;;;   * State1: The first tile ID for the actor.
;;;   * State2: Boolean; if true ($ff), the NPC uses Ram_ActorFlags_bObj_arr
;;;     unchanged; if false ($00), the NPC is automatically drawn facing the
;;;     player avatar.
;;;   * State3: Unused.

;;;=========================================================================;;;

;;; The first tile IDs for various adults.
kTileIdAdultElderFirst = $c4
kTileIdAdultElder1     = kTileIdAdultElderFirst + 0
kTileIdAdultElder2     = kTileIdAdultElderFirst + 6
kTileIdAdultManFirst   = $d6
kTileIdAdultSmithFirst = $b8
kTileIdAdultSmith1     = kTileIdAdultSmithFirst + 0
kTileIdAdultSmith2     = kTileIdAdultSmithFirst + 6
kTileIdAdultWomanFirst = $d0

;;; The first tile IDs for various mermaids.
kTileIdCorraSwimmingDownFirst = $e0
kTileIdCorraSwimmingDown1     = kTileIdCorraSwimmingDownFirst + 0
kTileIdCorraSwimmingDown2     = kTileIdCorraSwimmingDownFirst + 6
kTileIdCorraSwimmingUpFirst   = $f0
kTileIdCorraSwimmingUp1       = kTileIdCorraSwimmingUpFirst + 0
kTileIdCorraSwimmingUp2       = kTileIdCorraSwimmingUpFirst + 8
kTileIdMermaidCorraFirst      = $aa
kTileIdMermaidFloristFirst    = $92
kTileIdMermaidDaphneFirst     = $98
kTileIdMermaidGhostFirst      = $c4
kTileIdMermaidGuardFFirst     = $9e
kTileIdMermaidGuardMFirst     = $80
kTileIdMermaidPhoebeFirst     = $86
kTileIdMermaidFarmerFirst     = $8c
kTileIdMermaidQueenFirst      = $b0

;;; Mermaid first tile IDs of this or more must be drawn 2x4 instead of 2x3.
kFirst2x4MermaidTileId = kTileIdCorraSwimmingUpFirst

;;;=========================================================================;;;
