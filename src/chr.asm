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

.INCLUDE "actors/acid.inc"
.INCLUDE "actors/adult.inc"
.INCLUDE "actors/axe.inc"
.INCLUDE "actors/bat.inc"
.INCLUDE "actors/bird.inc"
.INCLUDE "actors/breakball.inc"
.INCLUDE "actors/breakbomb.inc"
.INCLUDE "actors/breakfire.inc"
.INCLUDE "actors/bullet.inc"
.INCLUDE "actors/child.inc"
.INCLUDE "actors/crab.inc"
.INCLUDE "actors/crawler.inc"
.INCLUDE "actors/dirt.inc"
.INCLUDE "actors/duck.inc"
.INCLUDE "actors/ember.inc"
.INCLUDE "actors/fireball.inc"
.INCLUDE "actors/firefly.inc"
.INCLUDE "actors/fish.inc"
.INCLUDE "actors/flamestrike.inc"
.INCLUDE "actors/flydrop.inc"
.INCLUDE "actors/goo.inc"
.INCLUDE "actors/grenade.inc"
.INCLUDE "actors/grub.inc"
.INCLUDE "actors/jelly.inc"
.INCLUDE "actors/lavaball.inc"
.INCLUDE "actors/orc.inc"
.INCLUDE "actors/queen.inc"
.INCLUDE "actors/raindrop.inc"
.INCLUDE "actors/rhino.inc"
.INCLUDE "actors/rodent.inc"
.INCLUDE "actors/slime.inc"
.INCLUDE "actors/spider.inc"
.INCLUDE "actors/spike.inc"
.INCLUDE "actors/spine.inc"
.INCLUDE "actors/steam.inc"
.INCLUDE "actors/toad.inc"
.INCLUDE "actors/toddler.inc"
.INCLUDE "actors/vinebug.inc"
.INCLUDE "actors/wasp.inc"
.INCLUDE "avatar.inc"
.INCLUDE "devices/breaker.inc"
.INCLUDE "dialog.inc"
.INCLUDE "machines/ammorack.inc"
.INCLUDE "machines/blaster.inc"
.INCLUDE "machines/boiler.inc"
.INCLUDE "machines/bridge.inc"
.INCLUDE "machines/cannon.inc"
.INCLUDE "machines/carriage.inc"
.INCLUDE "machines/conveyor.inc"
.INCLUDE "machines/crane.inc"
.INCLUDE "machines/drums.inc"
.INCLUDE "machines/emitter.inc"
.INCLUDE "machines/field.inc"
.INCLUDE "machines/hoist.inc"
.INCLUDE "machines/jet.inc"
.INCLUDE "machines/laser.inc"
.INCLUDE "machines/launcher.inc"
.INCLUDE "machines/lift.inc"
.INCLUDE "machines/minigun.inc"
.INCLUDE "machines/multiplexer.inc"
.INCLUDE "machines/organ.inc"
.INCLUDE "machines/pump.inc"
.INCLUDE "machines/reloader.inc"
.INCLUDE "machines/rotor.inc"
.INCLUDE "machines/semaphore.inc"
.INCLUDE "machines/shared.inc"
.INCLUDE "machines/trombone.inc"
.INCLUDE "machines/winch.inc"
.INCLUDE "pause.inc"
.INCLUDE "platforms/barrier.inc"
.INCLUDE "platforms/chex.inc"
.INCLUDE "platforms/column.inc"
.INCLUDE "platforms/crate.inc"
.INCLUDE "platforms/force.inc"
.INCLUDE "platforms/gate.inc"
.INCLUDE "platforms/girder.inc"
.INCLUDE "platforms/glass.inc"
.INCLUDE "platforms/monitor.inc"
.INCLUDE "platforms/stepstone.inc"
.INCLUDE "platforms/water.inc"
.INCLUDE "portrait.inc"
.INCLUDE "rooms/boss_city.inc"
.INCLUDE "rooms/boss_crypt.inc"
.INCLUDE "rooms/boss_garden.inc"
.INCLUDE "rooms/boss_lava.inc"
.INCLUDE "rooms/boss_mine.inc"
.INCLUDE "rooms/boss_shadow.inc"
.INCLUDE "rooms/boss_temple.inc"
.INCLUDE "rooms/city_center.inc"
.INCLUDE "rooms/garden_tower.inc"
.INCLUDE "rooms/mine_west.inc"
.INCLUDE "upgrade.inc"

;;;=========================================================================;;;

.DEFINE kSizeofChr 16

.MACRO CHR_BANK FIRST, SIZE
    .scope
    _chr_first .set FIRST
    _chr_count .set SIZE
_chr_begin:
.ENDMACRO

.MACRO CHR1_BANK FIRST
    CHR_BANK FIRST, $40
.ENDMACRO

.MACRO CHR2_BANK FIRST
    CHR_BANK FIRST, $80
.ENDMACRO

.MACRO END_CHR_BANK
    .assert * - _chr_begin = kSizeofChr * _chr_count, error
    .endscope
.ENDMACRO

.MACRO chr_inc NAME, FIRST
    .ifnblank FIRST
    .assert * - _chr_begin = ((FIRST) - _chr_first) * kSizeofChr, error
    .endif
    .incbin .sprintf("out/tiles/%s.chr", NAME)
.ENDMACRO

.MACRO chr_res COUNT
    .res kSizeofChr * (COUNT)
.ENDMACRO

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA0"

.EXPORT Ppu_ChrBgAnimA0
.PROC Ppu_ChrBgAnimA0
    CHR1_BANK $40
    chr_inc "water_anim0"
    chr_inc "acid_anim0"
    chr_inc "waterfall_anim0"
    chr_inc "anim_seaweed_0"
    chr_inc "thorns_anim0"
    chr_inc "sewage_anim0"
    chr_inc "circuit_anim0"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA1"

.PROC Ppu_ChrBgAnimA1
    CHR1_BANK $40
    chr_inc "water_anim0"
    chr_inc "acid_anim1"
    chr_inc "waterfall_anim1"
    chr_inc "anim_seaweed_0"
    chr_inc "thorns_anim1"
    chr_inc "sewage_anim1"
    chr_inc "circuit_anim1"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA2"

