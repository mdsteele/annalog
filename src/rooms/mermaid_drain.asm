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
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_MermaidAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_MermaidAreaName_u8_arr
.IMPORT DataA_Room_Mermaid_sTileset
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjUpgrade

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Drain_sRoom
.PROC DataC_Mermaid_Drain_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $0008
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 14
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0  ; TODO
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjUpgrade)
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
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_drain.room"
    .assert * - :- = 18 * 24, error
_Platforms_sPlatform_arr:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $ff
    d_word Left_i16,  $0060
    d_word Top_i16,   $0074
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::MermaidVillage
    d_byte SpawnBlock_u8, 4
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MermaidEast
    d_byte SpawnBlock_u8, 4
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::MermaidDrain  ; TODO
    d_byte SpawnBlock_u8, 7
    D_END
.ENDPROC

;;;=========================================================================;;;
