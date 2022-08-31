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

.INCLUDE "actors/crawler.inc"
.INCLUDE "actors/fireball.inc"
.INCLUDE "actors/grenade.inc"
.INCLUDE "actors/townsfolk.inc"
.INCLUDE "actors/vinebug.inc"
.INCLUDE "avatar.inc"
.INCLUDE "device.inc"
.INCLUDE "machines/cannon.inc"

;;;=========================================================================;;;

.DEFINE kSizeofChr 16

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim0"

.EXPORT Ppu_ChrBgAnim0
.PROC Ppu_ChrBgAnim0
:   .incbin "out/data/tiles/anim01.chr"
    .res $26 * kSizeofChr
    .incbin "out/data/tiles/gazer_anim0.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim1"

.EXPORT Ppu_ChrBgAnim1
.PROC Ppu_ChrBgAnim1
:   .incbin "out/data/tiles/anim11.chr"
    .res $26 * kSizeofChr
    .incbin "out/data/tiles/gazer_anim1.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim2"

.EXPORT Ppu_ChrBgAnim2
.PROC Ppu_ChrBgAnim2
:   .incbin "out/data/tiles/anim21.chr"
    .res $26 * kSizeofChr
    .incbin "out/data/tiles/gazer_anim2.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim3"

.EXPORT Ppu_ChrBgAnim3
.PROC Ppu_ChrBgAnim3
:   .incbin "out/data/tiles/anim31.chr"
    .res $26 * kSizeofChr
    .incbin "out/data/tiles/gazer_anim3.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgCrypt"

.EXPORT Ppu_ChrBgCrypt
.PROC Ppu_ChrBgCrypt
:   .incbin "out/data/tiles/crypt.chr"
    .res $02 * kSizeofChr
    .incbin "out/data/tiles/cobweb.chr"
    .res $08 * kSizeofChr
    .incbin "out/data/tiles/gazer_eye.chr"
    .res $04 * kSizeofChr
    .incbin "out/data/tiles/arch.chr"
    .res $02 * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontUpper"

.EXPORT Ppu_ChrBgFontUpper
.PROC Ppu_ChrBgFontUpper
:   .incbin "out/data/tiles/font_upper.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower01"

.EXPORT Ppu_ChrBgFontLower01
.PROC Ppu_ChrBgFontLower01
:   .incbin "out/data/tiles/font_lower.chr"
    .incbin "out/data/tiles/diagram01.chr"
    .incbin "out/data/tiles/portrait01.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower02"

.PROC Ppu_ChrBgFontLower02
:   .incbin "out/data/tiles/font_lower.chr"
    .incbin "out/data/tiles/diagram02.chr"
    .incbin "out/data/tiles/portrait02.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower03"

.PROC Ppu_ChrBgFontLower03
:   .incbin "out/data/tiles/font_lower.chr"
    .incbin "out/data/tiles/diagram03.chr"
    .incbin "out/data/tiles/portrait03.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgGarden"

.EXPORT Ppu_ChrBgGarden
.PROC Ppu_ChrBgGarden
:   .incbin "out/data/tiles/jungle1.chr"
    .incbin "out/data/tiles/jungle2.chr"
    .incbin "out/data/tiles/jungle3.chr"
    .incbin "out/data/tiles/arch.chr"
    .incbin "out/data/tiles/drawbridge.chr"
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgHut"

.EXPORT Ppu_ChrBgHut
.PROC Ppu_ChrBgHut
:   .incbin "out/data/tiles/hut1.chr"
    .incbin "out/data/tiles/hut2.chr"
    .res $1c * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgIndoors"

.EXPORT Ppu_ChrBgIndoors
.PROC Ppu_ChrBgIndoors
:   .incbin "out/data/tiles/indoors.chr"
    .res $08 * kSizeofChr
    .incbin "out/data/tiles/window.chr"
    .incbin "out/data/tiles/furniture.chr"
    .res $17 * kSizeofChr
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgLava"

.EXPORT Ppu_ChrBgLava
.PROC Ppu_ChrBgLava
:   .incbin "out/data/tiles/steam_pipes.chr"
    .incbin "out/data/tiles/volcanic.chr"
    .res $16 * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMermaid"

.EXPORT Ppu_ChrBgMermaid
.PROC Ppu_ChrBgMermaid
:   .incbin "out/data/tiles/cave.chr"
    .incbin "out/data/tiles/hut.chr"
    .res $03 * kSizeofChr
    .incbin "out/data/tiles/beach.chr"
    .res $0e * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMinimap"

.EXPORT Ppu_ChrBgMinimap
.PROC Ppu_ChrBgMinimap
:   .incbin "out/data/tiles/minimap1.chr"
    .incbin "out/data/tiles/minimap2.chr"
    .incbin "out/data/tiles/minimap3.chr"
    .res $05 * kSizeofChr
    .incbin "out/data/tiles/minimap4.chr"
    .res $0b * kSizeofChr
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgOutdoors"

