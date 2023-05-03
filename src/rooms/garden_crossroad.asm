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
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_LiftTick
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInPlatform
.IMPORT Func_Noop
.IMPORT Func_SetPointToActorCenter
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device index for the lever in this room.
kLeverDeviceIndex = 1

;;; The machine index for the GardenCrossroadLift machine in this room.
kLiftMachineIndex = 0

;;; The platform index for the GardenCrossroadLift machine.
kLiftPlatformIndex = 0

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 1
kLiftMaxGoalY = 9

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $00e0
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;; The actor index for the enemy that can get squished by the lift machine.
kSquishableActorIndex = 0

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the room's lever.
    Lever_u8     .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Crossroad_sRoom
.PROC DataC_Garden_Crossroad_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $08
    d_byte Flags_bRoom, bRoom::Tall | eArea::Garden
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 9
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
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
    D_END
_TerrainData:
:   .incbin "out/data/garden_crossroad.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenCrossroadLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $08
    d_byte ScrollGoalY_u8, $60
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncC_Garden_CrossroadLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Garden_CrossroadLift_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Garden_CrossroadLift_WriteReg
    d_addr TryMove_func_ptr, FuncC_Garden_CrossroadLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Garden_CrossroadLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncC_Garden_CrossroadLift_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $00a0
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    ;; The enemy that can get squished by the lift machine:
:   .assert * - :- = kSquishableActorIndex * .sizeof(sPlatform), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0098
    d_word PosY_i16, $00f8
    d_byte Param_byte, 0
    D_END
    ;; Other enemies:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0038
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0088
    d_word PosY_i16, $0138
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 2
    d_byte Target_u8, kLiftMachineIndex
    D_END
    .assert * - :- = kLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 4
    d_byte Target_u8, sState::Lever_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::GardenShrine
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::FactoryWest
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::GardenHallway
    d_byte SpawnBlock_u8, 21
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::GardenEast
    d_byte SpawnBlock_u8, 21
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Garden_CrossroadLift_InitReset
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    ldx #kLeverDeviceIndex
    jmp FuncA_Room_ResetLever
.ENDPROC

.PROC FuncC_Garden_CrossroadLift_ReadReg
    cmp #$c
    beq _ReadL
_ReadY:
    .assert kLiftMaxPlatformTop + kTileHeightPx < $100, error
    lda #kLiftMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    div #kBlockHeightPx
    rts
_ReadL:
    lda Zp_RoomState + sState::Lever_u8
    rts
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncC_Garden_CrossroadLift_WriteReg
    ldx #kLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncC_Garden_CrossroadLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncC_Garden_CrossroadLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_LiftTick  ; returns N and Z
    ;; If the machine moved downwards, check if the baddie below got squished.
    beq @noSquish  ; the machine didn't move
    bmi @noSquish  ; the machine moved up, not down
    lda Ram_ActorType_eActor_arr + kSquishableActorIndex
    .assert eActor::None = 0, error
    beq @noSquish  ; the actor is already gone
    ldx #kSquishableActorIndex  ; param: actor index
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kLiftPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcc @noSquish
    jmp Func_InitActorSmokeExplosion
    @noSquish:
    rts
.ENDPROC

;;;=========================================================================;;;
