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
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Dialog_AddQuestMarker
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_ProgressFlags_arr

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
    d_addr Enter_func_ptr, FuncA_Room_FactoryVault_EnterRoom
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
    d_byte Type_ePlatform, ePlatform::Harm
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
    d_byte Target_byte, eDialog::FactoryVaultAlex
    D_END
    .assert * - :- = kAlexDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eDialog::FactoryVaultAlex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Screen
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
;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_FactoryVault_EnterRoom
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerLava
    beq @removeAlex
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
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

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_FactoryVaultAlex_sDialog
.PROC DataA_Dialog_FactoryVaultAlex_sDialog
    dlg_Func _InitFunc
_InitFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
    bne _MeetAtHotSpringFunc
    ldya #_WhatDidYouFindOut_sDialog
    rts
_WhatDidYouFindOut_sDialog:
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex_Part2_u8_arr
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex_Part4_u8_arr
    dlg_Func _MeetAtHotSpringFunc
_MeetAtHotSpringFunc:
    ldx #eFlag::FactoryVaultTalkedToAlex  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_MeetAtHotSpring_sDialog
    rts
_MeetAtHotSpring_sDialog:
    dlg_Text ChildAlex, DataA_Text0_FactoryVaultAlex_Part5_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_FactoryVaultScreen_sDialog
.PROC DataA_Dialog_FactoryVaultScreen_sDialog
    dlg_Text Screen, DataA_Text0_FactoryVaultScreen_Page1_u8_arr
    dlg_Text Screen, DataA_Text0_FactoryVaultScreen_Page2_u8_arr
    dlg_Text Screen, DataA_Text0_FactoryVaultScreen_Page3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

;;; TODO: update dialog; Alex shouldn't meet you here until after Lava area
.PROC DataA_Text0_FactoryVaultAlex_Part1_u8_arr
    .byte "Anna, you're back! I$"
    .byte "knew you'd do great.$"
    .byte "What did you find out$"
    .byte "under the temple?#"
.ENDPROC

.PROC DataA_Text0_FactoryVaultAlex_Part2_u8_arr
    .byte "...Huh? The mermaids$"
    .byte "were CREATED by$"
    .byte "humans? But why? Wait$"
    .byte "a minute...#"
.ENDPROC

.PROC DataA_Text0_FactoryVaultAlex_Part3_u8_arr
    .byte "Anna, did you read the$"
    .byte "screen over there? I$"
    .byte "think...mermaids were$"
    .byte "created FROM humans.#"
.ENDPROC

.PROC DataA_Text0_FactoryVaultAlex_Part4_u8_arr
    .byte "This was all centuries$"
    .byte "ago. And now we're two$"
    .byte "different peoples. But$"
    .byte "why do any of that?#"
.ENDPROC

.PROC DataA_Text0_FactoryVaultAlex_Part5_u8_arr
    .byte "We need to learn more.$"
    .byte "I've got a plan. Meet$"
    .byte "me at the hot spring$"
    .byte "near the village, OK?#"
.ENDPROC

.PROC DataA_Text0_FactoryVaultScreen_Page1_u8_arr
    .byte "ERROR: Transmutation$"
    .byte "tank production line$"
    .byte "has been stalled.#"
.ENDPROC

.PROC DataA_Text0_FactoryVaultScreen_Page2_u8_arr
    .byte "Current batch: Q6382A$"
    .byte "Designated for:$"
    .byte "  Volunteer group 922$"
    .byte "  <Mermaid Aspect>#"
.ENDPROC

.PROC DataA_Text0_FactoryVaultScreen_Page3_u8_arr
    .byte "Due date: 2245 Feb 21$"
    .byte "Overdue by: 495 years$"
    .byte "Report to supervisor$"
    .byte "for instructions.#"
.ENDPROC

;;;=========================================================================;;;
