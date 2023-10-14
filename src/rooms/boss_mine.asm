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
.INCLUDE "../avatar.inc"
.INCLUDE "../boss.inc"
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

.IMPORT DataA_Room_Mine_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawBoulderPlatform
.IMPORT FuncA_Objects_DrawCraneMachine
.IMPORT FuncA_Objects_DrawCraneRopeToPulley
.IMPORT FuncA_Objects_DrawTrolleyMachine
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ppu_ChrBgAnimB0
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_Chr0cBank_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 3
kLeverRightDeviceIndex = 4

;;; The machine indices for the BossMineTrolley and BossMineCrane machines in
;;; this room.
kTrolleyMachineIndex = 0
kCraneMachineIndex   = 1

;;; The platform indices for the BossMineTrolley and BossMineCrane machines in
;;; this room.
kTrolleyPlatformIndex = 0
kCranePlatformIndex   = 1

;;; The initial and maximum permitted values for the crane's Z-goal.
kCraneInitGoalZ = 0
kCraneMaxGoalZ  = 2

;;; The initial and maximum permitted values for the trolley's X-goal.
kTrolleyInitGoalX = 9
kTrolleyMaxGoalX  = 9

;;; The minimum, initial, and maximum room pixel position for the top edge of
;;; the crane.
kCraneMinPlatformTop  = $30
kCraneInitPlatformTop = kCraneMinPlatformTop + kBlockHeightPx * kCraneInitGoalZ
kCraneMaxPlatformTop  = kCraneMinPlatformTop + kBlockHeightPx * kCraneMaxGoalZ

;;; The minimum, initial, and maximum room pixel position for the left edge of
;;; the trolley.
.LINECONT +
kTrolleyMinPlatformLeft = $20
kTrolleyInitPlatformLeft = \
    kTrolleyMinPlatformLeft + kBlockWidthPx * kTrolleyInitGoalX
kTrolleyMaxPlatformLeft = \
    kTrolleyMinPlatformLeft + kBlockWidthPx * kTrolleyMaxGoalX
.LINECONT +

;;;=========================================================================;;;

;;; The width and height of the boulder platform.
kBoulderWidthPx  = kBlockWidthPx
kBoulderHeightPx = kBlockHeightPx

;;; The room pixel positions for each side of the boulder platform when a new
;;; boulder is spawned.
kBoulderSpawnTop    = $0060
kBoulderSpawnBottom = kBoulderSpawnTop + kBoulderHeightPx
kBoulderSpawnLeft   = $ffff & -$18
kBoulderSpawnRight  = kBoulderSpawnLeft + kBoulderWidthPx

;;;=========================================================================;;;

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    Hiding  ; within the walls
    ;; TODO: other modes
    NUM_VALUES
.ENDENUM

;;; How many boulder hits are needed to defeat the boss.
kBossInitHealth = 8

;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120

;;; The platform index for the boss's body.
kBossBodyPlatformIndex = 2

;;; States that the boulder in this room can be in.
.ENUM eBoulder
    Absent      ; not present in the room
    OnConveyor  ; sitting on the conveyor belt
    OnGround    ; sitting on the ground
    Grasped     ; held by the crane
    Falling     ; in free fall
    NUM_VALUES
.ENDENUM

;;; The platform index for the boulder that can be dropped on the boss.
kBoulderPlatformIndex = 3

;;; How fast the boulder must be moving to break when it hits the floor.
kBoulderBreakSpeed = 4

;;; How many frames it takes for the conveyor to move one pixel.
.DEFINE kConveyorSlowdown 8

;;; The room pixel X-position of the right edge of the conveyor belt.
kConveyorRightEdge = $30

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8  .byte
    LeverRight_u8 .byte
    ;; What mode the boss is in.
    Current_eBossMode .byte
    ;; How many more boulder hits are needed before the boss dies.
    BossHealth_u8 .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8 .byte
    ;; What state the boulder is in.
    BoulderState_eBoulder .byte
    ;; The current Y subpixel position of the boulder.
    BoulderSubY_u8 .byte
    ;; The current Y-velocity of the boulder, in subpixels per frame.
    BoulderVelY_i16 .word
    ;; A counter that increments each frame that the conveyor moves.
    ConveyorMotion_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.EXPORT DataC_Boss_Mine_sRoom
