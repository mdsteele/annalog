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
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/launcher.inc"
.INCLUDE "../machines/lift.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/gate.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT FuncA_Objects_DrawLauncherMachine
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT FuncA_Objects_DrawRocksPlatformHorz
.IMPORT FuncA_Room_FindRocketActor
.IMPORT FuncA_Room_SetPointToAvatarCenter
.IMPORT FuncC_Prison_DrawGatePlatform
.IMPORT FuncC_Prison_OpenGateAndFlipLever
.IMPORT FuncC_Prison_TickGatePlatform
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjParticle
.IMPORT Func_InitActorProjRocket
.IMPORT Func_InitActorProjSmoke
.IMPORT Func_IsFlagSet
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_Noop
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetOrClearFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjPrison
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_CameraCanScroll_bool
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The minimum scroll-X value for this room.
kMinScrollX = $10

;;; The index of the passage that leads into the tunnel under the prison cell.
kTunnelPassageIndex = 1
;;; The index of the passage on the eastern side of the room.
kEasternPassageIndex = 2

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
    GateLever_u1 .byte
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
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPrison)
    d_addr Tick_func_ptr, FuncC_Prison_Cell_TickRoom
    d_addr Draw_func_ptr, FuncC_Prison_Cell_DrawRoom
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
    D_END
_TerrainData:
:   .incbin "out/data/prison_cell.room"
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
    d_addr Init_func_ptr, FuncC_Prison_CellLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Prison_CellLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Prison_CellLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Prison_CellLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncC_Prison_CellLift_InitReset
    D_END
    .assert * - :- = kLauncherMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellLauncher
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act
    d_byte Status_eDiagram, eDiagram::CannonRight  ; TODO
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, kLauncherPlatformIndex
    d_addr Init_func_ptr, FuncC_Prison_CellLauncher_InitReset
    d_addr ReadReg_func_ptr, FuncC_Prison_CellLauncher_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Prison_CellLauncher_TryMove
    d_addr TryAct_func_ptr, FuncC_Prison_CellLauncher_TryAct
    d_addr Tick_func_ptr, FuncC_Prison_CellLauncher_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLauncherMachine
    d_addr Reset_func_ptr, FuncC_Prison_CellLauncher_InitReset
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
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
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
    ;; TODO: Add orc guards.
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 9
    d_byte Target_u8, eDialog::PrisonCellPaper
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kLiftMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 13
    d_byte BlockCol_u8, 30
    d_byte Target_u8, kLauncherMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 19
    d_byte Target_u8, sState::GateLever_u1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::PrisonEscape
    d_byte SpawnBlock_u8, 9
    D_END
    .assert * - :- = kTunnelPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::PrisonEscape
    d_byte SpawnBlock_u8, 20
    D_END
    .assert * - :- = kEasternPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonCrossroad
    d_byte SpawnBlock_u8, 11
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 1
    d_byte Destination_eRoom, eRoom::GardenLanding
    d_byte SpawnBlock_u8, 25
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Called when the player avatar enters the PrisonCell room.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncC_Prison_Cell_EnterRoom
    sta Zp_Tmp1_byte  ; bSpawn value
