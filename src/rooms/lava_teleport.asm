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
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/field.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_LavaAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_LavaAreaName_u8_arr
.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_FieldTick
.IMPORT FuncA_Machine_FieldTryAct
.IMPORT FuncA_Objects_DrawFieldMachine
.IMPORT Func_MachineError
.IMPORT Func_MachineFieldReadRegT
.IMPORT Func_MachineFieldReset
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjUpgrade

;;;=========================================================================;;;

;;; The machine index for the LavaTeleportField machine in this room.
kFieldMachineIndex = 0

;;; The primary platform index for the LavaTeleportField machine.
kFieldPlatformIndex = 0

;;; The device index for the device where the player avatar should spawn when
;;; teleporting into this room.
kTeleportSpawnDeviceIndex = 0

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_Teleport_sRoom
.PROC DataC_Lava_Teleport_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 13
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjUpgrade)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_LavaAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_LavaAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
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
:   .incbin "out/data/lava_teleport.room"
    .assert * - :- = 17 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kFieldMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaTeleportField
    d_byte Breaker_eFlag, eFlag::BreakerCity
    d_byte Flags_bMachine, bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch  ; TODO
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, "T", 0, 0, 0
    d_byte MainPlatform_u8, kFieldPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineFieldReadRegT
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, Func_MachineError
    d_addr TryAct_func_ptr, FuncA_Machine_FieldTryAct
    d_addr Tick_func_ptr, FuncA_Machine_FieldTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawFieldMachine
    d_addr Reset_func_ptr, Func_MachineFieldReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kFieldPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kFieldMachineWidth
    d_byte HeightPx_u8, kFieldMachineHeight
    d_word Left_i16,  $0050
    d_word Top_i16,   $0070
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $00ce
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kTeleportSpawnDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Teleporter
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::ShadowTeleport
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 11
    d_byte Target_u8, kFieldMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::LavaWest
    d_byte SpawnBlock_u8, 9
    D_END
.ENDPROC

;;;=========================================================================;;;