.PROC DataC_Boss_Mine_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Mine
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 18
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Boss_Mine_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Boss_Mine_TickRoom
    d_addr Draw_func_ptr, FuncC_Boss_Mine_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/boss_mine.room"
    .assert * - :- = 16 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kTrolleyMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossMineTrolley
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Trolley
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "L", "R", "X", 0
    d_byte MainPlatform_u8, kTrolleyPlatformIndex
    d_addr Init_func_ptr, FuncC_Boss_MineTrolley_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_MineTrolley_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Boss_Mine_WriteReg
    d_addr TryMove_func_ptr, FuncC_Boss_MineTrolley_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Boss_MineTrolley_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawTrolleyMachine
    d_addr Reset_func_ptr, FuncC_Boss_MineTrolley_InitReset
    D_END
    .assert * - :- = kCraneMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossMineCrane
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Crane
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, "L", "R", 0, "Z"
    d_byte MainPlatform_u8, kCranePlatformIndex
    d_addr Init_func_ptr, FuncC_Boss_MineCrane_InitReset
    d_addr ReadReg_func_ptr, FuncC_Boss_MineCrane_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Boss_Mine_WriteReg
    d_addr TryMove_func_ptr, FuncC_Boss_MineCrane_TryMove
    d_addr TryAct_func_ptr, FuncC_Boss_MineCrane_TryAct
    d_addr Tick_func_ptr, FuncC_Boss_MineCrane_Tick
    d_addr Draw_func_ptr, FuncA_Objects_BossMineCrane_Draw
    d_addr Reset_func_ptr, FuncC_Boss_MineCrane_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kTrolleyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kTrolleyInitPlatformLeft
    d_word Top_i16,   $0020
    D_END
    .assert * - :- = kCranePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kTrolleyInitPlatformLeft
    d_word Top_i16, kCraneInitPlatformTop
    D_END
    .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $004c
    d_word Top_i16,   $005c
    D_END
    .assert * - :- = kBoulderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kBoulderWidthPx
    d_byte HeightPx_u8, kBoulderHeightPx
    d_word Left_i16, kBoulderSpawnLeft
    d_word Top_i16,  kBoulderSpawnTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 3
    d_byte Target_byte, eRoom::MineCollapse
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eFlag::UpgradeRam4
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eFlag::BreakerMine
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kTrolleyMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kCraneMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Boss_Mine_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossMine
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Mine_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_Mine_DrawBoss
    D_END
.ENDPROC

;;; Room init function for the BossMine room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Mine_EnterRoom
    ldax #FuncC_Boss_Mine_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    bne _BossIsDead
_BossIsAlive:
    lda #kBossInitHealth
    sta Zp_RoomState + sState::BossHealth_u8
    lda #kBossInitCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::Hiding
    sta Zp_RoomState + sState::Current_eBossMode
_BossIsDead:
    rts
.ENDPROC

;;; Room tick function for the BossMine room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Mine_TickRoom
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Mine_TickBoss
    jsr FuncC_Boss_Mine_TickBoulder
_CoolDown:
    ;; Wait for cooldown to expire.
    dec Zp_RoomState + sState::BossCooldown_u8
    beq _CheckMode
    rts
_CheckMode:
    ;; Branch based on the current boss mode.
    ldy Zp_RoomState + sState::Current_eBossMode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBossMode
    d_entry table, Dead,   Func_Noop
    d_entry table, Hiding, _BossHiding
    D_END
.ENDREPEAT
_BossHiding:
    ;; TODO: implement real behavior
    rts
.ENDPROC

;;; Performs per-frame upates for the boulder.
.PROC FuncC_Boss_Mine_TickBoulder
    ldy Zp_RoomState + sState::BoulderState_eBoulder
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBoulder
    d_entry table, Absent,     FuncC_Boss_Mine_TickBoulderAbsent
    d_entry table, OnConveyor, FuncC_Boss_Mine_TickBoulderOnConveyor
    d_entry table, OnGround,   FuncC_Boss_Mine_TickBoulderOnGround
    d_entry table, Grasped,    Func_Noop
    d_entry table, Falling,    FuncC_Boss_Mine_TickBoulderFalling
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame upates for the boulder when it's on the conveyor.
;;; @prereq BoulderState_eBoulder is eBoulder::Absent.
.PROC FuncC_Boss_Mine_TickBoulderAbsent
    ;; Spawn a new boulder.
    lda #<kBoulderSpawnLeft
    sta Ram_PlatformLeft_i16_0_arr + kBoulderPlatformIndex
    lda #<kBoulderSpawnRight
    sta Ram_PlatformRight_i16_0_arr + kBoulderPlatformIndex
    lda #>kBoulderSpawnLeft
    sta Ram_PlatformLeft_i16_1_arr + kBoulderPlatformIndex
    .assert >kBoulderSpawnRight = >kBoulderSpawnLeft, error
    sta Ram_PlatformRight_i16_1_arr + kBoulderPlatformIndex
    lda #<kBoulderSpawnTop
    sta Ram_PlatformTop_i16_0_arr + kBoulderPlatformIndex
    lda #<kBoulderSpawnBottom
    sta Ram_PlatformBottom_i16_0_arr + kBoulderPlatformIndex
    lda #>kBoulderSpawnTop
    sta Ram_PlatformTop_i16_1_arr + kBoulderPlatformIndex
    .assert >kBoulderSpawnBottom = >kBoulderSpawnTop, error
    sta Ram_PlatformBottom_i16_1_arr + kBoulderPlatformIndex
    .assert >kBoulderSpawnBottom = 0, error
    sta Zp_RoomState + sState::BoulderSubY_u8
    sta Zp_RoomState + sState::BoulderVelY_i16 + 0
    sta Zp_RoomState + sState::BoulderVelY_i16 + 1
    lda #eBoulder::OnConveyor
    sta Zp_RoomState + sState::BoulderState_eBoulder
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kBoulderPlatformIndex
    rts
