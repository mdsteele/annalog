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
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The machine index for the GardenCrossroadLift machine in this room.
kLiftMachineIndex = 0

;;; The platform index for the GardenCrossroadLift machine.
kLiftPlatformIndex = 0

;;; The initial and maximum permitted values for sState::LiftGoalY_u8.
kLiftInitGoalY = 1
kLiftMaxGoalY = 9

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $00e0
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;; How many frames the GardenCrossroadLift machine spends per move operation.
kLiftMoveCooldown = kBlockHeightPx

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the room's lever.
    Lever_u1     .byte
    ;; The goal value for the GardenCrossroadLift machine's Y register.
    LiftGoalY_u8 .byte
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
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrUpgrade)
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
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_crossroad.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
    .assert kLiftMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenCrossroadLift
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $08
    d_byte ScrollGoalY_u8, $60
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_addr Init_func_ptr, _Lift_Init
    d_addr ReadReg_func_ptr, FuncC_Garden_CrossroadLift_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Garden_CrossroadLift_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, FuncC_Garden_CrossroadLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenCrossroadLift_Draw
    d_addr Reset_func_ptr, _Lift_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kLiftPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $00a0
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 23
    d_byte TileCol_u8, 7
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 31
    d_byte TileCol_u8, 19
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 39
    d_byte TileCol_u8, 17
    d_byte Param_byte, 0
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
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
    sta Ram_RoomState + sState::LiftGoalY_u8
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
    ldy Ram_RoomState + sState::LiftGoalY_u8
    cpx #eDir::Up
    bne @moveDown
    @moveUp:
    cpy #kLiftMaxGoalY
    bge @error
    iny
    bne @success  ; unconditional
    @moveDown:
    tya
    beq @error
    dey
    @success:
    sty Ram_RoomState + sState::LiftGoalY_u8
    lda #kLiftMoveCooldown
    clc  ; success
    rts
    @error:
    sec  ; failure
    rts
.ENDPROC

.PROC FuncC_Garden_CrossroadLift_Tick
    ;; Calculate the desired Y-position for the top edge of the lift, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    lda Ram_RoomState + sState::LiftGoalY_u8
    .assert kLiftMaxGoalY * kBlockHeightPx < $100, error
    mul #kBlockHeightPx  ; fits in one byte
    sta Zp_Tmp1_byte
    .assert kLiftMaxPlatformTop < $100, error
    lda #kLiftMaxPlatformTop
    sub Zp_Tmp1_byte
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine the vertical speed of the lift (faster if resetting).
    lda #1
    ldy Ram_MachineStatus_eMachine_arr + kLiftMachineIndex
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the lift vertically, as necessary.
    ldx #kLiftPlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopToward  ; returns Z and A
    beq @done
    ;; TODO: If moving down, check if the actor got crushed.
    rts
    @done:
    jmp Func_MachineFinishResetting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the GardenCrossroadLift machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_GardenCrossroadLift_Draw
    ldx #kLiftPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawLiftMachine
.ENDPROC

;;;=========================================================================;;;
