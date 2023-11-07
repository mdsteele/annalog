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
.INCLUDE "actors/bat.inc"
.INCLUDE "actors/bird.inc"
.INCLUDE "actors/breakball.inc"
.INCLUDE "actors/bullet.inc"
.INCLUDE "actors/child.inc"
.INCLUDE "actors/crab.inc"
.INCLUDE "actors/crawler.inc"
.INCLUDE "actors/ember.inc"
.INCLUDE "actors/fireball.inc"
.INCLUDE "actors/firefly.inc"
.INCLUDE "actors/fish.inc"
.INCLUDE "actors/flamewave.inc"
.INCLUDE "actors/flydrop.inc"
.INCLUDE "actors/grenade.inc"
.INCLUDE "actors/grub.inc"
.INCLUDE "actors/jelly.inc"
.INCLUDE "actors/lavaball.inc"
.INCLUDE "actors/orc.inc"
.INCLUDE "actors/rhino.inc"
.INCLUDE "actors/rodent.inc"
.INCLUDE "actors/spider.inc"
.INCLUDE "actors/spike.inc"
.INCLUDE "actors/toad.inc"
.INCLUDE "actors/toddler.inc"
.INCLUDE "actors/townsfolk.inc"
.INCLUDE "actors/vinebug.inc"
.INCLUDE "actors/wasp.inc"
.INCLUDE "avatar.inc"
.INCLUDE "devices/breaker.inc"
.INCLUDE "dialog.inc"
.INCLUDE "machine.inc"
.INCLUDE "machines/blaster.inc"
.INCLUDE "machines/boiler.inc"
.INCLUDE "machines/cannon.inc"
.INCLUDE "machines/crane.inc"
.INCLUDE "machines/emitter.inc"
.INCLUDE "machines/hoist.inc"
.INCLUDE "machines/jet.inc"
.INCLUDE "machines/laser.inc"
.INCLUDE "machines/launcher.inc"
.INCLUDE "machines/minigun.inc"
.INCLUDE "machines/multiplexer.inc"
.INCLUDE "machines/pump.inc"
.INCLUDE "machines/reloader.inc"
.INCLUDE "machines/rotor.inc"
.INCLUDE "machines/semaphore.inc"
.INCLUDE "machines/winch.inc"
.INCLUDE "platforms/barrier.inc"
.INCLUDE "platforms/column.inc"
.INCLUDE "platforms/crate.inc"
.INCLUDE "platforms/force.inc"
.INCLUDE "platforms/gate.inc"
.INCLUDE "platforms/monitor.inc"
.INCLUDE "platforms/rocks.inc"
.INCLUDE "platforms/stepstone.inc"
.INCLUDE "rooms/boss_crypt.inc"
.INCLUDE "rooms/boss_garden.inc"
.INCLUDE "rooms/boss_temple.inc"
.INCLUDE "rooms/city_building2.inc"
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
    CHR1_BANK $c0
    chr_inc "water_anim0"
    chr_inc "acid_anim0"
    chr_inc "waterfall_anim0"
    chr_res $02
    chr_inc "thorns_anim0"
    chr_inc "sewage_anim0"
    chr_inc "circuit_anim0"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA1"

.PROC Ppu_ChrBgAnimA1
    CHR1_BANK $c0
    chr_inc "water_anim0"
    chr_inc "acid_anim1"
    chr_inc "waterfall_anim1"
    chr_res $02
    chr_inc "thorns_anim1"
    chr_inc "sewage_anim1"
    chr_inc "circuit_anim1"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA2"

.PROC Ppu_ChrBgAnimA2
    CHR1_BANK $c0
    chr_inc "water_anim1"
    chr_inc "acid_anim2"
    chr_inc "waterfall_anim2"
    chr_res $02
    chr_inc "thorns_anim2"
    chr_inc "sewage_anim2"
    chr_inc "circuit_anim2"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA3"

