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
.INCLUDE "../actors/orc.inc"
.INCLUDE "../actors/particle.inc"
.INCLUDE "../actors/rocket.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/launcher.inc"
.INCLUDE "../machines/lift.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/gate.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../scroll.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Avatar_SpawnAtDevice
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_LauncherTryAct
.IMPORT FuncA_Machine_LiftTick
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT FuncA_Objects_DrawLauncherMachineVert
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT FuncA_Objects_DrawRocksPlatformHorz
.IMPORT FuncC_Prison_DrawGatePlatform
.IMPORT FuncC_Prison_OpenGateAndFlipLever
.IMPORT FuncC_Prison_TickGatePlatform
.IMPORT FuncM_SwitchPrgcAndLoadRoom
.IMPORT Func_FadeOutToBlackSlowly
.IMPORT Func_FindActorWithType
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_InitActorSmokeParticle
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_Noop
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetLastSpawnPoint
.IMPORT Func_SetOrClearFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Main_Explore_EnterRoom
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The minimum scroll-X value for this room.
kMinScrollX = $10

;;; The device index to use for the last spawn point after the player avatar
;;; enters the room via the get-thrown-in-prison cutscene.
kCutsceneSpawnDeviceIndex = 0

;;; The index of the passage that leads into the tunnel under the prison cell.
kTunnelPassageIndex = 1
;;; The index of the passage on the eastern side of the room.
kEasternPassageIndex = 2
;;; The index of the console device for the PrisonCellLauncher machine.
kLauncherConsoleDeviceIndex = 3

;;; The actor indices for the orcs in this room.
kOrc1ActorIndex = 0
kOrc2ActorIndex = 1

;;; The machine indices for the machines in this room.
kLiftMachineIndex = 0
kLauncherMachineIndex = 1

;;; The platform index for the PrisonCellLift machine in this room.
kLiftPlatformIndex = 0
;;; The platform index for the PrisonCellLauncher machine in this room.
kLauncherPlatformIndex = 1
;;; The platform index for the prison cell gate.
kGatePlatformIndex = 2
;;; The platform index for the crate used to reach the gate lever.
kCratePlatformIndex = 3
;;; The platform indices for rocks that can be blasted away by the
;;; PrisonCellLauncher machine.
kUpperFloor1PlatformIndex = 4
kUpperFloor2PlatformIndex = 5
kMidCeilingPlatformIndex  = 6
kEastCeilingPlatformIndex = 7
;;; The platform index for the rocks that collapse when the player avatar walks
;;; on them (after firing the launcher).
kTrapFloorPlatformIndex = 8
;;; The zone that the player avatar must be in in order for the trap floor to
;;; collapse.
kTrapZonePlatformIndex = 9

;;; How much to shake the room when the trap floor collapses.
kTrapFloorShakeFrames = 4

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 0
kLiftMaxGoalY = 1

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $0080
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;; The initial and maximum permitted horizontal goal values for the launcher.
kLauncherInitGoalX = 1
kLauncherMaxGoalX = 1

;;; The minimum and initial X-positions for the left of the launcher platform.
.LINECONT +
kLauncherMinPlatformLeft = $0180
kLauncherInitPlatformLeft = \
    kLauncherMinPlatformLeft + kLauncherInitGoalX * kBlockWidthPx
.LINECONT -

;;; The room block row for the top of the gate when it's shut.
kGateBlockRow = 10

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the lever in this room.
    GateLever_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Cell_sRoom
