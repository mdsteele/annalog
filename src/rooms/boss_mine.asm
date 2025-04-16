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
.INCLUDE "../sample.inc"
.INCLUDE "boss_mine.inc"

.IMPORT DataA_Room_Mine_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GetGenericMoveSpeed
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawBoulderPlatform
.IMPORT FuncA_Objects_DrawCraneMachine
.IMPORT FuncA_Objects_DrawCraneRopeToPulley
.IMPORT FuncA_Objects_DrawTrolleyMachine
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitActorSmokeDirt
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_MachineResetRun
.IMPORT FuncA_Room_PlaySfxRumbling
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_DivAByBlockSizeAndClampTo9
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetAngleFromPointToAvatar
.IMPORT Func_GetRandomByte
.IMPORT Func_HarmAvatar
.IMPORT Func_InitActorProjFireball
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeFracture
.IMPORT Func_PlaySfxSample
.IMPORT Func_PlaySfxShootFire
.IMPORT Func_PlaySfxThump
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetMachineIndex
.IMPORT Func_SetPlatformTopLeftToPoint
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Func_SpawnExplosionAtPoint
.IMPORT Ppu_ChrBgAnimB4
.IMPORT Ppu_ChrBgAnimStatic
.IMPORT Ppu_ChrObjBoss1
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_PpuTransferLen_u8
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
kBoulderSpawnTop  = $0060
kBoulderSpawnLeft = $ffff & -$18

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

;;;=========================================================================;;;

;;; How many frames it takes for the conveyor to move one pixel.
.DEFINE kConveyorSlowdown 8

;;; The room pixel X-position of the right edge of the conveyor belt.
kConveyorRightEdge = $30

;;; The PPU address in the upper nametable for the leftmost tile of the
;;; conveyor belt.
.LINECONT +
Ppu_BossMineConveyorStart = \
    Ppu_Nametable0_sName + sName::Tiles_u8_arr + kScreenWidthTiles * 14 + 1
.LINECONT -

;;;=========================================================================;;;

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    Hiding      ; within the walls
    Burrowing   ; making the room shake just before emerging
    Emerging    ; emerging from the wall
    Shooting    ; firing projectiles
    Retreating  ; retreating back into the wall
    Hurt        ; was just hit by a boulder
    NUM_VALUES
.ENDENUM

;;; Locations that the boss in this room can be in.
.ENUM eBossLoc
    Hidden  ; not currently emerging/retreating from any exit
    Exit1   ; the leftmost exit
    Exit2
    Exit3
    Exit4   ; the rightmost exit
.ENDENUM

;;; Directions that the boss's eye can be looking towards.
.ENUM eEyeDir
    Left
    DownLeft
    Down
    DownRight
    Right
    NUM_VALUES
.ENDENUM

;;; The size of each one of the boss's exit locations, in tiles.
kBossExitWidthTiles  = 4
kBossExitHeightTiles = 4

;;; The room tile row for the top of each of the boss's exit locations.
kBossExit1TileRow = 11
kBossExit2TileRow =  9
kBossExit3TileRow = 15
kBossExit4TileRow = 11
;;; The room tile column for the left of each of the boss's exit locations.
kBossExit1TileCol =  9
kBossExit2TileCol = 15
kBossExit3TileCol = 17
kBossExit4TileCol = 21

;;; The PPU address in the upper nametable for the top-left tile of each of the
;;; boss's four exit locations.
.LINECONT +
Ppu_BossMineExit1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kBossExit1TileRow + kBossExit1TileCol
Ppu_BossMineExit2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kBossExit2TileRow + kBossExit2TileCol
Ppu_BossMineExit3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kBossExit3TileRow + kBossExit3TileCol
Ppu_BossMineExit4Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kBossExit4TileRow + kBossExit4TileCol
.LINECONT -

;;; The platform index for the boss's body.
kBossBodyPlatformIndex = 2

;;; How many boulder hits are needed to defeat the boss.
kBossInitHealth = 4