.PROC Ppu_ChrBgAnimA3
    CHR1_BANK $c0
    chr_inc "water_anim1"
    chr_inc "acid_anim3"
    chr_inc "waterfall_anim3"
    chr_res $02
    chr_inc "thorns_anim3"
    chr_inc "sewage_anim3"
    chr_inc "circuit_anim3"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA4"

.PROC Ppu_ChrBgAnimA4
    CHR1_BANK $c0
    chr_inc "water_anim2"
    chr_inc "acid_anim4"
    chr_inc "waterfall_anim0"
    chr_res $02
    chr_inc "thorns_anim4"
    chr_inc "sewage_anim0"
    chr_inc "circuit_anim4"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA5"

.PROC Ppu_ChrBgAnimA5
    CHR1_BANK $c0
    chr_inc "water_anim2"
    chr_inc "acid_anim5"
    chr_inc "waterfall_anim1"
    chr_res $02
    chr_inc "thorns_anim5"
    chr_inc "sewage_anim1"
    chr_inc "circuit_anim5"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA6"

.PROC Ppu_ChrBgAnimA6
    CHR1_BANK $c0
    chr_inc "water_anim1"
    chr_inc "acid_anim6"
    chr_inc "waterfall_anim2"
    chr_res $02
    chr_inc "thorns_anim6"
    chr_inc "sewage_anim2"
    chr_inc "circuit_anim6"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA7"

.PROC Ppu_ChrBgAnimA7
    CHR1_BANK $c0
    chr_inc "water_anim1"
    chr_inc "acid_anim7"
    chr_inc "waterfall_anim3"
    chr_res $02
    chr_inc "thorns_anim7"
    chr_inc "sewage_anim3"
    chr_inc "circuit_anim7"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB0"

.EXPORT Ppu_ChrBgAnimB0
.PROC Ppu_ChrBgAnimB0
    CHR1_BANK $c0
    chr_inc "lava_anim0"
    chr_res $06
    chr_inc "conveyor_anim0"
    chr_res $1e
    chr_inc "gazer_anim0"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB1"

.PROC Ppu_ChrBgAnimB1
    CHR1_BANK $c0
    chr_inc "lava_anim1"
    chr_res $06
    chr_inc "conveyor_anim1"
    chr_res $1e
    chr_inc "gazer_anim1"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB2"

.PROC Ppu_ChrBgAnimB2
    CHR1_BANK $c0
    chr_inc "lava_anim2"
    chr_res $06
    chr_inc "conveyor_anim2"
    chr_res $1e
    chr_inc "gazer_anim2"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB3"

.PROC Ppu_ChrBgAnimB3
    CHR1_BANK $c0
    chr_inc "lava_anim3"
    chr_res $06
    chr_inc "conveyor_anim3"
    chr_res $1e
    chr_inc "gazer_anim3"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimStatic"

.EXPORT Ppu_ChrBgAnimStatic
.PROC Ppu_ChrBgAnimStatic
    CHR1_BANK $c0
    chr_res $10
    chr_inc "thorns_anim_static"
    chr_res $0a
    chr_inc "circuit_anim_static"
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
    chr_res $0a
    chr_inc "console"
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
    chr_res $0c
    chr_inc "console"
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
    chr_inc "console"
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
    chr_res $08
    chr_inc "gazer_eye"
    chr_res $04
    chr_inc "arch"
    chr_res $06
    chr_inc "plaque"
    chr_inc "console"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontUpper"

.EXPORT Ppu_ChrBgFontUpper
.PROC Ppu_ChrBgFontUpper
    CHR1_BANK $00
    chr_inc "font_upper"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower01"

.EXPORT Ppu_ChrBgFontLower01
.PROC Ppu_ChrBgFontLower01
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Lift, error
    chr_inc "diagram_lift"
    .assert .bank(*) = <ePortrait::AdultWoman, error
    chr_inc "portrait_woman_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower02"