.PROC Ppu_ChrBgAnimA2
    CHR1_BANK $40
    chr_inc "water_anim1"
    chr_inc "acid_anim2"
    chr_inc "waterfall_anim2"
    chr_inc "anim_seaweed_1"
    chr_inc "thorns_anim2"
    chr_inc "sewage_anim2"
    chr_inc "circuit_anim2"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA3"

.PROC Ppu_ChrBgAnimA3
    CHR1_BANK $40
    chr_inc "water_anim1"
    chr_inc "acid_anim3"
    chr_inc "waterfall_anim3"
    chr_inc "anim_seaweed_1"
    chr_inc "thorns_anim3"
    chr_inc "sewage_anim3"
    chr_inc "circuit_anim3"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA4"

.PROC Ppu_ChrBgAnimA4
    CHR1_BANK $40
    chr_inc "water_anim2"
    chr_inc "acid_anim4"
    chr_inc "waterfall_anim0"
    chr_inc "anim_seaweed_2"
    chr_inc "thorns_anim4"
    chr_inc "sewage_anim0"
    chr_inc "circuit_anim4"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA5"

.PROC Ppu_ChrBgAnimA5
    CHR1_BANK $40
    chr_inc "water_anim2"
    chr_inc "acid_anim5"
    chr_inc "waterfall_anim1"
    chr_inc "anim_seaweed_2"
    chr_inc "thorns_anim5"
    chr_inc "sewage_anim1"
    chr_inc "circuit_anim5"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA6"

.PROC Ppu_ChrBgAnimA6
    CHR1_BANK $40
    chr_inc "water_anim1"
    chr_inc "acid_anim6"
    chr_inc "waterfall_anim2"
    chr_inc "anim_seaweed_3"
    chr_inc "thorns_anim6"
    chr_inc "sewage_anim2"
    chr_inc "circuit_anim6"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA7"

.PROC Ppu_ChrBgAnimA7
    CHR1_BANK $40
    chr_inc "water_anim1"
    chr_inc "acid_anim7"
    chr_inc "waterfall_anim3"
    chr_inc "anim_seaweed_3"
    chr_inc "thorns_anim7"
    chr_inc "sewage_anim3"
    chr_inc "circuit_anim7"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB0"

.EXPORT Ppu_ChrBgAnimB0
.PROC Ppu_ChrBgAnimB0
    CHR1_BANK $40
    chr_inc "lava_anim0"
    chr_res $06
    chr_inc "anim_conveyor_0"
    chr_res $05
    chr_inc "anim_boss_lava_2",  kTileIdBgAnimBossLavaFirst
    chr_inc "anim_rocks_fall_0"
    chr_inc "anim_boss_crypt_0", kTileIdBgAnimBossCryptFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB1"

.PROC Ppu_ChrBgAnimB1
    CHR1_BANK $40
    chr_inc "lava_anim1"
    chr_res $06
    chr_inc "anim_conveyor_1"
    chr_res $05
    chr_inc "anim_boss_lava_1",  kTileIdBgAnimBossLavaFirst
    chr_inc "anim_rocks_fall_1"
    chr_inc "anim_boss_crypt_1", kTileIdBgAnimBossCryptFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB2"

.PROC Ppu_ChrBgAnimB2
    CHR1_BANK $40
    chr_inc "lava_anim2"
    chr_res $06
    chr_inc "anim_conveyor_2"
    chr_res $05
    chr_inc "anim_boss_lava_2",  kTileIdBgAnimBossLavaFirst
    chr_inc "anim_rocks_fall_2"
    chr_inc "anim_boss_crypt_2", kTileIdBgAnimBossCryptFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB3"

.PROC Ppu_ChrBgAnimB3
    CHR1_BANK $40
    chr_inc "lava_anim3"
    chr_res $06
    chr_inc "anim_conveyor_3"
    chr_res $05
    chr_inc "anim_boss_lava_3",  kTileIdBgAnimBossLavaFirst
    chr_inc "anim_rocks_fall_3"
    chr_inc "anim_boss_crypt_3", kTileIdBgAnimBossCryptFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB4"

.EXPORT Ppu_ChrBgAnimB4
.PROC Ppu_ChrBgAnimB4
    CHR1_BANK $40
    chr_inc "anim_outbreak_0"
    chr_inc "anim_rocks_fall_4"
    chr_res $04
    chr_inc "anim_wyrm_0", kTileIdBgAnimWyrmFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB5"

.PROC Ppu_ChrBgAnimB5
    CHR1_BANK $40
    chr_inc "anim_outbreak_1"
    chr_inc "anim_rocks_fall_5"
    chr_res $04
    chr_inc "anim_wyrm_1", kTileIdBgAnimWyrmFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB6"

.PROC Ppu_ChrBgAnimB6
    CHR1_BANK $40
    chr_inc "anim_outbreak_2"
    chr_inc "anim_rocks_fall_6"
    chr_res $04
    chr_inc "anim_wyrm_2", kTileIdBgAnimWyrmFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB7"

.PROC Ppu_ChrBgAnimB7
    CHR1_BANK $40
    chr_res $28
    chr_inc "anim_rocks_fall_7"
    chr_res $04
    chr_inc "anim_wyrm_3", kTileIdBgAnimWyrmFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimStatic"

.EXPORT Ppu_ChrBgAnimStatic
.PROC Ppu_ChrBgAnimStatic
    CHR1_BANK $40
    chr_res $10
    chr_inc "thorns_anim_static"
    chr_res $0a
    chr_inc "circuit_anim_static"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgBossStatic"

.EXPORT Ppu_ChrBgBossStatic
.PROC Ppu_ChrBgBossStatic
    CHR1_BANK $40
    chr_inc "boss_city"
    chr_res $04
    chr_inc "anim_wyrm_static"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgBuilding"

.EXPORT Ppu_ChrBgBuilding
.PROC Ppu_ChrBgBuilding
    CHR1_BANK $80
    chr_inc "building1"
    chr_inc "building2"
    chr_inc "building3"
    chr_inc "building4"
    chr_res $0e
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgCity"

.EXPORT Ppu_ChrBgCity
.PROC Ppu_ChrBgCity
    CHR1_BANK $80
    chr_inc "city1"
    chr_inc "city2"
    chr_inc "city3"
    chr_inc "city4"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgCore"

