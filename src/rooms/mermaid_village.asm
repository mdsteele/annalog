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

.INCLUDE "../actor.inc"
.INCLUDE "../actors/adult.inc"
.INCLUDE "../actors/child.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Mermaid_sTileset
.IMPORT DataA_Text1_MermaidVillageAlex_Part1_u8_arr
.IMPORT DataA_Text1_MermaidVillageAlex_Part2_u8_arr
.IMPORT DataA_Text1_MermaidVillageAlex_Part3_u8_arr
.IMPORT DataA_Text1_MermaidVillageAlex_Part4_u8_arr
.IMPORT DataA_Text1_MermaidVillageAlex_Part5_u8_arr
.IMPORT DataA_Text1_MermaidVillageBruno_AlexAtSpring_u8_arr
.IMPORT DataA_Text1_MermaidVillageBruno_AlexExploring_u8_arr
.IMPORT DataA_Text1_MermaidVillageBruno_AlexInCity_u8_arr
.IMPORT DataA_Text1_MermaidVillageBruno_AlexInTemple_u8_arr
.IMPORT DataA_Text1_MermaidVillageBruno_AlexNearCity_u8_arr
.IMPORT DataA_Text1_MermaidVillageBruno_AlexWithQueen_u8_arr
.IMPORT DataA_Text1_MermaidVillageCorra_FoundFriends_u8_arr
.IMPORT DataA_Text1_MermaidVillageCorra_Hello1_u8_arr
.IMPORT DataA_Text1_MermaidVillageCorra_Hello2_u8_arr
.IMPORT DataA_Text1_MermaidVillageCorra_VisitTemple1_u8_arr
.IMPORT DataA_Text1_MermaidVillageCorra_VisitTemple2_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_CoreSouth_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_CorraGone1_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_CorraGone2_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_FactoryEast_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_Farming_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_Monster_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_NeedHelp_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_OpenTheWay_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_TempleEntry_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_ThankYou_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_TowerDanger_u8_arr
.IMPORT DataA_Text1_MermaidVillageFarmer_TowerSafe_u8_arr
.IMPORT DataA_Text1_MermaidVillageGuard_Guarding_u8_arr
.IMPORT DataA_Text1_MermaidVillageGuard_Temple1_u8_arr
.IMPORT DataA_Text1_MermaidVillageGuard_Temple2_u8_arr
.IMPORT DataA_Text1_MermaidVillageGuard_Temple3_u8_arr
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0
;;; The talk device indices for Alex in this room.
kAlexDeviceIndexLeft = 1
kAlexDeviceIndexRight = 0

;;; The actor index for Corra in this room.
kCorraActorIndex = 3
;;; The talk device indices for Corra in this room.
kCorraDeviceIndexLeft = 7
kCorraDeviceIndexRight = 6

;;; The actor index for Bruno in this room.
kBrunoActorIndex = 4
;;; The talk device indices for Bruno in this room.
kBrunoDeviceIndexLeft = 9
kBrunoDeviceIndexRight = 8

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Village_sRoom
.PROC DataC_Mermaid_Village_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0210
    d_byte Flags_bRoom, bRoom::Tall | eArea::Mermaid
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 11
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjVillage)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mermaid_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_MermaidVillage_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/mermaid_village1.room"
    .incbin "out/rooms/mermaid_village2.room"
    .assert * - :- = 50 * 24, error
