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
.INCLUDE "../actors/child.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/dialog.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT DataA_Text0_FactoryVaultAlex1_Part1_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex1_Part2_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex2_Part1_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex2_Part2_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex3_Part1_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex3_Part2_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex3_Part3_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex3_Part4_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex4_Part1_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex4_Part2_u8_arr
.IMPORT DataA_Text0_FactoryVaultAlex4_Part3_u8_arr
.IMPORT DataA_Text0_FactoryVaultScreen_Page1_u8_arr
.IMPORT DataA_Text0_FactoryVaultScreen_Page2_u8_arr
.IMPORT DataA_Text0_FactoryVaultScreen_Page3_u8_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0
;;; The talk device indices for Alex in this room.
kAlexDeviceIndexRight = 0
kAlexDeviceIndexLeft  = 1

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_Vault_sRoom
.PROC DataC_Factory_Vault_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0100
    d_byte Flags_bRoom, eArea::Factory
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 8
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjVillage)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Factory_Vault_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/factory_vault.room"
    .assert * - :- = 33 * 15, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0110
    d_word Top_i16,   $00cc
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0110
    d_word Top_i16,   $00de
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0060
    d_word PosY_i16, $00a8
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kAlexDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eDialog::FactoryVaultAlex1
    D_END
    .assert * - :- = kAlexDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eDialog::FactoryVaultAlex1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ScreenRed
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 20
    d_byte Target_byte, eDialog::FactoryVaultScreen
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::FactoryLock
    d_byte SpawnBlock_u8, 11
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Factory_Vault_EnterRoom
    flag_bit Ram_ProgressFlags_arr, eFlag::BreakerLava
    beq @removeAlex
    flag_bit Ram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
    beq @keepAlex
    @removeAlex:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexRight
    @keepAlex:
    rts
.ENDPROC
;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_FactoryVaultLookAtTank_sCutscene
.PROC DataA_Cutscene_FactoryVaultLookAtTank_sCutscene
    ;; Anna steps out of the way to the left.
    act_ForkStart 1, _WalkAvatar_sCutscene
    ;; Alex walks over to the big tank and kneels down for a closer look.
    act_MoveNpcAlexWalk kAlexActorIndex, $007a
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 45
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexKneeling
    act_WaitFrames 60
    ;; Alex reads off the label on the tank.
    act_RunDialog eDialog::FactoryVaultAlex2
    ;; Alex walk over and looks at the tank from the right side.
    act_MoveNpcAlexWalk kAlexActorIndex, $009c
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 10
    act_SetActorFlags kAlexActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexLooking
    act_WaitFrames 90
    ;; Alex walk over and looks at the tank from the left side.
    act_MoveNpcAlexWalk kAlexActorIndex, $006c
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 10
    act_SetActorFlags kAlexActorIndex, 0
    act_WaitFrames 10
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexLooking
    act_WaitFrames 90
    ;; Alex thinks out loud for a bit.
    act_RunDialog eDialog::FactoryVaultAlex3
    ;; Alex walks back to where he was standing before and talks to Anna again.
    act_MoveNpcAlexWalk kAlexActorIndex, $0060
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_SetActorState2 kAlexActorIndex, 0
    act_RunDialog eDialog::FactoryVaultAlex4
    act_ContinueExploring
_WalkAvatar_sCutscene:
    act_MoveAvatarWalk $0050 | kTalkRightAvatarOffset
    act_SetAvatarPose eAvatar::Standing
    act_SetAvatarFlags kPaletteObjAvatarNormal | 0
    act_ForkStop $ff
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_FactoryVaultAlex1_sDialog
.PROC DataA_Dialog_FactoryVaultAlex1_sDialog
    dlg_IfSet FactoryVaultTalkedToAlex, DataA_Dialog_FactoryVaultAlex4_sDialog
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex1_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex1_Part2_u8_arr
    dlg_Cutscene eCutscene::FactoryVaultLookAtTank
.ENDPROC

.EXPORT DataA_Dialog_FactoryVaultAlex2_sDialog
.PROC DataA_Dialog_FactoryVaultAlex2_sDialog
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex2_Part1_u8_arr
    dlg_Call FuncA_Dialog_FactoryVault_AlexStand
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex2_Part2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_FactoryVaultAlex3_sDialog
.PROC DataA_Dialog_FactoryVaultAlex3_sDialog
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex3_Part1_u8_arr
    dlg_Call FuncA_Dialog_FactoryVault_AlexStand
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex3_Part2_u8_arr
    dlg_Call _LookLeft
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex3_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex3_Part4_u8_arr
    dlg_Done
_LookLeft:
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    rts
.ENDPROC

.EXPORT DataA_Dialog_FactoryVaultAlex4_sDialog
.PROC DataA_Dialog_FactoryVaultAlex4_sDialog
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex4_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex4_Part2_u8_arr
    dlg_Quest FactoryVaultTalkedToAlex
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex4_Part3_u8_arr
    dlg_Done
.ENDPROC

.PROC FuncA_Dialog_FactoryVault_AlexStand
    lda #eNpcChild::AlexStanding
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    rts
.ENDPROC

.EXPORT DataA_Dialog_FactoryVaultScreen_sDialog
.PROC DataA_Dialog_FactoryVaultScreen_sDialog
    dlg_Text Screen, DataA_Text0_FactoryVaultScreen_Page1_u8_arr
    dlg_Text Screen, DataA_Text0_FactoryVaultScreen_Page2_u8_arr
    dlg_Text Screen, DataA_Text0_FactoryVaultScreen_Page3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
