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

;;;=========================================================================;;;

;;; Types of actors in a room (e.g. baddies, NPCs, or projectiles).
.ENUM eActor
    None
    BadCrab
    BadCrawler
    BadFish
    BadSpider
    BadVinebug
    NpcAdult
    NpcChild
    NpcMermaid
    NpcToddler
    ProjFireball
    ProjGrenade
    ProjSmoke
    ProjSpike
    ProjSteamUp
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Static information about a particular actor instance in a room.  This is
;;; used for static baddies and NPCs, but not for projectiles (which are
;;; generally spawned dynamically).
.STRUCT sActor
    ;; The type of this actor.
    Type_eActor .byte
    ;; The room tile row for this actor.
    TileRow_u8  .byte
    ;; The room tile column for this actor.
    TileCol_u8  .byte
    ;; Type-specific initialization parameter.
    ;;   * For NpcAdult, this is the first tile ID (of six).
    ;;   * For NpcChild, this is the first tile ID (of four).
    ;;   * For NpcMermaid, this is the first tile ID (of six).
    ;;   * For NpcToddler, this is how far to walk before turning around.
    ;;   * For all other baddies and NPCs, this is ignored.
    Param_byte  .byte
.ENDSTRUCT

;;;=========================================================================;;;
