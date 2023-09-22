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
;;;   * Param: The bNpcChild value specifying the child's initial pose.
;;;   * Flags: Only the FlipH and Pri bits are used.
;;;       * The FlipH bit is set if the child is facing left, or cleared if
;;;         they are facing right.  However, if State2 is false ($00), then
;;;         this bit is ignored and instead the child automatically faces
;;;         toward the player avatar.
;;;       * The Pri bit is set if the child should appear behind the
;;;         background.  Unlike FlipH, this bit is not affected by State2.
;;;   * State1: The current eNpcChild value.
;;;   * State2: Boolean; If true ($ff), the child uses Ram_ActorFlags_bObj_arr
;;;     unchanged; if false ($00), the child is automatically drawn facing the
;;;     player avatar.
;;;   * State3: Unused.

;;;=========================================================================;;;

;;; Possible values for a child NPC actor's State1 byte.
.ENUM eNpcChild
    AlexBoosting
    AlexHolding
    AlexKneeling
    AlexLooking
    AlexStanding
    AlexSwimDoor
    AlexSwimming1
    AlexSwimming2
    AlexWalking1
    AlexWalking2
    BrunoStanding
    BrunoWalking1
    BrunoWalking2
    MarieStanding
    MarieWalking1
    MarieWalking2
    NoraStanding
    NUM_VALUES
.ENDENUM

;;; Flags for the param byte for child NPC actors.
.SCOPE bNpcChild
    Pri      = %10000000  ; if set, draw this actor behind the background
    EnumMask = %00011111  ; bits used for the eNpcChild value
.ENDSCOPE

;;;=========================================================================;;;

;;; Tile IDs for drawing child NPC actors.
kTileIdObjChildSwimFirst  = $d8
kTileIdObjChildStandFirst = $e0

;;;=========================================================================;;;
