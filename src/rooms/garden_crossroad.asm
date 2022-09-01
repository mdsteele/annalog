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

.IMPORT DataA_Pause_GardenAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_GardenAreaName_u8_arr
.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Machine_LiftMoveTowardGoal
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT Func_InitActorProjSmoke
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_RoomState

;;;=========================================================================;;;

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
    Lever_u1     .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Crossroad_sRoom
.PROC DataC_Garden_Crossroad_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $08
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 9
    d_byte MinimapWidth_u8, 1
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
    d_addr AreaName_u8_arr_ptr, DataA_Pause_GardenAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_GardenAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
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
:   .incbin "out/data/garden_crossroad.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenCrossroadLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $08
    d_byte ScrollGoalY_u8, $60
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, _Lift_Init
    d_addr ReadReg_func_ptr, FuncC_Garden_CrossroadLift_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Garden_CrossroadLift_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, FuncC_Garden_CrossroadLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, _Lift_Reset
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
    d_byte Type_eActor, eActor::BadCrawler
    d_byte TileRow_u8, 31
    d_byte TileCol_u8, 19
    d_byte Param_byte, 0
    D_END
    ;; Other enemies:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadCrawler
    d_byte TileRow_u8, 23
    d_byte TileCol_u8, 7
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadCrawler
    d_byte TileRow_u8, 39
    d_byte TileCol_u8, 17
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 4
    d_byte Target_u8, kLiftMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 13
    d_byte BlockCol_u8, 7
    d_byte Target_u8, sState::Lever_u1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::GardenShrine
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::GardenCrossroad  ; TODO
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::GardenCrossroad  ; TODO
    d_byte SpawnBlock_u8, 21
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::GardenEast
    d_byte SpawnBlock_u8, 21
    D_END
_Lift_Init:
_Lift_Reset:
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
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
    lda Ram_RoomState + sState::Lever_u1
    rts
.ENDPROC

.PROC FuncC_Garden_CrossroadLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncC_Garden_CrossroadLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_LiftMoveTowardGoal  ; returns Z, N, and A
    jeq Func_MachineFinishResetting
    ;; If the machine moved downwards, check if the enemy below got squished.
    bmi @noSquish  ; the machine moved up, not down
    lda Ram_ActorType_eActor_arr + kSquishableActorIndex
    .assert eActor::None = 0, error
    beq @noSquish  ; the actor is already gone
    .assert kLiftMaxPlatformTop < $100, error
    lda Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    cmp #kLiftMaxPlatformTop - 7
    blt @noSquish  ; the platform is not low enough to squish the enemy
    ;; This room is only one screen wide, so we only need to check the lo byte
    ;; of the actor and platform's horizontal positions.
    lda Ram_ActorPosX_i16_0_arr + kSquishableActorIndex
    cmp Ram_PlatformLeft_i16_0_arr + kLiftPlatformIndex
    blt @noSquish  ; the actor is to the left of the platform
    cmp Ram_PlatformRight_i16_0_arr + kLiftPlatformIndex
    bge @noSquish  ; the actor is to the right of the platform
    ldx #kSquishableActorIndex  ; param: actor index
    jmp Func_InitActorProjSmoke
    @noSquish:
    rts
.ENDPROC

;;;=========================================================================;;;
