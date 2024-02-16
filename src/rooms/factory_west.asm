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
.INCLUDE "../machines/crane.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Machine_CraneMoveTowardGoal
.IMPORT FuncA_Machine_GenericTryMoveZ
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_DrawCraneMachine
.IMPORT FuncA_Objects_DrawCranePulleyAndRope
.IMPORT Func_DistanceSensorDownDetectPoint
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToAvatarTop
.IMPORT Ppu_ChrObjFactory
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr

;;;=========================================================================;;;

;;; The actor index for the grub baddie in this room.
kGrubActorIndex = 0

;;; The machine index for the FactoryWestCrane machine in this room.
kCraneMachineIndex = 0

;;; The platform index for the FactoryWestCrane machine.
kCranePlatformIndex = 0
;;; The platform index for the pulley that the crane hangs from.
kPulleyPlatformIndex = 1

;;; The initial and maximum permitted values for the crane's Z-goal.
kCraneInitGoalZ = 1
kCraneMaxGoalZ = 9

;;; The minimum and initial Y-positions for the top of the crane platform.
kCraneMinPlatformTop = $00a8
kCraneInitPlatformTop = kCraneMinPlatformTop + kCraneInitGoalZ * kBlockHeightPx

;;; The room pixel Y-position for the surface of the floor under the crane.
kCraneFloorPosY = $0160

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_West_sRoom
.PROC DataC_Factory_West_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Factory
    d_byte MinimapStartRow_u8, 6
    d_byte MinimapStartCol_u8, 10
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
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
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/factory_west.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kCraneMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::FactoryWestCrane
    d_byte Breaker_eFlag, eFlag::BreakerTemple
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Crane
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $a0
    d_byte RegNames_u8_arr4, "D", 0, 0, "Z"
    d_byte MainPlatform_u8, kCranePlatformIndex
    d_addr Init_func_ptr, FuncC_Factory_WestCrane_InitReset
    d_addr ReadReg_func_ptr, FuncC_Factory_WestCrane_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Factory_WestCrane_TryMove
    d_addr TryAct_func_ptr, FuncC_Factory_WestCrane_TryAct
    d_addr Tick_func_ptr, FuncC_Factory_WestCrane_Tick
    d_addr Draw_func_ptr, FuncA_Objects_FactoryWestCrypt_Draw
    d_addr Reset_func_ptr, FuncC_Factory_WestCrane_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCranePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00a0
    d_word Top_i16, kCraneInitPlatformTop
    D_END
    .assert * - :- = kPulleyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a4
    d_word Top_i16,   $009f
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kGrubActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00a8
    d_word PosY_i16, $0158
    d_byte Param_byte, bObj::FlipH
    D_END
    ;; TODO: add more baddies
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kCraneMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; TODO: Paper
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 2
    d_byte Target_byte, 0  ; TODO: eFlag::Paper???
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::GardenCrossroad
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::FactoryUpper
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Factory_WestCrane_InitReset
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    lda #kCraneInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    rts
.ENDPROC

.PROC FuncC_Factory_WestCrane_ReadReg
    cmp #$f
    beq _ReadZ
_ReadD:
    lda #<kCraneFloorPosY
    sub Ram_PlatformBottom_i16_0_arr + kCranePlatformIndex
    sta T0  ; param: minimum distance so far, in pixels
    ldy #kCranePlatformIndex  ; param: distance sensor platform index
    ;; Check the player avatar with the distance sensor.
    jsr Func_SetPointToAvatarTop  ; preserves Y, T0+
    jsr Func_DistanceSensorDownDetectPoint  ; preserves Y, returns T0
    ;; Check the grub baddie with the distance sensor.
    ldx #kGrubActorIndex  ; param: actor index
    jsr Func_SetPointToActorCenter  ; preserves Y, T0+
    lda #2  ; param: offset
    jsr Func_MovePointUpByA  ; preserves Y, T0+
    jsr Func_DistanceSensorDownDetectPoint  ; returns T0
    lda T0  ; minimum distance so far, in pixels
    div #kBlockHeightPx
    cmp #10
    blt @done
    lda #9
    @done:
    rts
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kCranePlatformIndex
    sub #kCraneMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Factory_WestCrane_TryMove
    lda #kCraneMaxGoalZ  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveZ
.ENDPROC

.PROC FuncC_Factory_WestCrane_TryAct
    lda Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    eor #$ff
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    lda #kCraneActCooldown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

.PROC FuncC_Factory_WestCrane_Tick
    ldya #kCraneMinPlatformTop  ; param: min platform top
    jsr FuncA_Machine_CraneMoveTowardGoal  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the BossCryptWinch machine.
.PROC FuncA_Objects_FactoryWestCrypt_Draw
    jsr FuncA_Objects_DrawCraneMachine
    ldx #kPulleyPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawCranePulleyAndRope
.ENDPROC

;;;=========================================================================;;;