.EXPORT Ppu_ChrBgOutdoors
.PROC Ppu_ChrBgOutdoors
:   .incbin "out/data/tiles/outdoors.chr"
    .incbin "out/data/tiles/roof.chr"
    .incbin "out/data/tiles/window.chr"
    .incbin "out/data/tiles/house.chr"
    .res $0d * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPause"

.EXPORT Ppu_ChrBgPause
.PROC Ppu_ChrBgPause
:   .incbin "out/data/tiles/upgrade.chr"
    .res $06 * kSizeofChr
    .incbin "out/data/tiles/minicore1.chr"
    .res $07 * kSizeofChr
    .incbin "out/data/tiles/minicore2.chr"
    .res $04 * kSizeofChr
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPrison"

.EXPORT Ppu_ChrBgPrison
.PROC Ppu_ChrBgPrison
:   .incbin "out/data/tiles/cave.chr"
    .res $26 * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgTitle"

.EXPORT Ppu_ChrBgTitle
.PROC Ppu_ChrBgTitle
:   .incbin "out/data/tiles/title1.chr"
    .incbin "out/data/tiles/title2.chr"
    .incbin "out/data/tiles/title3.chr"
    .res $1b * kSizeofChr
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjAnnaFlower"

.EXPORT Ppu_ChrObjAnnaFlower
.PROC Ppu_ChrObjAnnaFlower
:   .incbin "out/data/tiles/font_hilight.chr"
    .assert * - :- = kSizeofChr * eAvatar::Standing, error
    .incbin "out/data/tiles/player_flower.chr"
    .incbin "out/data/tiles/machine.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjAnnaNormal"

.EXPORT Ppu_ChrObjAnnaNormal
.PROC Ppu_ChrObjAnnaNormal
:   .incbin "out/data/tiles/font_hilight.chr"
    .assert * - :- = kSizeofChr * eAvatar::Standing, error
    .incbin "out/data/tiles/player_normal.chr"
    .incbin "out/data/tiles/machine.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjGarden"

.EXPORT Ppu_ChrObjGarden
.PROC Ppu_ChrObjGarden
:   .res $0e * kSizeofChr
    .assert * - :- = (kTileIdMermaidAdultFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaid_adult.chr"
    .res $06 * kSizeofChr
    .assert * - :- = (kFireballFirstTileId - $80) * kSizeofChr, error
    .incbin "out/data/tiles/fireball.chr"
    .assert * - :- = (kCrawlerFirstTileId1 - $80) * kSizeofChr, error
    .incbin "out/data/tiles/crawler.chr"
    .incbin "out/data/tiles/spike.chr"
    .incbin "out/data/tiles/eye.chr"
    .assert * - :- = (kTileIdVinebugFirst1 - $80) * kSizeofChr, error
    .incbin "out/data/tiles/vinebug.chr"
    .assert * - :- = (kTileIdCannonFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/cannon.chr"
    .res $1f * kSizeofChr
    .assert * - :- = (kGrenadeFirstTileId - $80) * kSizeofChr, error
    .incbin "out/data/tiles/grenade.chr"
    .res $1f * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjTownsfolk"

.EXPORT Ppu_ChrObjTownsfolk
.PROC Ppu_ChrObjTownsfolk
:   .incbin "out/data/tiles/children.chr"
    .assert * - :- = (kTileIdAdultWomanFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/adults.chr"
    .assert * - :- = (kTileIdMermaidAdultFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaid_adult.chr"
    .assert * - :- = (kTileIdMermaidFloristFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaids.chr"
    ;; .assert * - :- = (kMermaidWorkerFirstTileId - $80) * kSizeofChr, error
    ;; .incbin "out/data/tiles/mermaid_worker.chr"
    .res $3c * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjUpgrade"

.EXPORT Ppu_ChrObjUpgrade
.PROC Ppu_ChrObjUpgrade
:   .incbin "out/data/tiles/upgrade.chr"
    .assert * - :- = (kFireballFirstTileId - $80) * kSizeofChr, error
    .incbin "out/data/tiles/fireball.chr"
    .assert * - :- = (kCrawlerFirstTileId1 - $80) * kSizeofChr, error
    .incbin "out/data/tiles/crawler.chr"
    .incbin "out/data/tiles/spike.chr"
    .incbin "out/data/tiles/eye.chr"
    .incbin "out/data/tiles/spider.chr"
    .incbin "out/data/tiles/crusher.chr"
    .incbin "out/data/tiles/winch.chr"
    .incbin "out/data/tiles/gazer_obj.chr"
    .incbin "out/data/tiles/breakable.chr"
    .incbin "out/data/tiles/fish.chr"
    .incbin "out/data/tiles/crab.chr"
    .assert * - :- = (kGrenadeFirstTileId - $80) * kSizeofChr, error
    .incbin "out/data/tiles/grenade.chr"
    .incbin "out/data/tiles/prison_obj.chr"
    .incbin "out/data/tiles/valve.chr"
    .res $08 * kSizeofChr
    .assert * - :- = (kTileIdBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;
