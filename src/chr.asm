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

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA0"

.EXPORT Ppu_ChrBgAnimA0
.PROC Ppu_ChrBgAnimA0
:   .incbin "out/tiles/water_anim0.chr"
    .incbin "out/tiles/acid_anim0.chr"
    .incbin "out/tiles/waterfall_anim0.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/thorns_anim0.chr"
    .incbin "out/tiles/sewage_anim0.chr"
    .incbin "out/tiles/circuit_anim0.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA1"

.PROC Ppu_ChrBgAnimA1
:   .incbin "out/tiles/water_anim0.chr"
    .incbin "out/tiles/acid_anim1.chr"
    .incbin "out/tiles/waterfall_anim1.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/thorns_anim1.chr"
    .incbin "out/tiles/sewage_anim1.chr"
    .incbin "out/tiles/circuit_anim1.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA2"

.PROC Ppu_ChrBgAnimA2
:   .incbin "out/tiles/water_anim1.chr"
    .incbin "out/tiles/acid_anim2.chr"
    .incbin "out/tiles/waterfall_anim2.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/thorns_anim2.chr"
    .incbin "out/tiles/sewage_anim2.chr"
    .incbin "out/tiles/circuit_anim2.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA3"

.PROC Ppu_ChrBgAnimA3
:   .incbin "out/tiles/water_anim1.chr"
    .incbin "out/tiles/acid_anim3.chr"
    .incbin "out/tiles/waterfall_anim3.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/thorns_anim3.chr"
    .incbin "out/tiles/sewage_anim3.chr"
    .incbin "out/tiles/circuit_anim3.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA4"

.PROC Ppu_ChrBgAnimA4
:   .incbin "out/tiles/water_anim2.chr"
    .incbin "out/tiles/acid_anim4.chr"
    .incbin "out/tiles/waterfall_anim0.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/thorns_anim4.chr"
    .incbin "out/tiles/sewage_anim0.chr"
    .incbin "out/tiles/circuit_anim4.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA5"

.PROC Ppu_ChrBgAnimA5
:   .incbin "out/tiles/water_anim2.chr"
    .incbin "out/tiles/acid_anim5.chr"
    .incbin "out/tiles/waterfall_anim1.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/thorns_anim5.chr"
    .incbin "out/tiles/sewage_anim1.chr"
    .incbin "out/tiles/circuit_anim5.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA6"

.PROC Ppu_ChrBgAnimA6
:   .incbin "out/tiles/water_anim1.chr"
    .incbin "out/tiles/acid_anim6.chr"
    .incbin "out/tiles/waterfall_anim2.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/thorns_anim6.chr"
    .incbin "out/tiles/sewage_anim2.chr"
    .incbin "out/tiles/circuit_anim6.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimA7"

.PROC Ppu_ChrBgAnimA7
:   .incbin "out/tiles/water_anim1.chr"
    .incbin "out/tiles/acid_anim7.chr"
    .incbin "out/tiles/waterfall_anim3.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/thorns_anim7.chr"
    .incbin "out/tiles/sewage_anim3.chr"
    .incbin "out/tiles/circuit_anim7.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB0"

.EXPORT Ppu_ChrBgAnimB0
.PROC Ppu_ChrBgAnimB0
:   .incbin "out/tiles/lava_anim0.chr"
    .res $06 * kSizeofChr
    .incbin "out/tiles/conveyor_anim0.chr"
    .res $1e * kSizeofChr
    .incbin "out/tiles/gazer_anim0.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB1"

.PROC Ppu_ChrBgAnimB1
:   .incbin "out/tiles/lava_anim1.chr"
    .res $06 * kSizeofChr
    .incbin "out/tiles/conveyor_anim1.chr"
    .res $1e * kSizeofChr
    .incbin "out/tiles/gazer_anim1.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB2"

.PROC Ppu_ChrBgAnimB2
:   .incbin "out/tiles/lava_anim2.chr"
    .res $06 * kSizeofChr
    .incbin "out/tiles/conveyor_anim2.chr"
    .res $1e * kSizeofChr
    .incbin "out/tiles/gazer_anim2.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimB3"

.PROC Ppu_ChrBgAnimB3
:   .incbin "out/tiles/lava_anim3.chr"
    .res $06 * kSizeofChr
    .incbin "out/tiles/conveyor_anim3.chr"
    .res $1e * kSizeofChr
    .incbin "out/tiles/gazer_anim3.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgAnimStatic"