;;; How many waves of fireballs to shoot after emerging.
kBossNumFireballWaves = 6
;;; When shooting a fireball pair, this is the angle each fireball is off from
;;; center, measured in increments of tau/256.
kBossFireballSplitAngle = 12

;;; How many frames the boss spends burrowing before emerging from an exit.
kBossBurrowFrames = 50
;;; How many frames it takes the boss to emerge from the wall.
.DEFINE kBossEmergeFrames 31
;;; How many frames the boss is stunned for when damaged.
kBossHurtFrames = 120
;;; How many frames the boss waits, after you first enter the room, before
;;; taking action.
kBossInitCooldown = 120
;;; How many frames to pause between emerging and shooting the first fireball
;;; wave.
kBossFirstShootCooldown = 60
;;; How many frames to pause between subsequent fireball waves.
kBossSubsequentShootCooldown = 45

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8          .byte
    LeverRight_u8         .byte
    ;; What mode the boss is in.
    Current_eBossMode     .byte
    ;; The boss's current location.
    Current_eBossLoc      .byte
    ;; Which direction the boss's eye is currently looking in.
    Boss_eEyeDir          .byte
    ;; How many more boulder hits are needed before the boss dies.
    BossHealth_u8         .byte
    ;; Timer that ticks down each frame when nonzero.  Used to time transitions
    ;; between boss modes.
    BossCooldown_u8       .byte
    ;; How many more projectile waves to fire before changing modes.
    BossFireCount_u8      .byte
    ;; How emerged from the wall the boss is, from 0 (not at all) to
    ;; kBossEmergeFrames (completely).
    BossEmerge_u8         .byte
    ;; What state the boulder is in.
    BoulderState_eBoulder .byte
    ;; The current Y subpixel position of the boulder.
    BoulderSubY_u8        .byte
    ;; The current Y-velocity of the boulder, in subpixels per frame.
    BoulderVelY_i16       .word
    ;; A counter that increments each frame that the conveyor moves.
    ConveyorMotion_u8     .byte
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
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss1)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_BossMine_EnterRoom
    d_addr FadeIn_func_ptr, FuncC_Boss_Mine_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_BossMine_TickRoom
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
    d_addr Init_func_ptr, FuncC_Boss_MineTrolley_Init
    d_addr ReadReg_func_ptr, FuncC_Boss_MineTrolley_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BossMine_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BossMineTrolley_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_BossMineTrolley_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawTrolleyMachine
    d_addr Reset_func_ptr, FuncC_Boss_MineTrolley_Reset
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
    d_addr WriteReg_func_ptr, FuncA_Machine_BossMine_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BossMineCrane_TryMove
    d_addr TryAct_func_ptr, FuncC_Boss_MineCrane_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BossMineCrane_Tick
    d_addr Draw_func_ptr, FuncC_Boss_MineCrane_Draw
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
    d_word Left_i16,  $0088
    d_word Top_i16,   $0078
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
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kTrolleyMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kCraneMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC DataC_Boss_Mine_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossMine
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Mine_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_Mine_DrawBoss
    D_END
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Mine_TickBoss
_HarmAvatarIfCollision:
    lda Zp_RoomState + sState::Current_eBossLoc
    .assert eBossLoc::Hidden = 0, error
    beq @done
    jsr Func_SetPointToAvatarCenter
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done  ; no collision
    jsr Func_HarmAvatar
    @done:
_CoolDown:
    lda Zp_RoomState + sState::BossCooldown_u8
    beq @done
    dec Zp_RoomState + sState::BossCooldown_u8
    @done:
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
    d_entry table, Dead,       Func_Noop
    d_entry table, Hiding,     _BossHiding
    d_entry table, Burrowing,  _BossBurrowing
    d_entry table, Emerging,   _BossEmerging
    d_entry table, Shooting,   _BossShooting
    d_entry table, Retreating, _BossRetreating
    d_entry table, Hurt,       _BossHurt
    D_END
