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
.INCLUDE "../devices/flower.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/rotor.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_RotorMoveCarriage
.IMPORT FuncA_Machine_RotorTick
.IMPORT FuncA_Machine_RotorTryMove
.IMPORT FuncA_Objects_DrawRotorCarriage
.IMPORT FuncA_Objects_DrawRotorMachine
.IMPORT FuncA_Objects_DrawRotorWheelLarge
.IMPORT FuncA_Objects_DrawRotorWheelSmall
.IMPORT FuncA_Objects_SetWheelChr04Bank
.IMPORT FuncA_Room_MachineRotorReset
.IMPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.IMPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.IMPORT Func_MachineRotorReadRegT
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjFactory
.IMPORT Ram_MachineState1_byte_arr

;;;=========================================================================;;;

;;; The machine indices for the machines in this room.
kLowerRotorMachineIndex = 0
kUpperRotorMachineIndex = 1

;;; The platform indices used for the rotor machines in this room.
kLowerRotorPlatformIndex       = 0
kUpperRotorPlatformIndex       = 1
kLowSmWheelCenterPlatformIndex = 2
kUppSmWheelCenterPlatformIndex = 3
kLowLgWheelCenterPlatformIndex = 4
kUppLgWheelCenterPlatformIndex = 5
kLowRotorCarriagePlatformIndex = 6
kUppRotorCarriagePlatformIndex = 7

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_Flower_sRoom
.PROC DataC_Factory_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Factory
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 15
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFactory)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_RespawnFlowerDeviceIfDropped
    d_addr Draw_func_ptr, FuncA_Objects_SetWheelChr04Bank
    D_END
_TerrainData:
:   .incbin "out/rooms/factory_flower.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLowerRotorMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::FactoryFlowerLowerRotor
    d_byte Breaker_eFlag, eFlag::BreakerTemple
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Winch  ; TODO
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $a8
    d_byte RegNames_u8_arr4, 0, 0, "T", 0
    d_byte MainPlatform_u8, kLowerRotorPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineRotorReadRegT
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_RotorTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_FactoryFlowerLowerRotor_Tick
    d_addr Draw_func_ptr, FuncC_Factory_FlowerLowerRotor_Draw
    d_addr Reset_func_ptr, FuncA_Room_MachineRotorReset
    D_END
    .assert * - :- = kUpperRotorMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::FactoryFlowerUpperRotor
    d_byte Breaker_eFlag, eFlag::BreakerTemple
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Winch  ; TODO
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $58
    d_byte RegNames_u8_arr4, 0, 0, "T", 0
    d_byte MainPlatform_u8, kUpperRotorPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineRotorReadRegT
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_RotorTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_FactoryFlowerUpperRotor_Tick
    d_addr Draw_func_ptr, FuncC_Factory_FlowerUpperRotor_Draw
    d_addr Reset_func_ptr, FuncA_Room_MachineRotorReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLowerRotorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorMachineWidthPx
    d_byte HeightPx_u8, kRotorMachineHeightPx
    d_word Left_i16,  $0028
    d_word Top_i16,   $00e0
    D_END
    .assert * - :- = kUpperRotorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorMachineWidthPx
    d_byte HeightPx_u8, kRotorMachineHeightPx
    d_word Left_i16,  $0068
    d_word Top_i16,   $0090
    D_END
    .assert * - :- = kLowSmWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0030
    d_word Top_i16,   $0100
    D_END
    .assert * - :- = kUppSmWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0070
    d_word Top_i16,   $00b0
    D_END
    .assert * - :- = kLowLgWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0060
    d_word Top_i16,   $0100
    D_END
    .assert * - :- = kUppLgWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $00a0
    d_word Top_i16,   $00b0
    D_END
    .assert * - :- = kLowRotorCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorCarriageWidthPx
    d_byte HeightPx_u8, kRotorCarriageHeightPx
    d_word Left_i16,  $0058
    d_word Top_i16,   $00e0
    D_END
    .assert * - :- = kUppRotorCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorCarriageWidthPx
    d_byte HeightPx_u8, kRotorCarriageHeightPx
    d_word Left_i16,  $00b4
    d_word Top_i16,   $00ac
    D_END
    ;; Solid terrain:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $70
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0060
    d_word Top_i16,   $0020
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $006e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $1f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0020
    d_word Top_i16,   $00ce
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $c0
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $015e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00f0
    d_word PosY_i16, $0068
    d_byte Param_byte, bObj::FlipH
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kFlowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eFlag::FlowerFactory
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 15
    d_byte Target_byte, kUpperRotorMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 10
    d_byte Target_byte, kLowerRotorMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::FactoryElevator
    d_byte SpawnBlock_u8, 20
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::FactoryFlower  ; TODO
    d_byte SpawnBlock_u8, 20
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Factory_FlowerLowerRotor_Draw
    jsr FuncA_Objects_DrawRotorMachine
_Carriage:
    ldx #kLowRotorCarriagePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRotorCarriage
_LargeWheel:
    lda Ram_MachineState1_byte_arr + kLowerRotorMachineIndex  ; rotor angle
    ldx #kLowLgWheelCenterPlatformIndex  ; param: center platform index
    jsr FuncA_Objects_DrawRotorWheelLarge
_SmallWheel:
    lda Ram_MachineState1_byte_arr + kLowerRotorMachineIndex  ; rotor angle
    mul #2
    eor #$ff
    add #$41  ; param: rotation angle
    ldx #kLowSmWheelCenterPlatformIndex  ; param: center platform index
    jmp FuncA_Objects_DrawRotorWheelSmall
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Factory_FlowerUpperRotor_Draw
    jsr FuncA_Objects_DrawRotorMachine
_Carriage:
    ldx #kUppRotorCarriagePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRotorCarriage
_LargeWheel:
    lda Ram_MachineState1_byte_arr + kUpperRotorMachineIndex  ; rotor angle
    add #$20
    ldx #kUppLgWheelCenterPlatformIndex  ; param: center platform index
    jsr FuncA_Objects_DrawRotorWheelLarge
_SmallWheel:
    lda Ram_MachineState1_byte_arr + kUpperRotorMachineIndex  ; rotor angle
    mul #2
    eor #$ff
    add #$41  ; param: rotation angle
    ldx #kUppSmWheelCenterPlatformIndex  ; param: center platform index
    jmp FuncA_Objects_DrawRotorWheelSmall
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_FactoryFlowerLowerRotor_Tick
    jsr FuncA_Machine_RotorTick
_MoveCarriage:
    lda Ram_MachineState1_byte_arr + kLowerRotorMachineIndex  ; rotor angle
    add #$c0  ; param: carriage angle
    ldx #kLowLgWheelCenterPlatformIndex  ; param: center platform index
    ldy #kLowRotorCarriagePlatformIndex  ; param: carriage platform index
    jmp FuncA_Machine_RotorMoveCarriage
.ENDPROC

.PROC FuncA_Machine_FactoryFlowerUpperRotor_Tick
    jsr FuncA_Machine_RotorTick
_MoveCarriage:
    lda Ram_MachineState1_byte_arr + kUpperRotorMachineIndex  ; rotor angle
    ldx #kUppLgWheelCenterPlatformIndex  ; param: center platform index
    ldy #kUppRotorCarriagePlatformIndex  ; param: carriage platform index
    jmp FuncA_Machine_RotorMoveCarriage
.ENDPROC

;;;=========================================================================;;;