.EXPORT Ppu_ChrBgAnimStatic
.PROC Ppu_ChrBgAnimStatic
:   .res $10 * kSizeofChr
    .incbin "out/tiles/thorns_anim_static.chr"
    .res $0a * kSizeofChr
    .incbin "out/tiles/circuit_anim_static.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgBuilding"

.EXPORT Ppu_ChrBgBuilding
.PROC Ppu_ChrBgBuilding
:   .incbin "out/tiles/building1.chr"
    .incbin "out/tiles/building2.chr"
    .incbin "out/tiles/building3.chr"
    .incbin "out/tiles/building4.chr"
    .res $0a * kSizeofChr
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgCity"

.EXPORT Ppu_ChrBgCity
.PROC Ppu_ChrBgCity
:   .incbin "out/tiles/city1.chr"
    .incbin "out/tiles/city2.chr"
    .incbin "out/tiles/city3.chr"
    .res $0c * kSizeofChr
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgCore"

.EXPORT Ppu_ChrBgCore
.PROC Ppu_ChrBgCore
:   .incbin "out/tiles/core_pipes1.chr"
    .incbin "out/tiles/core_pipes2.chr"
    .res $04 * kSizeofChr
    .incbin "out/tiles/fullcore1.chr"
    .incbin "out/tiles/fullcore2.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgCrypt"

.EXPORT Ppu_ChrBgCrypt
.PROC Ppu_ChrBgCrypt
:   .incbin "out/tiles/crypt.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/cobweb.chr"
    .res $08 * kSizeofChr
    .incbin "out/tiles/gazer_eye.chr"
    .res $04 * kSizeofChr
    .incbin "out/tiles/arch.chr"
    .res $06 * kSizeofChr
    .incbin "out/tiles/plaque.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontUpper"

.EXPORT Ppu_ChrBgFontUpper
.PROC Ppu_ChrBgFontUpper
:   .incbin "out/tiles/font_upper.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower01"

.EXPORT Ppu_ChrBgFontLower01
.PROC Ppu_ChrBgFontLower01
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Lift, error
    .incbin "out/tiles/diagram_lift.chr"
    .assert .bank(*) = <ePortrait::AdultWoman, error
    .incbin "out/tiles/portrait_woman_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower02"

.PROC Ppu_ChrBgFontLower02
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Trolley, error
    .incbin "out/tiles/diagram_trolley.chr"
    .assert .bank(*) = >ePortrait::AdultWoman, error
    .incbin "out/tiles/portrait_woman_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower03"

.PROC Ppu_ChrBgFontLower03
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Winch, error
    .incbin "out/tiles/diagram_winch.chr"
    .assert .bank(*) = <ePortrait::Sign, error
    .assert .bank(*) = >ePortrait::Sign, error
    .incbin "out/tiles/portrait_sign.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower04"

.PROC Ppu_ChrBgFontLower04
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Boiler, error
    .incbin "out/tiles/diagram_boiler.chr"
    .assert .bank(*) = <ePortrait::Paper, error
    .assert .bank(*) = >ePortrait::Paper, error
    .incbin "out/tiles/portrait_paper.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower05"

.PROC Ppu_ChrBgFontLower05
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Field, error
    .incbin "out/tiles/diagram_field.chr"
    .assert .bank(*) = <ePortrait::MermaidDaphne, error
    .assert .bank(*) = <ePortrait::MermaidGuardF, error
    .incbin "out/tiles/portrait_mermaid_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower06"

.PROC Ppu_ChrBgFontLower06
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Jet, error
    .incbin "out/tiles/diagram_jet.chr"
    .assert .bank(*) = >ePortrait::MermaidDaphne, error
    .assert .bank(*) = >ePortrait::MermaidGuardF, error
    .incbin "out/tiles/portrait_mermaid_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower07"

.PROC Ppu_ChrBgFontLower07
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Carriage, error
    .incbin "out/tiles/diagram_carriage.chr"
    .assert .bank(*) = <ePortrait::AdultMan, error
    .incbin "out/tiles/portrait_man_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower08"

.PROC Ppu_ChrBgFontLower08
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::CannonRight, error
    .incbin "out/tiles/diagram_cannon_right.chr"
    .assert .bank(*) = >ePortrait::AdultMan, error
    .incbin "out/tiles/portrait_man_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower09"