.ENDREPEAT
_BossHiding:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; Start burrowing out of an exit.
    lda #eBossMode::Burrowing
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossBurrowFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    @done:
    rts
_BossBurrowing:
    ;; Shake the room.
    lda Zp_RoomState + sState::BossCooldown_u8
    mod #4
    bne @noShake
    lda #2  ; param: num frames
    jsr Func_ShakeRoom
    lda #4  ; param: num frames
    jsr FuncA_Room_PlaySfxRumbling
    @noShake:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne _Return
    ;; Pick a random exit to emerge from.
    jsr Func_GetRandomByte
    and #$03
    tax
    lda _ExitLeft_u8_arr, x
    sta Ram_PlatformLeft_i16_0_arr + kBossBodyPlatformIndex
    add #kTileWidthPx * kBossExitWidthTiles
    sta Ram_PlatformRight_i16_0_arr + kBossBodyPlatformIndex
    lda _ExitTop_u8_arr, x
    sta Ram_PlatformTop_i16_0_arr + kBossBodyPlatformIndex
    adc #kTileHeightPx * kBossExitHeightTiles  ; carry is already clear
    sta Ram_PlatformBottom_i16_0_arr + kBossBodyPlatformIndex
    inx  ; param: eBossLoc::Exit* value
    stx Zp_RoomState + sState::Current_eBossLoc
    jsr FuncC_Boss_MineTransferExitEmerge
    ;; Spray dirt from the exit.
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    lda #2
    sta T3  ; loop index
    @dirtLoop:
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @dirtDone
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    ldy T3  ; loop index
    lda _DirtAngle_u8_arr3, y  ; param: angle
    jsr FuncA_Room_InitActorSmokeDirt  ; preserves T3+
    dec T3  ; loop index
    bpl @dirtLoop
    @dirtDone:
    ;; Start emerging from that exit.
    jsr Func_PlaySfxExplodeFracture
    lda #eBossMode::Emerging
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossEmergeFrames  ; param: num frames
    jmp Func_ShakeRoom
_DirtAngle_u8_arr3:
    .byte $a8, $c4, $d0
_BossEmerging:
    jsr FuncC_Boss_MineSetEyeDir
    lda Zp_RoomState + sState::BossEmerge_u8
    cmp #kBossEmergeFrames
    bge @fullyEmerged
    inc Zp_RoomState + sState::BossEmerge_u8
    rts
    @fullyEmerged:
    lda #eBossMode::Shooting
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossNumFireballWaves
    sta Zp_RoomState + sState::BossFireCount_u8
    lda #kBossFirstShootCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
_Return:
    rts
_BossShooting:
    jsr FuncC_Boss_MineSetEyeDir
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne _Return
    ;; If there are no more projectiles to fire, retreat.
    lda Zp_RoomState + sState::BossFireCount_u8
    beq _StartRetreating
    ;; Otherwise, shoot a fireball.
    @shoot:
    dec Zp_RoomState + sState::BossFireCount_u8
    lda #kBossSubsequentShootCooldown
    sta Zp_RoomState + sState::BossCooldown_u8
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    jsr Func_GetAngleFromPointToAvatar  ; returns A
    tay  ; angle to avatar
    jsr Func_GetRandomByte  ; preserves Y, returns A
    lsr a  ; shift bottom bit into C
    tya  ; angle to avatar
    bcc @fireOne
    pha  ; angle to avatar
    add #kBossFireballSplitAngle
    jsr FuncC_Boss_MineShootFireball
    pla  ; angle to avatar
    sub #kBossFireballSplitAngle
    @fireOne:
    jmp FuncC_Boss_MineShootFireball
_StartRetreating:
    lda #eBossMode::Retreating
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossEmergeFrames  ; param: num frames
    jsr FuncA_Room_PlaySfxRumbling
    lda #kBossEmergeFrames  ; param: num frames
    jmp Func_ShakeRoom
