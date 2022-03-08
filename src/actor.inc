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

;;; Types of actors in a room (e.g. enemies or projectiles).
.ENUM eActor
    None
    Crawler
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
    ;; Type-specific initial state data.
    State_byte  .byte
.ENDSTRUCT

;;;=========================================================================;;;