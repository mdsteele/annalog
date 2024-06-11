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

;;; When Sram_MagicNumber_u8 is set to this, the save file exists.  Otherwise,
;;; the save file is considered empty.  This value is chosen such that an SRAM
;;; chip initialized to all zeros ($00), all ones ($ff), or even random-ish-ly
;;; is unlikely to initialize Sram_MagicNumber_u8 to this value.
kSaveMagicNumber = $b2

;;; How many upgrades there are that increase the maximum number of program
;;; instructions.
.DEFINE kNumRamUpgrades 4

;;; How many extra program instructions are permitted per UpgradeRam* upgrade.
.DEFINE kNumExtraInstructionsPerRamUpgrade 2

;;;=========================================================================;;;

;;; Circuit breakers that can be activated throughout the game.
.ENUM eBreaker
    Garden
    Temple
    Crypt
    Lava
    Mine
    City
    Shadow
    NUM_VALUES
.ENDENUM

;;; Progress flags for the save file, each of which can be cleared or set.
;;; These represent things like "has this upgrade been acquired?" or "has this
;;; boss been defeated?" or "is this switch turned on?"
.ENUM eFlag
    None  ; null flag, never set
    ;; Each of these flags is set when that upgrade has been collected:
    UpgradeRam1
    UpgradeRam2
    UpgradeRam3
    UpgradeRam4
    UpgradeBRemote
    UpgradeOpIf
    UpgradeOpTil
    UpgradeOpCopy
    UpgradeOpAddSub
    UpgradeOpMul
    UpgradeOpBeep
    UpgradeOpGoto
    UpgradeOpSkip
    UpgradeOpRest
    UpgradeOpSync
    ;; Each of these flags is set when that flower is delivered to the florist:
    FlowerTemple
    FlowerPrison
    FlowerCore
    FlowerFactory
    FlowerSewer
    FlowerCity
    FlowerCrypt
    FlowerShadow
    FlowerGarden
    FlowerMermaid
    FlowerLava
    FlowerMine
    ;; Each of these flags is set when that boss has been defeated:
    BossGarden
    BossTemple
    BossCrypt
    BossLava
    BossMine
    BossCity
    BossShadow
    ;; Each of these flags is set when that circuit breaker has been activated:
    BreakerGarden
    BreakerTemple
    BreakerCrypt
    BreakerLava
    BreakerMine
    BreakerCity
    BreakerShadow
    ;; Each of these flags is set when that paper has been collected:
    PaperJerome01
    PaperJerome02
    PaperJerome03
    PaperJerome04
    PaperJerome05
    PaperJerome06
    PaperJerome07
    PaperJerome08
    PaperJerome09
    PaperJerome10
    PaperJerome11
    PaperJerome12
    PaperJerome13
    PaperJerome14
    PaperJerome15
    PaperJerome16
    PaperJerome17
    PaperJerome18
    PaperJerome19
    PaperJerome20
    PaperJerome21
    PaperJerome22
    PaperJerome23
    PaperJerome24
    PaperJerome25
    PaperJerome26
    PaperJerome27
    PaperJerome28
    PaperJerome29
    PaperJerome30
    PaperJerome31
    PaperJerome32
    PaperJerome33
    PaperJerome34
    PaperJerome35
    PaperJerome36
    PaperManual1
    PaperManual2
    PaperManual3
    PaperManual4
    PaperManual5
    PaperManual6
    PaperManual7
    PaperManual8
    PaperManual9
    ;; Flags for persistent room state:
    CityBuilding3BlastedCrates
    CityCenterDoorUnlocked
    CityCenterKeygenConnected
    CityOutskirtsBlastedRocks
    CityOutskirtsTalkedToAlex
    CoreSouthCorraHelped
    CoreSouthCorraWaiting
    CryptLandingDroppedIn
    CryptSouthBrokeFloor
    CryptTombBrokeFloors
    FactoryPassLoweredRocks
    FactoryVaultTalkedToAlex
    GardenEastTalkedToCorra
    GardenLandingDroppedIn
    GardenTowerCratesPlaced
    GardenTowerWallBroken
    LavaCenterChain1Broken
    LavaCenterChain2Broken
    LavaCenterChain3Broken
    MermaidHut1AlexPetition
    MermaidHut1MetQueen
    MermaidHut4MetFlorist
    MermaidHut4OpenedCellar
    MermaidSpringConsoleFixed
    MermaidSpringUnplugged
    PrisonCellBlastedRocks
    PrisonCellGateOpen
    PrisonCellReachedTunnel
    PrisonEastEastGateOpen
    PrisonEastLowerGateShut
    PrisonEastOrcTrapped
    PrisonEastWestGateOpen
    PrisonUpperFoundAlex
    PrisonUpperFreedAlex
    PrisonUpperFreedKids
    PrisonUpperGateOpen
    PrisonUpperLoosenedBrick
    ShadowHallGlassBroken
    ShadowHallInitialized
    ShadowTrapDisarmed
    TempleAltarColumnBroken
    TempleEntryColumnRaised
    TempleEntryPermission
    TempleEntryTalkedToCorra
    TempleNaveAlexWaiting
    TempleNaveTalkedToAlex
    ;; TODO: Sort the below within the above once it won't disrupt playtesting.
    FactoryEastCorraHelped
    FactoryElevatorTalkedToBruno
    CityCenterEnteredCity
    ShadowHeartTaggedGhost
    ShadowOfficeRemovedWall
    ShadowOfficeTaggedGhost
    NUM_VALUES
