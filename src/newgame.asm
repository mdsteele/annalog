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
.INCLUDE "rooms/city_sinkhole.inc"
.INCLUDE "rooms/crypt_tomb.inc"
.INCLUDE "rooms/garden_tower.inc"
.INCLUDE "rooms/lava_cavern.inc"
.INCLUDE "rooms/mine_burrow.inc"
.INCLUDE "rooms/shadow_depths.inc"
.INCLUDE "rooms/temple_spire.inc"
.INCLUDE "spawn.inc"

.IMPORT FuncA_Avatar_LoadProgress
.IMPORT Func_SaveProgress
.IMPORT Func_SetFlag
.IMPORT Ram_Minimap_u16_arr
.IMPORT Sram_LastSafe_bSpawn
.IMPORT Sram_LastSafe_eRoom
.IMPORT Sram_MagicNumber_u8
.IMPORT __SRAM_SIZE__
.IMPORT __SRAM_START__

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; Maps from eNewGame values to 8-byte name strings.
.EXPORT DataC_Title_NewGameName_u8_arr8_arr
.PROC DataC_Title_NewGameName_u8_arr8_arr
    D_ARRAY .enum, eNewGame, 8
    d_byte Town,     "TOWN    "
    d_byte Prison,   "PRISON  "
    d_byte Tower,    "TOWER   "
    d_byte Breaker1, "BREAKER1"
    d_byte Spire,    "SPIRE   "
    d_byte Breaker2, "BREAKER2"
    d_byte Rescue,   "RESCUE  "
    d_byte Petition, "PETITION"
    d_byte Nave,     "NAVE    "
    d_byte Tomb,     "TOMB    "
    d_byte Breaker3, "BREAKER3"
    d_byte Spring,   "SPRING  "
    d_byte Cavern,   "CAVERN  "
    d_byte Breaker4, "BREAKER4"
    d_byte Mine,     "MINE    "
    d_byte Burrow,   "BURROW  "
    d_byte Breaker5, "BREAKER5"
    d_byte Pass,     "PASS    "
    d_byte City,     "CITY    "
    d_byte Sinkhole, "SINKHOLE"
    d_byte Breaker6, "BREAKER6"
    d_byte Shadow,   "SHADOW  "
    d_byte Office,   "OFFICE  "
    d_byte Depths,   "DEPTHS  "
    d_byte Breaker7, "BREAKER7"
    d_byte Core,     "CORE    "
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Erases all of SRAM and creates a save file for a new game.
;;; @param Y The eNewGame value to use to initialize the save file.
.EXPORT FuncA_Avatar_ResetSramForNewGame
.PROC FuncA_Avatar_ResetSramForNewGame
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
    ;; Set starting location.
    lda DataA_Avatar_NewGameStarting_eRoom_arr, y
    sta Sram_LastSafe_eRoom
    lda DataA_Avatar_NewGameStarting_bSpawn_arr, y
    sta Sram_LastSafe_bSpawn
    ;; Mark the save file as present.
    lda #kSaveMagicNumber
    sta Sram_MagicNumber_u8
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
_Load:
    jsr FuncA_Avatar_LoadProgress  ; preserves Y
_RevealMinimap:
    ;; Change this to ".if 1" to reveal whole minimap.
    .if 0
    lda #$ff
    ldx #$30 - 1
    @loop:
    sta Ram_Minimap_u16_arr, x
    dex
    bpl @loop
    .endif
_SetFlags:
    ;; Set flags based on the eNewGame value.
    lda DataA_Avatar_NewGameFirstMissing_eFlag_arr, y
    sta T1  ; first missing eFlag
    ldy #0
    beq @start  ; unconditional
    @loop:
    sty T0  ; index into DataA_Avatar_NewGameFlags_eFlag_arr
    jsr Func_SetFlag  ; preserves T0+
    ldy T0  ; index into DataA_Avatar_NewGameFlags_eFlag_arr
    iny
    @start:
    ldx DataA_Avatar_NewGameFlags_eFlag_arr, y
    cpx T1  ; first missing eFlag
    bne @loop
_Save:
    jmp Func_SaveProgress
.ENDPROC