_BossHurt:
    ;; Wait for the cooldown to expire.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; If the boss is at zero health, it dies.  Otherwise, retreat.
    lda Zp_RoomState + sState::BossHealth_u8
    bne _StartRetreating
    .assert eBossMode::Dead = 0, error
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_BossRetreating:
    jsr FuncC_Boss_MineSetEyeDir
    lda Zp_RoomState + sState::BossEmerge_u8
    beq @fullyRetreated
    dec Zp_RoomState + sState::BossEmerge_u8
    rts
    @fullyRetreated:
    ldx Zp_RoomState + sState::Current_eBossLoc  ; param: eBossLoc::Exit* value
    jsr FuncC_Boss_MineTransferExitHide
    lda #eBossMode::Hiding
    sta Zp_RoomState + sState::Current_eBossMode
    lda #eBossLoc::Hidden
    sta Zp_RoomState + sState::Current_eBossLoc
    lda #90  ; TODO: make this a constant
    sta Zp_RoomState + sState::BossCooldown_u8
    rts
_ExitLeft_u8_arr:
    .byte kTileWidthPx * kBossExit1TileCol
    .byte kTileWidthPx * kBossExit2TileCol
    .byte kTileWidthPx * kBossExit3TileCol
    .byte kTileWidthPx * kBossExit4TileCol
_ExitTop_u8_arr:
    .byte kTileHeightPx * kBossExit1TileRow
    .byte kTileHeightPx * kBossExit2TileRow
    .byte kTileHeightPx * kBossExit3TileRow
    .byte kTileHeightPx * kBossExit4TileRow
.ENDPROC

;;; Sets Boss_eEyeDir so that the boss's eye is looking at the player avatar.
.PROC FuncC_Boss_MineSetEyeDir
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    jsr Func_GetAngleFromPointToAvatar  ; returns A
    add #$50
    div #$20
    tax
    lda _Dir_eEyeDir_arr8, x
    sta Zp_RoomState + sState::Boss_eEyeDir
    rts
_Dir_eEyeDir_arr8:
    .byte eEyeDir::Down, eEyeDir::Right,    eEyeDir::Right, eEyeDir::DownRight
    .byte eEyeDir::Down, eEyeDir::DownLeft, eEyeDir::Left,  eEyeDir::Left
.ENDPROC

;;; Shoots a single fireball from the boss's eye.
;;; @prereq Zp_Point*_i16 is set to the center of the boss's body.
;;; @param A The angle to fire at, measured in increments of tau/256.
.PROC FuncC_Boss_MineShootFireball
    sta T0  ; angle to fire at
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @done
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    lda T0  ; param: angle to fire at
    jsr Func_InitActorProjFireball
    jmp Func_PlaySfxShootFire
    @done:
    rts
.ENDPROC

.PROC FuncC_Boss_Mine_FadeInRoom
    ldx Zp_RoomState + sState::Current_eBossLoc  ; param: eBossLoc value
    .assert eBossLoc::Hidden = 0, error
    bne FuncC_Boss_MineTransferExitEmerge
    rts
.ENDPROC

;;; Buffers a PPU transfer to restore the original BG tiles for an exit
;;; location after the boss has retreated.
;;; @param X The eBossLoc::Exit* value.
.PROC FuncC_Boss_MineTransferExitHide
    ldy #0  ; tile ID index
    beq FuncC_Boss_MineTransferExit  ; unconditional
.ENDPROC

;;; Buffers a PPU transfer to draw the BG tiles for the boss emerging from the
;;; specified exit location.
;;; @param X The eBossLoc::Exit* value.
.PROC FuncC_Boss_MineTransferExitEmerge
    ldy #kTileIdBgAnimWyrmFirst  ; tile ID
    fall FuncC_Boss_MineTransferExit
.ENDPROC

