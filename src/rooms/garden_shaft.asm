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
.INCLUDE "../actors/adult.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/bridge.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Machine_BridgeTick
.IMPORT FuncA_Machine_BridgeTryMove
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawBridgeMachine
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_MachineBridgeReadRegY
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The machine indices for the GardenShaftLowerBridge and
;;; GardenShaftUpperBridge machines.
kLowerBridgeMachineIndex = 0
kUpperBridgeMachineIndex = 1

;;; The device indices for the levers in this room.
kLeverLowerDeviceIndex = 0
kLeverUpperDeviceIndex = 1

;;; The number of movable segments in each drawbridge (i.e. NOT including the
;;; fixed segment).
.DEFINE kNumMovableLowerBridgeSegments 6
.DEFINE kNumMovableUpperBridgeSegments 4
;;; The platform indices for each bridge's fixed segment, which the rest of the
;;; bridge pivots around.
kLowerBridgePivotPlatformIndex = 0
kUpperBridgePivotPlatformIndex = kNumMovableLowerBridgeSegments + 1
;;; Room pixel positions for the top-left corner of the each bridge's fixed
;;; segment.
kLowerBridgePivotPosX = $0070
kLowerBridgePivotPosY = $0120
kUpperBridgePivotPosX = $0048
kUpperBridgePivotPosY = $0080

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers, indexed by machine index.
    Lever_u8_arr       .res 2
.ENDSTRUCT

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Shaft_sRoom
.PROC DataC_Garden_Shaft_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, bRoom::Tall | eArea::Garden
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 6
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/garden_shaft.room"
    .assert * - :- = 17 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLowerBridgeMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenShaftLowerBridge
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::BridgeLeft
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $90
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_byte MainPlatform_u8, kLowerBridgePivotPlatformIndex
    d_addr Init_func_ptr, FuncC_Garden_ShaftBridge_Init
    d_addr ReadReg_func_ptr, FuncC_Garden_ShaftBridge_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_GardenShaftBridge_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BridgeTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_GardenShaftLowerBridge_Tick
    d_addr Draw_func_ptr, FuncC_Garden_ShaftLowerBridge_Draw
    d_addr Reset_func_ptr, FuncC_Garden_ShaftBridge_Reset
    D_END
    .assert * - :- = kUpperBridgeMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenShaftUpperBridge
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::BridgeRight
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $20
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_byte MainPlatform_u8, kUpperBridgePivotPlatformIndex
    d_addr Init_func_ptr, FuncC_Garden_ShaftBridge_Init
    d_addr ReadReg_func_ptr, FuncC_Garden_ShaftBridge_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_GardenShaftBridge_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BridgeTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_GardenShaftUpperBridge_Tick
    d_addr Draw_func_ptr, FuncC_Garden_ShaftUpperBridge_Draw
    d_addr Reset_func_ptr, FuncC_Garden_ShaftBridge_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLowerBridgePivotPlatformIndex * .sizeof(sPlatform), error
    .repeat kNumMovableLowerBridgeSegments + 1, index
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kTileWidthPx
    d_byte HeightPx_u8, kTileHeightPx
    d_word Left_i16, kLowerBridgePivotPosX
    d_word Top_i16, kLowerBridgePivotPosY - kTileWidthPx * index
    D_END
    .endrepeat
    .assert * - :- = kUpperBridgePivotPlatformIndex * .sizeof(sPlatform), error
    .repeat kNumMovableUpperBridgeSegments + 1, index
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kTileWidthPx
    d_byte HeightPx_u8, kTileHeightPx
    d_word Left_i16, kUpperBridgePivotPosX
    d_word Top_i16, kUpperBridgePivotPosY - kTileWidthPx * index
    D_END
    .endrepeat
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_word PosX_i16, $00c7
    d_word PosY_i16, $0088
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kLeverLowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 17
    d_byte BlockCol_u8, 2
    d_byte Target_byte, sState::Lever_u8_arr + kLowerBridgeMachineIndex
    D_END
    .assert * - :- = kLeverUpperDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 2
    d_byte Target_byte, sState::Lever_u8_arr + kUpperBridgeMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 3
    d_byte Target_byte, kUpperBridgeMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 8
    d_byte Target_byte, kLowerBridgeMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 1
    d_byte Target_byte, eFlag::PaperManual6
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::GardenTower
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::GardenTower
    d_byte SpawnBlock_u8, 17
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Garden_ShaftBridge_ReadReg
    cmp #$c
    beq @readL
    @readY:
    jmp Func_MachineBridgeReadRegY
    @readL:
    ldx Zp_MachineIndex_u8
    lda Zp_RoomState + sState::Lever_u8_arr, x
    rts
.ENDPROC

.PROC FuncC_Garden_ShaftBridge_Init
    ldx Zp_MachineIndex_u8
    lda #kBridgeMaxAngle
    sta Ram_MachineState1_byte_arr, x  ; bridge angle (0-kBridgeMaxAngle)
    .assert * = FuncC_Garden_ShaftBridge_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Garden_ShaftBridge_Reset
    ldx Zp_MachineIndex_u8
    lda #1
    sta Ram_MachineGoalVert_u8_arr, x
    jmp FuncA_Room_ResetLever
.ENDPROC

.PROC FuncC_Garden_ShaftLowerBridge_Draw
    ldx #kLowerBridgePivotPlatformIndex + kNumMovableLowerBridgeSegments
    jmp FuncA_Objects_DrawBridgeMachine
.ENDPROC

.PROC FuncC_Garden_ShaftUpperBridge_Draw
    ldx #kUpperBridgePivotPlatformIndex + kNumMovableUpperBridgeSegments
    jmp FuncA_Objects_DrawBridgeMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_GardenShaftBridge_WriteReg
    .assert kLeverLowerDeviceIndex = kLowerBridgeMachineIndex, error
    .assert kLeverUpperDeviceIndex = kUpperBridgeMachineIndex, error
    ldx Zp_MachineIndex_u8  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_GardenShaftLowerBridge_Tick
    lda #kLowerBridgePivotPlatformIndex  ; param: fixed segment platform index
    ldx #kLowerBridgePivotPlatformIndex + kNumMovableLowerBridgeSegments
    jmp FuncA_Machine_BridgeTick
.ENDPROC

.PROC FuncA_Machine_GardenShaftUpperBridge_Tick
    lda #kUpperBridgePivotPlatformIndex  ; param: fixed segment platform index
    ldx #kUpperBridgePivotPlatformIndex + kNumMovableUpperBridgeSegments
    jmp FuncA_Machine_BridgeTick
.ENDPROC

;;;=========================================================================;;;
