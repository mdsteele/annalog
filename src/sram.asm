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

.INCLUDE "death.inc"
.INCLUDE "minimap.inc"
.INCLUDE "program.inc"
.INCLUDE "timer.inc"

;;;=========================================================================;;;

.SEGMENT "SRAM"

;;; If equal to kSaveMagicNumber, then this save file exists.  If equal to any
;;; other value, this save file is considered empty.
.EXPORT Sram_MagicNumber_u8
Sram_MagicNumber_u8: .res 1

;;; The room number that the player should start in when continuing a saved
;;; game.
.EXPORT Sram_LastSafe_eRoom
Sram_LastSafe_eRoom: .res 1

;;; The passage or device within the room that the player should start at
;;; when continuing a saved game (e.g. a particular door or console).
.EXPORT Sram_LastSafe_bSpawn
Sram_LastSafe_bSpawn: .res 1

;;; The eFlag for the flower that the player avatar is currently carrying, or
;;; zero for none.
.EXPORT Sram_CarryingFlower_eFlag
Sram_CarryingFlower_eFlag: .res 1

;;; The total time spent in explore mode for this saved game, stored as hours
;;; (3 decimal digits), minutes (2 decimal digits), seconds (2 decimal digits),
;;; and frames (1 base-60 digit), in big-endian order.
.EXPORT Sram_ExploreTimer_u8_arr
Sram_ExploreTimer_u8_arr: .res kNumTimerDigits

;;; The number of times the player avatar has died, stored as one decimal digit
;;; per byte (little-endian).
.EXPORT Sram_DeathCount_u8_arr
Sram_DeathCount_u8_arr: .res kNumDeathDigits

.RES $01

;;; A bit array indicating which minimap cells have been explored.  The array
;;; contains one u16 for each minimap column; if the minimap cell at row R and
;;; column C has been explored, then the Rth bit of the Cth u16 in this array
;;; will be set.
.EXPORT Sram_Minimap_u16_arr
Sram_Minimap_u16_arr:
    .assert * & $0f = 0, error, "16-byte alignment"
    .assert kMinimapHeight <= 16, error
    .res 2 * kMinimapWidth

;;; A bit array of progress flags.  Given an eFlag value N, bit number (N & 7)
;;; of the (N >> 3)-th byte of this array indicates whether the flag is set (1)
;;; or cleared (0).
.EXPORT Sram_ProgressFlags_arr
Sram_ProgressFlags_arr:
:   .assert * & $1f = 0, error, "32-byte alignment"
    .res $20
    .assert (* - :-) * 8 = $100, error

;;; An array of the player's saved programs.
.EXPORT Sram_Programs_sProgram_arr
Sram_Programs_sProgram_arr:
    .assert * & $1f = 0, error, "32-byte alignment"
    .assert .sizeof(sProgram) = $20, error
    .res .sizeof(sProgram) * eProgram::NUM_VALUES

;;;=========================================================================;;;
