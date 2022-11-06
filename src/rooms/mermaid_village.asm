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
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_MermaidAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_MermaidAreaName_u8_arr
.IMPORT DataA_Room_Mermaid_sTileset
.IMPORT FuncA_Dialog_AddQuestMarker
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTownsfolk
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The dialog indices for the mermaids in this room.
kMermaidGuardDialogIndex = 0
kMermaidFarmerDialogIndex = 1
kMermaidYouthDialogIndex = 2

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Village_sRoom
.PROC DataC_Mermaid_Village_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0210
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 11
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTownsfolk)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_MermaidAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_MermaidAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Mermaid_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    .linecont +
    d_addr Dialogs_sDialog_ptr_arr_ptr, \
           DataA_Dialog_MermaidVillage_sDialog_ptr_arr
    .linecont -
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_village1.room"
    .incbin "out/data/mermaid_village2.room"
    .assert * - :- = 50 * 24, error
_Platforms_sPlatform_arr:
    ;; Water for upper-left passage:
:   D_STRUCT sPlatform
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
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_byte TileRow_u8, 17
    d_byte TileCol_u8, 84
    d_byte Param_byte, kTileIdMermaidGuardFFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_byte TileRow_u8, 43
    d_byte TileCol_u8, 26
    d_byte Param_byte, kTileIdMermaidFarmerFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_byte TileRow_u8, 43
    d_byte TileCol_u8, 34
    d_byte Param_byte, kTileIdMermaidYouthFirst
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 41
    d_byte Target_u8, kMermaidGuardDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 42
    d_byte Target_u8, kMermaidGuardDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 12
    d_byte Target_u8, kMermaidFarmerDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 13
    d_byte Target_u8, kMermaidFarmerDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 16
    d_byte Target_u8, kMermaidYouthDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 17
    d_byte Target_u8, kMermaidYouthDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 24
    d_byte Target_u8, eRoom::MermaidHut1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 39
    d_byte Target_u8, eRoom::MermaidHut2
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 5
    d_byte Target_u8, eRoom::MermaidHut3
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 25
    d_byte Target_u8, eRoom::MermaidHut4
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 41
    d_byte Target_u8, eRoom::MermaidHut5
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::MermaidEntry
    d_byte SpawnBlock_u8, 8
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MermaidDrain
    d_byte SpawnBlock_u8, 5
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the MermaidVillage room.
.PROC DataA_Dialog_MermaidVillage_sDialog_ptr_arr
:   .assert * - :- = kMermaidGuardDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_MermaidVillage_MermaidGuard_sDialog
    .assert * - :- = kMermaidFarmerDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_MermaidVillage_MermaidFarmer_sDialog
    .assert * - :- = kMermaidYouthDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_MermaidVillage_MermaidYouth_sDialog
.ENDPROC

.PROC DataA_Dialog_MermaidVillage_MermaidGuard_sDialog
    .word ePortrait::Mermaid
    .byte "I am guarding this$"
    .byte "village.#"
    .word ePortrait::Done
.ENDPROC

.PROC DataA_Dialog_MermaidVillage_MermaidFarmer_sDialog
    .addr _InitialFunc
_InitialFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerGarden
    bne @farming  ; TODO different message
    flag_bit Sram_ProgressFlags_arr, eFlag::GardenTowerBoxesPlaced
    bne @monster
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut1MetQueen
    bne @needHelp
    @farming:
    ldya #_Farming_sDialog
    rts
    @needHelp:
    ldya #_NeedHelp_sDialog
    rts
    @monster:
    ldya #_Monster_sDialog
    rts
_Farming_sDialog:
    .word ePortrait::Man
    .byte "I am farming seaweed.$"
    .byte "The harvest has not$"
    .byte "been good this year,$"
    .byte "though.#"
    .word ePortrait::Done
_NeedHelp_sDialog:
    .word ePortrait::Man
    .byte "The queen sent you?$"
    .byte "Thank goodness. We$"
    .byte "could use your help.#"
_Monster_sDialog:
    .word ePortrait::Man
    .byte "West of our village,$"
    .byte "there is a tower in$"
    .byte "the gardens. A monster$"
    .byte "has taken it over.#"
    .addr _OpenTheWayFunc
_OpenTheWayFunc:
    ldx #eFlag::GardenTowerBoxesPlaced  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_OpenTheWay_sDialog
    rts
_OpenTheWay_sDialog:
    .word ePortrait::Man
    .byte "Perhaps, one of your$"
    .byte "ingenuity could get$"
    .byte "rid of it. We'll open$"
    .byte "the way up for you.#"
    .word ePortrait::Done
.ENDPROC

.PROC DataA_Dialog_MermaidVillage_MermaidYouth_sDialog
    .word ePortrait::Mermaid
    .byte "Lorem ipsum.#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
