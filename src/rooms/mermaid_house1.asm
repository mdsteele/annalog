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
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Indoors_sTileset
.IMPORT DataC_Mermaid_AreaCells_u8_arr2_arr
.IMPORT DataC_Mermaid_AreaName_u8_arr
.IMPORT Func_Noop
.IMPORT Ppu_ChrTownsfolk

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_House1_sRoom
.PROC DataC_Mermaid_House1_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 11
    d_byte MinimapStartCol_u8, 12
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrTownsfolk)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncA_Objects_MermaidHouse1_Draw
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataC_Mermaid_AreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataC_Mermaid_AreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Indoors_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, _Dialogs_sDialog_ptr_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_house1.room"
    .assert * - :- = 16 * 16, error
_Platforms_sPlatform_arr:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_byte WidthPx_u8,  $50
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0020
    d_word Top_i16,   $00c4
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Adult
    d_byte TileRow_u8, 21
    d_byte TileCol_u8, 22
    d_byte Param_byte, kAdultMermaidSitting
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 10
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 11
    d_byte Target_u8, 0
    D_END
    .byte eDevice::None
_Dialogs_sDialog_ptr_arr:
    .addr _Dialog0_sDialog
_Dialog0_sDialog:
    .word ePortrait::Woman
    .byte "I'm a florist.#"
    .byte 0
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for this room.
.PROC FuncA_Objects_MermaidHouse1_Draw
    ;; TODO: draw collected flowers in their vases
    rts
.ENDPROC

;;;=========================================================================;;;
