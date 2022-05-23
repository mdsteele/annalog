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
.DEFINE kNumMaxInstructionUpgrades 4

;;; How many extra program instructions are permitted per max-instructions
;;; upgrade.
.DEFINE kNumExtraInstructionsPerUpgrade 2

;;;=========================================================================;;;

;;; Progress flags for the save file, each of which can be cleared or set.
;;; These represent things like "has this upgrade been acquired?" or "has this
;;; boss been defeated?" or "is this switch turned on?"
.ENUM eFlag
    ;; Each of these flags is set when that upgrade has been collected:
    UpgradeMaxInstructions0  ; Each of these four upgrades
    UpgradeMaxInstructions1  ; increases the maximum number
    UpgradeMaxInstructions2  ; of instructions in a program
    UpgradeMaxInstructions3  ; by kNumExtraInstructionsPerUpgrade.
    UpgradeOpcodeCopy
    UpgradeOpcodeSwap
    UpgradeOpcodeAddSub
    UpgradeOpcodeMul
    UpgradeOpcodeIfGoto
    UpgradeOpcodeSkip
    UpgradeOpcodeTil
    UpgradeOpcodeBeep
    UpgradeRegisterB
    ;; Each of these flags is set when that boss has been defeated:
    BossGarden
    BossCrypt
    BossLava
    BossMine
    BossCity
    BossLab
    BossCore
    ;; Each of these flags is set when that power conduit has been activated:
    ConduitGarden
    ConduitCrypt
    ConduitLava
    ConduitMine
    ConduitCity
    ConduitLab
    ;; Each of these flags is set when that flower is delivered to the florist:
    FlowerPrison
    FlowerGarden
    FlowerTemple
    FlowerCrypt
    FlowerFactory
    FlowerLava
    FlowerMermaid
    FlowerMine
    FlowerSewer
    FlowerCity
    FlowerLab
    FlowerCore
.ENDENUM

;;;=========================================================================;;;

kFirstUpgradeFlag = eFlag::UpgradeMaxInstructions0
kLastUpgradeFlag = eFlag::UpgradeRegisterB
kNumUpgradeFlags = 13
.ASSERT kNumUpgradeFlags = kLastUpgradeFlag + 1 - kFirstUpgradeFlag, error

kFirstConduitFlag = eFlag::ConduitGarden
kLastConduitFlag = eFlag::ConduitLab
kNumConduitFlags = 6
.ASSERT kNumConduitFlags = kLastConduitFlag + 1 - kFirstConduitFlag, error

kFirstFlowerFlag = eFlag::FlowerPrison
kLastFlowerFlag = eFlag::FlowerCore
kNumFlowerFlags = 12
.ASSERT kNumFlowerFlags = kLastFlowerFlag + 1 - kFirstFlowerFlag, error

;;;=========================================================================;;;
