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

.INCLUDE "flag.inc"
.INCLUDE "macros.inc"
.INCLUDE "minimap.inc"
.INCLUDE "room.inc"

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; An array of all the markers that can appear on the minimap during the game.
;;; This array is sorted, first by Row_u8 (ascending), then by Col_u8
;;; (ascending), then by priority (descending).  It is terminated by an entry
;;; with Row_u8 = $ff.
.EXPORT DataA_Pause_Minimap_sMarker_arr
.PROC DataA_Pause_Minimap_sMarker_arr
    D_STRUCT sMarker
    d_byte Row_u8, 1
    d_byte Col_u8, 1  ; room: BossTemple
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::BreakerTemple
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 1
    d_byte Col_u8, 8  ; room: PrisonFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerPrison
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 3
    d_byte Col_u8, 20  ; room: CityFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerCity
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 3
    d_byte Col_u8, 21  ; room: BossCity
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::BreakerCity
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 4
    d_byte Col_u8, 12  ; room: CoreSouth
    d_byte If_eFlag, eFlag::CoreSouthCorraWaiting
    d_byte Not_eFlag, eFlag::CoreSouthCorraHelped
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 4
    d_byte Col_u8, 13  ; room: CoreFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerCore
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 5
    d_byte Col_u8, 4  ; room: TempleFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerTemple
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 5
    d_byte Col_u8, 15  ; room: FactoryFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerFactory
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 5
    d_byte Col_u8, 23  ; room: SewerFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerSewer
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 6
    d_byte Col_u8, 1  ; room: TempleNave
    d_byte If_eFlag, eFlag::TempleNaveAlexWaiting
    d_byte Not_eFlag, eFlag::CryptLandingDroppedIn
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 6
    d_byte Col_u8, 4  ; room: TempleFoyer
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpTil
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 7
    d_byte Col_u8, 8  ; room: GardenShrine
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpIf
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 7
    d_byte Col_u8, 11  ; room: GardenFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerGarden
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 7
    d_byte Col_u8, 13  ; room: FactoryCenter
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpSkip
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 7
    d_byte Col_u8, 23  ; room: SewerBasin
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpAddSub
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 8
    d_byte Col_u8, 5  ; room: TempleEntry
    d_byte If_eFlag, eFlag::TempleEntryPermission
    d_byte Not_eFlag, eFlag::TempleEntryColumnRaised
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 9
    d_byte Col_u8, 3  ; room: CryptFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerCrypt
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 9
    d_byte Col_u8, 7  ; room: GardenTower
    d_byte If_eFlag, eFlag::GardenTowerCratesPlaced
    d_byte Not_eFlag, eFlag::BreakerGarden
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 9
    d_byte Col_u8, 13  ; room: MermaidFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerMermaid
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 9
    d_byte Col_u8, 18  ; room: BossMine
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::BreakerMine
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 10
    d_byte Col_u8, 4  ; room: CryptGallery
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpGoto
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 10
    d_byte Col_u8, 12  ; room: MermaidHut1
    d_byte If_eFlag, eFlag::GardenEastTalkedToCorra
    d_byte Not_eFlag, eFlag::MermaidHut1MetQueen
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 10
    d_byte Col_u8, 18  ; room: MineFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerMine
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 11
    d_byte Col_u8, 11  ; room: MermaidVillage
    d_byte If_eFlag, eFlag::MermaidHut1MetQueen
    d_byte Not_eFlag, eFlag::GardenTowerCratesPlaced
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 12
    d_byte Col_u8, 17  ; room: LavaStation
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpCopy
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 13
    d_byte Col_u8, 0  ; room: BossCrypt
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::BreakerCrypt
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 13
    d_byte Col_u8, 23  ; room: MinePit
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::UpgradeOpSync
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 14
    d_byte Col_u8, 9  ; room: BossShadow
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::BreakerShadow
    D_END
    D_STRUCT sMarker
    d_byte Row_u8, 14
    d_byte Col_u8, 16  ; room: LavaFlower
    d_byte If_eFlag, 0
    d_byte Not_eFlag, eFlag::FlowerLava
    D_END
    .assert sMarker::Row_u8 = 0, error
    .byte $ff
.ENDPROC
;;; Ensure that we can access all bytes of the array with one index register.
.ASSERT .sizeof(DataA_Pause_Minimap_sMarker_arr) <= $100, error

;;;=========================================================================;;;