_CheckIfReachedTunnel:
    ;; If the player has reached the tunnel before, then don't lock scrolling.
    ldx #eFlag::PrisonCellReachedTunnel  ; param: flag
    jsr Func_IsFlagSet  ; preserves X and Zp_Tmp*, returns Z
    bne @done
    ;; If the player enters from the tunnel (or from the eastern passage,
    ;; though normally that shouldn't be possible before reaching the tunnel),
    ;; then set the flag indicating that the tunnel has been reached, and don't
    ;; lock scrolling.
    lda Zp_Tmp1_byte  ; bSpawn value
    cmp #bSpawn::Passage | kTunnelPassageIndex
    beq @setFlag
    cmp #bSpawn::Passage | kEasternPassageIndex
    beq @setFlag
    ;; Otherwise, lock scrolling so that only the prison cell is visible.
    @lockScrolling:
    lda #0
    sta Zp_CameraCanScroll_bool
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
    ldy #sState::GateLever_u1  ; param: lever target
    ldx #kGatePlatformIndex  ; param: gate platform index
    jsr FuncC_Prison_OpenGateAndFlipLever
    @shut:
_InitRocksAndCrate:
    flag_bit Sram_ProgressFlags_arr, eFlag::GardenLandingDroppedIn
    bne @removeAllRocks
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonCellBlastedRocks
    bne @removeSomeRocks
    @loadRocketLauncher:
    inc Ram_MachineParam1_u8_arr + kLauncherMachineIndex  ; ammo count
    rts
    @removeAllRocks:
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kTrapFloorPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kEastCeilingPlatformIndex
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kCratePlatformIndex
    @removeSomeRocks:
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kMidCeilingPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kUpperFloor1PlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kUpperFloor2PlatformIndex
    rts
.ENDPROC

;;; Tick function for the PrisonCell room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Prison_Cell_TickRoom
_RocketImpact:
    ;; Find the rocket (if any).  If there isn't one, we're done.
    jsr FuncA_Room_FindRocketActor  ; returns C and X
    bcs @done
    ;; Check if the rocket has hit the breakable floor; if not, we're done.
    ;; (Note that no rocket can exist in this room if the breakable floor is
    ;; already gone.)
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kUpperFloor1PlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcc @done
    ;; Explode the rocket and break the floor.
    jsr Func_InitActorProjSmoke
    ;; TODO: more smoke/particles
    lda #30  ; param: shake frames
    jsr Func_ShakeRoom
    ;; TODO: play a sound
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kMidCeilingPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kUpperFloor1PlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kUpperFloor2PlatformIndex
    ldx #eFlag::PrisonCellBlastedRocks
    jsr Func_SetFlag
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
    jsr FuncA_Room_SetPointToAvatarCenter
    ldy #kTrapZonePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done
    ;; Collapse the trap floor.
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kTrapFloorPlatformIndex
    lda #2  ; param: shake frames
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
    jsr Func_InitActorProjParticle
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
    lda Zp_RoomState + sState::GateLever_u1  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::GateLever_u1  ; param: zero for shut
    ldx #kGatePlatformIndex  ; param: gate platform index
    lda #kGateBlockRow  ; param: block row
    jmp FuncC_Prison_TickGatePlatform
_ParticleAngle_u8_arr:
    .byte 52, 65, 70, 76
.ENDPROC

;;; Draw function for the PrisonCell room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Prison_Cell_DrawRoom
    ldx #kCratePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawCratePlatform
    ldx #kTrapFloorPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRocksPlatformHorz
    ldx #kMidCeilingPlatformIndex  ; param: platform index
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

.PROC FuncC_Prison_CellLift_InitReset
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

.PROC FuncC_Prison_CellLift_ReadReg
    lda #kLiftMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Prison_CellLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncC_Prison_CellLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncC_Prison_CellLauncher_InitReset
    lda #kLauncherInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLauncherMachineIndex
    rts
.ENDPROC

.PROC FuncC_Prison_CellLauncher_ReadReg
    lda Ram_PlatformLeft_i16_0_arr + kLauncherPlatformIndex
    sub #<(kLauncherMinPlatformLeft - kTileWidthPx)
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Prison_CellLauncher_TryMove
    lda #kLauncherMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncC_Prison_CellLauncher_TryAct
    ;; If the launcher is out of ammo, fail.
    lda Ram_MachineParam1_u8_arr + kLauncherMachineIndex  ; ammo count
    beq _Error
    ;; If the launcher is blocked, fail.
    lda Ram_MachineGoalHorz_u8_arr + kLauncherMachineIndex
    bne _Error
    ;; Fire a rocket.
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs _Finish
    dec Ram_MachineParam1_u8_arr + kLauncherMachineIndex  ; ammo count
    ldy #kLauncherPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    lda #5
    jsr Func_MovePointLeftByA  ; preserves X
    lda #4
    jsr Func_MovePointDownByA  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #eDir::Down  ; param: rocket direction
    jsr Func_InitActorProjRocket
    ;; TODO: play a sound
_Finish:
    lda #kLauncherActFrames  ; param: wait frames
    jmp FuncA_Machine_StartWaiting
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Prison_CellLauncher_Tick
    ldax #kLauncherMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PrisonCellPaper_sDialog
.PROC DataA_Dialog_PrisonCellPaper_sDialog
    .word ePortrait::Paper
    .byte "Day 87: By now there's$"
    .byte "probably not much time$"
    .byte "left to finish this.#"
    .word ePortrait::Paper
    .byte "I'm going to start$"
    .byte "pinning up all these$"
    .byte "pages. Maybe someday$"
    .byte "someone'll find them.#"
    .word ePortrait::Paper
    .byte "By then, I'm sure I'll$"
    .byte "be long gone.#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