.EXPORT Ppu_ChrBgCore
.PROC Ppu_ChrBgCore
    CHR1_BANK $80
    chr_inc "core_pipes1"
    chr_inc "core_pipes2"
    chr_res $04
    chr_inc "fullcore1"
    chr_inc "fullcore2"
    chr_res $04
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgCrypt"

.EXPORT Ppu_ChrBgCrypt
.PROC Ppu_ChrBgCrypt
    CHR1_BANK $80
    chr_inc "crypt"
    chr_res $02
    chr_inc "cobweb"
    chr_res $0c
    chr_inc "boss_crypt_eye_white", kTileIdBgBossCryptEyeWhiteFirst
    chr_inc "arch"
    chr_inc "boss_crypt_eye_red",   kTileIdBgBossCryptEyeRedFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFactory"

.EXPORT Ppu_ChrBgFactory
.PROC Ppu_ChrBgFactory
    CHR1_BANK $80
    chr_inc "factory1"
    chr_inc "factory2"
    chr_res $08
    chr_inc "tank"
    chr_res $06
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower"

.EXPORT Ppu_ChrBgFontLower
.PROC Ppu_ChrBgFontLower
    CHR1_BANK $00
    chr_inc "terrain_shared_0", $00
    chr_inc "terrain_shared_1", $10
    chr_inc "font_lower"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontUpper"

.EXPORT Ppu_ChrBgFontUpper
.PROC Ppu_ChrBgFontUpper
    CHR1_BANK $40
    chr_inc "font_upper"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgGarden"

.EXPORT Ppu_ChrBgGarden
.PROC Ppu_ChrBgGarden
    CHR1_BANK $80
    chr_inc "jungle1"
    chr_inc "jungle2"
    chr_inc "jungle3"
    chr_inc "arch"
    chr_inc "drawbridge"
    chr_res $0a
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgHouse"

.EXPORT Ppu_ChrBgHouse
.PROC Ppu_ChrBgHouse
    CHR1_BANK $80
    chr_inc "indoors"
    chr_res $07
    chr_inc "window"
    chr_inc "terrain_furniture"
    chr_res $12
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgHut"

.EXPORT Ppu_ChrBgHut
.PROC Ppu_ChrBgHut
    CHR1_BANK $80
    chr_inc "terrain_hut0"
    chr_inc "terrain_hut1"
    chr_inc "terrain_hut2"
    chr_inc "terrain_hut3"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgLava"

.EXPORT Ppu_ChrBgLava
.PROC Ppu_ChrBgLava
    CHR1_BANK $80
    chr_inc "steam_pipes"
    chr_inc "volcanic1"
    chr_inc "volcanic2"
    chr_inc "terrain_boss_lava",      kTileIdBgTerrainBossLavaFirst
    chr_inc "arch"
    chr_inc "boiler"
    chr_inc "terrain_boss_lava_hurt", kTileIdBgTerrainBossLavaHurtFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMermaid"

.EXPORT Ppu_ChrBgMermaid
.PROC Ppu_ChrBgMermaid
    CHR1_BANK $80
    chr_inc "cave"
    chr_inc "hut"
    chr_inc "terrain_mermaid_2"
    chr_inc "terrain_mermaid_3"
    chr_inc "pump"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMine"

.EXPORT Ppu_ChrBgMine
.PROC Ppu_ChrBgMine
    CHR1_BANK $80
    chr_inc "crystal"
    chr_inc "minecart"
    chr_inc "scaffhold"
    chr_inc "mine_door"
    chr_inc "terrain_hoist"
    chr_inc "terrain_conveyor", kTileIdBgTerrainConveyorFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMinimap"

.EXPORT Ppu_ChrBgMinimap
.PROC Ppu_ChrBgMinimap
    CHR1_BANK $c0
    chr_inc "minimap1"
    chr_inc "minimap2"
    chr_inc "minimap3"
    chr_inc "minimap4"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgOutdoors"

.EXPORT Ppu_ChrBgOutdoors
.PROC Ppu_ChrBgOutdoors
    CHR1_BANK $80
    chr_inc "outdoors"
    chr_inc "roof"
    chr_inc "window"
    chr_inc "house"
    chr_inc "tree"
    chr_inc "hill"
    chr_res $08
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPause"

.EXPORT Ppu_ChrBgPause
.PROC Ppu_ChrBgPause
    CHR1_BANK $80
    chr_inc "upgrade_bottom",  kTileIdBgUpgradeBottomFirst
    chr_inc "upgrade_ram",     kTileIdBgUpgradeRamFirst
    chr_inc "upgrade_bremote"
    chr_inc "upgrade_opif"
    chr_inc "upgrade_optil"
    chr_inc "upgrade_opcopy"
    chr_inc "upgrade_opaddsub"
    chr_inc "upgrade_opmul"
    chr_inc "upgrade_opbeep"
    chr_inc "upgrade_opgoto"
    chr_inc "upgrade_opskip"
    chr_inc "upgrade_oprest"
    chr_inc "upgrade_opsync"
    chr_res $06
    chr_inc "minicore1"
    chr_res $06
    chr_inc "minicore2"
    chr_inc "paper"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait01"

.PROC Ppu_ChrBgPortrait01
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitAlexRest, error
    chr_inc "portrait_alex_rest", kTileIdBgPortraitAlexFirst
    .assert .bank(*) = kChrBankPortraitPaper, error
    chr_inc "portrait_paper", kTileIdBgPortraitPaperFirst
    .assert .bank(*) = kChrBankDiagramDebugger, error
    chr_inc "diagram_debugger"
    chr_inc "diagram_debugger"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait02"

.PROC Ppu_ChrBgPortrait02
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitAlexTalk, error
    chr_inc "portrait_alex_talk", kTileIdBgPortraitAlexFirst
    .assert .bank(*) = kChrBankPortraitPlaque, error
    chr_inc "portrait_plaque", kTileIdBgPortraitPlaqueFirst
    .assert .bank(*) = kChrBankDiagramLift, error
    chr_inc "diagram_lift", kTileIdBgDiagramLiftFirst
    .assert .bank(*) = kChrBankDiagramCarriage, error
    chr_inc "diagram_carriage", kTileIdBgDiagramCarriageFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait03"

