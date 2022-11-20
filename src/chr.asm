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

.INCLUDE "actors/crab.inc"
.INCLUDE "actors/fireball.inc"
.INCLUDE "actors/fish.inc"
.INCLUDE "actors/grenade.inc"
.INCLUDE "actors/grub.inc"
.INCLUDE "actors/hothead.inc"
.INCLUDE "actors/spider.inc"
.INCLUDE "actors/spike.inc"
.INCLUDE "actors/townsfolk.inc"
.INCLUDE "actors/vinebug.inc"
.INCLUDE "avatar.inc"
.INCLUDE "devices/breaker.inc"
.INCLUDE "machines/boiler.inc"
.INCLUDE "machines/cannon.inc"
.INCLUDE "machines/crane.inc"
.INCLUDE "machines/jet.inc"
.INCLUDE "machines/pump.inc"
.INCLUDE "machines/winch.inc"
.INCLUDE "rooms/garden_boss.inc"
.INCLUDE "rooms/garden_tower.inc"
.INCLUDE "upgrade.inc"

;;;=========================================================================;;;

.DEFINE kSizeofChr 16

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim0"

.EXPORT Ppu_ChrBgAnim0
.PROC Ppu_ChrBgAnim0
:   .incbin "out/data/tiles/water_anim0.chr"
    .incbin "out/data/tiles/conveyor_anim0.chr"
    .incbin "out/data/tiles/waterfall_anim0.chr"
    .incbin "out/data/tiles/thorns_anim0.chr"
    .res $0c * kSizeofChr
    .incbin "out/data/tiles/gazer_anim0.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim1"

.EXPORT Ppu_ChrBgAnim1
.PROC Ppu_ChrBgAnim1
:   .incbin "out/data/tiles/water_anim0.chr"
    .incbin "out/data/tiles/conveyor_anim0.chr"
    .incbin "out/data/tiles/waterfall_anim1.chr"
    .incbin "out/data/tiles/thorns_anim1.chr"
    .res $0c * kSizeofChr
    .incbin "out/data/tiles/gazer_anim0.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim2"

.EXPORT Ppu_ChrBgAnim2
.PROC Ppu_ChrBgAnim2
:   .incbin "out/data/tiles/water_anim1.chr"
    .incbin "out/data/tiles/conveyor_anim1.chr"
    .incbin "out/data/tiles/waterfall_anim2.chr"
    .incbin "out/data/tiles/thorns_anim2.chr"
    .res $0c * kSizeofChr
    .incbin "out/data/tiles/gazer_anim1.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim3"

.EXPORT Ppu_ChrBgAnim3
.PROC Ppu_ChrBgAnim3
:   .incbin "out/data/tiles/water_anim1.chr"
    .incbin "out/data/tiles/conveyor_anim1.chr"
    .incbin "out/data/tiles/waterfall_anim3.chr"
    .incbin "out/data/tiles/thorns_anim3.chr"
    .res $0c * kSizeofChr
    .incbin "out/data/tiles/gazer_anim1.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim4"

.EXPORT Ppu_ChrBgAnim4
.PROC Ppu_ChrBgAnim4
:   .incbin "out/data/tiles/water_anim2.chr"
    .incbin "out/data/tiles/conveyor_anim2.chr"
    .incbin "out/data/tiles/waterfall_anim0.chr"
    .incbin "out/data/tiles/thorns_anim4.chr"
    .res $0c * kSizeofChr
    .incbin "out/data/tiles/gazer_anim2.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim5"

.EXPORT Ppu_ChrBgAnim5
.PROC Ppu_ChrBgAnim5
:   .incbin "out/data/tiles/water_anim2.chr"
    .incbin "out/data/tiles/conveyor_anim2.chr"
    .incbin "out/data/tiles/waterfall_anim1.chr"
    .incbin "out/data/tiles/thorns_anim5.chr"
    .res $0c * kSizeofChr
    .incbin "out/data/tiles/gazer_anim2.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim6"

.EXPORT Ppu_ChrBgAnim6
.PROC Ppu_ChrBgAnim6
:   .incbin "out/data/tiles/water_anim1.chr"
    .incbin "out/data/tiles/conveyor_anim3.chr"
    .incbin "out/data/tiles/waterfall_anim2.chr"
    .incbin "out/data/tiles/thorns_anim6.chr"
    .res $0c * kSizeofChr
    .incbin "out/data/tiles/gazer_anim3.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnim7"

.EXPORT Ppu_ChrBgAnim7
.PROC Ppu_ChrBgAnim7
:   .incbin "out/data/tiles/water_anim1.chr"
    .incbin "out/data/tiles/conveyor_anim3.chr"
    .incbin "out/data/tiles/waterfall_anim3.chr"
    .incbin "out/data/tiles/thorns_anim7.chr"
    .res $0c * kSizeofChr
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
    .res $04 * kSizeofChr
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

.SEGMENT "CHR_BgFontLower04"

