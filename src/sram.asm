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
.INCLUDE "mmc3.inc"
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

;;; The eFlag for the flower that the player avatar is carrying in the saved
;;; game, or eFlag::None for none.
.EXPORT Sram_CarryingFlower_eFlag
Sram_CarryingFlower_eFlag: .res 1

;;; The number of times the player avatar has died, stored as one decimal digit
;;; per byte (little-endian).
.EXPORT Sram_DeathCount_u8_arr
Sram_DeathCount_u8_arr: .res kNumDeathDigits

.RES $01

;;; The total time spent playing this saved game, stored as frames (1 base-60
;;; digit), seconds (2 decimal digits), minutes (2 decimal digits), and hours
;;; (3 decimal digits), in little-endian order.
Sram_ProgressTimer_u8_arr: .res kNumTimerDigits

;;; A bit array indicating which minimap cells have been explored.  The array
;;; contains one u16 for each minimap column; if the minimap cell at row R and
;;; column C has been explored, then the Rth bit of the Cth u16 in this array
;;; will be set.
.PROC Sram_Minimap_u16_arr
    .assert * .mod 16 = 0, error, "16-byte alignment"
    .assert kMinimapHeight <= 16, error
    .res 2 * kMinimapWidth
.ENDPROC

;;; A bit array of progress flags.  Given an eFlag value N, bit number (N & 7)
;;; of the (N >> 3)-th byte of this array indicates whether the flag is set (1)
;;; or cleared (0).
.PROC Sram_ProgressFlags_arr
    .assert * .mod 32 = 0, error, "32-byte alignment"
    .res $100 / 8
.ENDPROC

;;; An array of the player's saved programs.
.EXPORT Sram_Programs_sProgram_arr
.PROC Sram_Programs_sProgram_arr
    .assert * .mod 32 = 0, error, "32-byte alignment"
    .assert .sizeof(sProgram) = $20, error
    .res .sizeof(sProgram) * eProgram::NUM_VALUES
.ENDPROC

;;;=========================================================================;;;

.ZEROPAGE

;;; The eFlag for the flower that the player avatar is currently carrying, or
;;; eFlag::None for none.
.EXPORTZP Zp_CarryingFlower_eFlag
Zp_CarryingFlower_eFlag: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Progress"

;;; A bit array of progress flags.  Given an eFlag value N, bit number (N & 7)
;;; of the (N >> 3)-th byte of this array indicates whether the flag is set (1)
;;; or cleared (0).
.EXPORT Ram_ProgressFlags_arr
.PROC Ram_ProgressFlags_arr
    .assert * .mod 32 = 0, error, "32-byte alignment"
    .res $100 / 8
.ENDPROC

;;; A bit array indicating which minimap cells have been explored.  The array
;;; contains one u16 for each minimap column; if the minimap cell at row R and
;;; column C has been explored, then the Rth bit of the Cth u16 in this array
;;; will be set.
.EXPORT Ram_Minimap_u16_arr
.PROC Ram_Minimap_u16_arr
    .assert * .mod 16 = 0, error, "16-byte alignment"
    .assert kMinimapHeight <= 16, error
    .res 2 * kMinimapWidth
.ENDPROC

;;; The total time spent playing this game so far, stored as frames (1 base-60
;;; digit), seconds (2 decimal digits), minutes (2 decimal digits), and hours
;;; (3 decimal digits), in little-endian order.
.EXPORT Ram_ProgressTimer_u8_arr
Ram_ProgressTimer_u8_arr: .res kNumTimerDigits

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Saves transient progress data from RAM to SRAM.
;;; @preserve X, Y, T0+
.EXPORT Func_SaveProgress
.PROC Func_SaveProgress
    txa  ; old X value
    pha  ; old X value
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
_ProgressTimer:
    ldx #kNumTimerDigits - 1
    @loop:
    lda Ram_ProgressTimer_u8_arr, x
    sta Sram_ProgressTimer_u8_arr, x
    dex
    .assert kNumTimerDigits <= $80, error
    bpl @loop
_Flags:
    .linecont +
    .assert .sizeof(Sram_ProgressFlags_arr) = .sizeof(Ram_ProgressFlags_arr), \
            error
    .linecont -
    ldx #.sizeof(Sram_ProgressFlags_arr) - 1
    @loop:
    lda Ram_ProgressFlags_arr, x
    sta Sram_ProgressFlags_arr, x
    dex
    .assert .sizeof(Sram_ProgressFlags_arr) <= $80, error
    bpl @loop
_Flower:
    lda Zp_CarryingFlower_eFlag
    sta Sram_CarryingFlower_eFlag
_Minimap:
    .assert .sizeof(Sram_Minimap_u16_arr) = .sizeof(Ram_Minimap_u16_arr), error
    ldx #.sizeof(Sram_Minimap_u16_arr) - 1
    @loop:
    lda Ram_Minimap_u16_arr, x
    sta Sram_Minimap_u16_arr, x
    dex
    .assert .sizeof(Sram_Minimap_u16_arr) <= $80, error
    bpl @loop
_Finish:
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    pla  ; old X value
    tax  ; old X value
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Loads transient progress data from SRAM to RAM.
;;; @preserve Y, T0+
.EXPORT FuncA_Avatar_LoadProgress
.PROC FuncA_Avatar_LoadProgress
_ProgressTimer:
    ldx #kNumTimerDigits - 1
    @loop:
    lda Sram_ProgressTimer_u8_arr, x
    sta Ram_ProgressTimer_u8_arr, x
    dex
    .assert kNumTimerDigits <= $80, error
    bpl @loop
_Flags:
    .linecont +
    .assert .sizeof(Sram_ProgressFlags_arr) = .sizeof(Ram_ProgressFlags_arr), \
            error
    .linecont -
    ldx #.sizeof(Sram_ProgressFlags_arr) - 1
    @loop:
    lda Sram_ProgressFlags_arr, x
    sta Ram_ProgressFlags_arr, x
    dex
    .assert .sizeof(Sram_ProgressFlags_arr) <= $80, error
    bpl @loop
_Flower:
    lda Sram_CarryingFlower_eFlag
    sta Zp_CarryingFlower_eFlag
_Minimap:
    .assert .sizeof(Sram_Minimap_u16_arr) = .sizeof(Ram_Minimap_u16_arr), error
    ldx #.sizeof(Sram_Minimap_u16_arr) - 1
    @loop:
    lda Sram_Minimap_u16_arr, x
    sta Ram_Minimap_u16_arr, x
    dex
    .assert .sizeof(Sram_Minimap_u16_arr) <= $80, error
    bpl @loop
    rts
.ENDPROC

;;;=========================================================================;;;