.ENDPROC

;;; Performs per-frame upates for the boulder when it's on the conveyor.
;;; @prereq BoulderState_eBoulder is eBoulder::OnConveyor.
.PROC FuncC_Boss_Mine_TickBoulderOnConveyor
    ;; Make the conveyor move the boulder.
    inc Zp_RoomState + sState::ConveyorMotion_u8
    lda Zp_RoomState + sState::ConveyorMotion_u8
    and #kConveyorSlowdown - 1
    bne @done
    ldx #kBoulderPlatformIndex  ; param: platform index
    lda #1  ; param: move delta
    jsr Func_MovePlatformHorz
    ;; One the boulder reaches the end of the conveyor, change state to
    ;; OnGround (so that the conveyor will stop).
    lda Ram_PlatformRight_i16_0_arr + kBoulderPlatformIndex
    cmp #kConveyorRightEdge
    bne @done
    lda #eBoulder::OnGround
    sta Zp_RoomState + sState::BoulderState_eBoulder
    @done:
    rts
.ENDPROC

;;; Performs per-frame upates for the boulder when it's on the ground.
;;; @prereq BoulderState_eBoulder is eBoulder::OnGround.
.PROC FuncC_Boss_Mine_TickBoulderOnGround
    ;; If the boulder is not aligned to the block grid, slide it into place.
    lda Ram_PlatformLeft_i16_0_arr + kBoulderPlatformIndex
    .assert kBlockWidthPx = $10, error
    and #$0f
    beq @done
    cmp #$08
    bge @slideRight
    @slideLeft:
    lda #<-1
    bmi @slide  ; unconditional
    @slideRight:
    lda #1
    @slide:
    ldx #kBoulderPlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz
    ;; If the boulder has slid off a cliff and is now above the ground, make
    ;; it start falling.
    jsr FuncC_Boss_Mine_GetBoulderDistAboveFloor  ; returns Z
    beq @done
    lda #eBoulder::Falling
    sta Zp_RoomState + sState::BoulderState_eBoulder
    @done:
    rts
.ENDPROC

