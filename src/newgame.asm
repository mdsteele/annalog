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

.INCLUDE "boss.inc"
.INCLUDE "charmap.inc"
.INCLUDE "devices/teleporter.inc"
.INCLUDE "flag.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "newgame.inc"
.INCLUDE "room.inc"
.INCLUDE "spawn.inc"

.IMPORT Func_SetFlag
.IMPORT Sram_LastSafe_bSpawn
.IMPORT Sram_LastSafe_eRoom
.IMPORT Sram_MagicNumber_u8
.IMPORT Sram_Minimap_u16_arr
.IMPORT __SRAM_SIZE__
.IMPORT __SRAM_START__

;;;=========================================================================;;;

.SEGMENT "PRGA_Title"

;;; Erases all of SRAM and creates a save file for a new game.
;;; @param Y The eNewGame value to use to initialize the save file.
.EXPORT FuncA_Title_ResetSramForNewGame
.PROC FuncA_Title_ResetSramForNewGame
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Zero all of SRAM.
    lda #0
    tax
    @loop:
    .assert $20 * $100 = __SRAM_SIZE__, error
    .repeat $20, index
    sta __SRAM_START__ + $100 * index, x
    .endrepeat
    inx
    bne @loop
    ;; TODO: For testing, reveal whole minimap (remove this later).
.IF 0
    lda #$ff
    ldx #0
    @minimapLoop:
    sta Sram_Minimap_u16_arr, x
    inx
    cpx #$30
    blt @minimapLoop
.ENDIF
    ;; Set starting location.
    lda DataA_Title_NewGameStarting_eRoom_arr, y
    sta Sram_LastSafe_eRoom
    lda DataA_Title_NewGameStarting_bSpawn_arr, y
    sta Sram_LastSafe_bSpawn
    ;; Mark the save file as present.
    lda #kSaveMagicNumber
    sta Sram_MagicNumber_u8
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
_SetFlags:
    ;; Set flags based on the eNewGame value.
    lda DataA_Title_NewGameFirstMissing_eFlag_arr, y
    sta T1  ; first missing eFlag
    ldy #0
    beq @start  ; unconditional
    @loop:
    sty T0  ; index into DataA_Title_NewGameFlags_eFlag_arr
    jsr Func_SetFlag  ; preserves T0+
    ldy T0  ; index into DataA_Title_NewGameFlags_eFlag_arr
    iny
    @start:
    ldx DataA_Title_NewGameFlags_eFlag_arr, y
    cpx T1  ; first missing eFlag
    bne @loop
    rts
.ENDPROC

;;; Maps from eNewGame values to 8-byte name strings.
.EXPORT DataA_Title_NewGameName_u8_arr8_arr
.PROC DataA_Title_NewGameName_u8_arr8_arr
    D_ARRAY .enum, eNewGame, 8
    d_byte Town,     "  TOWN  "
    d_byte Prison,   " PRISON "
    d_byte Tower,    " GARDEN "
    d_byte Breaker1, "BREAKER1"
    d_byte Spire,    " TEMPLE "
    d_byte Breaker2, "BREAKER2"
    d_byte Rescue,   " RESCUE "
    d_byte Nave,     "  NAVE  "
    d_byte Tomb,     "  TOMB  "
    d_byte Breaker3, "BREAKER3"
    d_byte Spring,   " SPRING "
    d_byte Volcanic, "VOLCANIC"
    d_byte Breaker4, "BREAKER4"
    d_byte Collapse, "  MINE  "
    d_byte Breaker5, "BREAKER5"
    d_byte Sinkhole, "SINKHOLE"
    d_byte Breaker6, "BREAKER6"
    d_byte Shadow,   " SHADOW "
    d_byte Depths,   " DEPTHS "
    d_byte Breaker7, "BREAKER7"
    d_byte Core,     "  CORE  "
    D_END
.ENDPROC

