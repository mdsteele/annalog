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

;;; State bytes for child NPCs:
;;;   * State1: The eNpcChild value.
;;;   * State2: Boolean; If true ($ff), the NPC uses Ram_ActorFlags_bObj_arr
;;;     unchanged; if false ($00), the NPC is automatically drawn facing the
;;;     player avatar.

;;; State bytes for adult/mermaid NPCs:
;;;   * State1: The first tile ID for the actor.
;;;   * State2: Boolean; If true ($ff), the NPC uses Ram_ActorFlags_bObj_arr
;;;     unchanged; if false ($00), the NPC is automatically drawn facing the
;;;     player avatar.

;;;=========================================================================;;;

.ENUM eNpcChild
    PonytailStanding = $01
    AlexStanding     = $12
    AlexLooking      = $13
    AlexDucking      = $14
    AlexBoosting     = $15
    AlexWalking1     = $16
    AlexWalking2     = $17
    CrewcutStanding  = $19
    CrewcutWalking1  = $1a
    CrewcutWalking2  = $1b
    BobcutStanding   = $1c
    BobcutWalking1   = $1d
    BobcutWalking2   = $1e
.ENDENUM

;;; Flags for the param byte for child NPC actors.
.SCOPE bNpcChild
    Pri      = %10000000  ; if set, draw this actor behind the background
    EnumMask = %00011111  ; bits used for the eNpcChild value
.ENDSCOPE

;;;=========================================================================;;;

;;; The first tile IDs for various children.
kTileIdObjChildPonytailFirst = $80 | (eNpcChild::PonytailStanding << 2)
kTileIdObjChildAlexFirst     = $80 | (eNpcChild::AlexStanding     << 2)
kTileIdObjChildCrewcutFirst  = $80 | (eNpcChild::CrewcutStanding  << 2)
kTileIdObjChildBobcutFirst   = $80 | (eNpcChild::BobcutStanding   << 2)

;;; The first tile IDs for various adults.
kTileIdAdultWomanFirst = $88

;;; The first tile IDs for various mermaids.
kTileIdMermaidAdultFirst    = $8e
kTileIdMermaidFloristFirst  = $94
kTileIdMermaidYouthFirst    = $9a
kTileIdMermaidGuardFFirst   = $a0
kTileIdMermaidPonytailFirst = $a6
kTileIdMermaidGuardMFirst   = $ac
kTileIdMermaidFarmerFirst   = $be
kTileIdMermaidQueenFirst    = $c4

;;;=========================================================================;;;