;;; Performs per-frame upates for the boulder when it's falling.
;;; @prereq BoulderState_eBoulder is eBoulder::Falling.
.PROC FuncC_Boss_Mine_TickBoulderFalling
    jsr FuncC_Boss_Mine_GetBoulderDistAboveFloor  ; returns A
    sta T0  ; boulder dist above floor
    ;; Apply gravity.
    lda Zp_RoomState + sState::BoulderVelY_i16 + 0
    add #<kAvatarGravity
    sta Zp_RoomState + sState::BoulderVelY_i16 + 0
    lda Zp_RoomState + sState::BoulderVelY_i16 + 1
    adc #>kAvatarGravity
    sta Zp_RoomState + sState::BoulderVelY_i16 + 1
    ;; Update subpixels, and calculate the number of whole pixels to move,
    ;; storing the latter in A.
    lda Zp_RoomState + sState::BoulderSubY_u8
    add Zp_RoomState + sState::BoulderVelY_i16 + 0
    sta Zp_RoomState + sState::BoulderSubY_u8
    lda #0
    adc Zp_RoomState + sState::BoulderVelY_i16 + 1
    ;; If the number of pixels to move this frame is >= the distance above the
    ;; floor, then the boulder is hitting the floor this frame.
    cmp T0  ; boulder dist above floor
    blt @moveBoulder
    ;; If the boulder is moving fast enough, it should break when it hits the
    ;; floor.  Otherwise, it stays on the ground.
    lda Zp_RoomState + sState::BoulderVelY_i16 + 1
    cmp #kBoulderBreakSpeed
    blt @landOnGround
    @breakOnGround:
    lda #eBoulder::Absent
    .assert eBoulder::Absent = 0, error
    beq @setState  ; unconditional
    @landOnGround:
    lda #eBoulder::OnGround
    @setState:
    sta Zp_RoomState + sState::BoulderState_eBoulder
    ;; Zero the boulder's velocity, and move it to exactly hit the floor.
    lda #0
    sta Zp_RoomState + sState::BoulderSubY_u8
    sta Zp_RoomState + sState::BoulderVelY_i16 + 0
    sta Zp_RoomState + sState::BoulderVelY_i16 + 1
    lda T0  ; cage dist above floor
    ;; Move the boulder platform.
    @moveBoulder:
    ldx #kBoulderPlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    ;; TODO: check if the boulder has hit the boss
    ;; If the boulder should break (either because it hit the boss, or because
    ;; it hit the floor going fast enough), animate it breaking.
    lda Zp_RoomState + sState::BoulderState_eBoulder
    .assert eBoulder::Absent = 0, error
    bne @doneBreaking
    ;; TODO: play a sound for the boulder breaking
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kBoulderPlatformIndex
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @doneBreaking
    ldy #kBoulderPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_InitActorSmokeExplosion
    @doneBreaking:
    rts
.ENDPROC

;;; Returns the distance between the floor and the bottom of the boulder.
;;; @prereq The boulder is not absent.
;;; @return A The distance to the floor, in pixels.
;;; @return Z Set if the boulder is exactly on the floor.
.PROC FuncC_Boss_Mine_GetBoulderDistAboveFloor
    lda Ram_PlatformRight_i16_0_arr + kBoulderPlatformIndex
    cmp #$60
    bge @floorLowest
    cmp #$50
    bge @floorDoor
    cmp #$31
    bge @floorHighest
    @floorConveyor:
    lda #$70
    bne @setFloorPos  ; unconditional
    @floorHighest:
    lda #$50
    bne @setFloorPos  ; unconditional
    @floorDoor:
    lda #$c0
    bne @setFloorPos  ; unconditional
    @floorLowest:
    lda #$d0
    @setFloorPos:
    sub Ram_PlatformBottom_i16_0_arr + kBoulderPlatformIndex
    rts
.ENDPROC

;;; Draw function for the BossMine room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Mine_DrawRoom
_AnimateConveyor:
    lda Zp_RoomState + sState::ConveyorMotion_u8
    div #kConveyorSlowdown
    and #$03
    add #<.bank(Ppu_ChrBgAnimB0)
    sta Zp_Chr0cBank_u8
_DrawBoulder:
    ldx #kBoulderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawBoulderPlatform
_DrawBoss:
    jmp FuncA_Objects_DrawBoss
.ENDPROC

;;; Draw function for the mine boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Mine_DrawBoss
    ;; TODO: draw the boss
    rts
.ENDPROC

.PROC FuncC_Boss_MineTrolley_InitReset
    lda #kTrolleyInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    rts
.ENDPROC

.PROC FuncC_Boss_MineCrane_InitReset
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    .assert kCraneInitGoalZ = 0, error
    sta Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    .assert * = FuncC_Boss_Mine_DropBoulder, error, "fallthrough"
.ENDPROC

;;; If the boulder is currently grasped by the crane, makes it start falling.
;;; Otherwise, does nothing.
.PROC FuncC_Boss_Mine_DropBoulder
    lda Zp_RoomState + sState::BoulderState_eBoulder
    cmp #eBoulder::Grasped
    bne @done
    lda #eBoulder::Falling
    sta Zp_RoomState + sState::BoulderState_eBoulder
    @done:
    rts
.ENDPROC

;;; ReadReg implementation for the BossMineTrolley machine.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Boss_MineTrolley_ReadReg
    cmp #$e
    bne FuncC_Boss_Mine_ReadRegLR
_RegX:
    .assert kTrolleyMaxPlatformLeft < $100, error
    lda Ram_PlatformLeft_i16_0_arr + kTrolleyPlatformIndex
    sub #kTrolleyMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
.ENDPROC

;;; ReadReg implementation for the BossMineCrane machine.
;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Boss_MineCrane_ReadReg
    cmp #$f
    bne FuncC_Boss_Mine_ReadRegLR