_Platforms_sPlatform_arr:
:   ;; Water for upper-left passage:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $b0
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0000
    d_word Top_i16,   $0084
    D_END
    ;; Water for little floating pond in left half of village:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00d0
    d_word Top_i16,   $0104
    D_END
    ;; Water for lower-left house:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $110
    d_byte HeightPx_u8,  $10
    d_word Left_i16,   $0020
    d_word Top_i16,    $0154
    D_END
    ;; Water for upper-mid house:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $100
    d_byte HeightPx_u8,  $10
    d_word Left_i16,   $0100
    d_word Top_i16,    $0094
    D_END
    ;; Water for lower-mid and lower-right houses:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $1b0
    d_byte HeightPx_u8,  $30
    d_word Left_i16,   $0150
    d_word Top_i16,    $0134
    D_END
    ;; Water for upper-right house:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $90
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0250
    d_word Top_i16,   $0084
    D_END
    ;; Sand:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0150
    d_word Top_i16,   $0148
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $80
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01a0
    d_word Top_i16,   $0148
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0160
    d_word PosY_i16, $0094
    d_byte Param_byte, eNpcChild::AlexSwimming1
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $02a0
    d_word PosY_i16, $0088
    d_byte Param_byte, eNpcAdult::MermaidGuardF
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $00d0
    d_word PosY_i16, $0158
    d_byte Param_byte, eNpcAdult::MermaidFarmer
    D_END
    .assert * - :- = kCorraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0110
    d_word PosY_i16, $0158
    d_byte Param_byte, eNpcAdult::MermaidCorra
    D_END
    .assert * - :- = kBrunoActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $02c0
    d_word PosY_i16, $0128
    d_byte Param_byte, eNpcChild::BrunoStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kAlexDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 21
    d_byte Target_byte, eDialog::MermaidVillageAlex
    D_END
    .assert * - :- = kAlexDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 22
    d_byte Target_byte, eDialog::MermaidVillageAlex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 41
    d_byte Target_byte, eDialog::MermaidVillageGuard
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 42
    d_byte Target_byte, eDialog::MermaidVillageGuard
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 12
    d_byte Target_byte, eDialog::MermaidVillageFarmer
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 13
    d_byte Target_byte, eDialog::MermaidVillageFarmer
    D_END
    .assert * - :- = kCorraDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 16
    d_byte Target_byte, eDialog::MermaidVillageCorra
    D_END
    .assert * - :- = kCorraDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 17
    d_byte Target_byte, eDialog::MermaidVillageCorra
    D_END
    .assert * - :- = kBrunoDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 43
    d_byte Target_byte, eDialog::MermaidVillageBruno
    D_END
    .assert * - :- = kBrunoDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 44
    d_byte Target_byte, eDialog::MermaidVillageBruno
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 24
    d_byte Target_byte, eRoom::MermaidHut1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 39
    d_byte Target_byte, eRoom::MermaidHut2
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eRoom::MermaidHut3
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 25
    d_byte Target_byte, eRoom::MermaidHut4
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 41
    d_byte Target_byte, eRoom::MermaidHut5
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::MermaidEntry
    d_byte SpawnBlock_u8, 8
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MermaidSpring
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_MermaidVillage_EnterRoom
_Alex:
    ;; Until Alex finishes his petition, Alex is in PrisonUpper or MermaidHut1,
    ;; not here.
    flag_bit Ram_ProgressFlags_arr, eFlag::MermaidHut1AlexPetition
    beq @removeAlex
    ;; Once Alex is waiting in the temple, he's no longer here.
    flag_bit Ram_ProgressFlags_arr, eFlag::TempleNaveAlexWaiting
    beq @keepAlex
    @removeAlex:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexRight
    @keepAlex:
_Bruno:
    ;; Until the kids are rescued, Bruno is in PrisonUpper, not here.
    flag_bit Ram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq @removeBruno  ; Bruno is still imprisoned
    ;; If you've lowered the rocks in the FactoryPass, but not yet met with
    ;; Alex in FactoryVault, Bruno is in FactoryElevator, not here.
    flag_bit Ram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
    bne @keepBruno  ; Bruno is back again
    flag_bit Ram_ProgressFlags_arr, eFlag::FactoryPassLoweredRocks
    beq @keepBruno  ; Bruno is still here
    @removeBruno:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kBrunoActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kBrunoDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kBrunoDeviceIndexRight
    @keepBruno:
_Corra:
    ;; Until Anna meets the mermaid queen, Corra is in GardenEast, not here.
    flag_bit Ram_ProgressFlags_arr, eFlag::MermaidHut1MetQueen
    beq @removeCorra
    ;; Then, until Corra is waiting in CoreSouth, she's here.
    flag_bit Ram_ProgressFlags_arr, eFlag::CoreSouthCorraWaiting
    beq @keepCorra
    ;; Then, until Anna frees the other kids, Corra is in CoreSouth, not here.
    flag_bit Ram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq @removeCorra
    ;; Then, until the crypt breaker is activated, Corra is here.
    flag_bit Ram_ProgressFlags_arr, eFlag::BreakerCrypt
    beq @keepCorra
    ;; Then, until Anna meets up with Alex in the city outskirts, Corra is in
    ;; TempleEntry, not here.
    flag_bit Ram_ProgressFlags_arr, eFlag::CityOutskirtsTalkedToAlex
    beq @removeCorra
    ;; Then, until Anna meets up with Alex in the vault, Corra is here.
    flag_bit Ram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
    beq @keepCorra
    ;; Once Anna meets up with Alex in the vault, Corra is in FactoryEast for a
    ;; while, and then she disappears from the game, so she's not here.
    @removeCorra:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kCorraActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexRight
    @keepCorra:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_MermaidVillageAlexLeave_sCutscene