.PROC Ppu_ChrBgFontLower09
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::CannonLeft, error
    .incbin "out/tiles/diagram_cannon_left.chr"
    .assert .bank(*) = <ePortrait::ChildNora, error
    .incbin "out/tiles/portrait_nora_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0A"

.PROC Ppu_ChrBgFontLower0A
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::BridgeRight, error
    .incbin "out/tiles/diagram_bridge_right.chr"
    .assert .bank(*) = >ePortrait::ChildNora, error
    .incbin "out/tiles/portrait_nora_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0B"

.PROC Ppu_ChrBgFontLower0B
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::BridgeLeft, error
    .incbin "out/tiles/diagram_bridge_left.chr"
    .assert .bank(*) = <ePortrait::ChildAlex, error
    .incbin "out/tiles/portrait_alex_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0C"

.PROC Ppu_ChrBgFontLower0C
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Crane, error
    .incbin "out/tiles/diagram_crane.chr"
    .assert .bank(*) = >ePortrait::ChildAlex, error
    .incbin "out/tiles/portrait_alex_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0D"

.PROC Ppu_ChrBgFontLower0D
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Multiplexer, error
    .incbin "out/tiles/diagram_multiplexer.chr"
    .assert .bank(*) = <ePortrait::MermaidCorra, error
    .incbin "out/tiles/portrait_corra_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0E"

.PROC Ppu_ChrBgFontLower0E
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Debugger, error
    .incbin "out/tiles/diagram_debugger.chr"
    .assert .bank(*) = >ePortrait::MermaidCorra, error
    .incbin "out/tiles/portrait_corra_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower0F"

.PROC Ppu_ChrBgFontLower0F
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::HoistRight, error
    .incbin "out/tiles/diagram_hoist_right.chr"
    .assert .bank(*) = <ePortrait::MermaidFlorist, error
    .incbin "out/tiles/portrait_florist_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower10"

.PROC Ppu_ChrBgFontLower10
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::HoistLeft, error
    .incbin "out/tiles/diagram_hoist_left.chr"
    .assert .bank(*) = >ePortrait::MermaidFlorist, error
    .incbin "out/tiles/portrait_florist_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower11"

.PROC Ppu_ChrBgFontLower11
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::LauncherDown, error
    .incbin "out/tiles/diagram_launcher_down.chr"
    .assert .bank(*) = <ePortrait::ChildMarie, error
    .incbin "out/tiles/portrait_marie_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower12"

.PROC Ppu_ChrBgFontLower12
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::MinigunDown, error
    .incbin "out/tiles/diagram_minigun_down.chr"
    .assert .bank(*) = >ePortrait::ChildMarie, error
    .incbin "out/tiles/portrait_marie_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower13"

.PROC Ppu_ChrBgFontLower13
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::MinigunLeft, error
    .incbin "out/tiles/diagram_minigun_left.chr"
    .assert .bank(*) = <ePortrait::ChildBruno, error
    .incbin "out/tiles/portrait_bruno_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower14"

.PROC Ppu_ChrBgFontLower14
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::MinigunUp, error
    .incbin "out/tiles/diagram_minigun_up.chr"
    .assert .bank(*) = >ePortrait::ChildBruno, error
    .incbin "out/tiles/portrait_bruno_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower15"

.PROC Ppu_ChrBgFontLower15
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::LauncherLeft, error
    .incbin "out/tiles/diagram_launcher_left.chr"
    .assert .bank(*) = <ePortrait::Plaque, error
    .assert .bank(*) = >ePortrait::Plaque, error
    .incbin "out/tiles/portrait_plaque.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower16"

.PROC Ppu_ChrBgFontLower16
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::SemaphoreNormal, error
    .incbin "out/tiles/diagram_semaphore_normal.chr"
    .assert .bank(*) = <ePortrait::OrcGronta, error
    .incbin "out/tiles/portrait_gronta_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower17"

.PROC Ppu_ChrBgFontLower17
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::SemaphoreNoFlags, error
    .incbin "out/tiles/diagram_semaphore_no_flags.chr"
    .assert .bank(*) = >ePortrait::OrcGronta, error
    .incbin "out/tiles/portrait_gronta_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower18"

.PROC Ppu_ChrBgFontLower18
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::SemaphoreNoSensor, error
    .incbin "out/tiles/diagram_semaphore_no_sensor.chr"
    .assert .bank(*) = <ePortrait::OrcMale, error
    .incbin "out/tiles/portrait_orc_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower19"