.PROC Ppu_ChrBgPortrait03
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitEireneRest, error
    chr_inc "portrait_eirene_rest", kTileIdBgPortraitEireneFirst
    .assert .bank(*) = kChrBankPortraitScreen, error
    chr_inc "portrait_screen", kTileIdBgPortraitScreenFirst
    .assert .bank(*) = kChrBankDiagramBridgeLeft, error
    chr_inc "diagram_bridge_left", kTileIdBgDiagramBridgeLeftFirst
    .assert .bank(*) = kChrBankDiagramBridgeRight, error
    chr_inc "diagram_bridge_right", kTileIdBgDiagramBridgeRightFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait04"

.PROC Ppu_ChrBgPortrait04
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitEireneTalk, error
    chr_inc "portrait_eirene_talk", kTileIdBgPortraitEireneFirst
    .assert .bank(*) = kChrBankPortraitSign, error
    chr_inc "portrait_sign", kTileIdBgPortraitSignFirst
    .assert .bank(*) = kChrBankDiagramCannonLeft, error
    chr_inc "diagram_cannon_left", kTileIdBgDiagramCannonLeftFirst
    .assert .bank(*) = kChrBankDiagramCannonRight, error
    chr_inc "diagram_cannon_right", kTileIdBgDiagramCannonRightFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait05"

.PROC Ppu_ChrBgPortrait05
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitGrontaRest, error
    chr_inc "portrait_gronta_rest", kTileIdBgPortraitGrontaFirst
    .assert .bank(*) = kChrBankPortraitFloristRest, error
    chr_inc "portrait_florist_rest", kTileIdBgPortraitFloristFirst
    .assert .bank(*) = kChrBankDiagramHoistLeft, error
    chr_inc "diagram_hoist_left", kTileIdBgDiagramHoistLeftFirst
    .assert .bank(*) = kChrBankDiagramHoistRight, error
    chr_inc "diagram_hoist_right", kTileIdBgDiagramHoistRightFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait06"

.PROC Ppu_ChrBgPortrait06
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitGrontaTalk, error
    chr_inc "portrait_gronta_talk", kTileIdBgPortraitGrontaFirst
    .assert .bank(*) = kChrBankPortraitFloristTalk, error
    chr_inc "portrait_florist_talk", kTileIdBgPortraitFloristFirst
    .assert .bank(*) = kChrBankDiagramTrolley, error
    chr_inc "diagram_trolley", kTileIdBgDiagramTrolleyFirst
    .assert .bank(*) = kChrBankDiagramCrane, error
    chr_inc "diagram_crane", kTileIdBgDiagramCraneFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait07"

.PROC Ppu_ChrBgPortrait07
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitOrcRest, error
    chr_inc "portrait_orc_rest", kTileIdBgPortraitOrcFirst
    .assert .bank(*) = kChrBankPortraitMermaidRest, error
    chr_inc "portrait_mermaid_rest", kTileIdBgPortraitMermaidFirst
    .assert .bank(*) = kChrBankDiagramMinigunUp, error
    chr_inc "diagram_minigun_up", kTileIdBgDiagramMinigunUpFirst
    .assert .bank(*) = kChrBankDiagramMinigunDown, error
    chr_inc "diagram_minigun_down", kTileIdBgDiagramMinigunDownFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait08"

.PROC Ppu_ChrBgPortrait08
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitOrcTalk, error
    chr_inc "portrait_orc_talk", kTileIdBgPortraitOrcFirst
    .assert .bank(*) = kChrBankPortraitMermaidTalk, error
    chr_inc "portrait_mermaid_talk", kTileIdBgPortraitMermaidFirst
    .assert .bank(*) = kChrBankDiagramMinigunLeft, error
    chr_inc "diagram_minigun_left", kTileIdBgDiagramMinigunLeftFirst
    .assert .bank(*) = kChrBankDiagramMinigunRight, error
    chr_inc "diagram_minigun_right", kTileIdBgDiagramMinigunRightFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait09"

.PROC Ppu_ChrBgPortrait09
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitCorraRest, error
    chr_inc "portrait_corra_rest", kTileIdBgPortraitCorraFirst
    .assert .bank(*) = kChrBankPortraitMarieRest, error
    chr_inc "portrait_marie_rest", kTileIdBgPortraitMarieFirst
    .assert .bank(*) = kChrBankDiagramField, error
    chr_inc "diagram_field", kTileIdBgDiagramFieldFirst
    .assert .bank(*) = kChrBankDiagramJet, error
    chr_inc "diagram_jet", kTileIdBgDiagramJetFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait0A"

.PROC Ppu_ChrBgPortrait0A
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitCorraTalk, error
    chr_inc "portrait_corra_talk", kTileIdBgPortraitCorraFirst
    .assert .bank(*) = kChrBankPortraitMarieTalk, error
    chr_inc "portrait_marie_talk", kTileIdBgPortraitMarieFirst
    .assert .bank(*) = kChrBankDiagramPump, error
    chr_inc "diagram_pump", kTileIdBgDiagramPumpFirst
    .assert .bank(*) = kChrBankDiagramSemaphoreComm, error
    chr_inc "diagram_semaphore_comm", kTileIdBgDiagramSemaphoreCommFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait0B"

.PROC Ppu_ChrBgPortrait0B
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitNoraRest, error
    chr_inc "portrait_nora_rest", kTileIdBgPortraitNoraFirst
    .assert .bank(*) = kChrBankPortraitBrunoRest, error
    chr_inc "portrait_bruno_rest", kTileIdBgPortraitBrunoFirst
    .assert .bank(*) = kChrBankDiagramSemaphoreKey, error
    chr_inc "diagram_semaphore_key", kTileIdBgDiagramSemaphoreKeyFirst
    .assert .bank(*) = kChrBankDiagramSemaphoreLock, error
    chr_inc "diagram_semaphore_lock", kTileIdBgDiagramSemaphoreLockFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait0C"

.PROC Ppu_ChrBgPortrait0C
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitNoraTalk, error
    chr_inc "portrait_nora_talk", kTileIdBgPortraitNoraFirst
    .assert .bank(*) = kChrBankPortraitBrunoTalk, error
    chr_inc "portrait_bruno_talk", kTileIdBgPortraitBrunoFirst
    .assert .bank(*) = kChrBankDiagramLauncherDown, error
    chr_inc "diagram_launcher_down", kTileIdBgDiagramLauncherDownFirst
    .assert .bank(*) = kChrBankDiagramLauncherLeft, error
    chr_inc "diagram_launcher_left", kTileIdBgDiagramLauncherLeftFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait0D"

