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
.INCLUDE "../actors/lavaball.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/boiler.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_BoilerFinishEmittingSteam
.IMPORT FuncA_Machine_BoilerStartEmittingSteam
.IMPORT FuncA_Machine_BoilerTick
.IMPORT FuncA_Machine_BoilerWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Objects_DrawBoilerMachine
.IMPORT FuncA_Objects_DrawBoilerValve
.IMPORT FuncA_Room_InitActorSmokeRaindrop
.IMPORT FuncA_Room_MachineBoilerReset
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_TurnSteamToSmokeIfConsoleOpen
.IMPORT FuncA_Terrain_FadeInTallRoomWithLava
.IMPORT Func_DistanceSensorRightDetectPoint
.IMPORT Func_EmitSteamUpFromPipe
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_MachineBoilerReadReg
.IMPORT Func_MarkMinimap
.IMPORT Func_Noop
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The index of the vertical passage at the top of the room.
kShaftPassageIndex = 0

;;; The minimap column/row for the bottom of the vertical shaft that leads into
;;; this room.
kShaftMinimapCol = 14
kShaftMinimapBottomRow = 12

;;; The device index for the lever in this room.
kLeverDeviceIndex = 1

;;; The machine index for the LavaWestBoiler machine in this room.
kBoilerMachineIndex = 0

;;; Platform indices for various parts of the LavaWestBoiler machine.
kBoilerPlatformIndex = 0
kSensorPlatformIndex = 1
kValvePlatformIndex  = 2
kPipe1PlatformIndex  = 3
kPipe2PlatformIndex  = 4

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the lever in this room.
    Lever_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_West_sRoom
.PROC DataC_Lava_West_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, bRoom::Tall | eArea::Lava
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjLava)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Lava_West_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_FadeInTallRoomWithLava
    d_addr Tick_func_ptr, FuncA_Room_TurnSteamToSmokeIfConsoleOpen
    d_addr Draw_func_ptr, FuncA_Objects_AnimateLavaTerrain
    D_END
_TerrainData:
:   .incbin "out/rooms/lava_west.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaWestBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteCE
    d_byte Status_eDiagram, eDiagram::BoilerValve
    d_word ScrollGoalX_u16, $108
    d_byte ScrollGoalY_u8, $48
    d_byte RegNames_u8_arr4, "L", "D", "V", 0
    d_byte MainPlatform_u8, kBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Lava_WestBoiler_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LavaWestBoiler_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_LavaWestBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncC_Lava_WestBoiler_Draw
    d_addr Reset_func_ptr, FuncC_Lava_WestBoiler_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0180
    d_word Top_i16,   $00c0
    D_END
    .assert * - :- = kSensorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0138
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- = kValvePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0154
    d_word Top_i16,   $00c4
    D_END
    .assert * - :- = kPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0130
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0150
    d_word Top_i16,   $00b0
    D_END
    ;; Spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0140
    d_word Top_i16,   $007a
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0180
    d_word Top_i16,   $005a
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01c0
    d_word Top_i16,   $00be
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $220
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopTallRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadHotheadHorz
    d_word PosX_i16, $0078
    d_word PosY_i16, $00c8
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadHotheadHorz
    d_word PosX_i16, $00d0
    d_word PosY_i16, $0098
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadHotheadVert
    d_word PosX_i16, $0138
    d_word PosY_i16, $0038
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadHotheadHorz
    d_word PosX_i16, $01c8
    d_word PosY_i16, $0088
    d_byte Param_byte, bObj::FlipV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadHotheadHorz
    d_word PosX_i16, $01c8
    d_word PosY_i16, $0118
    d_byte Param_byte, bObj::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadLavaball
    d_word PosX_i16, $0098
    d_word PosY_i16, kLavaballStartYTall
    d_byte Param_byte, 6
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadLavaball
    d_word PosX_i16, $0110
    d_word PosY_i16, kLavaballStartYTall
    d_byte Param_byte, 6
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 28
    d_byte Target_byte, eFlag::PaperJerome10
    D_END
    .assert * - :- = kLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 19
    d_byte Target_byte, sState::Lever_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 24
    d_byte Target_byte, kBoilerMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   .assert * - :- = kShaftPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::MermaidSpring
    d_byte SpawnBlock_u8, 8
    d_byte SpawnAdjust_byte, $f5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::LavaTeleport
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::LavaShaft
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::LavaTunnel
    d_byte SpawnBlock_u8, 15
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Lava_WestBoiler_ReadReg
    cmp #$d
    blt _ReadL
    beq _ReadD
    jmp Func_MachineBoilerReadReg