;;; Maps from eNewGame values to the starting room.
.PROC DataA_Avatar_NewGameStarting_eRoom_arr
    D_ARRAY .enum, eNewGame
    d_byte Town,     eRoom::TownHouse2
    d_byte Prison,   eRoom::PrisonCell
    d_byte Tower,    eRoom::GardenTower
    d_byte Breaker1, eRoom::BossGarden
    d_byte Spire,    eRoom::TempleSpire
    d_byte Breaker2, eRoom::BossTemple
    d_byte Rescue,   eRoom::PrisonEast
    d_byte Petition, eRoom::MermaidVillage
    d_byte Nave,     eRoom::TempleNave
    d_byte Tomb,     eRoom::CryptTomb
    d_byte Breaker3, eRoom::BossCrypt
    d_byte Spring,   eRoom::MermaidSpring
    d_byte Cavern,   eRoom::LavaCavern
    d_byte Breaker4, eRoom::BossLava
    d_byte Mine,     eRoom::MineEntry
    d_byte Burrow,   eRoom::MineBurrow
    d_byte Breaker5, eRoom::BossMine
    d_byte Pass,     eRoom::FactoryPass
    d_byte City,     eRoom::CityCenter
    d_byte Sinkhole, eRoom::CitySinkhole
    d_byte Breaker6, eRoom::BossCity
    d_byte Shadow,   eRoom::ShadowTeleport
    d_byte Office,   eRoom::ShadowOffice
    d_byte Depths,   eRoom::ShadowDepths
    d_byte Breaker7, eRoom::BossShadow
    d_byte Core,     eRoom::CoreLock
    D_END
.ENDPROC

;;; Maps from eNewGame values to the starting spawn location.
.PROC DataA_Avatar_NewGameStarting_bSpawn_arr
    D_ARRAY .enum, eNewGame
    d_byte Town,     bSpawn::Device | 0
    d_byte Prison,   bSpawn::Device | 0
    d_byte Tower,    bSpawn::Device | kGardenTowerDoorDeviceIndex
    d_byte Breaker1, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Spire,    bSpawn::Device | kTempleSpireDoorDeviceIndex
    d_byte Breaker2, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Rescue,   bSpawn::Passage | 1
    d_byte Petition, bSpawn::Device | 0
    d_byte Nave,     bSpawn::Passage | 3
    d_byte Tomb,     bSpawn::Device | kCryptTombDoorDeviceIndex
    d_byte Breaker3, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Spring,   bSpawn::Passage | 0
    d_byte Cavern,   bSpawn::Device | kLavaCavernDoorDeviceIndex
    d_byte Breaker4, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Mine,     bSpawn::Passage | 0
    d_byte Burrow,   bSpawn::Device | kMineBurrowDoorDeviceIndex
    d_byte Breaker5, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Pass,     bSpawn::Passage | 1
    d_byte City,     bSpawn::Passage | 1
    d_byte Sinkhole, bSpawn::Device | kCitySinkholeDoorDeviceIndex
    d_byte Breaker6, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Shadow,   bSpawn::Device | kTeleporterDeviceIndex
    d_byte Office,   bSpawn::Passage | 0
    d_byte Depths,   bSpawn::Device | kShadowDepthsDoorDeviceIndex
    d_byte Breaker7, bSpawn::Device | kBossDoorDeviceIndex
    d_byte Core,     bSpawn::Passage | 1
    D_END
.ENDPROC

;;; Maps from eNewGame values to the first flag to *not* start with.
.PROC DataA_Avatar_NewGameFirstMissing_eFlag_arr
    D_ARRAY .enum, eNewGame
    d_byte Town,     eFlag::PaperJerome36
    d_byte Prison,   eFlag::PaperJerome36
    d_byte Tower,    eFlag::BossGarden
    d_byte Breaker1, eFlag::BreakerGarden
    d_byte Spire,    eFlag::BossTemple
    d_byte Breaker2, eFlag::BreakerTemple
    d_byte Rescue,   eFlag::PrisonEastEastGateOpen
    d_byte Petition, eFlag::MermaidHut1AlexPetition
    d_byte Nave,     eFlag::TempleNaveTalkedToAlex
    d_byte Tomb,     eFlag::BossCrypt
    d_byte Breaker3, eFlag::BreakerCrypt
    d_byte Spring,   eFlag::MermaidSpringConsoleFixed
    d_byte Cavern,   eFlag::BossLava
    d_byte Breaker4, eFlag::BreakerLava
    d_byte Mine,     eFlag::UpgradeOpSync
    d_byte Burrow,   eFlag::BossMine
    d_byte Breaker5, eFlag::BreakerMine
    d_byte Pass,     eFlag::FactoryPassLoweredRocks
    d_byte City,     eFlag::CityCenterEnteredCity
    d_byte Sinkhole, eFlag::BossCity
    d_byte Breaker6, eFlag::BreakerCity
    d_byte Shadow,   eFlag::PaperJerome01
    d_byte Office,   eFlag::ShadowTrapDisarmed
    d_byte Depths,   eFlag::BossShadow
    d_byte Breaker7, eFlag::BreakerShadow
    d_byte Core,     eFlag::None
    D_END