.PROC Ppu_ChrBgFontLower19
:   .incbin "out/tiles/font_lower.chr"
    .assert .bank(*) = eDiagram::Pump, error
    .incbin "out/tiles/diagram_pump.chr"
    .assert .bank(*) = >ePortrait::OrcMale, error
    .incbin "out/tiles/portrait_orc_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower1A"

.PROC Ppu_ChrBgFontLower1A
:   .incbin "out/tiles/font_lower.chr"
    .res $10 * kSizeofChr
    .assert .bank(*) = <ePortrait::Screen, error
    .assert .bank(*) = >ePortrait::Screen, error
    .incbin "out/tiles/portrait_screen.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower1B"

.PROC Ppu_ChrBgFontLower1B
:   .incbin "out/tiles/font_lower.chr"
    .res $10 * kSizeofChr
    .assert .bank(*) = <ePortrait::MermaidEirene, error
    .incbin "out/tiles/portrait_eirene_rest.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFontLower1C"

.PROC Ppu_ChrBgFontLower1C
:   .incbin "out/tiles/font_lower.chr"
    .res $10 * kSizeofChr
    .assert .bank(*) = >ePortrait::MermaidEirene, error
    .incbin "out/tiles/portrait_eirene_talk.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgFactory"

.EXPORT Ppu_ChrBgFactory
.PROC Ppu_ChrBgFactory
:   .incbin "out/tiles/factory1.chr"
    .incbin "out/tiles/factory2.chr"
    .res $08 * kSizeofChr
    .incbin "out/tiles/tank.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgGarden"

.EXPORT Ppu_ChrBgGarden
.PROC Ppu_ChrBgGarden
:   .incbin "out/tiles/jungle1.chr"
    .incbin "out/tiles/jungle2.chr"
    .incbin "out/tiles/jungle3.chr"
    .incbin "out/tiles/arch.chr"
    .incbin "out/tiles/drawbridge.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/sign.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgHouse"

.EXPORT Ppu_ChrBgHouse
.PROC Ppu_ChrBgHouse
:   .incbin "out/tiles/indoors.chr"
    .res $07 * kSizeofChr
    .incbin "out/tiles/window.chr"
    .incbin "out/tiles/furniture.chr"
    .res $14 * kSizeofChr
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgHut"

.EXPORT Ppu_ChrBgHut
.PROC Ppu_ChrBgHut
:   .incbin "out/tiles/hut1.chr"
    .incbin "out/tiles/hut2.chr"
    .res $1e * kSizeofChr
    .incbin "out/tiles/sign.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgLava"

.EXPORT Ppu_ChrBgLava
.PROC Ppu_ChrBgLava
:   .incbin "out/tiles/steam_pipes.chr"
    .incbin "out/tiles/volcanic1.chr"
    .incbin "out/tiles/volcanic2.chr"
    .res $08 * kSizeofChr
    .incbin "out/tiles/field_bg.chr"
    .res $04 * kSizeofChr
    .incbin "out/tiles/boiler.chr"
    .incbin "out/tiles/sign.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMermaid"

.EXPORT Ppu_ChrBgMermaid
.PROC Ppu_ChrBgMermaid
:   .incbin "out/tiles/cave.chr"
    .incbin "out/tiles/hut.chr"
    .incbin "out/tiles/beach.chr"
    .res $08 * kSizeofChr
    .incbin "out/tiles/pump.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/lever_ceil.chr"
    .incbin "out/tiles/sign.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMine"

.EXPORT Ppu_ChrBgMine
.PROC Ppu_ChrBgMine
:   .incbin "out/tiles/crystal.chr"
    .res $04 * kSizeofChr
    .incbin "out/tiles/minecart.chr"
    .incbin "out/tiles/scaffhold.chr"
    .incbin "out/tiles/mine_door.chr"
    .incbin "out/tiles/hoist_bg.chr"
    .incbin "out/tiles/sign.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgMinimap"

.EXPORT Ppu_ChrBgMinimap
.PROC Ppu_ChrBgMinimap
:   .incbin "out/tiles/minimap1.chr"
    .incbin "out/tiles/minimap2.chr"
    .incbin "out/tiles/minimap3.chr"
    .incbin "out/tiles/minimap4.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgOutbreak"

