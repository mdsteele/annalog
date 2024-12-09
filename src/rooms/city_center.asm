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
.INCLUDE "../actors/child.inc"
.INCLUDE "../actors/orc.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/semaphore.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../portrait.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"
.INCLUDE "city_center.inc"

.IMPORT DataA_Room_City_sTileset
.IMPORT DataA_Text1_CityCenterAlex_Part1_u8_arr
.IMPORT DataA_Text1_CityCenterAlex_Part2_u8_arr
.IMPORT DataA_Text1_CityCenterAlex_Part3_u8_arr
.IMPORT DataA_Text1_CityCenterAlex_Part4_u8_arr
.IMPORT DataA_Text1_CityCenterAlex_Part5_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity1_Part1_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity1_Part2_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity1_Part3_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity1_Part4_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity1_Part5_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity1_Part6_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity1_Part7_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity1_Part8_u8_arr
.IMPORT DataA_Text1_CityCenterBreakerCity2_Part1_u8_arr
.IMPORT FuncA_Machine_SemaphoreTick
.IMPORT FuncA_Machine_SemaphoreTryAct
.IMPORT FuncA_Machine_SemaphoreTryMove
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawSemaphoreCommMachine
.IMPORT FuncA_Objects_DrawSemaphoreKeyMachine
.IMPORT FuncA_Objects_DrawSemaphoreLockMachine
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_MachineResetRun
.IMPORT FuncA_Room_MachineSemaphoreReset
.IMPORT FuncA_Room_UnlockDoorDevice
.IMPORT Func_GetRandomByte
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_SetFlag
.IMPORT Func_SetMachineIndex
.IMPORT Main_Breaker_FadeBackToBreakerRoom
.IMPORT Ppu_ChrObjCity
.IMPORT Ppu_ChrObjParley
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_MachineState3_byte_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_Previous_eRoom
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0
;;; The talk device indices for Alex in this room.
kAlexDeviceIndexRight = 14
kAlexDeviceIndexLeft  = 15

;;; The actor index for Gronta in this room.
kGrontaActorIndex = 1
;;; The actor index for the eastern orc in this room.
kEastOrcActorIndex = 2

;;; The device index for the door that leads to/from CityBuilding2.
kCityBuilding2DoorDeviceIndex = 7

;;; The device index for the locked door in this room.
kLockedDoorDeviceIndex = 1

;;; The machine indices for the semaphore machines in this room.
kSemaphore1MachineIndex = 0
kSemaphore2MachineIndex = 1
kSemaphore3MachineIndex = 2
kSemaphore4MachineIndex = 3

;;; The platform indices for the semaphore machines in this room.
kSemaphore1PlatformIndex = 0
kSemaphore2PlatformIndex = 1
kSemaphore3PlatformIndex = 2
kSemaphore4PlatformIndex = 3

;;; The platform indices for the semaphore display screens in this room.
kKeyScreenPlatformIndex = 4
kLockScreenPlatformIndex = 5