.PROC Ppu_ChrBgFontLower02
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Trolley, error
    chr_inc "diagram_trolley"
    .assert .bank(*) = >ePortrait::AdultWoman, error
    chr_inc "portrait_woman_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower03"

.PROC Ppu_ChrBgFontLower03
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Winch, error
    chr_inc "diagram_winch"
    .assert .bank(*) = <ePortrait::Sign, error
    .assert .bank(*) = >ePortrait::Sign, error
    chr_inc "portrait_sign"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower04"

.PROC Ppu_ChrBgFontLower04
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Boiler, error
    chr_inc "diagram_boiler"
    .assert .bank(*) = <ePortrait::Paper, error
    .assert .bank(*) = >ePortrait::Paper, error
    chr_inc "portrait_paper"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower05"

.PROC Ppu_ChrBgFontLower05
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Field, error
    chr_inc "diagram_field"
    .assert .bank(*) = <ePortrait::MermaidDaphne, error
    .assert .bank(*) = <ePortrait::MermaidGuardF, error
    chr_inc "portrait_mermaid_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower06"

.PROC Ppu_ChrBgFontLower06
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Jet, error
    chr_inc "diagram_jet"
    .assert .bank(*) = >ePortrait::MermaidDaphne, error
    .assert .bank(*) = >ePortrait::MermaidGuardF, error
    chr_inc "portrait_mermaid_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower07"

.PROC Ppu_ChrBgFontLower07
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Carriage, error
    chr_inc "diagram_carriage"
    .assert .bank(*) = <ePortrait::AdultMan, error
    chr_inc "portrait_man_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower08"

.PROC Ppu_ChrBgFontLower08
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::CannonRight, error
    chr_inc "diagram_cannon_right"
    .assert .bank(*) = >ePortrait::AdultMan, error
    chr_inc "portrait_man_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower09"

.PROC Ppu_ChrBgFontLower09
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::CannonLeft, error
    chr_inc "diagram_cannon_left"
    .assert .bank(*) = <ePortrait::ChildNora, error
    chr_inc "portrait_nora_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0A"

.PROC Ppu_ChrBgFontLower0A
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::BridgeRight, error
    chr_inc "diagram_bridge_right"
    .assert .bank(*) = >ePortrait::ChildNora, error
    chr_inc "portrait_nora_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0B"

.PROC Ppu_ChrBgFontLower0B
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::BridgeLeft, error
    chr_inc "diagram_bridge_left"
    .assert .bank(*) = <ePortrait::ChildAlex, error
    chr_inc "portrait_alex_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0C"

.PROC Ppu_ChrBgFontLower0C
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Crane, error
    chr_inc "diagram_crane"
    .assert .bank(*) = >ePortrait::ChildAlex, error
    chr_inc "portrait_alex_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0D"

.PROC Ppu_ChrBgFontLower0D
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Multiplexer, error
    chr_inc "diagram_multiplexer"
    .assert .bank(*) = <ePortrait::MermaidCorra, error
    chr_inc "portrait_corra_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0E"

.PROC Ppu_ChrBgFontLower0E
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Debugger, error
    chr_inc "diagram_debugger"
    .assert .bank(*) = >ePortrait::MermaidCorra, error
    chr_inc "portrait_corra_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0F"

.PROC Ppu_ChrBgFontLower0F
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::HoistRight, error
    chr_inc "diagram_hoist_right"
    .assert .bank(*) = <ePortrait::MermaidFlorist, error
    chr_inc "portrait_florist_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower10"

.PROC Ppu_ChrBgFontLower10
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::HoistLeft, error
    chr_inc "diagram_hoist_left"
    .assert .bank(*) = >ePortrait::MermaidFlorist, error
    chr_inc "portrait_florist_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower11"

