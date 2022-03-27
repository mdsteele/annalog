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

.INCLUDE "avatar.inc"
.INCLUDE "device.inc"

;;;=========================================================================;;;

.DEFINE kSizeofChr 16

;;;=========================================================================;;;

.SEGMENT "CHR_Cave"

.EXPORT Ppu_ChrCave
.PROC Ppu_ChrCave
:   .incbin "out/data/tiles/cave.chr"
    .res $26 * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_FontUpper"

.EXPORT Ppu_ChrFontUpper
.PROC Ppu_ChrFontUpper
:   .incbin "out/data/tiles/font_upper.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_FontLower01"

.EXPORT Ppu_ChrFontLower01
.PROC Ppu_ChrFontLower01
:   .incbin "out/data/tiles/font_lower.chr"
    .incbin "out/data/tiles/diagram01.chr"
    .incbin "out/data/tiles/portrait01.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_FontLower02"

.PROC Ppu_ChrFontLower02
:   .incbin "out/data/tiles/font_lower.chr"
    .incbin "out/data/tiles/diagram02.chr"
    .incbin "out/data/tiles/portrait02.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_FontLower03"

.PROC Ppu_ChrFontLower03
:   .incbin "out/data/tiles/font_lower.chr"
    .res $10 * kSizeofChr
    .incbin "out/data/tiles/portrait03.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_Pause"

.EXPORT Ppu_ChrPause
.PROC Ppu_ChrPause
:   .incbin "out/data/tiles/minimap1.chr"
    .res $06 * kSizeofChr
    .incbin "out/data/tiles/minimap2.chr"
    .res $07 * kSizeofChr
    .incbin "out/data/tiles/minimap3.chr"
    .res $03 * kSizeofChr
    .incbin "out/data/tiles/upgrade.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_Player"

.EXPORT Ppu_ChrPlayer
.PROC Ppu_ChrPlayer
:   .incbin "out/data/tiles/cursor.chr"
    .assert * - :- = kSizeofChr * kConsoleScreenTileIdOk, error
    .incbin "out/data/tiles/screen.chr"
    .assert * - :- = kSizeofChr * kLeverHandleTileIdDown, error
    .incbin "out/data/tiles/lever.chr"
    .res $12 * kSizeofChr
    .assert * - :- = kSizeofChr * eAvatar::Standing, error
    .incbin "out/data/tiles/player.chr"
    .res $18 * kSizeofChr
    .incbin "out/data/tiles/machine.chr"
    .res $16 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_Town"

.EXPORT Ppu_ChrTown
.PROC Ppu_ChrTown
:   .incbin "out/data/tiles/forest.chr"
    .incbin "out/data/tiles/house.chr"
    .res $0d * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_Townsfolk"

.EXPORT Ppu_ChrTownsfolk
.PROC Ppu_ChrTownsfolk
:   .incbin "out/data/tiles/townsfolk.chr"
    .res $78 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_Upgrade"

.EXPORT Ppu_ChrUpgrade
.PROC Ppu_ChrUpgrade
:   .incbin "out/data/tiles/upgrade.chr"
    .incbin "out/data/tiles/crawler.chr"
    .res $60 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;