.ASSERT .sizeof(sCityCenterState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_City"

.EXPORT DataC_City_Center_sRoom
.PROC DataC_City_Center_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $310
    d_byte Flags_bRoom, bRoom::Tall | bRoom::ShareState | eArea::City
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 19
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 4
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCity)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_City_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_CityCenter_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_CityCenter_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_CityCenter_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/city_center1.room"
    .incbin "out/rooms/city_center2.room"
    .assert * - :- = 66 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kSemaphore1MachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CityCenterSemaphore1
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::SemaphoreKey
    d_word ScrollGoalX_u16, $034
    d_byte ScrollGoalY_u8, $0d
    d_byte RegNames_u8_arr4, "J", "F", "K", "Y"
    d_byte MainPlatform_u8, kSemaphore1PlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_City_CenterSemaphore_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_CityCenterSemaphore_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_SemaphoreTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_SemaphoreTryAct
    d_addr Tick_func_ptr, FuncA_Machine_SemaphoreTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawSemaphoreKeyMachine
    d_addr Reset_func_ptr, FuncA_Room_CityCenterSemaphore_Reset
    D_END
    .assert * - :- = kSemaphore2MachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CityCenterSemaphore2
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::SemaphoreComm
    d_word ScrollGoalX_u16, $114
    d_byte ScrollGoalY_u8, $0d
    d_byte RegNames_u8_arr4, 0, "F", "S", "Y"
    d_byte MainPlatform_u8, kSemaphore2PlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_City_CenterSemaphore_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_SemaphoreTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_SemaphoreTryAct
    d_addr Tick_func_ptr, FuncA_Machine_SemaphoreTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawSemaphoreCommMachine
    d_addr Reset_func_ptr, FuncA_Room_CityCenterSemaphore_Reset
    D_END
    .assert * - :- = kSemaphore3MachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CityCenterSemaphore3
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::SemaphoreComm
    d_word ScrollGoalX_u16, $224
    d_byte ScrollGoalY_u8, $0d
    d_byte RegNames_u8_arr4, 0, "F", "S", "Y"
    d_byte MainPlatform_u8, kSemaphore3PlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_City_CenterSemaphore_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_SemaphoreTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_SemaphoreTryAct
    d_addr Tick_func_ptr, FuncA_Machine_SemaphoreTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawSemaphoreCommMachine
    d_addr Reset_func_ptr, FuncA_Room_CityCenterSemaphore_Reset
    D_END
    .assert * - :- = kSemaphore4MachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CityCenterSemaphore4
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::SemaphoreLock
    d_word ScrollGoalX_u16, $310
    d_byte ScrollGoalY_u8, $0d
    d_byte RegNames_u8_arr4, "J", "K", "S", "Y"
    d_byte MainPlatform_u8, kSemaphore4PlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CityCenterSemaphore_InitLock
    d_addr ReadReg_func_ptr, FuncC_City_CenterSemaphore_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_CityCenterSemaphore_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_SemaphoreTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_SemaphoreTryAct
    d_addr Tick_func_ptr, FuncA_Machine_SemaphoreTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawSemaphoreLockMachine
    d_addr Reset_func_ptr, FuncA_Room_CityCenterSemaphore_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kSemaphore1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a8
    d_word Top_i16,   $0048
    D_END
    .assert * - :- = kSemaphore2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01a8
    d_word Top_i16,   $0048
    D_END
    .assert * - :- = kSemaphore3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $02a8
    d_word Top_i16,   $0048
    D_END
    .assert * - :- = kSemaphore4PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0388
    d_word Top_i16,   $0048
    D_END
    .assert * - :- = kKeyScreenPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0084
    d_word Top_i16,   $0050
    D_END
    .assert * - :- = kLockScreenPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0394
    d_word Top_i16,   $0050
    D_END
    ;; Bridges:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $06
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0090
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $180
    d_byte HeightPx_u8,  $06
    d_word Left_i16,   $01d0
    d_word Top_i16,    $0090
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $06
    d_word Left_i16,  $02f0
    d_word Top_i16,   $00c0
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $02b0
    d_word PosY_i16, $0148
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    .assert * - :- = kGrontaActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $03e4
    d_word PosY_i16, $0158
    d_byte Param_byte, eNpcOrc::GrontaStanding
    D_END
    .assert * - :- = kEastOrcActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadOrc
    d_word PosX_i16, $034c
    d_word PosY_i16, $0158
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadRhino
    d_word PosX_i16, $00b0
    d_word PosY_i16, $00e8
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadOrc
    d_word PosX_i16, $0170
    d_word PosY_i16, $0158
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door2Open
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 55
    d_byte Target_byte, eRoom::CityBuilding6
    D_END
    .assert * - :- = kLockedDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Locked
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 55
    d_byte Target_byte, eRoom::CityBuilding6
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door3Open
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 57
    d_byte Target_byte, eRoom::CityBuilding6
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 11
    d_byte Target_byte, kSemaphore1MachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 25
    d_byte Target_byte, kSemaphore2MachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 42
    d_byte Target_byte, kSemaphore3MachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 57
    d_byte Target_byte, kSemaphore4MachineIndex
    D_END
    .assert * - :- = kCityBuilding2DoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eRoom::CityBuilding2
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 14
    d_byte BlockCol_u8, 16
    d_byte Target_byte, eRoom::CityBuilding3
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door2Open
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 16
    d_byte Target_byte, eRoom::CityBuilding3
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 27
    d_byte Target_byte, eRoom::CityBuilding4
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door2Open
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 27
    d_byte Target_byte, eRoom::CityBuilding4
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 43
    d_byte Target_byte, eRoom::CityBuilding5
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door2Open
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 43
    d_byte Target_byte, eRoom::CityBuilding5
    D_END
    .assert * - :- = kAlexDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 42
    d_byte Target_byte, eDialog::CityCenterAlex
    D_END
    .assert * - :- = kAlexDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 43
    d_byte Target_byte, eDialog::CityCenterAlex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CityWest
    d_byte SpawnBlock_u8, 21
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::CityEast
    d_byte SpawnBlock_u8, 21
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 2
    d_byte Destination_eRoom, eRoom::CitySinkhole
    d_byte SpawnBlock_u8, 42
    d_byte SpawnAdjust_byte, $c1
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; ReadReg implemention for the semaphore machines in this room.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_City_CenterSemaphore_ReadReg
    ldy Zp_MachineIndex_u8
    cmp #$e
    beq @regE
    bge _ReadRegY
    cmp #$c
    beq _ReadRegJ
    @regD:
    cpy #kSemaphore4MachineIndex
    beq _ReadRegLock
    bne _ReadRegF  ; unconditional
    @regE:
    tya
    beq _ReadRegKey