.PROC Ppu_ChrBgPortrait0D
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitWomanRest, error
    chr_inc "portrait_woman_rest", kTileIdBgPortraitWomanFirst
    .assert .bank(*) = kChrBankPortraitManRest, error
    chr_inc "portrait_man_rest", kTileIdBgPortraitManFirst
    .assert .bank(*) = kChrBankDiagramWinch, error
    chr_inc "diagram_winch", kTileIdBgDiagramWinchFirst
    .assert .bank(*) = kChrBankDiagramMultiplexer, error
    chr_inc "diagram_multiplexer", kTileIdBgDiagramMultiplexerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait0E"

.PROC Ppu_ChrBgPortrait0E
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitWomanTalk, error
    chr_inc "portrait_woman_talk", kTileIdBgPortraitWomanFirst
    .assert .bank(*) = kChrBankPortraitManTalk, error
    chr_inc "portrait_man_talk", kTileIdBgPortraitManFirst
    .assert .bank(*) = kChrBankDiagramBoiler, error
    chr_inc "diagram_boiler", kTileIdBgDiagramBoilerFirst
    .assert .bank(*) = kChrBankDiagramLaser, error
    chr_inc "diagram_laser", kTileIdBgDiagramLaserFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait0F"

.PROC Ppu_ChrBgPortrait0F
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitElderRest, error
    chr_inc "portrait_elder_rest", kTileIdBgPortraitElderFirst
    chr_res $10
    .assert .bank(*) = kChrBankDiagramRotor, error
    chr_inc "diagram_rotor", kTileIdBgDiagramRotorFirst
    .assert .bank(*) = kChrBankDiagramConveyor, error
    chr_inc "diagram_conveyor", kTileIdBgDiagramConveyorFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait10"

.PROC Ppu_ChrBgPortrait10
    CHR1_BANK $c0
    .assert .bank(*) = kChrBankPortraitElderTalk, error
    chr_inc "portrait_elder_talk", kTileIdBgPortraitElderFirst
    chr_res $10
    .assert .bank(*) = kChrBankDiagramAmmoRack, error
    chr_inc "diagram_ammo_rack", kTileIdBgDiagramAmmoRackFirst
    .assert .bank(*) = kChrBankDiagramReloader, error
    chr_inc "diagram_reloader", kTileIdBgDiagramReloaderFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait11"

.PROC Ppu_ChrBgPortrait11
    CHR1_BANK $c0
    chr_res $20
    .assert .bank(*) = kChrBankDiagramBlaster, error
    chr_inc "diagram_blaster", kTileIdBgDiagramBlasterFirst
    .assert .bank(*) = kChrBankDiagramDrums, error
    chr_inc "diagram_drums", kTileIdBgDiagramDrumsFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait12"

.PROC Ppu_ChrBgPortrait12
    CHR1_BANK $c0
    chr_res $20
    .assert .bank(*) = kChrBankDiagramOrgan, error
    chr_inc "diagram_organ", kTileIdBgDiagramOrganFirst
    .assert .bank(*) = kChrBankDiagramTrombone, error
    chr_inc "diagram_trombone", kTileIdBgDiagramTromboneFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPortrait13"

.PROC Ppu_ChrBgPortrait13
    CHR1_BANK $c0
    chr_res $20
    .assert .bank(*) = kChrBankDiagramEmitterX, error
    chr_inc "diagram_emitter_x", kTileIdBgDiagramEmitterXFirst
    .assert .bank(*) = kChrBankDiagramEmitterY, error
    chr_inc "diagram_emitter_y", kTileIdBgDiagramEmitterYFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPrison"

.EXPORT Ppu_ChrBgPrison
.PROC Ppu_ChrBgPrison
    CHR1_BANK $80
    chr_inc "cave"
    chr_inc "prison"
    chr_inc "terrain_furniture"
    chr_res $12
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgSewer"

.EXPORT Ppu_ChrBgSewer
.PROC Ppu_ChrBgSewer
    CHR1_BANK $80
    chr_inc "steam_pipes"
    chr_inc "sewer1"
    chr_inc "sewer2"
    chr_res $0c
    chr_inc "pump"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgShadow"

.EXPORT Ppu_ChrBgShadow
.PROC Ppu_ChrBgShadow
    CHR1_BANK $80
    chr_inc "terrain_shadow_0"
    chr_inc "terrain_shadow_1"
    chr_inc "terrain_shadow_2"
    chr_inc "tank"
    chr_res $06
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgTeleport"

.EXPORT Ppu_ChrBgTeleport
.PROC Ppu_ChrBgTeleport
    CHR1_BANK $40
    chr_inc "terrain_teleport"
    chr_res $04
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgTemple"

.EXPORT Ppu_ChrBgTemple
.PROC Ppu_ChrBgTemple
    CHR1_BANK $80
    chr_inc "temple1"
    chr_inc "temple2"
    chr_inc "temple3"
    chr_inc "temple4"
    chr_res $04
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgTitle"

.EXPORT Ppu_ChrBgTitle
.PROC Ppu_ChrBgTitle
    CHR1_BANK $80
    chr_inc "title1"
    chr_inc "title2"
    chr_inc "title3"
    chr_res $1a
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgWheel"

.EXPORT Ppu_ChrBgWheel
.PROC Ppu_ChrBgWheel
    CHR1_BANK $40
    chr_inc "wheel1"
    chr_inc "wheel2"
    chr_inc "wheel3"
    chr_inc "wheel4"
    chr_res $05
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjAnnaFlower"

.EXPORT Ppu_ChrObjAnnaFlower
.PROC Ppu_ChrObjAnnaFlower
    CHR2_BANK $00
    chr_inc "device"
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_inc "player_flower"
    chr_inc "font_hilight"
    chr_inc "crate",          kTileIdObjCrateFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjAnnaNormal"

.EXPORT Ppu_ChrObjAnnaNormal
.PROC Ppu_ChrObjAnnaNormal
    CHR2_BANK $00
    chr_inc "device"
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_inc "player_normal"
    chr_inc "font_hilight"
    chr_inc "crate",          kTileIdObjCrateFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjBoss1"