.PROC Ppu_ChrBgFontLower11
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::LauncherDown, error
    chr_inc "diagram_launcher_down"
    .assert .bank(*) = <ePortrait::ChildMarie, error
    chr_inc "portrait_marie_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower12"

.PROC Ppu_ChrBgFontLower12
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::MinigunDown, error
    chr_inc "diagram_minigun_down"
    .assert .bank(*) = >ePortrait::ChildMarie, error
    chr_inc "portrait_marie_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower13"

.PROC Ppu_ChrBgFontLower13
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::MinigunLeft, error
    chr_inc "diagram_minigun_left"
    .assert .bank(*) = <ePortrait::ChildBruno, error
    chr_inc "portrait_bruno_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower14"

.PROC Ppu_ChrBgFontLower14
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::MinigunUp, error
    chr_inc "diagram_minigun_up"
    .assert .bank(*) = >ePortrait::ChildBruno, error
    chr_inc "portrait_bruno_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower15"

.PROC Ppu_ChrBgFontLower15
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::LauncherLeft, error
    chr_inc "diagram_launcher_left"
    .assert .bank(*) = <ePortrait::Plaque, error
    .assert .bank(*) = >ePortrait::Plaque, error
    chr_inc "portrait_plaque"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower16"

.PROC Ppu_ChrBgFontLower16
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::SemaphoreNormal, error
    chr_inc "diagram_semaphore_normal"
    .assert .bank(*) = <ePortrait::OrcGronta, error
    chr_inc "portrait_gronta_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower17"

.PROC Ppu_ChrBgFontLower17
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::SemaphoreNoFlags, error
    chr_inc "diagram_semaphore_no_flags"
    .assert .bank(*) = >ePortrait::OrcGronta, error
    chr_inc "portrait_gronta_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower18"

.PROC Ppu_ChrBgFontLower18
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::SemaphoreNoSensor, error
    chr_inc "diagram_semaphore_no_sensor"
    .assert .bank(*) = <ePortrait::OrcMale, error
    chr_inc "portrait_orc_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower19"

.PROC Ppu_ChrBgFontLower19
    CHR1_BANK $40
    chr_inc "font_lower"
    .assert .bank(*) = eDiagram::Pump, error
    chr_inc "diagram_pump"
    .assert .bank(*) = >ePortrait::OrcMale, error
    chr_inc "portrait_orc_talk"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower1A"

.PROC Ppu_ChrBgFontLower1A
    CHR1_BANK $40
    chr_inc "font_lower"
    chr_res $10
    .assert .bank(*) = <ePortrait::Screen, error
    .assert .bank(*) = >ePortrait::Screen, error
    chr_inc "portrait_screen"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower1B"

.PROC Ppu_ChrBgFontLower1B
    CHR1_BANK $40
    chr_inc "font_lower"
    chr_res $10
    .assert .bank(*) = <ePortrait::MermaidEirene, error
    chr_inc "portrait_eirene_rest"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower1C"

.PROC Ppu_ChrBgFontLower1C
    CHR1_BANK $40
    chr_inc "font_lower"
    chr_res $10
    .assert .bank(*) = >ePortrait::MermaidEirene, error
    chr_inc "portrait_eirene_talk"
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
    chr_res $02
    chr_inc "console"
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
    chr_res $02
    chr_inc "sign"
    chr_inc "console"
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
    chr_inc "furniture"
    chr_res $14
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgHut"

.EXPORT Ppu_ChrBgHut
.PROC Ppu_ChrBgHut
    CHR1_BANK $80
    chr_inc "hut1"
    chr_inc "hut2"
    chr_res $1e
    chr_inc "sign"
    chr_inc "console"
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
    chr_res $08
    chr_inc "field_bg"
    chr_res $04
    chr_inc "boiler"
    chr_inc "sign"
    chr_inc "console"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMermaid"