_ReadRegS:
    jsr _ReadRegY  ; returns A (param: flag number)
    dey  ; now Y is the machine index for the next semaphore to the left
    bpl _ReadFlagNumberA  ; unconditional
_ReadRegF:
    jsr _ReadRegY  ; returns A
_ReadFlagNumberA:
    tax
    beq @lowerFlag
    @upperFlag:
    lda Ram_MachineState2_byte_arr, y  ; upper bSemaphoreFlag
    jmp @readFlag
    @lowerFlag:
    lda Ram_MachineState1_byte_arr, y  ; lower bSemaphoreFlag
    @readFlag:
    and #bSemaphoreFlag::AngleMask
    .assert bSemaphoreFlag::AngleMask = $0f, error
    div #8
    rts
_ReadRegJ:
    lda Ram_MachineGoalHorz_u8_arr, y  ; combination array index
    rts
_ReadRegKey:
    flag_bit Sram_ProgressFlags_arr, eFlag::CityCenterKeygenConnected
    beq @done
    ldx Ram_MachineGoalHorz_u8_arr, y  ; combination array index
    lda Zp_RoomState + sCityCenterState::Key_u8_arr, x
    @done:
    rts
_ReadRegLock:
    ldx Ram_MachineGoalHorz_u8_arr, y  ; combination array index
    lda Zp_RoomState + sCityCenterState::Lock_u8_arr, x
    rts
_ReadRegY:
    lda Ram_MachineState3_byte_arr, y  ; vertical offset
    add #kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_CityCenter_DrawRoom
    ;; Once the door is unlocked, disable both display screens.
    flag_bit Sram_ProgressFlags_arr, eFlag::CityCenterDoorUnlocked
    bne _Return
    ;; Draw the lock display screen.
    ldx Ram_MachineGoalHorz_u8_arr + kSemaphore4MachineIndex  ; lock index
    ldy Zp_RoomState + sCityCenterState::Lock_u8_arr, x  ; param: digit
    ldx #kLockScreenPlatformIndex  ; param: platform index
    jsr _DrawScreen
    ;; Until the keygen is connected, disable the key display screen.
    flag_bit Sram_ProgressFlags_arr, eFlag::CityCenterKeygenConnected
    beq _Return
    ;; Draw the key display screen.
    ldx Ram_MachineGoalHorz_u8_arr + kSemaphore1MachineIndex  ; key index
    ldy Zp_RoomState + sCityCenterState::Key_u8_arr, x  ; param: digit
    ldx #kKeyScreenPlatformIndex  ; param: platform index