.EXPORT Ppu_ChrObjBoss1
.PROC Ppu_ChrObjBoss1
    CHR2_BANK $80
    chr_inc "spike",                 kTileIdObjSpike
    chr_res $01
    chr_inc "upgrade_ram",           kTileIdObjUpgradeRamFirst
    chr_res $02
    chr_inc "ember",                 kTileIdObjEmber
    chr_res $01
    chr_inc "cannon",                kTileIdObjCannonFirst
    chr_res $08
    chr_inc "upgrade_oprest",        kTileIdObjUpgradeOpRestFirst
    chr_res $08
    chr_inc "boss_garden_eye_white", kTileIdObjBossGardenEyeWhiteFirst
    chr_inc "boss_garden_eye_mini",  kTileIdObjBossGardenEyeMiniFirst
    chr_inc "boss_garden_eye_red",   kTileIdObjBossGardenEyeRedFirst
    chr_inc "platform_crypt_bricks", kTileIdObjPlatformCryptBricksFirst
    chr_inc "boss_crypt_pupil",      kTileIdObjBossCryptPupilFirst
    chr_inc "fireball",              kTileIdObjFireballFirst
    chr_res $1c
    chr_inc "crusher",               kTileIdObjCrusherFirst
    chr_inc "winch",                 kTileIdObjWinchFirst
    chr_inc "grenade",               kTileIdObjGrenadeFirst
    chr_inc "breaker",               kTileIdObjBreakerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjBoss2"

.EXPORT Ppu_ChrObjBoss2
.PROC Ppu_ChrObjBoss2
    CHR2_BANK $80
    chr_inc "breakbomb",            kTileIdObjBreakbombFirst
    chr_inc "upgrade_ram",          kTileIdObjUpgradeRamFirst
    chr_inc "upgrade_bremote",      kTileIdObjUpgradeBRemoteFirst
    chr_inc "reloader",             kTileIdObjReloaderFirst
    chr_inc "platform_city_bricks", kTileIdObjPlatformCityBricks
    chr_res $02
    chr_inc "boiler_flame",         kTileIdObjBoilerFlameFirst
    chr_inc "bullet",               kTileIdObjBulletFirst
    chr_inc "launcher_horz",        kTileIdObjLauncherHorzFirst
    chr_inc "boulder",              kTileIdObjBoulderFirst
    chr_inc "blaster",              kTileIdObjBlasterFirst
    chr_res $01
    chr_inc "fireblast",            kTileIdObjFireblastFirst
    chr_inc "platform_city_walls",  kTileIdObjPlatformCityWalls
    chr_inc "outbreak_obj",         kTileIdObjOutbreakFirst
    chr_inc "dirt",                 kTileIdObjDirtFirst
    chr_inc "breakfire",            kTileIdObjBreakfireFirst
    chr_inc "crane",                kTileIdObjCraneFirst
    chr_inc "proj_spine",           kTileIdObjProjSpineFirst
    chr_inc "valve",                kTileIdObjValveFirst
    chr_inc "fireball",             kTileIdObjFireballFirst
    chr_inc "breakball",            kTileIdObjBreakballFirst
    chr_inc "platform_volcanic",    kTileIdObjPlatformVolcanicFirst
    chr_inc "boss_mine_eye",        kTileIdObjBossMineEyeFirst
    chr_inc "boss_lava_jaws",       kTileIdObjBossLavaJawsFirst
    chr_inc "flamestrike",          kTileIdObjFlamestrikeFirst
    chr_inc "minigun_vert",         kTileIdObjMinigunVertFirst
    chr_inc "steam_vert",           kTileIdObjSteamVertFirst
    chr_inc "breaker",              kTileIdObjBreakerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjBoss3"

.EXPORT Ppu_ChrObjBoss3
.PROC Ppu_ChrObjBoss3
    CHR2_BANK $80
    chr_res $08
    chr_inc "cannon",              kTileIdObjCannonFirst
    chr_res $0a
    chr_inc "blaster",             kTileIdObjBlasterFirst
    chr_res $01
    chr_inc "fireblast",           kTileIdObjFireblastFirst
    chr_res $04
    chr_inc "orc_gronta_standing", kTileIdObjOrcGrontaStandingFirst
    chr_inc "orc_gronta_running",  kTileIdObjOrcGrontaRunningFirst
    chr_inc "orc_gronta_throwing", kTileIdObjOrcGrontaThrowingFirst
    chr_inc "orc_gronta_jumping",  kTileIdObjOrcGrontaJumpingFirst
    chr_res $08
    chr_inc "mirror",              kTileIdObjMirrorFirst
    chr_res $03
    chr_inc "proj_axe",            kTileIdObjProjAxeFirst
    chr_inc "laser",               kTileIdObjLaserFirst
    chr_inc "crusher",             kTileIdObjCrusherFirst
    chr_inc "winch",               kTileIdObjWinchFirst
    chr_inc "grenade",             kTileIdObjGrenadeFirst
    chr_inc "orc_gronta_crouch",   kTileIdObjOrcGrontaCrouchFirst
    chr_res $04
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjCity"

.EXPORT Ppu_ChrObjCity
.PROC Ppu_ChrObjCity
    CHR2_BANK $80
    chr_inc "semaphore",            kTileIdObjSemaphoreFirst
    chr_inc "orc_grunt_standing",   kTileIdObjOrcGruntStandingFirst
    chr_inc "launcher_horz",        kTileIdObjLauncherHorzFirst
    chr_res $04
    chr_inc "platform_rocks",       kTileIdObjPlatformRocksFirst
    chr_inc "bad_rodent",           kTileIdObjBadRodentFirst
    chr_res $03
    chr_inc "combo",                kTileIdObjComboFirst
    chr_inc "orc_grunt_running",    kTileIdObjOrcGruntRunningFirst
    chr_inc "orc_grunt_throwing",   kTileIdObjOrcGruntThrowingFirst
    chr_inc "bad_rhino",            kTileIdObjBadRhinoFirst
    chr_inc "child_stand",          kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjCrypt"

