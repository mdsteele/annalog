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

.INCLUDE "program.inc"

;;;=========================================================================;;;

;;; The number of distinct saved programs in the game.  Each machine in the
;;; game uses one of these programs, although in a few cases, multiple machines
;;; may share the same program.
kNumPrograms = 16

;;;=========================================================================;;;

.SEGMENT "SRAM"

;;; If equal to kSaveMagicNumber, then this save file exists.  If equal to any
;;; other value, this save file is considered empty.
.EXPORT Sram_MagicNumber_u8
Sram_MagicNumber_u8: .res 1

;;; The room number that the player should start in when continuing a saved
;;; game.
Sram_RespawnRoomNumber_u8: .res 1

;;; The device number within the respawn room that the player should start at
;;; when continuing a saved game (e.g. a particular door or console).
Sram_RespawnDeviceNumber_u8: .res 1

.RES $1d

;;; A bit array of progress flags.  Given an eFlag value N, bit number (N & 7)
;;; of the (N >> 3)-th byte of this array indicates whether the flag is set (1)
;;; or cleared (0).
.EXPORT Sram_ProgressFlags_arr
Sram_ProgressFlags_arr:
    .assert * & $1f = 0, error, "32-byte alignment"
    .res $20

;;; TODO: Store a bit array of which rooms/map tiles have been visited, so that
;;;   we can draw a minimap on the pause screen.

;;; An array of the player's saved programs.
Sram_Programs_sProgram_arr:
    .assert * & $1f = 0, error, "32-byte alignment"
    .assert .sizeof(sProgram) = $20, error
    .res .sizeof(sProgram) * kNumPrograms

;;;=========================================================================;;;