_DrawScreen:
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves Y
    ldx Ram_MachineGoalHorz_u8_arr + kSemaphore1MachineIndex  ; key array index
    tya  ; digit
    add #kTileIdObjComboFirst  ; param: tile ID
    ldy #kPaletteObjComboDigit  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CityCenter_EnterRoom
_RemoveEastOrc:
    ;; The eastern orc leaves once the B-remote has been collected (including
    ;; during the city breaker cutscene).
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeBRemote
    beq @keepOrc
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kEastOrcActorIndex
    @keepOrc:
_CheckForBreakerCutscene:
    ;; If the city breaker cutscene is playing, initialize it (and skip the
    ;; checking of progress flags below).  Otherwise, remove the orc NPCs
    ;; (which only appear in the cutscene).
    lda Zp_Next_eCutscene
    cmp #eCutscene::CityCenterBreakerCity
    bne @noCutscene
    @initCutscene:
    lda #<.bank(Ppu_ChrObjParley)
    sta Zp_Current_sRoom + sRoom::Chr18Bank_u8
    lda #eMachine::Halted
    sta Ram_MachineStatus_eMachine_arr + kSemaphore1MachineIndex
    sta Ram_MachineStatus_eMachine_arr + kSemaphore2MachineIndex
    sta Ram_MachineStatus_eMachine_arr + kSemaphore3MachineIndex
    sta Ram_MachineStatus_eMachine_arr + kSemaphore4MachineIndex
    lda #$ff
    sta Ram_ActorState2_byte_arr + kAlexActorIndex
    sta Ram_ActorState2_byte_arr + kGrontaActorIndex
    rts
    @noCutscene:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kGrontaActorIndex
_RemoveAlex:
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerCity
    beq @removeAlex
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowTeleportEnteredLab
    beq @keepAlex
    @removeAlex:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexRight
    @keepAlex:
_UnlockDoor:
    ;; If the door has already been unlocked, unlock it.
    flag_bit Sram_ProgressFlags_arr, eFlag::CityCenterDoorUnlocked
    beq @done
    lda #eDevice::Door1Unlocked
    sta Ram_DeviceType_eDevice_arr + kLockedDoorDeviceIndex
    @done:
_GenerateKey:
    ;; If the player avatar entered from CityBuilding2 (with which this room
    ;; shares state), don't re-randomize the key.
    lda Zp_Previous_eRoom
    cmp #eRoom::CityBuilding2
    beq @done
    ;; TODO: Play a sound for random key generation.
    ;; Generate a random key combination, with each digit between 1 and 4.
    ldx #kNumSemaphoreKeyDigits - 1
    @loop:
    jsr Func_GetRandomByte  ; preserves X and Y, returns A
    and #$03
    tay
    iny
    sty Zp_RoomState + sCityCenterState::Key_u8_arr, x
    dex
    bpl @loop
    @done:
_SetFlag:
    ldx #eFlag::CityCenterEnteredCity  ; param: flag
    jmp Func_SetFlag
.ENDPROC

