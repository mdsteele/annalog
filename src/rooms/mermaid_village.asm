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

.IMPORT DataA_Room_Mermaid_sTileset
.IMPORT FuncA_Dialog_AddQuestMarker
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The actor index for Corra in this room.
kCorraActorIndex = 2
;;; The talk device indices for Corra in this room.
kCorraDeviceIndexLeft = 5
kCorraDeviceIndexRight = 4

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
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mermaid_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Mermaid_Village_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_village1.room"
    .incbin "out/data/mermaid_village2.room"
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
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $02a0
    d_word PosY_i16, $0088
    d_byte Param_byte, kTileIdMermaidGuardFFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $00d0
    d_word PosY_i16, $0158
    d_byte Param_byte, kTileIdMermaidFarmerFirst
    D_END
    .assert * - :- = kCorraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $0110
    d_word PosY_i16, $0158
    d_byte Param_byte, kTileIdMermaidCorraFirst
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
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
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MermaidDrain
    d_byte SpawnBlock_u8, 5
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Mermaid_Village_EnterRoom
    ;; Until Anna meets the mermaid queen, Corra is in GardenEast, not here.
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut1MetQueen
    beq @removeCorra
    ;; Once Corra is waiting in CoreSouth, she's no longer here.
    flag_bit Sram_ProgressFlags_arr, eFlag::CoreSouthCorraWaiting
    beq @keepCorra
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

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidVillageGuard_sDialog
.PROC DataA_Dialog_MermaidVillageGuard_sDialog
    ;; TODO: Different dialog once temple permission has been given.
    dlg_Text MermaidAdult, DataA_Text0_MermaidVillageGuard_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidVillageFarmer_sDialog
.PROC DataA_Dialog_MermaidVillageFarmer_sDialog
    dlg_Func _InitialFunc
_InitialFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut1MetQueen
    beq _NoQuestFunc
    ;; First quest: Defeat the Garden boss.
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerGarden
    beq _Quest1Func
    ;; To be safe, set the "crates placed" flag (although normally, you can't
    ;; reach the garden breaker without the crates being placed).
    ldx #eFlag::GardenTowerCratesPlaced  ; param: flag
    jsr Func_SetFlag
    ;; Intermission: Thanks for defeating the garden boss.
    flag_bit Sram_ProgressFlags_arr, eFlag::CoreSouthCorraWaiting
    beq _ThankYouFunc
    ;; Third quest: Rescue Alex and the other children.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq _Quest2Func
    ;; Otherwise, back to no quest.
_NoQuestFunc:
    ldya #_Farming_sDialog
    rts
_Quest1Func:
    flag_bit Sram_ProgressFlags_arr, eFlag::GardenTowerCratesPlaced
    bne @monster
    ldya #_NeedHelp_sDialog
    rts
    @monster:
    ldya #_Monster_sDialog
    rts
_ThankYouFunc:
    ldya #_ThankYou_sDialog
    rts
_Quest2Func:
    ldya #_LookingForCorra_sDialog
    rts
_Farming_sDialog:
    dlg_Text MermaidFarmer, DataA_Text0_MermaidVillageFarmer_Farming_u8_arr
    dlg_Done
_NeedHelp_sDialog:
    dlg_Text MermaidFarmer, DataA_Text0_MermaidVillageFarmer_NeedHelp_u8_arr
_Monster_sDialog:
    dlg_Text MermaidFarmer, DataA_Text0_MermaidVillageFarmer_Monster_u8_arr
    dlg_Func _OpenTheWayFunc
_OpenTheWayFunc:
    ldx #eFlag::GardenTowerCratesPlaced  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_OpenTheWay_sDialog
    rts
_OpenTheWay_sDialog:
    dlg_Text MermaidFarmer, DataA_Text0_MermaidVillageFarmer_OpenTheWay_u8_arr
    dlg_Done
_ThankYou_sDialog:
    dlg_Text MermaidFarmer, DataA_Text0_MermaidVillageFarmer_ThankYou_u8_arr
    dlg_Done
_LookingForCorra_sDialog:
    dlg_Text MermaidFarmer, DataA_Text0_MermaidVillageFarmer_LookingFor_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidVillageCorra_sDialog
.PROC DataA_Dialog_MermaidVillageCorra_sDialog
    dlg_Text MermaidCorra, DataA_Text0_MermaidVillageCorra_u8_arr
    ;; TODO: more dialog
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_MermaidVillageGuard_u8_arr
    .byte "I am guarding this$"
    .byte "village.#"
.ENDPROC

.PROC DataA_Text0_MermaidVillageFarmer_Farming_u8_arr
    .byte "I am farming seaweed.$"
    .byte "The harvest has not$"
    .byte "been good this year,$"
    .byte "though.#"
.ENDPROC

.PROC DataA_Text0_MermaidVillageFarmer_NeedHelp_u8_arr
    .byte "The queen sent you?$"
    .byte "Thank goodness. We$"
    .byte "could use your help.#"
.ENDPROC

.PROC DataA_Text0_MermaidVillageFarmer_Monster_u8_arr
    .byte "West of our village,$"
    .byte "there is a tower in$"
    .byte "the gardens. A monster$"
    .byte "has taken it over.#"
.ENDPROC

.PROC DataA_Text0_MermaidVillageFarmer_OpenTheWay_u8_arr
    .byte "Perhaps one with your$"
    .byte "ingenuity could get$"
    .byte "rid of it? We'll open$"
    .byte "the way up for you.#"
.ENDPROC

.PROC DataA_Text0_MermaidVillageFarmer_ThankYou_u8_arr
    .byte "You did it! Thank you$"
    .byte "for your help. You$"
    .byte "should go see the$"
    .byte "queen.#"
.ENDPROC

.PROC DataA_Text0_MermaidVillageFarmer_LookingFor_u8_arr
    .byte "Are you looking for$"
    .byte "Corra? I think she$"
    .byte "went exploring in the$"
    .byte "caves above our vale.#"
.ENDPROC

.PROC DataA_Text0_MermaidVillageCorra_u8_arr
    .byte "Oh, hi! I met you back$"
    .byte "in the gardens. I'm$"
    .byte "Corra, by the way.#"
.ENDPROC

;;;=========================================================================;;;
