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

;;; The maximum number of actors that can exist at once in a room.
kMaxActors = 8

;;; State bytes to set for eActor::Adult for various adults.
kAdultWoman          = $88
kAdultMermaidSitting = $8e
kAdultMermaidWorker  = $94
kAdultMermaidYouth   = $9a
kAdultMermaidGuard   = $a0

;;; State bytes to set for eActor::Child for various children.
kChildPonytail = $84

;;;=========================================================================;;;

;;; Types of actors in a room (e.g. townsfolk, enemies, or projectiles).
.ENUM eActor
    None
    Adult
    Child
    Crab
    Crawler
    Fireball
    Fish
    Grenade
    Smoke
    Spider
    Spike
    Toddler
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Static information about an actor.
.STRUCT sActor
    ;; The type of this actor.
    Type_eActor .byte
    ;; The room tile row for this actor.
    TileRow_u8  .byte
    ;; The room tile column for this actor.
    TileCol_u8  .byte
    ;; Type-specific initialization parameter.
    ;;   * For Adult, this is the first tile ID (of six).
    ;;   * For Child, this is the first tile ID (of four).
    ;;   * For Fireball, this is the aim angle (mod 64).
    ;;   * For Grenade, this is the aim angle (0-1).
    ;;   * For all other actor types, this is ignored.
    Param_byte  .byte
.ENDSTRUCT

;;;=========================================================================;;;
