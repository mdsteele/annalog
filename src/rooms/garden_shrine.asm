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
.INCLUDE "../actors/orc.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../portrait.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Garden_sTileset
.IMPORT DataA_Text0_GardenShrineBreakerMine1_Part1_u8_arr
.IMPORT DataA_Text0_GardenShrineBreakerMine1_Part2_u8_arr
.IMPORT DataA_Text0_GardenShrineBreakerMine1_Part3_u8_arr
.IMPORT DataA_Text0_GardenShrineBreakerMine1_Part4_u8_arr
.IMPORT DataA_Text0_GardenShrineBreakerMine1_Part5_u8_arr
.IMPORT DataA_Text0_GardenShrineBreakerMine1_Part6_u8_arr
.IMPORT DataA_Text0_GardenShrineBreakerMine1_Part7_u8_arr
.IMPORT DataA_Text0_GardenShrineBreakerMine2_Part1_u8_arr
.IMPORT DataA_Text0_GardenShrineBreakerMine2_Part2_u8_arr
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Main_Breaker_FadeBackToBreakerRoom
.IMPORT Ppu_ChrObjParley
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Next_eCutscene

;;;=========================================================================;;;

;;; Actor indices for specific NPCs in this room.
kEireneActorIndex  = 0
kGrontaActorIndex = 1

;;; The device index for the upgrade in this room.
kUpgradeDeviceIndex = 0

;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeOpIf

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Shrine_sRoom
.PROC DataC_Garden_Shrine_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $08
    d_byte Flags_bRoom, eArea::Garden
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 8
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjParley)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Garden_Shrine_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/garden_shrine.room"
    .assert * - :- = 18 * 15, error
_Actors_sActor_arr:
:   .assert * - :- = kEireneActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $0049
    d_word PosY_i16, $0098
    d_byte Param_byte, eNpcOrc::EireneParley
    D_END
    .assert * - :- = kGrontaActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $00cb
    d_word PosY_i16, $0098
    d_byte Param_byte, eNpcOrc::GrontaParley
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 8
    d_byte Target_byte, kUpgradeFlag
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::GardenLanding
    d_byte SpawnBlock_u8, 7
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::GardenCrossroad
    d_byte SpawnBlock_u8, 7
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Garden_Shrine_EnterRoom
    ;; If the mine breaker cutscene is playing, initialize it.  Otherwise,
    ;; remove the NPCs (which only appear in the cutscene).
    lda Zp_Next_eCutscene
    cmp #eCutscene::GardenShrineBreakerMine
    bne @noCutscene
    @initCutscene:
    lda #$ff
    sta Ram_ActorState2_byte_arr + kEireneActorIndex
    sta Ram_ActorState2_byte_arr + kGrontaActorIndex
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kGrontaActorIndex
    bne @removeUpgrade  ; unconditional
    @noCutscene:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kEireneActorIndex
    sta Ram_ActorType_eActor_arr + kGrontaActorIndex
    ;; If the upgrade in this room has already been collected, remove it.
    flag_bit Sram_ProgressFlags_arr, kUpgradeFlag
    beq @done
    @removeUpgrade:
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_GardenShrineBreakerMine_sCutscene
.PROC DataA_Cutscene_GardenShrineBreakerMine_sCutscene
    act_WaitFrames 60
    act_RunDialog eDialog::GardenShrineBreakerMine1
    act_WaitFrames 30
    act_CallFunc Func_PlaySfxExplodeBig
    act_ShakeRoom 30
    act_WaitFrames 20
    act_SetActorFlags kGrontaActorIndex, 0
    act_WaitFrames 20
    act_SetActorFlags kGrontaActorIndex, bObj::FlipH
    act_WaitFrames 20
    act_SetActorFlags kGrontaActorIndex, 0
    act_WaitFrames 60
    act_SetActorFlags kGrontaActorIndex, bObj::FlipH
    act_RunDialog eDialog::GardenShrineBreakerMine2
    act_WaitFrames 60
    act_JumpToMain Main_Breaker_FadeBackToBreakerRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_GardenShrineBreakerMine1_sDialog
.PROC DataA_Dialog_GardenShrineBreakerMine1_sDialog
    .assert kTileIdBgPortraitEireneFirst = kTileIdBgPortraitGrontaFirst, error
    dlg_Text MermaidEirene, DataA_Text0_GardenShrineBreakerMine1_Part1_u8_arr
    dlg_Text OrcGronta, DataA_Text0_GardenShrineBreakerMine1_Part2_u8_arr
    dlg_Text OrcGronta, DataA_Text0_GardenShrineBreakerMine1_Part3_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_GardenShrineBreakerMine1_Part4_u8_arr
    dlg_Text MermaidEirene, DataA_Text0_GardenShrineBreakerMine1_Part5_u8_arr
    dlg_Text OrcGronta, DataA_Text0_GardenShrineBreakerMine1_Part6_u8_arr
    dlg_Text OrcGronta, DataA_Text0_GardenShrineBreakerMine1_Part7_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_GardenShrineBreakerMine2_sDialog
.PROC DataA_Dialog_GardenShrineBreakerMine2_sDialog
    .assert kTileIdBgPortraitEireneFirst = kTileIdBgPortraitGrontaFirst, error
    dlg_Text MermaidEirene, DataA_Text0_GardenShrineBreakerMine2_Part1_u8_arr
    dlg_Call _GrontaRaiseArms
    dlg_Text OrcGrontaShout, DataA_Text0_GardenShrineBreakerMine2_Part2_u8_arr
    dlg_Done
_GrontaRaiseArms:
    lda #eNpcOrc::GrontaArmsRaised
    sta Ram_ActorState1_byte_arr + kGrontaActorIndex
    rts
.ENDPROC

;;;=========================================================================;;;