.PROC Ppu_ChrBgFontLower04
:   .incbin "out/data/tiles/font_lower.chr"
    .incbin "out/data/tiles/diagram04.chr"
    .incbin "out/data/tiles/portrait04.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower05"

.PROC Ppu_ChrBgFontLower05
:   .incbin "out/data/tiles/font_lower.chr"
    .incbin "out/data/tiles/diagram05.chr"
    .incbin "out/data/tiles/portrait05.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower06"

.PROC Ppu_ChrBgFontLower06
:   .incbin "out/data/tiles/font_lower.chr"
    .incbin "out/data/tiles/diagram06.chr"
    .incbin "out/data/tiles/portrait06.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower07"

.PROC Ppu_ChrBgFontLower07
:   .incbin "out/data/tiles/font_lower.chr"
    .res $10 * kSizeofChr
    .incbin "out/data/tiles/portrait07.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower08"

.PROC Ppu_ChrBgFontLower08
:   .incbin "out/data/tiles/font_lower.chr"
    .res $10 * kSizeofChr
    .incbin "out/data/tiles/portrait08.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower09"

.PROC Ppu_ChrBgFontLower09
:   .incbin "out/data/tiles/font_lower.chr"
    .res $10 * kSizeofChr
    .incbin "out/data/tiles/portrait09.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0A"

.PROC Ppu_ChrBgFontLower0A
:   .incbin "out/data/tiles/font_lower.chr"
    .res $10 * kSizeofChr
    .incbin "out/data/tiles/portrait0a.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFactory"

.EXPORT Ppu_ChrBgFactory
.PROC Ppu_ChrBgFactory
:   .incbin "out/data/tiles/cave.chr"
    .incbin "out/data/tiles/metal.chr"
    .res $10 * kSizeofChr
    .incbin "out/data/tiles/device.chr"
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
    .res $02 * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgHut"

.EXPORT Ppu_ChrBgHut
.PROC Ppu_ChrBgHut
:   .incbin "out/data/tiles/hut1.chr"
    .incbin "out/data/tiles/hut2.chr"
    .res $1e * kSizeofChr
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
    .res $10 * kSizeofChr
    .incbin "out/data/tiles/field_bg.chr"
    .res $04 * kSizeofChr
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
    .incbin "out/data/tiles/lever_ceil.chr"
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMine"

.EXPORT Ppu_ChrBgMine
.PROC Ppu_ChrBgMine
:   .incbin "out/data/tiles/crystal.chr"
    .res $24 * kSizeofChr
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
    .res $04 * kSizeofChr
    .incbin "out/data/tiles/minimap4.chr"
    .res $05 * kSizeofChr
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
    .res $0f * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPause"

.EXPORT Ppu_ChrBgPause
.PROC Ppu_ChrBgPause
:   .incbin "out/data/tiles/upgrade_bottom.chr"
    .incbin "out/data/tiles/upgrade_maxinst.chr"
    .incbin "out/data/tiles/upgrade_bremote.chr"
    .incbin "out/data/tiles/upgrade_opif.chr"
    .incbin "out/data/tiles/upgrade_optil.chr"
    .incbin "out/data/tiles/upgrade_opcopy.chr"
    .incbin "out/data/tiles/upgrade_opaddsub.chr"
    .incbin "out/data/tiles/upgrade_opmul.chr"
    .incbin "out/data/tiles/upgrade_opbeep.chr"
    .incbin "out/data/tiles/upgrade_opgoto.chr"
    .incbin "out/data/tiles/upgrade_opskip.chr"
    .incbin "out/data/tiles/upgrade_opwait.chr"
    .incbin "out/data/tiles/upgrade_opsync.chr"
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
    .res $28 * kSizeofChr
    .incbin "out/data/tiles/device.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgTemple"

.EXPORT Ppu_ChrBgTemple
.PROC Ppu_ChrBgTemple
:   .incbin "out/data/tiles/temple1.chr"
    .incbin "out/data/tiles/temple2.chr"
    .incbin "out/data/tiles/temple3.chr"
    .res $0e * kSizeofChr
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

.SEGMENT "CHR_ObjCrypt"