.EXPORT Ppu_ChrObjCrypt
.PROC Ppu_ChrObjCrypt
    CHR2_BANK $80
    chr_inc "platform_girder", kTileIdObjPlatformGirder
    chr_res $11
    chr_inc "upgrade_opgoto",  kTileIdObjUpgradeOpGotoFirst
    chr_res $08
    chr_inc "bad_bat",         kTileIdObjBadBatFirst
    chr_res $18
    chr_inc "breakable",       kTileIdObjWeakFloorFirst
    chr_res $02
    chr_inc "bad_spider",      kTileIdObjBadSpiderFirst
    chr_res $04
    chr_inc "bad_fish",        kTileIdObjBadFishFirst
    chr_inc "crusher",         kTileIdObjCrusherFirst
    chr_inc "winch",           kTileIdObjWinchFirst
    chr_res $14
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjFactory"

.EXPORT Ppu_ChrObjFactory
.PROC Ppu_ChrObjFactory
    CHR2_BANK $80
    chr_inc "jet",            kTileIdObjJetFirst
    chr_inc "rotor",          kTileIdObjRotorFirst
    chr_res $07
    chr_inc "upgrade_opskip", kTileIdObjUpgradeOpSkipFirst
    chr_res $06
    chr_inc "bad_grub",       kTileIdObjBadGrubFirst
    chr_res $08
    chr_inc "crane",          kTileIdObjCraneFirst
    chr_res $28
    chr_inc "child_stand",    kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjGarden"

.EXPORT Ppu_ChrObjGarden
.PROC Ppu_ChrObjGarden
    CHR2_BANK $80
    chr_inc "platform_sewage",     kTileIdObjPlatformSewageFirst
    chr_inc "platform_water",      kTileIdObjPlatformWaterFirst
    chr_res $01
    chr_inc "cannon",              kTileIdObjCannonFirst
    chr_inc "garden_bricks",       kTileIdObjGardenBricksFirst
    chr_res $04
    chr_inc "platform_waterfall",  kTileIdObjPlatformWaterfallFirst
    chr_inc "bad_grub",            kTileIdObjBadGrubFirst
    chr_res $02
    chr_inc "mermaid_corra",       kTileIdObjMermaidCorraFirst
    chr_inc "bad_vinebug",         kTileIdObjBadVinebugFirst
    chr_inc "anchor",              kTileIdObjAnchorFirst
    chr_inc "valve",               kTileIdObjValveFirst
    chr_inc "bad_beetle",          kTileIdObjBadBeetleFirst
    chr_res $04
    chr_inc "bad_fish",            kTileIdObjBadFishFirst
    chr_inc "corra_swimming_down", kTileIdObjCorraSwimmingDownFirst
    chr_inc "grenade",             kTileIdObjGrenadeFirst
    chr_inc "corra_swimming_up",   kTileIdObjCorraSwimmingUpFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjLava"

.EXPORT Ppu_ChrObjLava
.PROC Ppu_ChrObjLava
    CHR2_BANK $80
    chr_res $06
    chr_inc "ember",             kTileIdObjEmber
    chr_res $03
    chr_inc "upgrade_opcopy",    kTileIdObjUpgradeOpCopyFirst
    chr_inc "boiler_flame",      kTileIdObjBoilerFlameFirst
    chr_res $02
    chr_inc "bad_lavaball",      kTileIdObjBadLavaballFirst
    chr_inc "blaster",           kTileIdObjBlasterFirst
    chr_res $01
    chr_inc "fireblast",         kTileIdObjFireblastFirst
    chr_res $04
    chr_inc "bad_hothead",       kTileIdObjBadHotheadFirst
    chr_res $07
    chr_inc "raindrop",          kTileIdObjRaindrop
    chr_inc "anchor",            kTileIdObjAnchorFirst
    chr_inc "valve",             kTileIdObjValveFirst
    chr_res $08
    chr_inc "bad_spider",        kTileIdObjBadSpiderFirst
    chr_inc "mirror",            kTileIdObjMirrorFirst
    chr_res $0b
    chr_inc "steam_vert",        kTileIdObjSteamVertFirst
    chr_inc "steam_horz",        kTileIdObjSteamHorzFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjMine"

.EXPORT Ppu_ChrObjMine
.PROC Ppu_ChrObjMine
    CHR2_BANK $80
    chr_inc "platform_girder", kTileIdObjPlatformGirder
    chr_res $03
    chr_inc "hoist_obj",       kTileIdObjHoistFirst
    chr_inc "mine_cage",       kTileIdObjMineCageFirst
    chr_res $0e
    chr_inc "upgrade_opsync",  kTileIdObjUpgradeOpSyncFirst
    chr_inc "fireblast",       kTileIdObjFireblastFirst
    chr_inc "bad_grub",        kTileIdObjBadGrubFirst
    chr_inc "bad_wasp",        kTileIdObjBadWaspFirst
    chr_inc "crane",           kTileIdObjCraneFirst
    chr_inc "bad_firefly",     kTileIdObjBadFireflyFirst
    chr_res $14
    chr_inc "bad_fish",        kTileIdObjBadFishFirst
    chr_res $20
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjParley"

.EXPORT Ppu_ChrObjParley
.PROC Ppu_ChrObjParley
    CHR2_BANK $80
    chr_res $06
    chr_inc "upgrade_opif",        kTileIdObjUpgradeOpIfFirst
    chr_res $08
    chr_inc "eirene_parley",       kTileIdObjEireneParleyFirst
    chr_res $04
    chr_inc "orc_gronta_parley",   kTileIdObjOrcGrontaParleyFirst
    chr_inc "orc_gronta_standing", kTileIdObjOrcGrontaStandingFirst
    chr_inc "orc_gronta_running",  kTileIdObjOrcGrontaRunningFirst
    chr_res $20
    chr_inc "child_stand",         kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjPause"

.EXPORT Ppu_ChrObjPause
.PROC Ppu_ChrObjPause
    CHR2_BANK $80
    chr_res $30
    chr_inc "pause",      kTileIdObjPauseFirst
    chr_inc "font_upper"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjSewer"