.ENDPROC

;;; A list of all flags that can potentially be set when starting a new game,
;;; in collection order.
.PROC DataA_Avatar_NewGameFlags_eFlag_arr
    .byte eFlag::PaperJerome36  ; room: PrisonCell
    .byte eFlag::PaperManual2   ; room: PrisonEscape
    .byte eFlag::PrisonCellReachedTunnel
    .byte eFlag::PrisonCellBlastedRocks
    .byte eFlag::GardenLandingDroppedIn
    .byte eFlag::PaperJerome13  ; room: GardenLanding
    .byte eFlag::UpgradeOpIf
    .byte eFlag::PaperManual3   ; room: GardenCrossroad
    .byte eFlag::PaperJerome12  ; room: GardenHallway
    .byte eFlag::GardenEastTalkedToCorra
    .byte eFlag::MermaidHut1MetQueen
    .byte eFlag::MermaidHut4MetFlorist
    .byte eFlag::GardenTowerCratesPlaced
    .byte eFlag::FlowerMermaid
    .byte eFlag::PaperManual6   ; room: GardenShaft
    .byte eFlag::GardenTowerWallBroken
    .byte eFlag::BossGarden
    .byte eFlag::UpgradeRam1
    .byte eFlag::BreakerGarden
    .byte eFlag::TempleEntryPermission
    .byte eFlag::TempleEntryColumnRaised
    .byte eFlag::PaperManual1   ; room: TempleFoyer
    .byte eFlag::UpgradeOpTil
    .byte eFlag::TempleAltarColumnBroken
    .byte eFlag::PaperJerome28  ; room: TempleChevet
    .byte eFlag::PaperManual9   ; room: TempleApse
    .byte eFlag::BossTemple
    .byte eFlag::UpgradeRam2
    .byte eFlag::BreakerTemple
    .byte eFlag::FlowerTemple
    .byte eFlag::PaperJerome29  ; room: MermaidElevator
    .byte eFlag::PaperJerome07  ; room: FactoryBridge
    .byte eFlag::FlowerFactory
    .byte eFlag::PaperManual5   ; room: FactoryUpper
    .byte eFlag::CoreSouthCorraWaiting
    .byte eFlag::PaperJerome18  ; room: FactoryWest
    .byte eFlag::CoreSouthCorraHelped
    .byte eFlag::PrisonEastEastGateOpen
    .byte eFlag::PaperJerome15  ; room: PrisonLower
    .byte eFlag::PrisonEastOrcTrapped
    .byte eFlag::PrisonEastWestGateOpen
    .byte eFlag::PrisonCellGateOpen
    .byte eFlag::PrisonUpperFoundAlex
    .byte eFlag::PrisonUpperLoosenedBrick
    .byte eFlag::PrisonUpperFreedAlex
    .byte eFlag::PrisonUpperGateOpen
    .byte eFlag::PrisonUpperFreedKids
    .byte eFlag::PrisonEastLowerGateOpen
    .byte eFlag::FlowerPrison
    .byte eFlag::MermaidHut1AlexPetition
    .byte eFlag::PaperJerome31  ; room: CoreFlower
    .byte eFlag::FlowerCore
    .byte eFlag::TempleNaveAlexWaiting
    .byte eFlag::TempleNaveTalkedToAlex
    .byte eFlag::PaperJerome34  ; room: TemplePit
    .byte eFlag::CryptLandingDroppedIn
    .byte eFlag::PaperJerome08  ; room: CryptCenter
    .byte eFlag::PaperJerome11  ; room: CryptSpiral
    .byte eFlag::UpgradeOpGoto
    .byte eFlag::CryptSouthBrokeFloor
    .byte eFlag::CryptTombBrokeFloors
    .byte eFlag::BossCrypt
    .byte eFlag::UpgradeOpRest
    .byte eFlag::BreakerCrypt
    .byte eFlag::PaperJerome21  ; room: CryptEscape
    .byte eFlag::TempleEntryTalkedToCorra
    .byte eFlag::FlowerCrypt
    .byte eFlag::PaperManual7   ; room: CoreElevator
    .byte eFlag::CityOutskirtsTalkedToAlex
    .byte eFlag::UpgradeOpSkip
    .byte eFlag::PaperJerome14  ; room: GardenFlower
    .byte eFlag::FlowerGarden
    .byte eFlag::MermaidSpringConsoleFixed
    .byte eFlag::MermaidSpringUnplugged
    .byte eFlag::LavaWestDroppedIn
    .byte eFlag::UpgradeOpCopy
    .byte eFlag::PaperManual4   ; room: LavaStation
    .byte eFlag::PaperJerome10  ; room: LavaWest
    .byte eFlag::LavaCenterChain3Broken
    .byte eFlag::LavaCenterChain1Broken
    .byte eFlag::LavaCenterChain2Broken
    .byte eFlag::PaperJerome27  ; room: LavaTunnel
    .byte eFlag::BossLava
    .byte eFlag::UpgradeRam3
    .byte eFlag::BreakerLava
    .byte eFlag::UpgradeOpSync
    .byte eFlag::PaperJerome09  ; room: MineFlower
    .byte eFlag::PaperJerome26  ; room: MineEast
    .byte eFlag::PaperJerome25  ; room: MineNorth
    .byte eFlag::BossMine
    .byte eFlag::UpgradeRam4
    .byte eFlag::BreakerMine
    .byte eFlag::PaperJerome19  ; room: SewerBasin
    .byte eFlag::UpgradeOpAddSub
    .byte eFlag::FactoryPassLoweredRocks
    .byte eFlag::FactoryElevatorTalkedToBruno
    .byte eFlag::PaperJerome23  ; room: CoreLock
    .byte eFlag::FlowerMine
    .byte eFlag::FactoryVaultTalkedToAlex
    .byte eFlag::FactoryEastCorraHelped
    .byte eFlag::SewerFaucetEnteredUpperSewer
    .byte eFlag::FlowerLava
    .byte eFlag::PaperJerome05  ; room: SewerWest
    .byte eFlag::PaperJerome03  ; room: SewerPipe
    .byte eFlag::PaperJerome22  ; room: SewerFlower
    .byte eFlag::FlowerSewer
    .byte eFlag::CityCenterEnteredCity
    .byte eFlag::PaperJerome16  ; room: CityBuilding6
    .byte eFlag::PaperJerome17  ; room: CityBuilding4
    .byte eFlag::PaperJerome24  ; room: CityBuilding1
    .byte eFlag::CityOutskirtsBlastedRocks
    .byte eFlag::CityCenterKeygenConnected
    .byte eFlag::PaperJerome35  ; room: CityDump
    .byte eFlag::PaperJerome33  ; room: CityDrain
    .byte eFlag::FlowerCity
    .byte eFlag::CityBuilding3BlastedCrates
    .byte eFlag::PaperManual8   ; room: CityBuilding3
    .byte eFlag::CityCenterDoorUnlocked
    .byte eFlag::PaperJerome30  ; room: CityBuilding5
    .byte eFlag::BossCity
    .byte eFlag::UpgradeBRemote
    .byte eFlag::BreakerCity
    .byte eFlag::CityCenterTalkedToAlex
    .byte eFlag::ShadowTeleportEnteredLab
    .byte eFlag::PaperJerome01  ; room: ShadowEntry
    .byte eFlag::ShadowHallInitialized
    .byte eFlag::ShadowHallGlassBroken
    .byte eFlag::PaperJerome02  ; room: ShadowHall
    .byte eFlag::ShadowDrillClearedGoo
    .byte eFlag::ShadowTrapDisarmed
    .byte eFlag::PaperJerome04  ; room: ShadowHeart
    .byte eFlag::ShadowHeartTaggedGhost
    .byte eFlag::PaperJerome06  ; room: ShadowOffice
    .byte eFlag::ShadowOfficeRemovedWall
    .byte eFlag::ShadowOfficeTaggedGhost
    .byte eFlag::PaperJerome20  ; room: ShadowDescent
    .byte eFlag::PaperJerome32  ; room: ShadowDepths
    .byte eFlag::BossShadow
    .byte eFlag::UpgradeOpMul
    .byte eFlag::BreakerShadow
    .byte eFlag::FlowerShadow
    .byte eFlag::MermaidHut4OpenedCellar
    .byte eFlag::UpgradeOpBeep
    .byte eFlag::None
.ENDPROC

;;;=========================================================================;;;