.EXPORT Ppu_ChrBgMermaid
.PROC Ppu_ChrBgMermaid
    CHR1_BANK $80
    chr_inc "cave"
    chr_inc "hut"
    chr_inc "beach"
    chr_res $08
    chr_inc "pump"
    chr_res $02
    chr_inc "lever_ceil"
    chr_inc "sign"
    chr_inc "console"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMine"

.EXPORT Ppu_ChrBgMine
.PROC Ppu_ChrBgMine
    CHR1_BANK $80
    chr_inc "crystal"
    chr_res $04
    chr_inc "minecart"
    chr_inc "scaffhold"
    chr_inc "mine_door"
    chr_inc "hoist_bg"
    chr_inc "sign"
    chr_inc "console"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMinimap"

.EXPORT Ppu_ChrBgMinimap
.PROC Ppu_ChrBgMinimap
    CHR1_BANK $80
    chr_inc "minimap1"
    chr_inc "minimap2"
    chr_inc "minimap3"
    chr_inc "minimap4"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgOutbreak"

.EXPORT Ppu_ChrBgOutbreak
.PROC Ppu_ChrBgOutbreak
    CHR1_BANK $c0
    chr_inc "outbreak_bg"
    chr_res $18
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
    chr_res $02
    chr_inc "sign"
    chr_inc "hill"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPause"

.EXPORT Ppu_ChrBgPause
.PROC Ppu_ChrBgPause
    CHR1_BANK $c0
    chr_inc "upgrade_bottom"
    chr_inc "upgrade_ram"
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
    chr_res $07
    chr_inc "minicore2"
    chr_inc "paper"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPrison"

.EXPORT Ppu_ChrBgPrison
.PROC Ppu_ChrBgPrison
    CHR1_BANK $80
    chr_inc "cave"
    chr_inc "prison"
    chr_res $18
    chr_inc "sign"
    chr_inc "console"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgSewer"

.EXPORT Ppu_ChrBgSewer
.PROC Ppu_ChrBgSewer
    CHR1_BANK $80
    chr_inc "sewer1"
    chr_inc "sewer2"
    chr_res $16
    chr_inc "pump"
    chr_res $04
    chr_inc "sign"
    chr_inc "console"
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgShadow"

.EXPORT Ppu_ChrBgShadow
.PROC Ppu_ChrBgShadow
    CHR1_BANK $80
    chr_inc "shadow1"
    chr_inc "shadow2"
    chr_res $0c
    chr_inc "field_bg"
    chr_inc "tank"
    chr_inc "plaque"
    chr_inc "console"
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
    chr_inc "plaque"
    chr_inc "console"
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
    chr_res $1b
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgWheel"

.EXPORT Ppu_ChrBgWheel
.PROC Ppu_ChrBgWheel
    CHR1_BANK $c0
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
    chr_inc "font_hilight"
    chr_inc "player_flower", eAvatar::Standing
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjAnnaNormal"

.EXPORT Ppu_ChrObjAnnaNormal
.PROC Ppu_ChrObjAnnaNormal
    CHR2_BANK $00
    chr_inc "font_hilight"
    chr_inc "player_normal", eAvatar::Standing
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjBoss1"