;;; Maps from eNewGame values to the starting room.
.PROC DataA_Title_NewGameStarting_eRoom_arr
    D_ARRAY .enum, eNewGame
    d_byte Town,     eRoom::TownHouse2
    d_byte Prison,   eRoom::PrisonCell
    d_byte Tower,    eRoom::GardenTower
    d_byte Breaker1, eRoom::BossGarden
    d_byte Spire,    eRoom::TempleSpire
    d_byte Breaker2, eRoom::BossTemple
    d_byte Rescue,   eRoom::PrisonEast
    d_byte Nave,     eRoom::TempleNave
    d_byte Tomb,     eRoom::CryptTomb
    d_byte Breaker3, eRoom::BossCrypt
    d_byte Spring,   eRoom::MermaidSpring
    d_byte Volcanic, eRoom::BossLava  ; TODO start just outside
    d_byte Breaker4, eRoom::BossLava
    d_byte Collapse, eRoom::MineCollapse
    d_byte Breaker5, eRoom::BossMine
    d_byte Sinkhole, eRoom::CitySinkhole
    d_byte Breaker6, eRoom::BossCity
    d_byte Shadow,   eRoom::ShadowTeleport
    d_byte Depths,   eRoom::ShadowDepths
    d_byte Breaker7, eRoom::BossShadow
    d_byte Core,     eRoom::CoreLock
    D_END
.ENDPROC

;;; Maps from eNewGame values to the starting spawn location.
.PROC DataA_Title_NewGameStarting_bSpawn_arr
    D_ARRAY .enum, eNewGame
    d_byte Town,     bSpawn::Device | 0
    d_byte Prison,   bSpawn::Device | 0
    d_byte Tower,    bSpawn::Device | 3  ; TODO: use a constant
    d_byte Breaker1, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Spire,    bSpawn::Device | 0  ; TODO: use a constant
    d_byte Breaker2, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Rescue,   bSpawn::Passage | 1
    d_byte Nave,     bSpawn::Passage | 3
    d_byte Tomb,     bSpawn::Device | 3  ; TODO: use a constant
    d_byte Breaker3, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Spring,   bSpawn::Passage | 0
    d_byte Volcanic, bSpawn::Device | kBossDoorDeviceIndex  ; TODO
    d_byte Breaker4, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Collapse, bSpawn::Device | 2  ; TODO: use a constant
    d_byte Breaker5, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Sinkhole, bSpawn::Device | 0  ; TODO: use a constant
    d_byte Breaker6, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Shadow,   bSpawn::Device | kTeleporterDeviceIndex
    d_byte Depths,   bSpawn::Device | 0  ; TODO: use a constant
    d_byte Breaker7, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Core,     bSpawn::Passage | 1
    D_END
.ENDPROC

;;; Maps from eNewGame values to the first flag to *not* start with.
.PROC DataA_Title_NewGameFirstMissing_eFlag_arr
    D_ARRAY .enum, eNewGame
    d_byte Town,     eFlag::PaperJerome36
    d_byte Prison,   eFlag::PaperJerome36
    d_byte Tower,    eFlag::BossGarden
    d_byte Breaker1, eFlag::BreakerGarden
    d_byte Spire,    eFlag::BossTemple
    d_byte Breaker2, eFlag::BreakerTemple
    d_byte Rescue,   eFlag::PrisonEastEastGateOpen
    d_byte Nave,     eFlag::TempleNaveTalkedToAlex
    d_byte Tomb,     eFlag::BossCrypt
    d_byte Breaker3, eFlag::BreakerCrypt
    d_byte Spring,   eFlag::MermaidSpringConsoleFixed
    d_byte Volcanic, eFlag::BossLava
    d_byte Breaker4, eFlag::BreakerLava
    d_byte Collapse, eFlag::BossMine
    d_byte Breaker5, eFlag::BreakerMine
    d_byte Sinkhole, eFlag::BossCity
    d_byte Breaker6, eFlag::BreakerCity
    d_byte Shadow,   eFlag::PaperJerome01
    d_byte Depths,   eFlag::BossShadow
    d_byte Breaker7, eFlag::BreakerShadow
    d_byte Core,     eFlag::None
    D_END
.ENDPROC

