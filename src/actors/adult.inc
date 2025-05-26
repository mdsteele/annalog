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

;;; State bytes for adult NPCs:
;;;   * Param: The eNpcAdult value specifying the NPC's initial pose.
;;;   * Flags: The FlipH bit is set if the NPC is facing left, or cleared if
;;;     they are facing right.  However, if State2 is false ($00), then this
;;;     bit is ignored and instead the NPC automatically faces toward the
;;;     player avatar.
;;;   * State1: The current eNpcAdult value.
;;;   * State2: Boolean; if true ($ff), the NPC uses Ram_ActorFlags_bObj_arr
;;;     unchanged; if false ($00), the NPC is automatically drawn facing the
;;;     player avatar.
;;;   * State3: Unused.
;;;   * State4: Unused.

;;;=========================================================================;;;

;;; Possible values for an adult NPC actor's State1 byte.
.ENUM eNpcAdult
    ;; NPCs that sit/stand on dry land AND use a red palette:
    HumanAlexSad
    HumanAlexStanding
    HumanAlexTaking
    HumanAlexWalking1
    HumanAlexWalking2
    HumanAnna
    HumanBorisGiving
    HumanBorisStanding
    HumanBorisWalking1
    HumanBorisWalking2
    ;; NPCs that sit/stand on dry land:
    HumanElder1
    HumanElder2
    HumanManStanding
    HumanManWalking1
    HumanManWalking2
    HumanSmith1
    HumanSmith2
    HumanWomanStanding
    HumanWomanWalking1
    HumanWomanWalking2
    MermaidFlorist
    ;; NPCs that float, bobbing up and down in the water/air:
    GhostJerome
    GhostMan
    GhostWoman
    MermaidCorra
    MermaidDaphne
    MermaidFarmer
    MermaidGhost
    MermaidGuardF
    MermaidGuardM
    MermaidPhoebe
    CorraSwimmingDown1
    CorraSwimmingDown2
    ;; NPCs that float AND are drawn with 2x4 tiles instead of 2x3:
    CorraSwimmingUp1
    CorraSwimmingUp2
    NUM_VALUES
.ENDENUM

;;; eNpcAdult values less than this are drawn with a red palette instead of a
;;; gray palette.
kFirstNonRedNpcAdult = eNpcAdult::HumanElder1

;;; eNpcAdult values greater than or equal to this are for NPCs that float.
kFirstFloatingNpcAdult = eNpcAdult::GhostJerome

;;; eNpcAdult values greater than or equal to this are drawn with 2x4 tiles,
;;; instead of 2x3.
kFirst2x4NpcAdult = eNpcAdult::CorraSwimmingUp1

;;; The first tile IDs for various human adults.
kTileIdObjAdultAlexFirst          = $86
kTileIdObjAdultAnnaFirst          = $80
kTileIdObjAdultBorisFirst         = $a4
kTileIdObjAdultElderFirst         = $c4
kTileIdObjAdultGhostFirst         = $e4
kTileIdObjAdultJeromeFirst        = $98
kTileIdObjAdultManStandingFirst   = $d6
kTileIdObjAdultManWalkingFirst    = $f0
kTileIdObjAdultSmithFirst         = $b8
kTileIdObjAdultWomanStandingFirst = $d0
kTileIdObjAdultWomanWalkingFirst  = $e0

;;; The first tile IDs for various mermaids.
kTileIdObjCorraSwimmingDownFirst = $e0
kTileIdObjCorraSwimmingUpFirst   = $f0
kTileIdObjMermaidCorraFirst      = $aa
kTileIdObjMermaidFloristFirst    = $92
kTileIdObjMermaidDaphneFirst     = $98
kTileIdObjMermaidGhostFirst      = $c4
kTileIdObjMermaidGuardFFirst     = $9e
kTileIdObjMermaidGuardMFirst     = $80
kTileIdObjMermaidPhoebeFirst     = $86
kTileIdObjMermaidFarmerFirst     = $8c

;;;=========================================================================;;;