.EXPORT Ppu_ChrObjBoss1
.PROC Ppu_ChrObjBoss1
    CHR2_BANK $80
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_inc "upgrade_ram",    kTileIdObjUpgradeRamFirst
    chr_inc "breakball",      kTileIdObjBreakballFirst
    chr_inc "ember",          kTileIdObjEmber
    chr_res $01
    chr_inc "cannon",         kTileIdObjCannonFirst
    chr_inc "bullet",         kTileIdObjBulletFirst
    chr_res $06
    chr_inc "upgrade_oprest", kTileIdObjUpgradeOpRestFirst
    chr_inc "blaster",        kTileIdObjBlasterFirst
    chr_inc "fireball",       kTileIdObjFireballFirst
    chr_inc "outbreak_obj",   kTileIdObjOutbreakFirst
    chr_res $08
    chr_inc "spike",          kTileIdObjSpike
    chr_inc "flamewave",      kTileIdObjFlamewaveFirst
    chr_res $02
    chr_inc "plant_eye",      kTileIdObjPlantEyeFirst
    chr_res $04
    chr_inc "plant_eye_red",  kTileIdObjPlantEyeRedFirst
    chr_inc "gazer_obj",      kTileIdObjGazerFirst
    chr_res $01
    chr_inc "mirror",         kTileIdObjMirrorFirst
    chr_res $03
    chr_inc "minigun_vert",   kTileIdObjMinigunVertFirst
    chr_inc "crusher",        kTileIdObjCrusherFirst
    chr_inc "winch",          kTileIdObjWinchFirst
    chr_inc "grenade",        kTileIdObjGrenadeFirst
    chr_inc "breaker",        kTileIdObjBreakerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjCity"

.EXPORT Ppu_ChrObjCity
.PROC Ppu_ChrObjCity
    CHR2_BANK $80
    chr_inc "upgrade_bottom",  kTileIdObjUpgradeBottomFirst
    chr_res $02
    chr_inc "upgrade_bremote", kTileIdObjUpgradeBRemoteFirst
    chr_inc "reloader",        kTileIdObjReloaderFirst
    chr_res $0b
    chr_inc "launcher_horz",   kTileIdObjLauncherHorzFirst
    chr_res $04
    chr_inc "combo",           kTileIdObjComboFirst
    chr_inc "rodent",          kTileIdObjRodentFirst
    chr_res $07
    chr_inc "rhino",           kTileIdObjRhinoFirst
    chr_inc "semaphore",       kTileIdObjSemaphoreFirst
    chr_res $28
    chr_inc "breaker",         kTileIdObjBreakerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjCrypt"

.EXPORT Ppu_ChrObjCrypt
.PROC Ppu_ChrObjCrypt
    CHR2_BANK $80
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_res $10
    chr_inc "upgrade_opgoto", kTileIdObjUpgradeOpGotoFirst
    chr_res $08
    chr_inc "bat",            kTileIdObjBatFirst
    chr_inc "spider",         kTileIdObjSpiderFirst
    chr_res $10
    chr_inc "breakable",      kTileIdObjWeakFloorFirst
    chr_res $0e
    chr_inc "fish",           kTileIdObjFishFirst
    chr_inc "crusher",        kTileIdObjCrusherFirst
    chr_inc "winch",          kTileIdObjWinchFirst
    chr_res $14
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjFactory"

.EXPORT Ppu_ChrObjFactory
.PROC Ppu_ChrObjFactory
    CHR2_BANK $80
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_inc "jet",            kTileIdObjJetFirst
    chr_inc "rotor",          kTileIdObjRotorFirst
    chr_res $07
    chr_inc "upgrade_opskip", kTileIdObjUpgradeOpSkipFirst
    chr_res $06
    chr_inc "grub",           kTileIdObjGrubFirst
    chr_inc "toad",           kTileIdObjToadFirst
    chr_inc "crane",          kTileIdObjCraneFirst
    chr_res $48
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjGarden"

.EXPORT Ppu_ChrObjGarden
.PROC Ppu_ChrObjGarden
    CHR2_BANK $80
    chr_inc "upgrade_bottom",      kTileIdObjUpgradeBottomFirst
    chr_res $04
    chr_inc "upgrade_opif",        kTileIdObjUpgradeOpIfFirst
    chr_inc "cannon",              kTileIdObjCannonFirst
    chr_inc "mermaid_corra",       kTileIdMermaidCorraFirst
    chr_inc "crate",               kTileIdObjCrateFirst
    chr_res $04
    chr_inc "grub",                kTileIdObjGrubFirst
    chr_res $02
    chr_inc "garden_bricks",       kTileIdObjGardenBricksFirst
    chr_inc "vinebug",             kTileIdObjVinebugFirst
    chr_inc "anchor",              kTileIdObjAnchorFirst
    chr_res $05
    chr_inc "beetle",              kTileIdObjBeetleFirst
    chr_res $04
    chr_inc "fish",                kTileIdObjFishFirst
    chr_inc "corra_swimming_down", kTileIdCorraSwimmingDownFirst
    chr_inc "grenade",             kTileIdObjGrenadeFirst
    chr_inc "corra_swimming_up",   kTileIdCorraSwimmingUpFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjLava"