.ENDENUM
.ASSERT eFlag::NUM_VALUES <= $100, error

;;;=========================================================================;;;

kFirstUpgradeFlag = eFlag::UpgradeRam1
kLastUpgradeFlag = eFlag::UpgradeOpSync
kNumUpgradeFlags = 15
.ASSERT kNumUpgradeFlags = kLastUpgradeFlag + 1 - kFirstUpgradeFlag, error

kFirstRamUpgradeFlag = eFlag::UpgradeRam1
kLastRamUpgradeFlag = eFlag::UpgradeRam4
.ASSERT kNumRamUpgrades = kLastRamUpgradeFlag + 1 - kFirstRamUpgradeFlag, error

;;; Check that the eFlag::Breaker* values line up one-to-one with eBreaker
;;; values.
kFirstBreakerFlag = eFlag::BreakerGarden
kLastBreakerFlag = eFlag::BreakerShadow
kNumBreakerFlags = eBreaker::NUM_VALUES
.ASSERT kNumBreakerFlags = kLastBreakerFlag + 1 - kFirstBreakerFlag, error
.ASSERT eFlag::BreakerGarden - kFirstBreakerFlag = eBreaker::Garden, error
.ASSERT eFlag::BreakerTemple - kFirstBreakerFlag = eBreaker::Temple, error
.ASSERT eFlag::BreakerCrypt - kFirstBreakerFlag = eBreaker::Crypt, error
.ASSERT eFlag::BreakerLava - kFirstBreakerFlag = eBreaker::Lava, error
.ASSERT eFlag::BreakerMine - kFirstBreakerFlag = eBreaker::Mine, error
.ASSERT eFlag::BreakerCity - kFirstBreakerFlag = eBreaker::City, error
.ASSERT eFlag::BreakerShadow - kFirstBreakerFlag = eBreaker::Shadow, error

;;; Check that the eFlag::Boss* values also line up one-to-one with eBreaker
;;; values.
kFirstBossFlag = eFlag::BossGarden
.ASSERT eFlag::BossGarden - kFirstBossFlag = eBreaker::Garden, error
.ASSERT eFlag::BossTemple - kFirstBossFlag = eBreaker::Temple, error
.ASSERT eFlag::BossCrypt - kFirstBossFlag = eBreaker::Crypt, error
.ASSERT eFlag::BossLava - kFirstBossFlag = eBreaker::Lava, error
.ASSERT eFlag::BossMine - kFirstBossFlag = eBreaker::Mine, error
.ASSERT eFlag::BossCity - kFirstBossFlag = eBreaker::City, error
.ASSERT eFlag::BossShadow - kFirstBossFlag = eBreaker::Shadow, error

kFirstFlowerFlag = eFlag::FlowerTemple
kLastFlowerFlag = eFlag::FlowerMine
kNumFlowerFlags = 12
.ASSERT kNumFlowerFlags = kLastFlowerFlag + 1 - kFirstFlowerFlag, error

kFirstPaperFlag = eFlag::PaperJerome01
kLastPaperFlag = eFlag::PaperManual9
kNumPaperFlags = 45
.ASSERT kNumPaperFlags = kLastPaperFlag + 1 - kFirstPaperFlag, error

;;;=========================================================================;;;