.PROC DataA_Cutscene_MermaidVillageAlexLeave_sCutscene
    act_MoveNpcAlexSwim kAlexActorIndex, $01f8
    act_CallFunc _RemoveAlex
    act_ContinueExploring
_RemoveAlex:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexRight
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidVillageAlex_sDialog
.PROC DataA_Dialog_MermaidVillageAlex_sDialog
    dlg_Text ChildAlex, DataA_Text1_MermaidVillageAlex_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text1_MermaidVillageAlex_Part2_u8_arr
    dlg_Text ChildAlex, DataA_Text1_MermaidVillageAlex_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text1_MermaidVillageAlex_Part4_u8_arr
    dlg_Quest TempleNaveAlexWaiting
    dlg_Text ChildAlex, DataA_Text1_MermaidVillageAlex_Part5_u8_arr
    dlg_Cutscene eCutscene::MermaidVillageAlexLeave
.ENDPROC

.EXPORT DataA_Dialog_MermaidVillageGuard_sDialog
.PROC DataA_Dialog_MermaidVillageGuard_sDialog
    dlg_IfSet BreakerTemple, _Guarding_sDialog
    dlg_IfSet TempleEntryPermission, _Temple_sDialog
_Guarding_sDialog:
    dlg_Text MermaidGuardF, DataA_Text1_MermaidVillageGuard_Guarding_u8_arr
    dlg_Done
_Temple_sDialog:
    dlg_Text MermaidGuardF, DataA_Text1_MermaidVillageGuard_Temple1_u8_arr
    dlg_Text MermaidGuardF, DataA_Text1_MermaidVillageGuard_Temple2_u8_arr
    dlg_Text MermaidGuardF, DataA_Text1_MermaidVillageGuard_Temple3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidVillageFarmer_sDialog
.PROC DataA_Dialog_MermaidVillageFarmer_sDialog
    ;; Don't talk about the garden quest until Anna has met Queen Eirene.
    dlg_IfClear MermaidHut1MetQueen, _Farming_sDialog
    ;; No longer talk about the garden quest once it's completed.
    dlg_IfSet BreakerGarden, _GardenTowerCleared_sDialog
_NeedHelp_sDialog:
    dlg_IfSet GardenTowerCratesPlaced, @monster
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_NeedHelp_u8_arr
    @monster:
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_Monster_u8_arr
    dlg_Quest GardenTowerCratesPlaced
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_OpenTheWay_u8_arr
    dlg_Done
_GardenTowerCleared_sDialog:
    ;; To be safe, set the "crates placed" flag (although normally, you can't
    ;; reach the garden breaker without the crates being placed).
    dlg_Call _PlaceCrates
    ;; If Corra is in CoreSouth, report that she went there.
    dlg_IfClear CoreSouthCorraWaiting, _CorraNotInCoreSouth_sDialog
    dlg_IfSet PrisonUpperFreedKids, _CorraNotInCoreSouth_sDialog
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_CoreSouth_u8_arr
    dlg_Done
_CorraNotInCoreSouth_sDialog:
    ;; If Corra is in TempleEntry, report that she went there.
    dlg_IfClear BreakerCrypt, _CorraNotInTempleEntry_sDialog
    dlg_IfSet CityOutskirtsTalkedToAlex, _CorraNotInTempleEntry_sDialog
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_TempleEntry_u8_arr
    dlg_Done
_CorraNotInTempleEntry_sDialog:
    ;; If Corra is in FactoryEast, report that she went there.
    dlg_IfClear FactoryVaultTalkedToAlex, _CorraInVillage_sDialog
    dlg_IfSet SewerFaucetEnteredUpperSewer, _CorraGone_sDialog
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_FactoryEast_u8_arr
    dlg_Done
_CorraInVillage_sDialog:
    dlg_IfSet TempleEntryPermission, _Farming_sDialog
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_ThankYou_u8_arr
    dlg_Done
_Farming_sDialog:
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_Farming_u8_arr
    dlg_IfSet BreakerGarden, _TowerFixed_sDialog
_TowerDanger_sDialog:
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_TowerDanger_u8_arr
    dlg_Done
_TowerFixed_sDialog:
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_TowerSafe_u8_arr
    dlg_Done