.EXPORT Ppu_ChrBgOutbreak
.PROC Ppu_ChrBgOutbreak
:   .incbin "out/tiles/outbreak_bg.chr"
    .res $18 * kSizeofChr
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgOutdoors"

.EXPORT Ppu_ChrBgOutdoors
.PROC Ppu_ChrBgOutdoors
:   .incbin "out/tiles/outdoors.chr"
    .incbin "out/tiles/roof.chr"
    .incbin "out/tiles/window.chr"
    .incbin "out/tiles/house.chr"
    .incbin "out/tiles/tree.chr"
    .res $02 * kSizeofChr
    .incbin "out/tiles/sign.chr"
    .incbin "out/tiles/hill.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPause"

.EXPORT Ppu_ChrBgPause
.PROC Ppu_ChrBgPause
:   .incbin "out/tiles/upgrade_bottom.chr"
    .incbin "out/tiles/upgrade_ram.chr"
    .incbin "out/tiles/upgrade_bremote.chr"
    .incbin "out/tiles/upgrade_opif.chr"
    .incbin "out/tiles/upgrade_optil.chr"
    .incbin "out/tiles/upgrade_opcopy.chr"
    .incbin "out/tiles/upgrade_opaddsub.chr"
    .incbin "out/tiles/upgrade_opmul.chr"
    .incbin "out/tiles/upgrade_opbeep.chr"
    .incbin "out/tiles/upgrade_opgoto.chr"
    .incbin "out/tiles/upgrade_opskip.chr"
    .incbin "out/tiles/upgrade_oprest.chr"
    .incbin "out/tiles/upgrade_opsync.chr"
    .res $06 * kSizeofChr
    .incbin "out/tiles/minicore1.chr"
    .res $07 * kSizeofChr
    .incbin "out/tiles/minicore2.chr"
    .incbin "out/tiles/paper.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgPrison"

.EXPORT Ppu_ChrBgPrison
.PROC Ppu_ChrBgPrison
:   .incbin "out/tiles/cave.chr"
    .incbin "out/tiles/prison.chr"
    .res $18 * kSizeofChr
    .incbin "out/tiles/sign.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgSewer"

.EXPORT Ppu_ChrBgSewer
.PROC Ppu_ChrBgSewer
:   .incbin "out/tiles/sewer1.chr"
    .incbin "out/tiles/sewer2.chr"
    .res $16 * kSizeofChr
    .incbin "out/tiles/pump.chr"
    .res $04 * kSizeofChr
    .incbin "out/tiles/sign.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgShadow"

.EXPORT Ppu_ChrBgShadow
.PROC Ppu_ChrBgShadow
:   .incbin "out/tiles/shadow1.chr"
    .incbin "out/tiles/shadow2.chr"
    .res $0c * kSizeofChr
    .incbin "out/tiles/field_bg.chr"
    .incbin "out/tiles/tank.chr"
    .incbin "out/tiles/plaque.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgTemple"

.EXPORT Ppu_ChrBgTemple
.PROC Ppu_ChrBgTemple
:   .incbin "out/tiles/temple1.chr"
    .incbin "out/tiles/temple2.chr"
    .incbin "out/tiles/temple3.chr"
    .incbin "out/tiles/temple4.chr"
    .incbin "out/tiles/plaque.chr"
    .incbin "out/tiles/console.chr"
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgTitle"

.EXPORT Ppu_ChrBgTitle
.PROC Ppu_ChrBgTitle
:   .incbin "out/tiles/title1.chr"
    .incbin "out/tiles/title2.chr"
    .incbin "out/tiles/title3.chr"
    .res $1b * kSizeofChr
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_BgWheel"

.EXPORT Ppu_ChrBgWheel
.PROC Ppu_ChrBgWheel
:   .incbin "out/tiles/wheel1.chr"
    .incbin "out/tiles/wheel2.chr"
    .incbin "out/tiles/wheel3.chr"
    .incbin "out/tiles/wheel4.chr"
    .res $05 * kSizeofChr
    .assert * - :- = kSizeofChr * $40, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjAnnaFlower"

.EXPORT Ppu_ChrObjAnnaFlower
.PROC Ppu_ChrObjAnnaFlower
:   .incbin "out/tiles/font_hilight.chr"
    .assert * - :- = kSizeofChr * eAvatar::Standing, error
    .incbin "out/tiles/player_flower.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjAnnaNormal"