.EXPORT Ppu_ChrObjLava
.PROC Ppu_ChrObjLava
    CHR2_BANK $80
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_inc "upgrade_ram",    kTileIdObjUpgradeRamFirst
    chr_res $02
    chr_inc "ember",          kTileIdObjEmber
    chr_res $03
    chr_inc "upgrade_opcopy", kTileIdObjUpgradeOpCopyFirst
    chr_res $08
    chr_inc "crate",          kTileIdObjCrateFirst
    chr_inc "blaster",        kTileIdObjBlasterFirst
    chr_inc "fireball",       kTileIdObjFireballFirst
    chr_res $04
    chr_inc "hothead",        kTileIdObjHotheadFirst
    chr_inc "lavaball",       kTileIdObjLavaballFirst
    chr_inc "anchor",         kTileIdObjAnchorFirst
    chr_inc "valve",          kTileIdObjValveFirst
    chr_res $10
    chr_inc "mirror",         kTileIdObjMirrorFirst
    chr_res $1b
    chr_inc "breaker",        kTileIdObjBreakerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjMine"

.EXPORT Ppu_ChrObjMine
.PROC Ppu_ChrObjMine
    CHR2_BANK $80
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_inc "upgrade_ram",    kTileIdObjUpgradeRamFirst
    chr_inc "hoist_obj",      kTileIdObjHoistFirst
    chr_inc "mine_cage",      kTileIdObjMineCageFirst
    chr_res $06
    chr_inc "wasp",           kTileIdObjWaspFirst
    chr_inc "upgrade_opsync", kTileIdObjUpgradeOpSyncFirst
    chr_inc "fireball",       kTileIdObjFireballFirst
    chr_inc "boulder",        kTileIdObjBoulderFirst
    chr_inc "firefly",        kTileIdObjFireflyFirst
    chr_res $08
    chr_inc "crane",          kTileIdObjCraneFirst
    chr_res $38
    chr_inc "breaker",        kTileIdObjBreakerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjPause"

.EXPORT Ppu_ChrObjPause
.PROC Ppu_ChrObjPause
    CHR2_BANK $80
    chr_inc "font_upper"
    chr_inc "pause"
    chr_res $30
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjSewer"

.EXPORT Ppu_ChrObjSewer
.PROC Ppu_ChrObjSewer
    CHR2_BANK $80
    chr_inc "upgrade_bottom",   kTileIdObjUpgradeBottomFirst
    chr_inc "multiplexer",      kTileIdObjMultiplexerFirst
    chr_inc "pump_light",       kTileIdObjPumpLight
    chr_inc "water",            kTileIdObjWaterFirst
    chr_inc "jelly",            kTileIdObjJellyFirst
    chr_res $02
    chr_inc "upgrade_opaddsub", kTileIdObjUpgradeOpAddSubFirst
    chr_res $02
    chr_inc "monitor",          kTileIdObjMonitorFirst
    chr_inc "launcher_horz",    kTileIdObjLauncherHorzFirst
    chr_inc "rocks",            kTileIdObjRocksFirst
    chr_res $02
    chr_inc "grub",             kTileIdObjGrubFirst
    chr_res $18
    chr_inc "bird",             kTileIdObjBirdFirst
    chr_inc "crab",             kTileIdObjCrabFirst
    chr_inc "hotspring",        kTileIdObjHotSpringFirst
    chr_inc "fish",             kTileIdObjFishFirst
    chr_inc "child_stand",      kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjShadow"