.PROC DataC_Prison_Cell_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, kMinScrollX
    d_word MaxScrollX_u16, kMinScrollX + $100
    d_byte Flags_bRoom, bRoom::Tall | eArea::Prison
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 5
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Prison_Cell_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Prison_Cell_TickRoom
    d_addr Draw_func_ptr, FuncC_Prison_Cell_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/prison_cell.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_PrisonCellLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Prison_CellLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_PrisonCellLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_PrisonCellLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncA_Room_PrisonCellLift_InitReset
    D_END
    .assert * - :- = kLauncherMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellLauncher
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act
    d_byte Status_eDiagram, eDiagram::LauncherDown
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, kLauncherPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_PrisonCellLauncher_InitReset
    d_addr ReadReg_func_ptr, FuncC_Prison_CellLauncher_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_PrisonCellLauncher_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_PrisonCellLauncher_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_PrisonCellLauncher_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLauncherMachineVert
    d_addr Reset_func_ptr, FuncA_Room_PrisonCellLauncher_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLiftMachineWidthPx
    d_byte HeightPx_u8, kLiftMachineHeightPx
    d_word Left_i16, $0020
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    .assert * - :- = kLauncherPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLauncherMachineWidthPx
    d_byte HeightPx_u8, kLauncherMachineHeightPx
    d_word Left_i16, kLauncherInitPlatformLeft
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kGatePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kGatePlatformWidthPx
    d_byte HeightPx_u8, kGatePlatformHeightPx
    d_word Left_i16, $00f3
    d_word Top_i16, kGateBlockRow * kBlockHeightPx
    D_END
    .assert * - :- = kCratePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0153
    d_word Top_i16,   $00b0
    D_END
    ;; Breakable rocks:
    .assert * - :- = kUpperFloor1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0170
    d_word Top_i16,   $00c0
    D_END
    .assert * - :- = kUpperFloor2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0190
    d_word Top_i16,   $00c8
    D_END
    .assert * - :- = kMidCeilingPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0180
    d_word Top_i16,   $00e8
    D_END
    .assert * - :- = kEastCeilingPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0190
    d_word Top_i16,   $00e8
    D_END
    .assert * - :- = kTrapFloorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0178
    d_word Top_i16,   $0100
    D_END
    .assert * - :- = kTrapZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $0e
    d_byte HeightPx_u8, $09
    d_word Left_i16,  $0181
    d_word Top_i16,   $00f7
    D_END
    ;; Unbreakable rocks:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0170
    d_word Top_i16,   $0100
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0198
    d_word Top_i16,   $0100
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kOrc1ActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $0175
    d_word PosY_i16, $00b8
    d_byte Param_byte, eNpcOrc::Standing
    D_END
    .assert * - :- = kOrc2ActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $01a2
    d_word PosY_i16, $00b8
    d_byte Param_byte, eNpcOrc::Standing
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kCutsceneSpawnDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 11
    d_byte Target_byte, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eFlag::PaperJerome36
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 3
    d_byte Target_byte, kLiftMachineIndex
    D_END
    .assert * - :- = kLauncherConsoleDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 13
    d_byte BlockCol_u8, 30
    d_byte Target_byte, kLauncherMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 19
    d_byte Target_byte, sState::GateLever_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::PrisonEscape
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- = kTunnelPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::PrisonEscape
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- = kEasternPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonCrossroad
    d_byte SpawnBlock_u8, 11
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 1
    d_byte Destination_eRoom, eRoom::GardenLanding
    d_byte SpawnBlock_u8, 25
    d_byte SpawnAdjust_byte, $f0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Called when the player avatar enters the PrisonCell room.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncC_Prison_Cell_EnterRoom
    sta T0  ; bSpawn value
_InitOrcs:
    lda #$ff
    sta Ram_ActorState2_byte_arr + kOrc1ActorIndex
    sta Ram_ActorState2_byte_arr + kOrc2ActorIndex
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kOrc1ActorIndex
_CheckIfReachedTunnel:
    ;; If the player has reached the tunnel before, then don't lock scrolling.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonCellReachedTunnel
    bne @done
    ;; If the player enters from the tunnel (or from the eastern passage or
    ;; eastern console, though normally that shouldn't be possible before
    ;; reaching the tunnel), then set the flag indicating that the tunnel has
    ;; been reached, and don't lock scrolling.
    lda T0  ; bSpawn value
    cmp #bSpawn::Passage | kTunnelPassageIndex
    beq @setFlag
    cmp #bSpawn::Passage | kEasternPassageIndex
    beq @setFlag
    cmp #bSpawn::Device | kLauncherConsoleDeviceIndex
    beq @setFlag
    ;; Otherwise, lock scrolling so that only the prison cell is visible.
    @lockScrolling:
    lda #bScroll::LockHorz | bScroll::LockVert
    sta Zp_Camera_bScroll
    lda #0
    sta Zp_RoomScrollY_u8
    .assert >kMinScrollX = 0, error
    sta Zp_RoomScrollX_u16 + 1
    .assert <kMinScrollX > 0, error
    lda #kMinScrollX
    sta Zp_RoomScrollX_u16 + 0
    .assert kMinScrollX <> 0, error
    bne @done  ; unconditional
    @setFlag:
    ldx #eFlag::PrisonCellReachedTunnel  ; param: flag
    jsr Func_SetFlag
    @done:
_InitGate:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonCellGateOpen
    beq @shut
    ldy #sState::GateLever_u8  ; param: lever target
    ldx #kGatePlatformIndex  ; param: gate platform index
    jsr FuncC_Prison_OpenGateAndFlipLever
    @shut:
_InitRocksAndCrate:
    flag_bit Sram_ProgressFlags_arr, eFlag::GardenLandingDroppedIn
    bne @removeAllRocks
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonCellBlastedRocks
    bne @removeSomeRocks
    @loadRocketLauncher:
    inc Ram_MachineState1_byte_arr + kLauncherMachineIndex  ; ammo count
    rts
    @removeAllRocks:
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kTrapFloorPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kEastCeilingPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kMidCeilingPlatformIndex
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kCratePlatformIndex
    @removeSomeRocks:
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kUpperFloor1PlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kUpperFloor2PlatformIndex
    .assert eActor::None = ePlatform::None, error
    sta Ram_ActorType_eActor_arr + kOrc1ActorIndex
    sta Ram_ActorType_eActor_arr + kOrc2ActorIndex
    rts
.ENDPROC

;;; Tick function for the PrisonCell room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Prison_Cell_TickRoom
_RocketImpact:
    ;; Find the rocket (if any).  If there isn't one, we're done.
    lda #eActor::ProjRocket  ; param: actor type to find
    jsr Func_FindActorWithType  ; returns C and X
    bcs @done
    ;; Check if the rocket has hit the breakable floor; if not, we're done.
    ;; (Note that no rocket can exist in this room if the breakable floor is
    ;; already gone.)
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kUpperFloor1PlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcc @done
    ;; Explode the rocket and break the floor.
    jsr Func_InitActorSmokeExplosion
    ;; TODO: more smoke/particles
    lda #kRocketShakeFrames  ; param: shake frames
    jsr Func_ShakeRoom
    ;; TODO: play a sound
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kUpperFloor1PlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kUpperFloor2PlatformIndex
    ldx #eFlag::PrisonCellBlastedRocks
    jsr Func_SetFlag
    ;; TODO: Make the orcs go flying and run away, instead of removing them.
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kOrc1ActorIndex
    sta Ram_ActorType_eActor_arr + kOrc2ActorIndex
    @done:
_TrapFloor:
    ;; If the trap floor is already gone, it can't collapse again.
    lda Ram_PlatformType_ePlatform_arr + kTrapFloorPlatformIndex
    .assert ePlatform::None = 0, error
    beq @done
    ;; The trap floor can't collapse until the rocks have been blasted.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonCellBlastedRocks
    beq @done
    ;; Don't collapse until the player avatar is in the trap zone.
    jsr Func_SetPointToAvatarCenter
    ldy #kTrapZonePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done
    ;; Collapse the trap floor.
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kTrapFloorPlatformIndex
    lda #kTrapFloorShakeFrames  ; param: shake frames
    jsr Func_ShakeRoom
    ;; Add particles for the collapsing floor.
    ldy #kTrapFloorPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    lda #kTileWidthPx * 2 + kTileWidthPx / 2  ; param: offset
    jsr Func_MovePointLeftByA
    ldy #3
    @loop:
    lda #kTileWidthPx  ; param: offset
    jsr Func_MovePointRightByA  ; preserves Y
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @continue
    jsr Func_SetActorCenterToPoint  ; preserves X and Y
    tya
    pha
    lda _ParticleAngle_u8_arr, y  ; param: angle
    jsr Func_InitActorSmokeParticle
    pla
    tay
    @continue:
    dey
    bpl @loop
    ;; TODO: Play a sound.
    @done:
_Gate:
    ;; Update the flag from the lever.
    ldx #eFlag::PrisonCellGateOpen  ; param: flag
    lda Zp_RoomState + sState::GateLever_u8  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::GateLever_u8  ; param: zero for shut
    jmp FuncC_Prison_Cell_TickGate
_ParticleAngle_u8_arr:
    .byte 52, 65, 70, 76
.ENDPROC

;;; Performs per-frame updates for the gate in this room.
;;; @param Y Zero if the gate should shut, nonzero if it should open.
;;; @return Z Cleared if the platform moved, set if it didn't.
.PROC FuncC_Prison_Cell_TickGate
    ldx #kGatePlatformIndex  ; param: gate platform index
    lda #kGateBlockRow  ; param: block row
    jmp FuncC_Prison_TickGatePlatform  ; returns Z
.ENDPROC

;;; Draw function for the PrisonCell room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Prison_Cell_DrawRoom
    ;; If the floor has been blasted away, don't draw the mid-ceiling, even if
    ;; it's still solid.  This creates the appearance that the player could
    ;; jump up through the gap (thus tempting them to walk out over the trap
    ;; floor), while still preventing them from doing so.
    lda Ram_PlatformType_ePlatform_arr + kUpperFloor1PlatformIndex
    cmp #kFirstSolidPlatformType
    blt @skipMidCeiling
    ldx #kMidCeilingPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRocksPlatformHorz
    @skipMidCeiling:
    ;; Draw the rest of the platforms (non-solid ones won't be drawn).
    ldx #kCratePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawCratePlatform
    ldx #kTrapFloorPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRocksPlatformHorz
    ldx #kEastCeilingPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRocksPlatformHorz
    ldx #kUpperFloor1PlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRocksPlatformHorz
    ldx #kUpperFloor2PlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRocksPlatformHorz
    ldx #kGatePlatformIndex  ; param: platform index
    jmp FuncC_Prison_DrawGatePlatform
.ENDPROC

.PROC FuncC_Prison_CellLift_ReadReg
    lda #kLiftMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Prison_CellLauncher_ReadReg
    lda Ram_PlatformLeft_i16_0_arr + kLauncherPlatformIndex
    sub #<(kLauncherMinPlatformLeft - kTileWidthPx)
    div #kBlockWidthPx
    rts
.ENDPROC

;;; Mode to spawn the player avatar into the PrisonCell room, then start the
;;; cutscene where Anna gets thrown into prison by the orcs.
;;; @prereq Rendering is disabled.
;;; @prereq The PrisonCell room has been loaded.
.PROC MainC_Prison_Cell_StartCutscene
    lda #bSpawn::Device | kCutsceneSpawnDeviceIndex  ; param: bSpawn value
    jsr Func_SetLastSpawnPoint
    ldx #kCutsceneSpawnDeviceIndex  ; param: device index
    jsr_prga FuncA_Avatar_SpawnAtDevice
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    lda #eCutscene::PrisonCellGetThrownIn
    sta Zp_Next_eCutscene
    jmp Main_Explore_EnterRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_PrisonCellLift_InitReset
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

.PROC FuncA_Room_PrisonCellLauncher_InitReset
    lda #kLauncherInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLauncherMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_PrisonCellLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncA_Machine_PrisonCellLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_LiftTick
.ENDPROC

.PROC FuncA_Machine_PrisonCellLauncher_TryMove
    lda #kLauncherMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_PrisonCellLauncher_TryAct
    ;; If the launcher is blocked, fail.
    lda Ram_MachineGoalHorz_u8_arr + kLauncherMachineIndex
    jne FuncA_Machine_Error
    ;; Otherwise, try to fire a rocket.
    lda #eDir::Down  ; param: rocket direction
    jmp FuncA_Machine_LauncherTryAct
.ENDPROC

.PROC FuncA_Machine_PrisonCellLauncher_Tick
    ldax #kLauncherMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PaperJerome36_sDialog
.PROC DataA_Dialog_PaperJerome36_sDialog
    dlg_Text Paper, DataA_Text0_PaperJerome36_Page1_u8_arr
    dlg_Text Paper, DataA_Text0_PaperJerome36_Page2_u8_arr
    dlg_Text Paper, DataA_Text0_PaperJerome36_Page3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_PaperJerome36_Page1_u8_arr
    .byte "Day 36: By now there's$"
    .byte "probably not much time$"
    .byte "left to finish this.#"
.ENDPROC

.PROC DataA_Text0_PaperJerome36_Page2_u8_arr
    .byte "I'm going to start$"
    .byte "pinning up all these$"
    .byte "pages. Maybe someday$"
    .byte "someone'll find them.#"
.ENDPROC

.PROC DataA_Text0_PaperJerome36_Page3_u8_arr
    .byte "By then, I'm sure I'll$"
    .byte "be long gone.#"
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode to switch PRGC banks and load the PrisonCell room, then start the
;;; cutscene where Anna gets thrown into prison by the orcs.
;;; @prereq Rendering is enabled.
.EXPORT Main_LoadPrisonCellAndStartCutscene
.PROC Main_LoadPrisonCellAndStartCutscene
    jsr Func_FadeOutToBlackSlowly
    ldx #eRoom::PrisonCell  ; param: room to load
    jsr FuncM_SwitchPrgcAndLoadRoom
    jmp MainC_Prison_Cell_StartCutscene
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_PrisonCellGetThrownIn_sCutscene
.PROC DataA_Cutscene_PrisonCellGetThrownIn_sCutscene
    act_WaitFrames 60
    ;; Animate the prison gate opening.
    act_WaitUntilZ _OpenGate
    ;; Animate the orc walking in.
    act_SetActorPosX kOrc1ActorIndex, $0118
    act_WalkNpcOrc kOrc1ActorIndex, $00f8
    act_SetActorState1 kOrc1ActorIndex, eNpcOrc::Standing
    act_WaitFrames 30
    ;; Animate Anna getting thrown into the cell.
    act_SetActorState1 kOrc1ActorIndex, eNpcOrc::Throwing1
    act_WaitFrames 6
    act_SetActorState1 kOrc1ActorIndex, eNpcOrc::Throwing2
    act_SetAvatarPosX $00f0
    act_SetAvatarPosY $00b0
    act_SetAvatarVelX -365
    act_SetAvatarVelY -580
    act_SetCutsceneFlags bCutscene::AvatarRagdoll
    act_WaitFrames 15
    act_SetActorState1 kOrc1ActorIndex, eNpcOrc::Standing
    act_WaitUntilZ _AnnaHasLanded
    act_SetCutsceneFlags 0
    act_SetAvatarFlags bObj::FlipH | kPaletteObjAvatarNormal
    act_SetAvatarPose eAvatar::Slumping
    act_SetAvatarState 0
    act_SetAvatarVelX 0
    act_WaitFrames 4
    act_SetAvatarPose eAvatar::Sleeping
    ;; Animate the orc walking out.
    act_WaitFrames 30
    act_WalkNpcOrc kOrc1ActorIndex, $0118
    ;; Animate the prison gate closing.
    act_WaitUntilZ _CloseGate
    ;; Animate Anna standing back up.
    act_WaitFrames 90
    act_SetAvatarPose eAvatar::Slumping
    act_WaitFrames 30
    act_SetAvatarPose eAvatar::Kneeling
    act_WaitFrames 20
    act_ContinueExploring
_OpenGate:
    ldy #1  ; param: zero for shut
    jmp FuncC_Prison_Cell_TickGate  ; returns Z
_AnnaHasLanded:
    lda Zp_AvatarState_bAvatar
    and #bAvatar::Airborne
    rts
_CloseGate:
    ldy #0  ; param: zero for shut
    jmp FuncC_Prison_Cell_TickGate  ; returns Z
.ENDPROC

;;;=========================================================================;;;