;;; Buffers a PPU transfer to set the BG tiles for one of the boss's exit
;;; locations.
;;; @param X The eBossLoc::Exit* value.
;;; @param Y Either kTileIdBgAnimWyrmFirst to emerge, or 0 to hide.
.PROC FuncC_Boss_MineTransferExit
    dex
    lda _ExitPpuDest_ptr_0_arr, x
    sta T2  ; PPU dest addr (lo)
    ;; Buffer one transfer entry for each tile column of the exit.
    lda #kBossExitWidthTiles
    sta T1  ; outer loop counter
    ldx Zp_PpuTransferLen_u8
_OuterLoop:
    lda #kPpuCtrlFlagsVert
    sta Ram_PpuTransfer_arr, x
    inx
    lda #>Ppu_BossMineExit1Start
    .assert >Ppu_BossMineExit2Start = >Ppu_BossMineExit1Start, error
    .assert >Ppu_BossMineExit3Start = >Ppu_BossMineExit1Start, error
    .assert >Ppu_BossMineExit4Start = >Ppu_BossMineExit1Start, error
    sta Ram_PpuTransfer_arr, x
    inx
    lda T2  ; PPU dest addr (lo)
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kBossExitHeightTiles  ; transfer length
    sta Ram_PpuTransfer_arr, x
    inx
    ;; Populate the transfer entry payload, one byte for each tile row of the
    ;; exit.
    sta T0  ; inner loop counter
    @innerLoop:
    ;; Y is either a tile ID, or an index into _ExitPpuDest_ptr_0_arr.
    tya  ; tile ID or index
    cmp #kTileIdBgAnimWyrmFirst
    .linecont +
    .assert kTileIdBgAnimWyrmFirst >= \
            kBossExitWidthTiles * kBossExitHeightTiles, error
    .linecont -
    bge @write
    lda _TileId_u8_arr, y
    @write:
    sta Ram_PpuTransfer_arr, x
    iny  ; tile ID or index
    inx
    dec T0  ; inner loop counter
    bne @innerLoop
    ;; Proceed to the next transfer entry, for the next tile column.
    inc T2  ; PPU dest addr (lo)
    dec T1  ; outer loop counter
    bne _OuterLoop
    ;; Finish the transfer.
    stx Zp_PpuTransferLen_u8
    rts
_ExitPpuDest_ptr_0_arr:
    .byte <Ppu_BossMineExit1Start
    .byte <Ppu_BossMineExit2Start
    .byte <Ppu_BossMineExit3Start
    .byte <Ppu_BossMineExit4Start
_TileId_u8_arr:
:   .byte $00, $ab, $ab, $00, $ab, $aa, $aa, $ab
    .byte $ab, $aa, $aa, $ab, $00, $ab, $ab, $00
    .assert * - :- = kBossExitWidthTiles * kBossExitHeightTiles, error
.ENDPROC

;;; Draw function for the BossMine room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Mine_DrawRoom
_AnimateConveyor:
    ;; Prepare a PPU transfer entry.
    ldx Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda #>Ppu_BossMineConveyorStart
    sta Ram_PpuTransfer_arr, x
    inx
    lda #<Ppu_BossMineConveyorStart
    sta Ram_PpuTransfer_arr, x
    inx
    lda #5
    sta Ram_PpuTransfer_arr, x
    inx
    ;; Compute the tile ID to use for the center of the conveyor belt.
    lda Zp_RoomState + sState::ConveyorMotion_u8
    div #kConveyorSlowdown
    and #$03
    .assert kTileIdBgTerrainConveyorFirst .mod 4 = 0, error
    ora #kTileIdBgTerrainConveyorFirst
    ;; Fill the first 4 of 5 payload bytes of the transfer entry.
    ldy #4
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
    ;; The last payload byte is the tile ID for the end of the conveyor.
    .assert kTileIdBgTerrainConveyorFirst .mod 8 = 0, error
    ora #$04
    sta Ram_PpuTransfer_arr, x
    inx
    stx Zp_PpuTransferLen_u8
_DrawBoulder:
    ldx #kBoulderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawBoulderPlatform
_DrawBoss:
    ;; Set default CHR04 bank, in case boss isn't drawn.
    lda #<.bank(Ppu_ChrBgAnimStatic)
    sta Zp_Chr04Bank_u8
    jmp FuncA_Objects_DrawBoss
.ENDPROC

;;; Draw function for the mine boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Mine_DrawBoss
_AnimateEmerge:
    lda Zp_RoomState + sState::BossEmerge_u8
    .assert (kBossEmergeFrames + 1) .mod 4 = 0, error
    div #(kBossEmergeFrames + 1) / 4
    .assert .bank(Ppu_ChrBgAnimB4) .mod 4 = 0, error
    ora #<.bank(Ppu_ChrBgAnimB4)
    sta Zp_Chr04Bank_u8
_DrawEye:
    lda Zp_RoomState + sState::BossEmerge_u8
    cmp #(kBossEmergeFrames + 1) / 2
    blt @done
    ldx #kBossBodyPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldy Zp_RoomState + sState::Boss_eEyeDir
    lda _EyeOffsetX_u8_arr, y  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves Y
    lda _EyeOffsetY_u8_arr, y  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    ;; If the boss is in Hurt mode, flash its eye red.
    lda #0
    ldx Zp_RoomState + sState::Current_eBossMode
    cpx #eBossMode::Hurt
    bne @noFlash
    lda Zp_FrameCounter_u8
    and #$02
    beq @noFlash
    asl a  ; now A is 4
    @noFlash:
    .assert kTileIdObjBossMineEyeFirst .mod 8 = 0, error
    ora #kTileIdObjBossMineEyeFirst  ; param: first tile ID
    ldy #bObj::Pri | kPaletteObjBossMineEye  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape
    @done:
    rts
_EyeOffsetX_u8_arr:
    D_ARRAY .enum, eEyeDir
    d_byte Left,      14
    d_byte DownLeft,  14
    d_byte Down,      15
    d_byte DownRight, 16
    d_byte Right,     16
    D_END