;;; A list of all flags that can potentially be set when starting a new game,
;;; in collection order.
.PROC DataA_Title_NewGameFlags_eFlag_arr
    .byte eFlag::PaperJerome36
    .byte eFlag::PaperManual2
    .byte eFlag::PrisonCellReachedTunnel
    .byte eFlag::PrisonCellBlastedRocks
    .byte eFlag::GardenLandingDroppedIn
    .byte eFlag::PaperJerome13
    .byte eFlag::UpgradeOpIf
    .byte eFlag::PaperJerome12
    .byte eFlag::GardenEastTalkedToCorra
    .byte eFlag::MermaidHut1MetQueen
    .byte eFlag::MermaidHut4MetFlorist
    .byte eFlag::GardenTowerCratesPlaced
    .byte eFlag::FlowerMermaid
    .byte eFlag::PaperManual5
    .byte eFlag::GardenTowerWallBroken
    .byte eFlag::BossGarden
    .byte eFlag::UpgradeRam1
    .byte eFlag::BreakerGarden
    .byte eFlag::TempleEntryPermission
    .byte eFlag::TempleEntryColumnRaised
    .byte eFlag::PaperManual1
    .byte eFlag::UpgradeOpTil
    .byte eFlag::TempleAltarColumnBroken
    .byte eFlag::PaperJerome28
    .byte eFlag::BossTemple
    .byte eFlag::UpgradeRam2
    .byte eFlag::BreakerTemple
    .byte eFlag::FlowerTemple
    .byte eFlag::FlowerFactory
    .byte eFlag::CoreSouthCorraWaiting
    .byte eFlag::PaperManual4
    .byte eFlag::CoreSouthCorraHelped
    .byte eFlag::PrisonEastEastGateOpen
    .byte eFlag::PrisonEastLowerGateShut
    .byte eFlag::PrisonEastOrcTrapped
    .byte eFlag::PrisonEastWestGateOpen
    .byte eFlag::PrisonUpperFoundAlex
    .byte eFlag::PrisonUpperFreedAlex
    .byte eFlag::PrisonUpperGateOpen
    .byte eFlag::PrisonUpperFreedKids
    .byte eFlag::PrisonCellGateOpen
    .byte eFlag::FlowerPrison
    .byte eFlag::MermaidHut1AlexPetition
    .byte eFlag::FlowerCore
    .byte eFlag::TempleNaveAlexWaiting
    .byte eFlag::TempleNaveTalkedToAlex
    .byte eFlag::PaperJerome34
    .byte eFlag::CryptLandingDroppedIn
    .byte eFlag::PaperJerome08
    .byte eFlag::PaperJerome11
    .byte eFlag::UpgradeOpGoto
    .byte eFlag::CryptSouthBrokeFloor
    .byte eFlag::CryptTombBrokeFloors
    .byte eFlag::BossCrypt
    .byte eFlag::UpgradeOpRest
    .byte eFlag::BreakerCrypt
    .byte eFlag::PaperJerome21
    .byte eFlag::TempleEntryTalkedToCorra
    .byte eFlag::FlowerCrypt
    .byte eFlag::CityOutskirtsTalkedToAlex
    .byte eFlag::UpgradeOpSkip
    .byte eFlag::PaperJerome14
    .byte eFlag::FlowerGarden
    .byte eFlag::MermaidSpringConsoleFixed
    .byte eFlag::MermaidSpringUnplugged
    .byte eFlag::UpgradeOpCopy
    .byte eFlag::PaperManual3
    .byte eFlag::PaperJerome10
    .byte eFlag::LavaCenterChain3Broken
    .byte eFlag::LavaCenterChain1Broken
    .byte eFlag::LavaCenterChain2Broken
    .byte eFlag::BossLava
    .byte eFlag::UpgradeRam3
    .byte eFlag::BreakerLava
    .byte eFlag::UpgradeOpSync
    .byte eFlag::PaperJerome09
    .byte eFlag::BossMine
    .byte eFlag::UpgradeRam4
    .byte eFlag::BreakerMine
    .byte eFlag::UpgradeOpAddSub
    .byte eFlag::FactoryPassLoweredRocks
    .byte eFlag::PaperJerome23
    .byte eFlag::FlowerMine
    .byte eFlag::FactoryVaultTalkedToAlex
    .byte eFlag::FlowerLava
    .byte eFlag::FlowerSewer
    .byte eFlag::CityOutskirtsBlastedRocks
    .byte eFlag::CityCenterKeygenConnected
    .byte eFlag::PaperJerome35
    .byte eFlag::FlowerCity
    .byte eFlag::CityBuilding3BlastedCrates
    .byte eFlag::CityCenterDoorUnlocked
    .byte eFlag::BossCity
    .byte eFlag::UpgradeBRemote
    .byte eFlag::BreakerCity
    .byte eFlag::PaperJerome01
    .byte eFlag::ShadowTrapDisarmed
    .byte eFlag::BossShadow
    .byte eFlag::UpgradeOpMul
    .byte eFlag::BreakerShadow
    .byte eFlag::FlowerShadow
    .byte eFlag::MermaidHut4OpenedCellar
    .byte eFlag::UpgradeOpBeep
    .byte eFlag::None
.ENDPROC

;;;=========================================================================;;;