.EXPORT Ppu_ChrObjSewer
.PROC Ppu_ChrObjSewer
    CHR2_BANK $80
    chr_inc "spike",              kTileIdObjSpike
    chr_inc "pump_light",         kTileIdObjPumpLight
    chr_inc "multiplexer",        kTileIdObjMultiplexerFirst
    chr_inc "platform_water",     kTileIdObjPlatformWaterFirst
    chr_inc "bad_jelly",          kTileIdObjBadJellyFirst
    chr_inc "machine_trombone",   kTileIdObjMachineTromboneFirst
    chr_inc "upgrade_opaddsub",   kTileIdObjUpgradeOpAddSubFirst
    chr_inc "machine_drums",      kTileIdObjMachineDrumsFirst
    chr_inc "npc_duck",           kTileIdObjNpcDuckFirst
    chr_inc "monitor",            kTileIdObjMonitorFirst
    chr_inc "platform_rocks",     kTileIdObjPlatformRocksFirst
    chr_res $02
    chr_inc "bad_grub",           kTileIdObjBadGrubFirst
    chr_inc "bad_slime",          kTileIdObjBadSlimeFirst
    chr_res $09
    chr_inc "raindrop",           kTileIdObjRaindrop
    chr_inc "bad_toad",           kTileIdObjBadToadFirst
    chr_inc "bad_bird",           kTileIdObjBadBirdFirst
    chr_inc "bad_crab",           kTileIdObjBadCrabFirst
    chr_inc "platform_hotspring", kTileIdObjPlatformHotSpringFirst
    chr_inc "bad_fish",           kTileIdObjBadFishFirst
    chr_inc "child_stand",        kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjShadow"

.EXPORT Ppu_ChrObjShadow
.PROC Ppu_ChrObjShadow
    CHR2_BANK $80
    chr_inc "acid",           kTileIdObjAcid
    chr_inc "emitter_light",  kTileIdObjEmitterLight
    chr_inc "emitter",        kTileIdObjEmitterFirst
    chr_res $04
    chr_inc "barrier",        kTileIdObjBarrierFirst
    chr_inc "upgrade_opmul",  kTileIdObjUpgradeOpMulFirst
    chr_inc "bad_goo",        kTileIdObjBadGooFirst
    chr_inc "bad_grub",       kTileIdObjBadGrubFirst
    chr_inc "bad_grub_fire",  kTileIdObjBadGrubFireFirst
    chr_inc "bad_flydrop",    kTileIdObjBadFlydropFirst
    chr_inc "forcefield",     kTileIdObjForcefieldFirst
    chr_inc "fireball",       kTileIdObjFireballFirst
    chr_inc "mermaid_ghost",  kTileIdObjMermaidGhostFirst
    chr_inc "orc_ghost",      kTileIdObjOrcGhostFirst
    chr_inc "laser",          kTileIdObjLaserFirst
    chr_inc "anna_ghost",     kTileIdObjAnnaGhostFirst
    chr_inc "adult_ghost",    kTileIdObjAdultGhostFirst
    chr_inc "breaker",        kTileIdObjBreakerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjTemple"

.EXPORT Ppu_ChrObjTemple
.PROC Ppu_ChrObjTemple
    CHR2_BANK $80
    chr_inc "glass",          kTileIdObjGlassFirst
    chr_inc "upgrade_optil",  kTileIdObjUpgradeOpTilFirst
    chr_res $04
    chr_inc "bullet",         kTileIdObjBulletFirst
    chr_inc "upgrade_opbeep", kTileIdObjUpgradeOpBeepFirst
    chr_inc "column",         kTileIdObjColumnFirst
    chr_res $0a
    chr_inc "mermaid_guardf", kTileIdObjMermaidGuardFFirst
    chr_res $06
    chr_inc "mermaid_corra",  kTileIdObjMermaidCorraFirst
    chr_inc "column_cracked", kTileIdObjColumnCrackedFirst
    chr_inc "bad_toad",       kTileIdObjBadToadFirst
    chr_inc "bad_beetle",     kTileIdObjBadBeetleFirst
    chr_inc "minigun_horz",   kTileIdObjMinigunHorzFirst
    chr_inc "minigun_vert",   kTileIdObjMinigunVertFirst
    chr_inc "child_stand",    kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjTown"

.EXPORT Ppu_ChrObjTown
.PROC Ppu_ChrObjTown
    CHR2_BANK $80
    chr_inc "toddler",             kTileIdObjToddlerFirst
    chr_inc "stepstone",           kTileIdObjStepstone
    chr_inc "gate",                kTileIdObjGateFirst
    chr_inc "orc_grunt_standing",  kTileIdObjOrcGruntStandingFirst
    chr_inc "launcher_vert",       kTileIdObjLauncherVertFirst
    chr_inc "orc_grunt_kneeling",  kTileIdObjOrcGruntKneelingFirst
    chr_inc "platform_rocks",      kTileIdObjPlatformRocksFirst
    chr_inc "child_sleep",         kTileIdObjChildSleepFirst
    chr_res $04
    chr_inc "orc_gronta_standing", kTileIdObjOrcGrontaStandingFirst
    chr_inc "orc_grunt_running",   kTileIdObjOrcGruntRunningFirst
    chr_inc "orc_grunt_throwing",  kTileIdObjOrcGruntThrowingFirst
    chr_inc "adult_woman",         kTileIdObjAdultWomanFirst
    chr_inc "adult_man",           kTileIdObjAdultManFirst
    chr_inc "orc_grunt_sleeping",  kTileIdObjOrcGruntSleepingFirst
    chr_inc "child_stand",         kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjVillage"

.EXPORT Ppu_ChrObjVillage
.PROC Ppu_ChrObjVillage
    CHR2_BANK $80
    chr_inc "mermaid_guardm",  kTileIdObjMermaidGuardMFirst
    chr_inc "mermaid_phoebe",  kTileIdObjMermaidPhoebeFirst
    chr_inc "mermaid_farmer",  kTileIdObjMermaidFarmerFirst
    chr_inc "mermaid_florist", kTileIdObjMermaidFloristFirst
    chr_inc "mermaid_daphne",  kTileIdObjMermaidDaphneFirst
    chr_inc "mermaid_guardf",  kTileIdObjMermaidGuardFFirst
    chr_res $06
    chr_inc "mermaid_corra",   kTileIdObjMermaidCorraFirst
    chr_inc "mermaid_queen",   kTileIdObjMermaidQueenFirst
    chr_inc "adult_smith",     kTileIdObjAdultSmithFirst
    chr_inc "adult_elder",     kTileIdObjAdultElderFirst
    chr_res $08
    chr_inc "child_swim",      kTileIdObjChildSwimFirst
    chr_inc "child_stand",     kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;