_EyeOffsetY_u8_arr:
    D_ARRAY .enum, eEyeDir
    d_byte Left,      17
    d_byte DownLeft,  18
    d_byte Down,      19
    d_byte DownRight, 18
    d_byte Right,     17
    D_END
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_MineTrolley_Reset
    ;; Reset the crane machine (if it's not already resetting).
    lda Ram_MachineStatus_eMachine_arr + kCraneMachineIndex
    cmp #kFirstResetStatus
    bge @alreadyResetting
    ldx #kCraneMachineIndex  ; param: machine index
    jsr Func_SetMachineIndex
    jsr FuncA_Room_MachineResetRun
    ldx #kTrolleyMachineIndex  ; param: machine index
    jsr Func_SetMachineIndex
    @alreadyResetting:
    ;; Now reset the trolley machine itself.
    fall FuncC_Boss_MineTrolley_Init
.ENDPROC

.PROC FuncC_Boss_MineTrolley_Init
    lda #kTrolleyInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    rts
.ENDPROC

.PROC FuncC_Boss_MineCrane_InitReset
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    .assert kCraneInitGoalZ = 0, error
    sta Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    fall FuncC_Boss_Mine_DropBoulder
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
    sub #kTrolleyMinPlatformLeft - kTileWidthPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
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
    sub #kCraneMinPlatformTop - kTileHeightPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
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

;;; @prereq PRGA_Machine is loaded.
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

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_MineCrane_Draw
    jsr FuncA_Objects_DrawCraneMachine
    ldx #kTrolleyPlatformIndex  ; param: pulley platform index
    jmp FuncA_Objects_DrawCraneRopeToPulley
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Room init function for the BossMine room.
.PROC FuncA_Room_BossMine_EnterRoom
    ldax #DataC_Boss_Mine_sBoss  ; param: sBoss ptr
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
.PROC FuncA_Room_BossMine_TickRoom
    jsr FuncA_Room_BossMine_TickBoulder
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Performs per-frame upates for the boulder.
.PROC FuncA_Room_BossMine_TickBoulder
    ;; If a machine console is open, do nothing.
    lda Zp_ConsoleMachineIndex_u8
    bpl @done  ; console is open
    ;; Otherwise, branch based on the boulder's current mode.
    ldy Zp_RoomState + sState::BoulderState_eBoulder
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
    @done:
    rts
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBoulder
    d_entry table, Absent,     FuncA_Room_BossMine_TickBoulderAbsent
    d_entry table, OnConveyor, FuncA_Room_BossMine_TickBoulderOnConveyor
    d_entry table, OnGround,   FuncA_Room_BossMine_TickBoulderOnGround
    d_entry table, Grasped,    Func_Noop
    d_entry table, Falling,    FuncA_Room_BossMine_TickBoulderFalling
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame upates for the boulder when it's absent.
;;; @prereq BoulderState_eBoulder is eBoulder::Absent.
.PROC FuncA_Room_BossMine_TickBoulderAbsent
    ;; Spawn a new boulder.
    .assert eBoulder::OnConveyor = eBoulder::Absent + 1, error
    inc Zp_RoomState + sState::BoulderState_eBoulder
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kBoulderPlatformIndex
    ldax #kBoulderSpawnLeft
    stax Zp_PointX_i16
    ldax #kBoulderSpawnTop
    stax Zp_PointY_i16
    .assert >kBoulderSpawnTop = 0, error
    sta Zp_RoomState + sState::BoulderSubY_u8
    sta Zp_RoomState + sState::BoulderVelY_i16 + 0
    sta Zp_RoomState + sState::BoulderVelY_i16 + 1
    ldy #kBoulderPlatformIndex  ; param: platform index
    jmp Func_SetPlatformTopLeftToPoint
.ENDPROC

;;; Performs per-frame upates for the boulder when it's on the conveyor.
;;; @prereq BoulderState_eBoulder is eBoulder::OnConveyor.
.PROC FuncA_Room_BossMine_TickBoulderOnConveyor
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
.PROC FuncA_Room_BossMine_TickBoulderOnGround
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
    jsr FuncA_Room_BossMine_GetBoulderDistAboveFloor  ; returns Z
    beq @done
    lda #eBoulder::Falling
    sta Zp_RoomState + sState::BoulderState_eBoulder
    @done:
    rts
.ENDPROC

;;; Performs per-frame upates for the boulder when it's falling.
;;; @prereq BoulderState_eBoulder is eBoulder::Falling.
.PROC FuncA_Room_BossMine_TickBoulderFalling
    jsr FuncA_Room_BossMine_GetBoulderDistAboveFloor  ; returns A
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
_CheckForFloorImpact:
    ;; If the number of pixels to move this frame is >= the distance above the
    ;; floor, then the boulder is hitting the floor this frame.
    cmp T0  ; boulder dist above floor
    blt _MoveBoulderDownByA  ; not hitting the floor
    ;; If the boulder is moving fast enough, it should break when it hits the
    ;; floor.  Otherwise, it stays on the ground.
    ldy Zp_RoomState + sState::BoulderVelY_i16 + 1
    cpy #kBoulderBreakSpeed
    blt @landOnGround
    @breakOnGround:
    lda #eBoulder::Absent
    .assert eBoulder::Absent = 0, error
    beq @setState  ; unconditional
    @landOnGround:
    lda #eBoulder::OnGround
    @setState:
    sta Zp_RoomState + sState::BoulderState_eBoulder
    lda _ShakeFrames_u8_arr, y  ; param: num frames
    beq @noShake
    jsr Func_ShakeRoom  ; preserves T0+
    jsr Func_PlaySfxThump
    @noShake:
    ;; Zero the boulder's velocity, and move it to exactly hit the floor.
    lda #0
    sta Zp_RoomState + sState::BoulderSubY_u8
    sta Zp_RoomState + sState::BoulderVelY_i16 + 0
    sta Zp_RoomState + sState::BoulderVelY_i16 + 1
    lda T0  ; boulder dist above floor
_MoveBoulderDownByA:
    ldx #kBoulderPlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
_CheckForBossImpact:
    ;; If the boss isn't fully emerged, the boulder can't hit it.
    lda Zp_RoomState + sState::BossEmerge_u8
    cmp #kBossEmergeFrames
    blt @done  ; boss isn't fully emerged
    ;; Check if the boulder has hit the boss's eye.
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    ldy #kBoulderPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done  ; no collision
    ;; Damage the boss.
    lda #eSample::BossHurtE  ; param: eSample to play
    jsr Func_PlaySfxSample
    lda #eBossMode::Hurt
    sta Zp_RoomState + sState::Current_eBossMode
    dec Zp_RoomState + sState::BossHealth_u8
    lda #kBossHurtFrames
    sta Zp_RoomState + sState::BossCooldown_u8
    ;; Set the boulder's state to broken.
    lda #eBoulder::Absent
    sta Zp_RoomState + sState::BoulderState_eBoulder
    @done:
_BreakBoulderIfAbsent:
    ;; If the boulder should break (either because it hit the boss, or because
    ;; it hit the floor going fast enough), then BoulderState_eBoulder has
    ;; already been set to eBoulder::Absent.  If that's the case, animate the
    ;; boulder breaking; otherwise, we're done.
    lda Zp_RoomState + sState::BoulderState_eBoulder
    .assert eBoulder::Absent = 0, error
    bne @done  ; boulder is not breaking
    jsr Func_PlaySfxExplodeFracture
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kBoulderPlatformIndex
    ldy #kBoulderPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    jmp Func_SpawnExplosionAtPoint
    @done:
    rts
_ShakeFrames_u8_arr:
    .byte 0, 0, 8, 16, 24, 32, 32, 32
.ENDPROC

;;; Returns the distance between the floor and the bottom of the boulder.
;;; @prereq The boulder is not absent.
;;; @return A The distance to the floor, in pixels.
;;; @return Z Set if the boulder is exactly on the floor.
.PROC FuncA_Room_BossMine_GetBoulderDistAboveFloor
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

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Shared WriteReg implementation for the BossMineTrolley and BossMineCrane
;;; machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncA_Machine_BossMine_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_BossMineTrolley_TryMove
    cpx #eDir::Left
    beq _MoveLeft
_MoveRight:
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    cmp #kTrolleyMaxGoalX
    bge _Error
    tay
    bne @move
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    bne _Error
    @move:
    inc Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    bne _Success  ; unconditional
_MoveLeft:
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    beq _Error
    cmp #2
    bne @move
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    bne _Error
    @move:
    dec Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
_Success:
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncA_Machine_BossMineCrane_TryMove
    .assert eDir::Up = 0, error
    txa  ; eDir value
    beq _MoveUp
_MoveDown:
    lda Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    cmp #1
    beq _Error
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    cmp #kCraneMaxGoalZ
    bge _Error
    inc Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    bne _Success  ; unconditional
_MoveUp:
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    beq _Error
    dec Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
_Success:
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncA_Machine_BossMineTrolley_Tick
    ;; If the crane is resetting, wait until it's done.
    lda Ram_MachineStatus_eMachine_arr + kCraneMachineIndex
    cmp #kFirstResetStatus
    blt @craneDoneResetting
    rts
    @craneDoneResetting:
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
    ;; Move the trolley horizontally, as necessary.
    jsr FuncA_Machine_GetGenericMoveSpeed  ; returns A
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

.PROC FuncA_Machine_BossMineCrane_Tick
    ;; Calculate the desired Y-position for the top edge of the crane, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    .assert kCraneMaxGoalZ * kBlockHeightPx < $100, error
    mul #kBlockHeightPx  ; fits in one byte
    add #kCraneMinPlatformTop
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Move the crane vertically, as necessary.
    jsr FuncA_Machine_GetGenericMoveSpeed  ; returns A
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
