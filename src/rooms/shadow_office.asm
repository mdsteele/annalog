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
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../fake.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Terrain_FadeInShortRoomWithLava
.IMPORT Ppu_ChrObjShadow

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Office_sRoom
.PROC DataC_Shadow_Office_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, eArea::Shadow
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 3
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjShadow)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_ShadowOffice_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_FadeInShortRoomWithLava
    d_addr Tick_func_ptr, FuncA_Room_ShadowOffice_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_AnimateLavaTerrain
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_office.room"
    .assert * - :- = 17 * 15, error
_Platforms_sPlatform_arr:
:   ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $110
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopShortRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   ;; TODO: orc ghost
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 1
    d_byte Target_byte, eFake::CoreDump
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 13
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 2
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 12
    d_byte Target_byte, eFake::InsufficientData  ; TODO
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eFake::InsufficientData
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 3
    d_byte Target_byte, eFake::Ethical
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::FakeConsole
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eFake::NoPower
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::ShadowDescent
    d_byte SpawnBlock_u8, 11
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_ShadowOffice_EnterRoom
    ;; TODO: remove ghost if tagged
    rts
.ENDPROC

.PROC FuncA_Room_ShadowOffice_TickRoom
    ;; TODO: tag ghost
    rts
.ENDPROC

;;;=========================================================================;;;
