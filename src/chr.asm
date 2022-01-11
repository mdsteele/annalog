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

kSizeofChr = 16

;;;=========================================================================;;;

.SEGMENT "CHR_Cave"

.EXPORT Ppu_ChrCave
Ppu_ChrCave:
:   .incbin "out/data/tiles/cave.chr"
    .res $31 * kSizeofChr
    .assert * - :- = kSizeofChr * 64, error

;;;=========================================================================;;;

.SEGMENT "CHR_Font"

.EXPORT Ppu_ChrFont
Ppu_ChrFont:
:   .incbin "out/data/tiles/font.chr"
    .res $22 * kSizeofChr
    .assert * - :- = kSizeofChr * 128, error

;;;=========================================================================;;;

.SEGMENT "CHR_Player"

.EXPORT Ppu_ChrPlayer
Ppu_ChrPlayer:
:   .incbin "out/data/tiles/cursor.chr"
    .incbin "out/data/tiles/player.chr"
    .res $6c * kSizeofChr
    .assert * - :- = kSizeofChr * 128, error

;;;=========================================================================;;;