.EXPORT Ppu_ChrObjShadow
.PROC Ppu_ChrObjShadow
    CHR2_BANK $80
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_res $0c
    chr_inc "upgrade_opmul",  kTileIdObjUpgradeOpMulFirst
    chr_res $40
    chr_inc "flydrop",        kTileIdObjFlydropFirst
    chr_inc "acid",           kTileIdObjAcid
    chr_res $03
    chr_inc "laser",          kTileIdObjLaserFirst
    chr_inc "barrier",        kTileIdObjBarrierFirst
    chr_inc "emitter",        kTileIdObjEmitterFirst
    chr_inc "forcefield",     kTileIdObjForcefieldFirst
    chr_inc "breaker",        kTileIdObjBreakerFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjTemple"

.EXPORT Ppu_ChrObjTemple
.PROC Ppu_ChrObjTemple
    CHR2_BANK $80
    chr_inc "upgrade_bottom", kTileIdObjUpgradeBottomFirst
    chr_res $04
    chr_inc "column",         kTileIdObjColumnFirst
    chr_inc "upgrade_optil",  kTileIdObjUpgradeOpTilFirst
    chr_res $04
    chr_inc "bullet",         kTileIdObjBulletFirst
    chr_inc "upgrade_opbeep", kTileIdObjUpgradeOpBeepFirst
    chr_res $02
    chr_inc "crate",          kTileIdObjCrateFirst
    chr_res $08
    chr_inc "mermaid_guardf", kTileIdMermaidGuardFFirst
    chr_res $02
    chr_inc "toad",           kTileIdObjToadFirst
    chr_inc "column_cracked", kTileIdObjColumnCrackedFirst
    chr_res $08
    chr_inc "beetle",         kTileIdObjBeetleFirst
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
    chr_inc "toddler",       kTileIdObjToddlerFirst
    chr_inc "stepstone",     kTileIdObjStepstone
    chr_inc "gate",          kTileIdObjGateFirst
    chr_inc "orc_standing",  kTileIdObjOrcStandingFirst
    chr_inc "launcher_vert", kTileIdObjLauncherVertFirst
    chr_inc "crate",         kTileIdObjCrateFirst
    chr_inc "rocks",         kTileIdObjRocksFirst
    chr_res $06
    chr_inc "orc_gronta",    kTileIdObjOrcGrontaFirst
    chr_inc "orc_running",   kTileIdObjOrcRunningFirst
    chr_inc "orc_throwing",  kTileIdObjOrcThrowingFirst
    chr_inc "adult_woman",   kTileIdAdultWomanFirst
    chr_inc "adult_man",     kTileIdAdultManFirst
    chr_res $04
    chr_inc "child_stand",   kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjVillage"

.EXPORT Ppu_ChrObjVillage
.PROC Ppu_ChrObjVillage
    CHR2_BANK $80
    chr_res $0e
    chr_inc "mermaid_corra",   kTileIdMermaidCorraFirst
    chr_inc "mermaid_florist", kTileIdMermaidFloristFirst
    chr_inc "mermaid_daphne",  kTileIdMermaidDaphneFirst
    chr_inc "mermaid_guardf",  kTileIdMermaidGuardFFirst
    chr_inc "mermaid_guardm",  kTileIdMermaidGuardMFirst
    chr_inc "mermaid_phoebe",  kTileIdMermaidPhoebeFirst
    chr_inc "mermaid_farmer",  kTileIdMermaidFarmerFirst
    chr_inc "mermaid_queen",   kTileIdMermaidQueenFirst
    chr_res $18
    chr_inc "child_swim",      kTileIdObjChildSwimFirst
    chr_inc "child_stand",     kTileIdObjChildStandFirst
    END_CHR_BANK
.ENDPROC

;;;=========================================================================;;;