_CorraGone_sDialog:
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_CorraGone1_u8_arr
    dlg_Text MermaidFarmer, DataA_Text1_MermaidVillageFarmer_CorraGone2_u8_arr
    dlg_Done
_PlaceCrates:
    ldx #eFlag::GardenTowerCratesPlaced  ; param: flag
    jmp Func_SetFlag
.ENDPROC

.EXPORT DataA_Dialog_MermaidVillageCorra_sDialog
.PROC DataA_Dialog_MermaidVillageCorra_sDialog
    dlg_IfSet TempleEntryTalkedToCorra, _VisitTemple_sDialog
    dlg_IfSet PrisonUpperFreedKids, _FoundFriends_sDialog
_Hello_sDialog:
    dlg_Text MermaidCorra, DataA_Text1_MermaidVillageCorra_Hello1_u8_arr
    dlg_Text MermaidCorra, DataA_Text1_MermaidVillageCorra_Hello2_u8_arr
    dlg_Done
_FoundFriends_sDialog:
    dlg_Text MermaidCorra, DataA_Text1_MermaidVillageCorra_FoundFriends_u8_arr
    dlg_Done
_VisitTemple_sDialog:
    dlg_Text MermaidCorra, DataA_Text1_MermaidVillageCorra_VisitTemple1_u8_arr
    dlg_Text MermaidCorra, DataA_Text1_MermaidVillageCorra_VisitTemple2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidVillageBruno_sDialog
.PROC DataA_Dialog_MermaidVillageBruno_sDialog
    ;; Bruno isn't here until the kids are rescued.  Once that happens, if Alex
    ;; hasn't yet started waiting in the temple, then report that he's still
    ;; meeting with the mermaid queen.
    dlg_IfClear TempleNaveAlexWaiting, _AlexWithQueen_sDialog
    ;; Otherwise, if Anna hasn't yet visited the crypt, then report that Alex
    ;; is still in the temple.
    dlg_IfClear CryptLandingDroppedIn, _AlexInTemple_sDialog
    ;; Otherwise, if the crypt breaker hasn't yet been activated, then how did
    ;; Anna get out of the crypt to talk to Bruno? Whatever, just report that
    ;; Alex is off exploring somewhere.
    dlg_IfClear BreakerCrypt, _AlexExploring_sDialog
    ;; Otherwise, if Anna hasn't yet met with Alex in the city outskirts, then
    ;; report that Alex is up near the city.
    dlg_IfClear CityOutskirtsTalkedToAlex, _AlexNearCity_sDialog
    ;; Otherwise, if the hot spring hasn't been unplugged yet, report that Alex
    ;; is at the spring.
    dlg_IfClear MermaidSpringUnplugged, _AlexAtSpring_sDialog
    ;; Between when Anna returns from under the mermaid spring and when she
    ;; talks to Alex in the factory vault, Alex is in the vault.  However,
    ;; during that period, Bruno is in the factory elevator rather than here,
    ;; so no need to report on that.  Once Bruno returns here, Alex is nowhere
    ;; to be found until the city breaker has been activated, so until then
    ;; just report that Alex is off exploring somewhere.
    dlg_IfClear BreakerCity, _AlexExploring_sDialog
    ;; Otherwise, if Anna hasn't yet entered the Shadow Labs, report that Alex
    ;; is in the city.
    dlg_IfClear ShadowTeleportEnteredLab, _AlexInCity_sDialog
_AlexExploring_sDialog:
    ;; If all else fails, just report that Alex is off exploring somewhere.
    dlg_Text ChildBruno, DataA_Text1_MermaidVillageBruno_AlexExploring_u8_arr
    dlg_Done
_AlexWithQueen_sDialog:
    dlg_Text ChildBruno, DataA_Text1_MermaidVillageBruno_AlexWithQueen_u8_arr
    dlg_Done
_AlexInTemple_sDialog:
    dlg_Text ChildBruno, DataA_Text1_MermaidVillageBruno_AlexInTemple_u8_arr
    dlg_Done
_AlexNearCity_sDialog:
    dlg_Text ChildBruno, DataA_Text1_MermaidVillageBruno_AlexNearCity_u8_arr
    dlg_Done
_AlexAtSpring_sDialog:
    dlg_Text ChildBruno, DataA_Text1_MermaidVillageBruno_AlexAtSpring_u8_arr
    dlg_Done
_AlexInCity_sDialog:
    dlg_Text ChildBruno, DataA_Text1_MermaidVillageBruno_AlexInCity_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