_RegZ:
    .assert kCraneMaxPlatformTop < $100, error
    lda Ram_PlatformTop_i16_0_arr + kCranePlatformIndex
    sub #kCraneMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

;;; Reads the shared "L" or "R" lever register for the BossMineTrolley and
;;; BossMineCrane machines.
;;; @param A The register to read ($c or $d).
;;; @return A The value of the register (0-9).
.PROC FuncC_Boss_Mine_ReadRegLR
    cmp #$d
    beq _RegR
_RegL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_RegR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

;;; Shared WriteReg implementation for the BossMineTrolley and BossMineCrane
;;; machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq PRGA_Machine is loaded.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncC_Boss_Mine_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncC_Boss_MineTrolley_TryMove
    cpx #eDir::Left
    beq @moveLeft
    @moveRight:
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    cmp #kTrolleyMaxGoalX
    bge @error
    inc Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    bne @success  ; unconditional
    @moveLeft:
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    beq @error
    dec Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    @success:
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Boss_MineCrane_TryMove
    .assert eDir::Up = 0, error
    txa
    beq @moveUp
    @moveDown:
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    cmp #kCraneMaxGoalZ
    bge @error
    inc Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    bne @success  ; unconditional
    @moveUp:
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    beq @error
    dec Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    @success:
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Boss_MineCrane_TryAct
    lda Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    eor #$ff
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    bpl _LetGo
_TryGrasp:
    lda Zp_RoomState + sState::BoulderState_eBoulder
    cmp #eBoulder::OnGround
    bne _StartWaiting
    lda Ram_PlatformLeft_i16_0_arr + kCranePlatformIndex
    cmp Ram_PlatformLeft_i16_0_arr + kBoulderPlatformIndex
    bne _StartWaiting
    lda Ram_PlatformBottom_i16_0_arr + kCranePlatformIndex
    cmp Ram_PlatformTop_i16_0_arr + kBoulderPlatformIndex
    bne _StartWaiting
    lda #eBoulder::Grasped
    sta Zp_RoomState + sState::BoulderState_eBoulder
    .assert eBoulder::Grasped <> 0, error
    bne _StartWaiting  ; unconditional
_LetGo:
    jsr FuncC_Boss_Mine_DropBoulder
_StartWaiting:
    lda #kCraneActCooldown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

.PROC FuncC_Boss_MineTrolley_Tick
    ;; Calculate the desired X-position for the left edge of the trolley, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    .assert kTrolleyMaxGoalX * kBlockWidthPx < $100, error
    mul #kBlockWidthPx  ; fits in one byte
    add #<kTrolleyMinPlatformLeft
    sta Zp_PointX_i16 + 0
    lda #0
    adc #>kTrolleyMinPlatformLeft
    sta Zp_PointX_i16 + 1
    ;; Determine the horizontal speed of the trolley (faster if resetting).
    lda #1
    ldy Ram_MachineStatus_eMachine_arr + kTrolleyMachineIndex
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the trolley horizontally, as necessary.
    ldx #kTrolleyPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z and A
    beq @done
    ;; If the trolley moved, move the crane too (and the boulder, if it's being
    ;; grasped by the crane).
    ldy Zp_RoomState + sState::BoulderState_eBoulder
    cpy #eBoulder::Grasped
    bne @noBoulder
    ldx #kBoulderPlatformIndex  ; param: platform index
    pha  ; move delta
    jsr Func_MovePlatformHorz
    pla  ; param: move delta
    @noBoulder:
    ldx #kCranePlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

.PROC FuncC_Boss_MineCrane_Tick
    ;; Calculate the desired Y-position for the top edge of the crane, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    .assert kCraneMaxGoalZ * kBlockHeightPx < $100, error
    mul #kBlockHeightPx  ; fits in one byte
    add #kCraneMinPlatformTop
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the crane (faster if resetting).
    lda #1
    ldy Ram_MachineStatus_eMachine_arr + kCraneMachineIndex
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the crane vertically, as necessary.
    ldx #kCranePlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopTowardPointY  ; returns Z and A
    beq @done
    ;; If the crane moved, move the boulder too (if it's being grasped).
    ldy Zp_RoomState + sState::BoulderState_eBoulder
    cpy #eBoulder::Grasped
    bne @noBoulder
    ldx #kBoulderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @noBoulder:
    rts
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_BossMineCrane_Draw
    jsr FuncA_Objects_DrawCraneMachine
    ldx #kTrolleyPlatformIndex  ; param: pulley platform index
    jmp FuncA_Objects_DrawCraneRopeToPulley
.ENDPROC

;;;=========================================================================;;;
