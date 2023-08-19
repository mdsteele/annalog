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
.INCLUDE "../devices/flower.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Building_sTileset
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.IMPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.IMPORT Func_InitActorBadOrc
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORTZP Zp_Next_eCutscene

;;;=========================================================================;;;

;;; The platform index for the crate that the flower is on.
kCratePlatformIndex = 0

;;; The actor index for the orc in this room.
kOrcActorIndex = 0

;;; The talk device indices for the orc in this room.
kOrcDeviceIndexLeft = 2
kOrcDeviceIndexRight = 1

;;;=========================================================================;;;

.SEGMENT "PRGC_City"

.EXPORT DataC_City_Flower_sRoom
.PROC DataC_City_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $00
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::City
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 20
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Tick_func_ptr, FuncC_City_Flower_TickRoom
    d_addr Draw_func_ptr, FuncC_City_Flower_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Building_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/city_flower.room"
    .assert * - :- = 16 * 15, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCratePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00af
    d_word Top_i16,   $00c0
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kOrcActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $0080
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcOrc::Standing
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kFlowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eFlag::FlowerCity
    D_END
    .assert * - :- = kOrcDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eDialog::CityFlowerOrcCalm
    D_END
    .assert * - :- = kOrcDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eDialog::CityFlowerOrcCalm
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eRoom::CityDump
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_City_Flower_TickRoom
_OrcAttack:
    ;; If the orc is already hostile, we're done.
    lda Ram_ActorType_eActor_arr + kOrcActorIndex
    cmp #eActor::NpcOrc
    bne @done
    ;; If the flower is still in the room, we're done.
    lda Ram_DeviceType_eDevice_arr + kFlowerDeviceIndex
    cmp #eDevice::Flower
    beq @done
    cmp #eDevice::FlowerInert
    beq @done
    ;; Otherwise, start the orc attack cutscene.
    lda #eCutscene::CityFlowerOrcAttack
    sta Zp_Next_eCutscene
    @done:
_RespawnFlower:
    jmp FuncA_Room_RespawnFlowerDeviceIfDropped
.ENDPROC

;;; Draw function for the CityFlower room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_City_Flower_DrawRoom
    ldx #kCratePlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawCratePlatform
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_CityFlowerOrcAttack_sCutscene
.PROC DataA_Cutscene_CityFlowerOrcAttack_sCutscene
    act_SetActorState1 kOrcActorIndex, eNpcOrc::Throwing1
    act_RunDialog eDialog::CityFlowerOrcAngry
    act_CallFunc _MakeOrcAttack
    act_ContinueExploring
_MakeOrcAttack:
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kOrcDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kOrcDeviceIndexRight
    ldx #kOrcActorIndex  ; param: actor index
    lda #0  ; param: actor flags
    jmp Func_InitActorBadOrc
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CityFlowerOrcAngry_sDialog
.PROC DataA_Dialog_CityFlowerOrcAngry_sDialog
    dlg_Text OrcMaleShout, DataA_Text0_CityFlowerOrcAngry_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_CityFlowerOrcCalm_sDialog
.PROC DataA_Dialog_CityFlowerOrcCalm_sDialog
    dlg_Text OrcMale, DataA_Text0_CityFlowerOrcCalm_Part1_u8_arr
    dlg_Text OrcMale, DataA_Text0_CityFlowerOrcCalm_Part2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_CityFlowerOrcAngry_u8_arr
    .byte "Hey! Thief! You take$"
    .byte "my flower!#"
.ENDPROC

.PROC DataA_Text0_CityFlowerOrcCalm_Part1_u8_arr
    .byte "Who you? Human? Seem$"
    .byte "too small to fight...$"
    .byte "Not know why we fight$"
    .byte "humans.#"
.ENDPROC

.PROC DataA_Text0_CityFlowerOrcCalm_Part2_u8_arr
    .byte "Happier in pretty orc$"
    .byte "village. Humans happy$"
    .byte "in ugly human village.$"
    .byte "Why fight? Pointless.#"
.ENDPROC

;;;=========================================================================;;;