_ReadL:
    lda Zp_RoomState + sState::Lever_u8
    rts
_ReadD:
    lda #kBlockWidthPx * 9
    sta T0  ; param: minimum distance so far, in pixels
    ldy #kSensorPlatformIndex  ; param: distance sensor platform index
    jsr Func_SetPointToAvatarCenter  ; preserves Y and T0+
    jsr Func_DistanceSensorRightDetectPoint  ; preserves Y, returns T0
    lda T0  ; minimum distance so far, in pixels
    div #kBlockWidthPx
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Lava_WestBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kValvePlatformIndex  ; param: platform index
    ldy #eValveInput::TopHalfOfRightEdge  ; param: input pipe position
    jmp FuncA_Objects_DrawBoilerValve
.ENDPROC

;;; Called when the player avatar enters the LavaWest room.
;;; @prereq PRGA_Room is loaded.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncC_Lava_West_EnterRoom
    ;; If the player avatar didn't enter from the shaft, do nothing.
    cmp #bSpawn::Passage | kShaftPassageIndex
    bne @done
    ;; Set the flag indicating that the player entered the lava pits.
    ldx #eFlag::LavaWestDroppedIn  ; param: flag
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs @doneRaindrops
    ;; The first time the player avatar drops in from the shaft, have some
    ;; water droplets fall in too.
    lda #0
    sta Zp_PointX_i16 + 1
    sta Zp_PointY_i16 + 1
    ldy #3
    @loop:
    lda _RaindropPosX_u8_arr, y
    sta Zp_PointX_i16 + 0
    lda _RaindropPosY_u8_arr, y
    sta Zp_PointY_i16 + 0
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @doneRaindrops  ; no more actor slots available
    jsr Func_SetActorCenterToPoint  ; preserves X and Y
    sty T0  ; loop index
    jsr FuncA_Room_InitActorSmokeRaindrop  ; preserves X and T0+
    ldy T0  ; loop index
    lda #2
    sta Ram_ActorVelY_i16_1_arr, x
    dey
    bpl @loop
    @doneRaindrops:
    ;; Mark the bottom minimap cell of the shaft as explored.
    lda #kShaftMinimapCol        ; param: minimap col
    ldy #kShaftMinimapBottomRow  ; param: minimap row
    jmp Func_MarkMinimap
    @done:
    rts
_RaindropPosX_u8_arr:
    .byte $73, $85, $8d, $7c
_RaindropPosY_u8_arr:
    .byte $08, $01, $0f, $1c
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Lava_WestBoiler_Reset
    ldx #kLeverDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    jmp FuncA_Room_MachineBoilerReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_LavaWestBoiler_WriteReg
    cpx #$c
    beq _WriteL
    jmp FuncA_Machine_BoilerWriteReg
_WriteL:
    ldx #kLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

;;; TryAct implemention for the LavaWestBoiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq PRGA_Machine is loaded.
.PROC FuncA_Machine_LavaWestBoiler_TryAct
    jsr FuncA_Machine_BoilerStartEmittingSteam
    ;; Determine which pipe the steam should exit out of (or fail if both pipes
    ;; are blocked).
    lda Ram_MachineGoalHorz_u8_arr + kBoilerMachineIndex  ; valve 1 angle
    and #$03
    tax  ; valve angle (in tau/8 units, mod 4)
    ldy _ValvePipePlatformIndex_u8_arr4, x  ; pipe platform index
    bmi _Failure
    ;; Emit upward steam from the chosen pipe.
    jsr Func_EmitSteamUpFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
_Failure:
    jmp FuncA_Machine_Error
_ValvePipePlatformIndex_u8_arr4:
    .byte $ff
    .byte kPipe1PlatformIndex
    .byte kPipe2PlatformIndex
    .byte kPipe2PlatformIndex
.ENDPROC

;;;=========================================================================;;;