.EXPORT Ppu_ChrObjAnnaNormal
.PROC Ppu_ChrObjAnnaNormal
:   .incbin "out/tiles/font_hilight.chr"
    .assert * - :- = kSizeofChr * eAvatar::Standing, error
    .incbin "out/tiles/player_normal.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjBoss1"

.EXPORT Ppu_ChrObjBoss1
.PROC Ppu_ChrObjBoss1
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjUpgradeRamFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_ram.chr"
    .assert * - :- = (kTileIdObjBreakballFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/breakball.chr"
    .assert * - :- = (kTileIdObjEmber - $80) * kSizeofChr, error
    .incbin "out/tiles/ember.chr"
    .res $01 * kSizeofChr
    .assert * - :- = (kTileIdObjCannonFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/cannon.chr"
    .assert * - :- = (kTileIdObjBulletFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/bullet.chr"
    .res $06 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpRestFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_oprest.chr"
    .assert * - :- = (kTileIdObjBlasterFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/blaster.chr"
    .assert * - :- = (kTileIdObjFireballFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/fireball.chr"
    .assert * - :- = (kTileIdObjOutbreakFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/outbreak_obj.chr"
    .res $08 * kSizeofChr
    .assert * - :- = (kTileIdObjSpike - $80) * kSizeofChr, error
    .incbin "out/tiles/spike.chr"
    .assert * - :- = (kTileIdObjFlamewaveFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/flamewave.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjPlantEyeFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/plant_eye.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjPlantEyeRedFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/plant_eye_red.chr"
    .assert * - :- = (kTileIdObjGazerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/gazer_obj.chr"
    .res $01 * kSizeofChr
    .assert * - :- = (kTileIdObjMirrorFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mirror.chr"
    .res $03 * kSizeofChr
    .assert * - :- = (kTileIdObjMinigunVertFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/minigun_vert.chr"
    .assert * - :- = (kTileIdObjCrusherFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crusher.chr"
    .assert * - :- = (kTileIdObjWinchFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/winch.chr"
    .assert * - :- = (kTileIdObjGrenadeFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/grenade.chr"
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjCity"

.EXPORT Ppu_ChrObjCity
.PROC Ppu_ChrObjCity
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeBRemoteFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bremote.chr"
    .assert * - :- = (kTileIdObjReloaderFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/reloader.chr"
    .res $07 * kSizeofChr
    .assert * - :- = (kTileIdObjLauncherVertFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/launcher_vert.chr"
    .assert * - :- = (kTileIdObjLauncherHorzFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/launcher_horz.chr"
    .assert * - :- = (kTileIdObjRocksFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/rocks.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjComboFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/combo.chr"
    .assert * - :- = (kTileIdObjRodentFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/rodent.chr"
    .res $07 * kSizeofChr
    .assert * - :- = (kTileIdObjRhinoFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/rhino.chr"
    .assert * - :- = (kTileIdObjSemaphoreFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/semaphore.chr"
    .res $28 * kSizeofChr
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjCrypt"

.EXPORT Ppu_ChrObjCrypt
.PROC Ppu_ChrObjCrypt
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .res $10 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpGotoFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_opgoto.chr"
    .res $08 * kSizeofChr
    .assert * - :- = (kTileIdObjBatFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/bat.chr"
    .assert * - :- = (kTileIdObjSpiderFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/spider.chr"
    .res $10 * kSizeofChr
    .assert * - :- = (kTileIdObjWeakFloorFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/breakable.chr"
    .res $0e * kSizeofChr
    .assert * - :- = (kTileIdObjFishFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/fish.chr"
    .assert * - :- = (kTileIdObjCrusherFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crusher.chr"
    .assert * - :- = (kTileIdObjWinchFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/winch.chr"
    .res $14 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjFactory"

.EXPORT Ppu_ChrObjFactory
.PROC Ppu_ChrObjFactory
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjJetFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/jet.chr"
    .assert * - :- = (kTileIdObjRotorFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/rotor.chr"
    .res $07 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpSkipFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_opskip.chr"
    .res $06 * kSizeofChr
    .assert * - :- = (kTileIdObjGrubFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/grub.chr"
    .assert * - :- = (kTileIdObjToadFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/toad.chr"
    .assert * - :- = (kTileIdObjCraneFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crane.chr"
    .res $48 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjGarden"

.EXPORT Ppu_ChrObjGarden
.PROC Ppu_ChrObjGarden
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpIfFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_opif.chr"
    .assert * - :- = (kTileIdObjCannonFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/cannon.chr"
    .assert * - :- = (kTileIdMermaidCorraFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_corra.chr"
    .assert * - :- = (kTileIdObjCrateFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crate.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjGrubFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/grub.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjGardenBricksFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/garden_bricks.chr"
    .assert * - :- = (kTileIdObjVinebugFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/vinebug.chr"
    .assert * - :- = (kTileIdObjAnchorFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/anchor.chr"
    .res $05 * kSizeofChr
    .assert * - :- = (kTileIdObjBeetleFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/beetle.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjFishFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/fish.chr"
    .assert * - :- = (kTileIdCorraSwimmingDownFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/corra_swimming_down.chr"
    .assert * - :- = (kTileIdObjGrenadeFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/grenade.chr"
    .assert * - :- = (kTileIdCorraSwimmingUpFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/corra_swimming_up.chr"
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjLava"

.EXPORT Ppu_ChrObjLava
.PROC Ppu_ChrObjLava
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjUpgradeRamFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_ram.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjEmber - $80) * kSizeofChr, error
    .incbin "out/tiles/ember.chr"
    .res $03 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpCopyFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_opcopy.chr"
    .res $08 * kSizeofChr
    .assert * - :- = (kTileIdObjCrateFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crate.chr"
    .assert * - :- = (kTileIdObjBlasterFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/blaster.chr"
    .assert * - :- = (kTileIdObjFireballFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/fireball.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjHotheadFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/hothead.chr"
    .assert * - :- = (kTileIdObjLavaballFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/lavaball.chr"
    .assert * - :- = (kTileIdObjAnchorFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/anchor.chr"
    .assert * - :- = (kTileIdObjValveFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/valve.chr"
    .res $10 * kSizeofChr
    .assert * - :- = (kTileIdObjMirrorFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mirror.chr"
    .res $1b * kSizeofChr
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjMine"

.EXPORT Ppu_ChrObjMine
.PROC Ppu_ChrObjMine
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjUpgradeRamFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_ram.chr"
    .assert * - :- = (kTileIdObjHoistFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/hoist_obj.chr"
    .assert * - :- = (kTileIdObjMineCageFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mine_cage.chr"
    .res $06 * kSizeofChr
    .assert * - :- = (kTileIdObjWaspFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/wasp.chr"
    .assert * - :- = (kTileIdObjUpgradeOpSyncFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_opsync.chr"
    .assert * - :- = (kTileIdObjFireballFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/fireball.chr"
    .assert * - :- = (kTileIdObjBoulderFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/boulder.chr"
    .assert * - :- = (kTileIdObjFireflyFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/firefly.chr"
    .res $08 * kSizeofChr
    .assert * - :- = (kTileIdObjCraneFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crane.chr"
    .res $38 * kSizeofChr
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjPause"

.EXPORT Ppu_ChrObjPause
.PROC Ppu_ChrObjPause
:   .incbin "out/tiles/font_upper.chr"
    .incbin "out/tiles/pause.chr"
    .res $30 * kSizeofChr
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjSewer"

.EXPORT Ppu_ChrObjSewer
.PROC Ppu_ChrObjSewer
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .assert * - :- = (kTileIdObjMultiplexerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/multiplexer.chr"
    .assert * - :- = (kTileIdObjPumpLight - $80) * kSizeofChr, error
    .incbin "out/tiles/pump_light.chr"
    .assert * - :- = (kTileIdObjWaterFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/water.chr"
    .assert * - :- = (kTileIdObjJellyFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/jelly.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpAddSubFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_opaddsub.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpBeepFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_opbeep.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjMonitorFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/monitor.chr"
    .assert * - :- = (kTileIdObjRocksFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/rocks.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjGrubFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/grub.chr"
    .res $18 * kSizeofChr
    .assert * - :- = (kTileIdObjBirdFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/bird.chr"
    .assert * - :- = (kTileIdObjCrabFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crab.chr"
    .assert * - :- = (kTileIdObjHotSpringFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/hotspring.chr"
    .assert * - :- = (kTileIdObjFishFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/fish.chr"
    .assert * - :- = (kTileIdObjChildStandFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/child_stand.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjShadow"

.EXPORT Ppu_ChrObjShadow
.PROC Ppu_ChrObjShadow
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .res $0c * kSizeofChr
    .assert * - :- = (kTileIdObjUpgradeOpMulFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_opmul.chr"
    .res $40 * kSizeofChr
    .assert * - :- = (kTileIdObjFlydropFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/flydrop.chr"
    .assert * - :- = (kTileIdObjAcid - $80) * kSizeofChr, error
    .incbin "out/tiles/acid.chr"
    .res $03 * kSizeofChr
    .assert * - :- = (kTileIdObjLaserFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/laser.chr"
    .assert * - :- = (kTileIdObjBarrierFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/barrier.chr"
    .assert * - :- = (kTileIdObjEmitterFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/emitter.chr"
    .assert * - :- = (kTileIdObjForcefieldFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/forcefield.chr"
    .assert * - :- = (kTileIdObjBreakerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/breaker.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjTemple"

.EXPORT Ppu_ChrObjTemple
.PROC Ppu_ChrObjTemple
:   .assert * - :- = (kTileIdObjUpgradeBottomFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_bottom.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjColumnFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/column.chr"
    .assert * - :- = (kTileIdObjUpgradeOpTilFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/upgrade_optil.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjBulletFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/bullet.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjCrateFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crate.chr"
    .res $08 * kSizeofChr
    .assert * - :- = (kTileIdMermaidGuardFFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_guardf.chr"
    .res $02 * kSizeofChr
    .assert * - :- = (kTileIdObjToadFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/toad.chr"
    .assert * - :- = (kTileIdObjColumnCrackedFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/column_cracked.chr"
    .res $08 * kSizeofChr
    .assert * - :- = (kTileIdObjBeetleFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/beetle.chr"
    .assert * - :- = (kTileIdObjMinigunHorzFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/minigun_horz.chr"
    .assert * - :- = (kTileIdObjMinigunVertFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/minigun_vert.chr"
    .assert * - :- = (kTileIdObjChildStandFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/child_stand.chr"
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjTown"

.EXPORT Ppu_ChrObjTown
.PROC Ppu_ChrObjTown
:   .assert * - :- = (kTileIdObjToddlerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/toddler.chr"
    .assert * - :- = (kTileIdObjStepstone - $80) * kSizeofChr, error
    .incbin "out/tiles/stepstone.chr"
    .assert * - :- = (kTileIdObjGateFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/gate.chr"
    .assert * - :- = (kTileIdObjOrcStandingFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/orc_standing.chr"
    .assert * - :- = (kTileIdObjLauncherVertFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/launcher_vert.chr"
    .assert * - :- = (kTileIdObjCrateFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/crate.chr"
    .assert * - :- = (kTileIdObjRocksFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/rocks.chr"
    .res $06 * kSizeofChr
    .assert * - :- = (kTileIdObjOrcGrontaFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/orc_gronta.chr"
    .assert * - :- = (kTileIdObjOrcRunningFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/orc_running.chr"
    .assert * - :- = (kTileIdObjOrcThrowingFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/orc_throwing.chr"
    .assert * - :- = (kTileIdAdultWomanFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/adult_woman.chr"
    .assert * - :- = (kTileIdAdultManFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/adult_man.chr"
    .res $04 * kSizeofChr
    .assert * - :- = (kTileIdObjChildStandFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/child_stand.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "CHR_ObjVillage"

.EXPORT Ppu_ChrObjVillage
.PROC Ppu_ChrObjVillage
:   .res $0e * kSizeofChr
    .assert * - :- = (kTileIdMermaidCorraFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_corra.chr"
    .assert * - :- = (kTileIdMermaidFloristFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_florist.chr"
    .assert * - :- = (kTileIdMermaidDaphneFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_daphne.chr"
    .assert * - :- = (kTileIdMermaidGuardFFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_guardf.chr"
    .assert * - :- = (kTileIdMermaidGuardMFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_guardm.chr"
    .assert * - :- = (kTileIdMermaidPhoebeFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_phoebe.chr"
    .assert * - :- = (kTileIdMermaidFarmerFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_farmer.chr"
    .assert * - :- = (kTileIdMermaidQueenFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/mermaid_queen.chr"
    .res $18 * kSizeofChr
    .assert * - :- = (kTileIdObjChildSwimFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/child_swim.chr"
    .assert * - :- = (kTileIdObjChildStandFirst - $80) * kSizeofChr, error
    .incbin "out/tiles/child_stand.chr"
    .assert * - :- = kSizeofChr * $80, error
.ENDPROC

;;;=========================================================================;;;