.PROC FuncA_Room_CityCenter_TickRoom
    ;; Check the lock combination against the key.
    ldx #kNumSemaphoreKeyDigits - 1
    @loop:
    lda Zp_RoomState + sCityCenterState::Lock_u8_arr, x
    cmp Zp_RoomState + sCityCenterState::Key_u8_arr, x
    bne @done  ; combination is incorrect
    dex
    bpl @loop
    ;; Combination is correct, so unlock the door.
    ;; TODO: Play a sound for entering the correct combination.
    ldx #eFlag::CityCenterDoorUnlocked  ; param: flag
    jsr Func_SetFlag
    ldx #kLockedDoorDeviceIndex  ; param: device index
    jmp FuncA_Room_UnlockDoorDevice
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_CityCenterSemaphore_Reset
    ;; Reset this semaphore machine.
    jsr FuncA_Room_MachineSemaphoreReset
    ;; We need to reset the other semaphore machines too.  If one of the other
    ;; semaphore machines is already doing that, then we're done.
    lda Zp_RoomState + sCityCenterState::SemaphoreReset_bool
    beq @resetOthers
    rts
    @resetOthers:
    ;; Save this machine's index so we can restore it later, and set
    ;; SemaphoreReset_bool to true so the other machines don't do this too.
    lda Zp_MachineIndex_u8
    pha  ; this machine's index
    dec Zp_RoomState + sCityCenterState::SemaphoreReset_bool  ; now $ff
    ;; Loop over all semaphore machines in the room, and reset any that aren't
    ;; already resetting.
    ldx #3  ; param: machine index
    @loop:
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #kFirstResetStatus
    bge @continue
    jsr Func_SetMachineIndex
    jsr FuncA_Room_MachineResetRun
    ldx Zp_MachineIndex_u8
    @continue:
    dex
    bpl @loop
    ;; Set SemaphoreReset_bool back to false, and restore the original machine
    ;; index.
    inc Zp_RoomState + sCityCenterState::SemaphoreReset_bool  ; now $00
    pla  ; this machine's index
    tax  ; param: machine index
    jsr Func_SetMachineIndex
    ;; Finally, reset the Lock_u8_arr array as well.
    fall FuncA_Room_CityCenterSemaphore_InitLock
.ENDPROC

.PROC FuncA_Room_CityCenterSemaphore_InitLock
    lda #0
    ldx #kNumSemaphoreKeyDigits - 1
    @loop:
    sta Zp_RoomState + sCityCenterState::Lock_u8_arr, x
    dex
    bpl @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncA_Machine_CityCenterSemaphore_WriteReg
    ldy Zp_MachineIndex_u8
    cpx #$c
    bne _WriteRegLock
_WriteRegJ:
    sta Ram_MachineGoalHorz_u8_arr, y  ; combination array index
    rts
_WriteRegLock:
    ldx Ram_MachineGoalHorz_u8_arr, y  ; combination array index
    sta Zp_RoomState + sCityCenterState::Lock_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_CityCenterBreakerCity_sCutscene
.PROC DataA_Cutscene_CityCenterBreakerCity_sCutscene
    act_WaitFrames 60
    act_SetActorPosX kAlexActorIndex, $0304
    act_SetActorPosY kAlexActorIndex, $00f8
    ;; Make Alex jump from offscreen onto the building roof.
    ;; TODO: play a sound for Alex jumping
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexWalking1
    act_SetActorVelX kAlexActorIndex, $180
    act_SetActorVelY kAlexActorIndex, -$200
    act_SetCutsceneFlags bCutscene::TickAllActors
    act_RepeatFunc 26, _ApplyAlexGravity
    act_SetCutsceneFlags 0
    act_SetActorPosY kAlexActorIndex, $00f8
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexKneeling
    act_SetActorFlags kGrontaActorIndex, bObj::FlipH
    act_WaitFrames 20
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 30
    ;; Make Alex walk over to talk to Gronta.
    act_MoveNpcAlexWalk kAlexActorIndex, $0346
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_RunDialog eDialog::CityCenterBreakerCity1
    act_SetActorState1 kGrontaActorIndex, eNpcOrc::GrontaStanding
    act_WaitFrames 60
    ;; Shake the room, and make Gronta look around in surprise.
    act_CallFunc Func_PlaySfxExplodeBig
    act_ShakeRoom 30
    act_WaitFrames 20
    act_SetActorFlags kGrontaActorIndex, 0
    act_WaitFrames 10
    act_SetActorFlags kAlexActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kGrontaActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kAlexActorIndex, 0
    act_WaitFrames 10
    act_SetActorFlags kGrontaActorIndex, 0
    act_WaitFrames 10
    act_SetActorFlags kAlexActorIndex, bObj::FlipH
    act_WaitFrames 80
    ;; Make Gronta mutter to herself, then walk offscreen.
    act_SetActorFlags kAlexActorIndex, 0
    act_RunDialog eDialog::CityCenterBreakerCity2
    act_MoveNpcGrontaWalk kGrontaActorIndex, $0418
    act_WaitFrames 90
    ;; Make Alex walk to the edge of the roof.
    act_MoveNpcAlexWalk kAlexActorIndex, $0322
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 6
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexKneeling
    act_WaitFrames 10
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 2
    ;; Make Alex jump offscreen toward the next building to the west.
    ;; TODO: play a sound for Alex jumping
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexWalking1
    act_SetActorVelX kAlexActorIndex, -$180
    act_SetActorVelY kAlexActorIndex, -$200
    act_SetCutsceneFlags bCutscene::TickAllActors
    act_RepeatFunc 20, _ApplyAlexGravity
    act_SetCutsceneFlags 0
    act_SetActorVelX kAlexActorIndex, 0
    act_SetActorVelY kAlexActorIndex, 0
    act_WaitFrames 80
    act_JumpToMain Main_Breaker_FadeBackToBreakerRoom