.EXPORT Ppu_ChrObjCrypt
.PROC Ppu_ChrObjCrypt
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_bottom.chr"
    .res $10 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpGotoFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_opgoto.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpWaitFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_opwait.chr"
    .res $18 * kSizeofChr
    .assert * - :- = (kTileIdObjSpiderFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/spider.chr"
    .assert * - :- = (kTileIdCrusherFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/crusher.chr"
    .assert * - :- = (kTileIdWinchFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/winch.chr"
    .incbin "out/data/tiles/gazer_obj.chr"
    .assert * - :- = (kTileIdWeakFloorFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/breakable.chr"
    .res $27 * kSizeofChr
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjFactory"

.EXPORT Ppu_ChrObjFactory
.PROC Ppu_ChrObjFactory
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_bottom.chr"
    .res $12 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpSkipFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_opskip.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdJetFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/jet.chr"
    .res $60 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjGarden"

.EXPORT Ppu_ChrObjGarden
.PROC Ppu_ChrObjGarden
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjUpgradeMaxInstFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_maxinst.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpIfFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_opif.chr"
    .assert * - :- = (kTileIdCannonFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/cannon.chr"
    .assert * - :- = (kTileIdMermaidAdultFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaid_adult.chr"
    .res $06 * kSizeofChr
    .assert * - :- = (kTileIdObjFireballFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/fireball.chr"
    .assert * - :- = (kTileIdObjGrubFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/grub.chr"
    .assert * - :- = (kTileIdObjSpike - $80) * kSizeofChr, error
    .incbin "out/data/tiles/spike.chr"
    .res $01 * kSizeofChr
    .assert * - :- = (kTileIdObjGardenBricksFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/garden_bricks.chr"
    .assert * - :- = (kTileIdVinebugFirst1 - $80) * kSizeofChr, error
    .incbin "out/data/tiles/vinebug.chr"
    .assert * - :- = (kTileIdObjPlantEyeFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/plant_eye.chr"
    .assert * - :- = (kTileIdObjCrateFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/crate.chr"
    .assert * - :- = (kTileIdObjGrenadeFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/grenade.chr"
    .assert * - :- = (kTileIdObjBeetleFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/beetle.chr"
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjLava"

.EXPORT Ppu_ChrObjLava
.PROC Ppu_ChrObjLava
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjUpgradeMaxInstFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_maxinst.chr"
    .res $06 * kSizeofChr
    .incbin "out/data/tiles/upgrade_opcopy.chr"
    .assert * - :- = (kTileIdObjUpgradeOpAddSubFirst - $80) * kSizeofChr, error
    .res $0e * kSizeofChr
    .incbin "out/data/tiles/boiler.chr"
    .assert * - :- = (kTileIdValveFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/valve.chr"
    .assert * - :- = (kTileIdObjHotheadFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/hothead.chr"
    .res $40 * kSizeofChr
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjMermaid"

.EXPORT Ppu_ChrObjMermaid
.PROC Ppu_ChrObjMermaid
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_bottom.chr"
    .res $0e * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpBeepFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_opbeep.chr"
    .res $37 * kSizeofChr
    .assert * - :- = (kTileIdObjFishFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/fish.chr"
    .assert * - :- = (kTileIdObjCrabFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/crab.chr"
    .res $07 * kSizeofChr
    .assert * - :- = (kTileIdObjHotSpringFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/hotspring.chr"
    .res $18 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjMine"

.EXPORT Ppu_ChrObjMine
.PROC Ppu_ChrObjMine
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjUpgradeMaxInstFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_maxinst.chr"
    .res $14 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpSyncFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_opsync.chr"
    .assert * - :- = (kTileIdCraneFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/crane.chr"
    .res $51 * kSizeofChr
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjPause"

.EXPORT Ppu_ChrObjPause
.PROC Ppu_ChrObjPause
:   .incbin "out/data/tiles/font_upper.chr"
    .incbin "out/data/tiles/miniflow.chr"
    .res $34 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjPrison"

.EXPORT Ppu_ChrObjPrison
.PROC Ppu_ChrObjPrison
:   .res $1c * kSizeofChr
    .assert * - :- = (kTileIdObjGrubFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/grub.chr"
    .res $39 * kSizeofChr
    .incbin "out/data/tiles/prison_obj.chr"
    .res $1c * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjSewer"

.EXPORT Ppu_ChrObjSewer
.PROC Ppu_ChrObjSewer
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_bottom.chr"
    .res $0a * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpAddSubFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_opaddsub.chr"
    .res $0c * kSizeofChr
    .assert * - :- = (kTileIdObjWaterFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/water.chr"
    .res $63 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjTemple"

.EXPORT Ppu_ChrObjTemple
.PROC Ppu_ChrObjTemple
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjUpgradeMaxInstFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/upgrade_maxinst.chr"
    .assert * - :- = (kTileIdObjUpgradeBRemoteFirst - $80) * kSizeofChr, error
    .res $04 * kSizeofChr
    .incbin "out/data/tiles/upgrade_optil.chr"
    .assert * - :- = (kTileIdObjUpgradeOpCopyFirst - $80) * kSizeofChr, error
    .res $10 * kSizeofChr
    .incbin "out/data/tiles/column.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdMermaidGuardFFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaid_guardf.chr"
    .res $3a * kSizeofChr
    .assert * - :- = (kTileIdObjBeetleFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/beetle.chr"
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/breaker.chr"
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
    .incbin "out/data/tiles/mermaid_florist.chr"
    .assert * - :- = (kTileIdMermaidYouthFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaid_youth.chr"
    .assert * - :- = (kTileIdMermaidGuardFFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaid_guardf.chr"
    .assert * - :- = (kTileIdMermaidPonytailFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaids.chr"
    .assert * - :- = (kTileIdMermaidQueenFirst - $80) * kSizeofChr, error
    .incbin "out/data/tiles/mermaid_queen.chr"
    .res $34 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;
