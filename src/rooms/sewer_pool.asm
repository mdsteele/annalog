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
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Sewer_sTileset
.IMPORT DataA_Text1_SewerPoolSign_u8_arr
.IMPORT FuncA_Cutscene_InitActorProjFood
.IMPORT FuncA_Room_SewagePushAvatar
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_Noop
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Ppu_ChrObjSewer
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_1_arr

;;;=========================================================================;;;

.SEGMENT "PRGC_Sewer"

.EXPORT DataC_Sewer_Pool_sRoom
.PROC DataC_Sewer_Pool_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0110
    d_byte Flags_bRoom, eArea::Sewer
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 17
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjSewer)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Sewer_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_SewagePushAvatar
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/sewer_pool.room"
    .assert * - :- = 34 * 15, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $160
    d_byte HeightPx_u8,  $30
    d_word Left_i16,   $0070
    d_word Top_i16,    $00b4
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcDuck
    d_word PosX_i16, $0090
    d_word PosY_i16, $00b4
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcDuck
    d_word PosX_i16, $00ac
    d_word PosY_i16, $00b4
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcDuck
    d_word PosX_i16, $00e4
    d_word PosY_i16, $00b4
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 17
    d_byte Target_byte, eDialog::SewerPoolFood
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 19
    d_byte Target_byte, eDialog::SewerPoolSign
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::FactoryEast
    d_byte SpawnBlock_u8, 8
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::SewerSouth
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_SewerPoolFeedDucks_sCutscene
.PROC DataA_Cutscene_SewerPoolFeedDucks_sCutscene
    act_SetCutsceneFlags bCutscene::TickAllActors
    act_SetAvatarState 0
    act_SetAvatarVelX 0
    act_WalkAvatar $0116
    act_SetAvatarFlags kPaletteObjAvatarNormal | bObj::FlipH | bObj::Pri
    act_SetAvatarPose eAvatar::Kneeling
    act_WaitFrames 20
    act_SetAvatarFlags kPaletteObjAvatarNormal | bObj::FlipH
    act_SetAvatarPose eAvatar::Reaching
    act_CallFunc _ThrowDuckFood
    act_WaitFrames 20
    act_SetAvatarPose eAvatar::Standing
    act_ContinueExploring
_ThrowDuckFood:
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @done
    jsr Func_SetPointToAvatarCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #$ff  ; param: frames until expire
    jsr FuncA_Cutscene_InitActorProjFood  ; preserves X
    lda #<-2
    sta Ram_ActorVelY_i16_1_arr, x
    lda #<-2
    sta Ram_ActorVelX_i16_1_arr, x
    jsr Func_GetRandomByte  ; preserves X, returns A
    sta Ram_ActorVelX_i16_0_arr, x
    lsr a
    bcc @done
    dec Ram_ActorVelX_i16_1_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_SewerPoolFood_sDialog
.PROC DataA_Dialog_SewerPoolFood_sDialog
    dlg_Cutscene eCutscene::SewerPoolFeedDucks
.ENDPROC

.EXPORT DataA_Dialog_SewerPoolSign_sDialog
.PROC DataA_Dialog_SewerPoolSign_sDialog
    dlg_Text Sign, DataA_Text1_SewerPoolSign_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