_ApplyAlexGravity:
    lda #kAvatarGravity
    add Ram_ActorVelY_i16_0_arr + kAlexActorIndex
    sta Ram_ActorVelY_i16_0_arr + kAlexActorIndex
    lda #0
    adc Ram_ActorVelY_i16_1_arr + kAlexActorIndex
    sta Ram_ActorVelY_i16_1_arr + kAlexActorIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CityCenterBreakerCity1_sDialog
.PROC DataA_Dialog_CityCenterBreakerCity1_sDialog
    .assert kTileIdBgPortraitGrontaFirst = kTileIdBgPortraitAlexFirst, error
    dlg_Text OrcGronta, DataA_Text1_CityCenterBreakerCity1_Part1_u8_arr
    dlg_Call _AlexRaiseArm
    dlg_Text ChildAlex, DataA_Text1_CityCenterBreakerCity1_Part2_u8_arr
    dlg_Text OrcGronta, DataA_Text1_CityCenterBreakerCity1_Part3_u8_arr
    dlg_Call _AlexLowerArm
    dlg_Text OrcGronta, DataA_Text1_CityCenterBreakerCity1_Part4_u8_arr
    dlg_Text OrcGronta, DataA_Text1_CityCenterBreakerCity1_Part5_u8_arr
    dlg_Text OrcGronta, DataA_Text1_CityCenterBreakerCity1_Part6_u8_arr
    dlg_Text ChildAlex, DataA_Text1_CityCenterBreakerCity1_Part7_u8_arr
    dlg_Call _GrontaRaiseAxe
    dlg_Text OrcGrontaShout, DataA_Text1_CityCenterBreakerCity1_Part8_u8_arr
    dlg_Done
_AlexRaiseArm:
    lda #eNpcChild::AlexHolding
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    rts
_AlexLowerArm:
    lda #eNpcChild::AlexStanding
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    rts
_GrontaRaiseAxe:
    lda #eNpcOrc::GrontaAxeRaised
    sta Ram_ActorState1_byte_arr + kGrontaActorIndex
    rts
.ENDPROC

.EXPORT DataA_Dialog_CityCenterBreakerCity2_sDialog
.PROC DataA_Dialog_CityCenterBreakerCity2_sDialog
    dlg_Text OrcGronta, DataA_Text1_CityCenterBreakerCity2_Part1_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_CityCenterAlex_sDialog
.PROC DataA_Dialog_CityCenterAlex_sDialog
    dlg_IfSet CityCenterTalkedToAlex, _MarkedMap_sDialog
    dlg_Text ChildAlex, DataA_Text1_CityCenterAlex_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text1_CityCenterAlex_Part2_u8_arr
    dlg_Quest CityCenterTalkedToAlex
_MarkedMap_sDialog:
    dlg_Text ChildAlex, DataA_Text1_CityCenterAlex_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text1_CityCenterAlex_Part4_u8_arr
    dlg_Text ChildAlex, DataA_Text1_CityCenterAlex_Part5_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
