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
.INCLUDE "../boss.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/winch.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../sample.inc"
.INCLUDE "boss_crypt.inc"

.IMPORT DataA_Room_Crypt_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ExpireFireballsWithinSolidPlatform
.IMPORT FuncA_Machine_ExpireProjectilesWithinSolidPlatform
.IMPORT FuncA_Machine_GetWinchHorzSpeed
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WinchReachedGoal
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawPlatformCryptBricksVert
.IMPORT FuncA_Objects_DrawWinchMachineWithSpikeball
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_SetPointToBossBodyCenter
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_DirectPpuTransfer
.IMPORT Func_DivAByBlockSizeAndClampTo9
.IMPORT Func_DivMod
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetAngleFromPointToAvatar
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorProjEmber
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_PlaySfxSample
.IMPORT Func_PlaySfxShootFire
.IMPORT Func_ResetWinchMachineState
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_ShootFireballFromPoint
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Ppu_ChrBgAnimB0
.IMPORT Ppu_ChrObjBoss1
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_IrqTmp_byte
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 4
kLeverRightDeviceIndex = 5

;;; The machine index for the CryptTombWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptTombWinch machine, the spikeball that
;;; hangs from its chain, and the side walls.
kWinchPlatformIndex      = 0
kSpikeballPlatformIndex  = 1
kLeftWallPlatformIndex   = 2
kRightWallPlatformIndex  = 3

;;; The initial and maximum permitted values for the winch's X-goal.
kWinchInitGoalX = 5
kWinchMaxGoalX  = 9

;;; The initial and maximum permitted values for the winch's Z-goal.
kWinchInitGoalZ = 2
kWinchMaxGoalZ = 9

;;; The minimum and initial room pixel position for the left edge of the winch.
.LINECONT +
kWinchMinPlatformLeft = $30
kWinchInitPlatformLeft = \
    kWinchMinPlatformLeft + kBlockWidthPx * kWinchInitGoalX
.LINECONT +

;;; The minimum and initial room pixel position for the top edge of the
;;; crusher.
.LINECONT +
kSpikeballMinPlatformTop = $32
kSpikeballInitPlatformTop = \
    kSpikeballMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;; Enum for the steps of the CryptTombWinch machine's reset sequence (listed
;;; in reverse order).
.ENUM eResetSeq
    Middle = 0  ; last step: move to mid-center position
    TopCenter   ; move up to top, then move horizontally to center
.ENDENUM

;;;=========================================================================;;;

;;; The room pixel Y-positions for the top and bottom of the zone that the boss
;;; can move within.
kBossZoneTopY    = $60
kBossZoneBottomY = $90

;;; The tile row/col in the lower nametable for the top-left corner of the
;;; boss's BG tiles.
kBossStartRow = 7
kBossStartCol = 0

;;; The width and height of the boss's BG tile grid.
kBossWidthTiles = 6
kBossHeightTiles = 4
kBossWidthPx = kBossWidthTiles * kTileWidthPx
kBossHeightPx = kBossHeightTiles * kTileHeightPx

;;; The PPU addresses for the start (left) of each row of the boss's BG tiles.
.LINECONT +
Ppu_BossRow0Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossStartRow + 0) + kBossStartCol
Ppu_BossRow1Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossStartRow + 1) + kBossStartCol
Ppu_BossRow2Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossStartRow + 2) + kBossStartCol
Ppu_BossRow3Start = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBossStartRow + 3) + kBossStartCol
.ASSERT (kBossStartRow + 1) .mod 4 = 0, error
.ASSERT (kBossStartCol + 2) .mod 4 = 2, error
Ppu_BossEyeAttrs = Ppu_Nametable3_sName + sName::Attrs_u8_arr64 + \
    ((kBossStartRow + 1) / 4) * 8 + (kBossStartCol / 4)
.LINECONT -

;;; The initial room pixel position for the center of the boss's eye.
kBossInitPosX = $a8
kBossInitPosY = $78

;;; How many spikeball hits are needed to defeat the boss.
kBossInitHealth = 6

;;; The maximum speed of the boss, in pixels per frame.
kBossMaxSpeedX = 2
kBossMaxSpeedY = 2

;;; If the boss's horizontal speed is at least this many subpixels per frame,
;;; the the boss's eye will lean in that direction.
kBossLeanSpeed = $40

;;; How far the boss should move horizontally when hurt, in pixels.
kBossHurtMoveDistPx = 60

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    Waiting   ; pausing before choosing a new goal position
    Firing    ; moving to goal position, shooting fireballs
    Strafing  ; moving from one side of the room to the other, dropping embers
    Hurt      ; just got hit, moving away and eye flashing
    NUM_VALUES
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

;;; The platform index for the boss's body.
kBossBodyPlatformIndex = 4

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8      .byte
    LeverRight_u8     .byte
    ;; Which step of its reset sequence the CryptTombWinch machine is on.
    Winch_eResetSeq   .byte
    ;; What mode the boss is in.
    Current_eBossMode .byte
    ;; Which direction the boss's eye is currently looking in.
    Boss_eEyeDir      .byte
    ;; How many more hits until the boss is dead.
    BossHealth_u8     .byte
    ;; How many more frames until the boss can fire again.
    BossCooldown_u8   .byte
    ;; How many more times the boss should shoot before changing modes.
    BossFireCount_u8  .byte
    ;; The room pixel position where the boss wants to move its center.
    BossGoalPosX_u8   .byte
    BossGoalPosY_u8   .byte
    ;; The boss's current subpixel position.
    BossSubX_u8       .byte
    BossSubY_u8       .byte
    ;; The boss's current velocity, in subpixels per frame.
    BossVelX_i16      .word
    BossVelY_i16      .word
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Boss"

.EXPORT DataC_Boss_Crypt_sRoom
.PROC DataC_Boss_Crypt_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Unsafe | eArea::Crypt
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 0
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss1)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_BossCrypt_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_BossCrypt_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_BossCrypt_TickRoom
    d_addr Draw_func_ptr, FuncA_Objects_DrawBoss
    D_END
_TerrainData:
:   .incbin "out/rooms/boss_crypt.room"
    .assert * - :- = 16 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::BossCryptWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveHV | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, "L", "R", "X", "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncC_Boss_CryptWinch_Init
    d_addr ReadReg_func_ptr, FuncC_Boss_CryptWinch_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BossCryptWinch_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_BossCryptWinch_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_BossCryptWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Boss_CryptWinch_Tick
    d_addr Draw_func_ptr, FuncC_Boss_CryptWinch_Draw
    d_addr Reset_func_ptr, FuncC_Boss_CryptWinch_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWinchPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16,   $0020
    D_END
    .assert * - :- = kSpikeballPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kSpikeballWidthPx
    d_byte HeightPx_u8, kSpikeballHeightPx
    d_word Left_i16, kWinchInitPlatformLeft + 2
    d_word Top_i16, kSpikeballInitPlatformTop
    D_END
    .assert * - :- = kLeftWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0018
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kRightWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kBossBodyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kBossWidthPx
    d_byte HeightPx_u8, kBossHeightPx
    d_word Left_i16, kBossInitPosX - kBossWidthPx / 2
    d_word Top_i16, kBossInitPosY - kBossHeightPx / 2
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Spike
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $00de
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Unlocked
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eRoom::CryptTomb
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eFlag::UpgradeOpRest
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 2
    d_byte Target_byte, eFlag::BreakerCrypt
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kWinchMachineIndex
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 4
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 11
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC DataC_Boss_Crypt_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossCrypt
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Crypt_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_Crypt_DrawBoss
    D_END
.ENDPROC

.PROC FuncC_Boss_CryptWinch_ReadReg
    cmp #$d
    blt _ReadL
    beq _ReadR
    cmp #$e
    beq _ReadX
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex
    sub #kSpikeballMinPlatformTop - kTileHeightPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kWinchPlatformIndex
    sub #kWinchMinPlatformLeft - kTileWidthPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
_ReadL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_ReadR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Boss_CryptWinch_Tick
    jsr FuncA_Machine_BossCryptWinch_TickMove  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
    lda Zp_RoomState + sState::Winch_eResetSeq
    bne FuncC_Boss_CryptWinch_ContinueResetting
    jmp FuncA_Machine_WinchReachedGoal
.ENDPROC

;;; Reset function for the BossCryptWinch machine.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_CryptWinch_Reset
_MakeBossDodge:
    ;; To prevent cheesing the boss, if the boss is in Firing or Waiting mode
    ;; when the machine is reset or reprogrammed, make it dodge to safety
    ;; (under one of the terrain blocks) and shoot back.
    ldx Zp_RoomState + sState::Current_eBossMode
    cpx #eBossMode::Firing
    beq @doDodge
    cpx #eBossMode::Waiting
    bne @done
    @doDodge:
    jsr FuncC_Boss_Crypt_StartFiring
    jsr FuncA_Room_SetPointToBossBodyCenter
    lda Zp_PointX_i16 + 0
    bmi @rightSide
    @leftSide:
    lda #$58
    bne @setGoalPos  ; unconditional
    @rightSide:
    lda #$a8
    @setGoalPos:
    sta Zp_RoomState + sState::BossGoalPosX_u8
    lda #$7c
    sta Zp_RoomState + sState::BossGoalPosY_u8
    @done:
_ResetMachine:
    ;; Reset levers and begin machine reset sequence.
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    fall FuncC_Boss_CryptWinch_ContinueResetting
.ENDPROC

;;; Shared helper function for FuncC_Boss_CryptWinch_Tick and
;;; FuncC_Boss_CryptWinch_Reset.  Note that no particular PRGA bank is
;;; guaranteed to be loaded when this is called.
.PROC FuncC_Boss_CryptWinch_ContinueResetting
    jsr Func_ResetWinchMachineState
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    cmp #3
    blt _Outer
    cmp #7
    blt _Inner
_Outer:
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda #1
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    lda #eResetSeq::TopCenter
    sta Zp_RoomState + sState::Winch_eResetSeq
    rts
_Inner:
    fall FuncC_Boss_CryptWinch_Init
.ENDPROC

;;; Init function for the BossCryptWinch machine.  Note that no particular
;;; PRGA bank is guaranteed to be loaded when this is called, since this is
;;; also transitively called from FuncC_Boss_CryptWinch_Tick.
.PROC FuncC_Boss_CryptWinch_Init
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    lda #0
    sta Zp_RoomState + sState::Winch_eResetSeq
    rts
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Crypt_TickBoss
    jsr FuncC_Boss_Crypt_CheckForSpikeballHit
    jsr FuncA_Room_BossCrypt_MoveBossTowardGoal
    jsr FuncA_Room_BossCrypt_SetBossEyeDir
_CoolDown:
    lda Zp_RoomState + sState::BossCooldown_u8
    beq _CheckMode
    dec Zp_RoomState + sState::BossCooldown_u8
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
    d_entry table, Dead,     Func_Noop
    d_entry table, Waiting,  _BossWaiting
    d_entry table, Firing,   _BossFiring
    d_entry table, Strafing, _BossStrafing
    d_entry table, Hurt,     _BossHurt
    D_END
.ENDREPEAT
_BossFiring:
    ;; If the boss has already fired all its fireballs for now, start waiting.
    lda Zp_RoomState + sState::BossFireCount_u8
    bne @shootFireball
    lda #220  ; param: wait frames
    bne _StartWaiting  ; unconditional
    @shootFireball:
    ;; Otherwise, shoot a fireball.
    dec Zp_RoomState + sState::BossFireCount_u8
    lda #40
    sta Zp_RoomState + sState::BossCooldown_u8
    jsr FuncA_Room_SetPointToBossBodyCenter  ; preserves X
    jsr Func_GetAngleFromPointToAvatar  ; preserves X, returns A (param: angle)
    jmp Func_ShootFireballFromPoint
_StartWaiting:
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #eBossMode::Waiting
    sta Zp_RoomState + sState::Current_eBossMode
_Return:
    rts
_BossStrafing:
    ;; If the boss has more embers to drop for this strafing run, drop another
    ;; ember.
    lda Zp_RoomState + sState::BossFireCount_u8
    beq @noMoreEmbers
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs _Return
    jsr FuncA_Room_SetPointToBossBodyCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_InitActorProjEmber
    lda #15  ; 0.25 seconds
    sta Zp_RoomState + sState::BossCooldown_u8
    dec Zp_RoomState + sState::BossFireCount_u8
    jmp Func_PlaySfxShootFire
    @noMoreEmbers:
    ;; Otherwise, hide under the nearby platform and start waiting.
    lda Zp_RoomState + sState::BossGoalPosX_u8
    bmi @rightSide
    @leftSide:
    lda #$58
    bne @setHideGoal  ; unconditional
    @rightSide:
    lda #$a8
    @setHideGoal:
    sta Zp_RoomState + sState::BossGoalPosX_u8
    lda #170  ; param: wait frames
    bne _StartWaiting  ; unconditional
_BossHurt:
    ;; If the boss is at zero health, it dies.  Otherwise, get ready to pick a
    ;; new goal position.
    lda Zp_RoomState + sState::BossHealth_u8
    bne @startWaiting
    .assert eBossMode::Dead = 0, error
    sta Zp_RoomState + sState::Current_eBossMode
    rts
    @startWaiting:
    lda #60  ; param: wait frames
    bne _StartWaiting  ; unconditional
_BossWaiting:
    ;; Pick a new random vertical goal position.
    jsr Func_GetRandomByte  ; returns A
    mod #4
    tax
    lda _GoalPosY_u8_arr4, x
    sta Zp_RoomState + sState::BossGoalPosY_u8
    ;; Check if the spikeball or chain is within the boss's vertical zone.
    ;; If so, move safely to avoid it; otherwise, move freely (and possibly
    ;; start a strafing attack).
    lda Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex
    cmp #kBossZoneTopY - kSpikeballHeightPx / 2
    blt _StartMovingFreely  ; spikeball is above boss zone
    fall _StartMovingSafely
_StartMovingSafely:
    ;; The spikeball is in the boss's zone, so the boss should move so as to
    ;; stay away from it.  If the boss is fully to one side of the spikeball,
    ;; then it should stay on that side.
    lda Zp_RoomState + sState::BossGoalPosX_u8
    cmp Ram_PlatformLeft_i16_0_arr + kSpikeballPlatformIndex
    blt @stayToLeftOfSpikeball
    cmp Ram_PlatformRight_i16_0_arr + kSpikeballPlatformIndex
    bge @stayToRightOfSpikeball
    ;; Otherwise, the boss is in the same column as the spikeball, in which
    ;; case it should retreat to whichever side has more room.
    tax  ; current boss X goal
    bpl @stayToRightOfSpikeball  ; boss is on left side of room, so go right
    @stayToLeftOfSpikeball:
    lda Ram_PlatformLeft_i16_0_arr + kSpikeballPlatformIndex
    sub #kBlockWidthPx
    tax  ; param: max X
    lda #0  ; param: min X
    beq _ChooseGoalXAndStartFiring  ; unconditional
    @stayToRightOfSpikeball:
    lda Ram_PlatformRight_i16_0_arr + kSpikeballPlatformIndex
    add #kBlockWidthPx  ; param: min X
    ldx #$ff  ; param: max X
    bne _ChooseGoalXAndStartFiring  ; unconditional
_StartMovingFreely:
    ;; The spikeball is not in the boss's zone, so the boss can move freely or
    ;; even start a strafing attack.  However, don't start a strafing attack if
    ;; the boss isn't near the room's edge.
    lda Zp_RoomState + sState::BossGoalPosX_u8
    cmp #$50
    blt @maybeStrafe  ; boss is at left edge of room
    cmp #$b0
    blt @doNotStrafe  ; boss is not at right edge of room.
    ;; When the boss is near the room's edge, start strafing 50% of the time.
    @maybeStrafe:
    jsr Func_GetRandomByte  ; returns N
    bpl _StartStrafing
    @doNotStrafe:
    ;; Pick a new random horizontal goal position.
    lda #0  ; param: minimum safe goal X position
    ldx #$ff  ; param: maximum safe goal X position
    fall _ChooseGoalXAndStartFiring
_ChooseGoalXAndStartFiring:
    jsr FuncC_Boss_Crypt_ChooseGoalPosX
    jmp FuncC_Boss_Crypt_StartFiring
_StartStrafing:
    ;; When strafing, pick a goal on the far edge of the room.
    lda Zp_RoomState + sState::BossGoalPosX_u8
    bpl @strafeToTheRight
    @strafeToTheLeft:
    lda #$48
    bne @setStrafeGoal  ; unconditional
    @strafeToTheRight:
    lda #$b8
    @setStrafeGoal:
    sta Zp_RoomState + sState::BossGoalPosX_u8
    ;; Start strafing.
    lda #eBossMode::Strafing
    sta Zp_RoomState + sState::Current_eBossMode
    lda #6
    sta Zp_RoomState + sState::BossFireCount_u8
    rts
_GoalPosY_u8_arr4:
    .byte $74, $77, $7a, $7c
.ENDPROC

;;; Puts the boss into Firing mode, and chooses a random fire count based on
;;; the boss's current health.
.PROC FuncC_Boss_Crypt_StartFiring
    lda #eBossMode::Firing
    sta Zp_RoomState + sState::Current_eBossMode
    lda #60  ; 1.0 seconds
    sta Zp_RoomState + sState::BossCooldown_u8
    ;; Randomly shoot a baseline of either 3 or 4 fireballs.
    jsr Func_GetRandomByte  ; returns A
    and #$01
    add #3
    sta Zp_RoomState + sState::BossFireCount_u8
    ;; Add additional fireballs as the boss loses health.
    lda #kBossInitHealth
    sub Zp_RoomState + sState::BossHealth_u8
    div #2
    add Zp_RoomState + sState::BossFireCount_u8
    sta Zp_RoomState + sState::BossFireCount_u8
    rts
.ENDPROC

;;; Set the boss's goal X position to a randomly chosen valid position within
;;; the specified range.
;;; @param A The minimum safe goal X position.
;;; @param X The maximum safe goal X position.
.PROC FuncC_Boss_Crypt_ChooseGoalPosX
    sta T0  ; min safe pos X
    stx T1  ; max safe pos X
    ldy #6
    sty T2  ; index upper bound
    dey
    @loop:
    lda _GoalPosX_u8_arr6, y
    cmp T1  ; max safe pos X
    blt @checkMin
    sty T2  ; index upper bound
    @checkMin:
    cmp T0  ; min safe pos X
    blt @break
    dey
    bpl @loop
    @break:
    iny
    sty T3  ; index lower bound
    lda T2  ; index upper bound
    sub T3  ; index lower bound
    tay  ; param: divisor
    beq @done  ; no safe X positions, so just don't update goal X position
    jsr Func_GetRandomByte  ; preserves Y and T0+, returns A (param: dividend)
    jsr Func_DivMod  ; preserves T2+, returns remainder in A
    add T3  ; index lower bound
    tax
    lda _GoalPosX_u8_arr6, x
    sta Zp_RoomState + sState::BossGoalPosX_u8
    @done:
    rts
_GoalPosX_u8_arr6:
    .byte $48, $68, $78, $88, $98, $b8
.ENDPROC

;;; Checks if the winch spikeball is falling and has hit the boss's eye; if so,
;;; damages the boss.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Crypt_CheckForSpikeballHit
    ;; If the boss got hit recently, don't check for another hit yet.
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #eBossMode::Hurt
    beq @done  ; boss still has temporary invincibility
    ;; Check if the spikeball is falling.
    bit Ram_MachineState1_byte_arr + kWinchMachineIndex  ; falling bool
    bpl @done  ; spikeball is not falling
    ;; Check if the spikeball has hit the center of the boss's eye.
    jsr FuncA_Room_SetPointToBossBodyCenter
    ldy #kSpikeballPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done
    ;; Damage the boss.
    lda #eSample::BossHurtF  ; param: eSample to play
    jsr Func_PlaySfxSample
    lda #eBossMode::Hurt
    sta Zp_RoomState + sState::Current_eBossMode
    dec Zp_RoomState + sState::BossHealth_u8
    lda #120
    sta Zp_RoomState + sState::BossCooldown_u8
    ;; Move horizontally away from the spikeball.
    lda Zp_PointX_i16 + 0
    cmp #kScreenWidthPx / 2
    bge @onRightSide
    @onLeftSide:
    adc #kBossHurtMoveDistPx  ; carry is already clear
    bcc @setGoal  ; unconditional
    @onRightSide:
    sbc #kBossHurtMoveDistPx  ; carry is already set
    @setGoal:
    sta Zp_RoomState + sState::BossGoalPosX_u8
    @done:
    rts
.ENDPROC

;;; A template (with unset payload bytes) for a pair of PPU transfer entries
;;; for changing the BG tiles of the boss's eye.
.PROC DataC_Boss_CryptEyeTemplate_sXfer_arr
    .assert kBossWidthTiles = 6, error
    .assert kBossHeightTiles = 4, error
    ;; Column 2:
    d_xfer_header kPpuCtrlFlagsVert, Ppu_BossRow1Start + 2
    d_xfer_data 0, 0
    ;; Column 3:
    d_xfer_header kPpuCtrlFlagsVert, Ppu_BossRow1Start + 3
    d_xfer_data 0, 0
    d_xfer_terminator
.ENDPROC

;;; Draw function for the crypt boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Crypt_DrawBoss
_AnimateTentacles:
    lda Zp_FrameCounter_u8
    div #8
    mod #4
    add #<.bank(Ppu_ChrBgAnimB0)
    sta Zp_Chr04Bank_u8
_SetEyeShapePosition:
    ;; Set the shape position to the center of the boss's eye.
    ldx #kBossBodyPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda #kBossWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kBossHeightPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
_SetUpIrq:
    ;; Compute the IRQ latch value to set between the bottom of the boss's zone
    ;; and the top of the window (if any), and set that as Param4_byte.
    lda Zp_Buffered_sIrq + sIrq::Latch_u8
    sub #kBossZoneBottomY
    add Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Param4_byte  ; window latch
    ;; Set up our own sIrq struct to handle boss movement.
    lda #kBossZoneTopY - 1
    sub Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_BossCryptZoneTopIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    ;; Compute PPU scroll values for the boss zone.
    lda #kBossStartCol * kTileWidthPx + kBossWidthPx / 2
    sub Zp_ShapePosX_i16 + 0
    sta Zp_Buffered_sIrq + sIrq::Param1_byte  ; boss scroll-X
    lda #kBossStartRow * kTileHeightPx + kBossHeightPx / 2 + kBossZoneTopY
    sub Zp_ShapePosY_i16 + 0
    sub Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Param2_byte  ; boss scroll-Y
_CalculateBossEyeLean:
    ldx Zp_RoomState + sState::BossVelX_i16 + 0
    lda Zp_RoomState + sState::BossVelX_i16 + 1
    bmi @movingLeft
    @movingRight:
    bne @leanRight
    cpx #kBossLeanSpeed
    blt @leanCenter
    @leanRight:
    lda #2
    bne @setEyeLeanOffset  ; unconditional
    @movingLeft:
    cmp #$ff
    blt @leanLeft
    cpx #$100 - kBossLeanSpeed
    blt @leanLeft
    @leanCenter:
    lda #0
    beq @setEyeLeanOffset  ; unconditional
    @leanLeft:
    lda #<-2
    @setEyeLeanOffset:
    sta T4  ; eye lean offset (-2, 0, or 2)
_CalculateBossEyeFlash:
    ;; If the boss is hurt, make its eye flash.
    ldx #0
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #eBossMode::Hurt
    bne @noFlash
    lda Zp_FrameCounter_u8
    and #$02
    beq @noFlash
    ldx #$10
    @noFlash:
    stx T3  ; flash bit (0 or $10)
_DrawBossPupil:
    ;; Adjust the shape position to the top left of the boss's 1x1 pupil shape.
    ldx Zp_RoomState + sState::Boss_eEyeDir
    lda _EyeOffsetX_u8_arr, x  ; param: offset
    sub T4  ; eye lean offset (-2, 0, or 2)
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X and T0+
    lda _EyeOffsetY_u8_arr, x  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves T0+
    ;; Draw the pupil white or red, depending on the flash bit.
    lda T3  ; flash bit (0 or $10)
    div #$10
    .assert kTileIdObjBossCryptPupilFirst .mod 2 = 0, error
    ora #kTileIdObjBossCryptPupilFirst  ; param: tile ID
    ldy #kPaletteObjBossCryptPupil  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves T2+
_TransferBossEye:
    ;; We're going to buffer a PPU transfer to update the BG tiles for the
    ;; boss's eye.  Start by copying the transfer template into the buffer,
    ;; leaving X as the index for the start of the transfer entries.
    lda Zp_PpuTransferLen_u8
    pha     ; transfer start
    ldax #DataC_Boss_CryptEyeTemplate_sXfer_arr  ; param: data pointer
    jsr Func_BufferPpuTransfer  ; preserves T3+
    pla     ; transfer start
    tax     ; transfer start
    ;; Fill in the payloads of the two transfer entries with the BG tile IDs to
    ;; set, taking the eye lean offset and flash bit into account.
    lda T4  ; eye lean offset (-2, 0, or 2)
    mul #2
    add #kTileIdBgBossCryptEyeWhiteFirst + 4
    .linecont +
    .assert kTileIdBgBossCryptEyeWhiteFirst | $10 = \
            kTileIdBgBossCryptEyeRedFirst, error
    ora T3  ; flash bit (0 or $10)
    sta Ram_PpuTransfer_arr + 4 + 0, x
    add #1
    sta Ram_PpuTransfer_arr + 4 + 1, x
    adc #1
    sta Ram_PpuTransfer_arr + 4 + 2 + 4 + 0, x
    adc #1
    sta Ram_PpuTransfer_arr + 4 + 2 + 4 + 1, x
    .linecont -
_DrawSideWalls:
    ldx #kLeftWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawPlatformCryptBricksVert
    ldx #kRightWallPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawPlatformCryptBricksVert
_EyeOffsetX_u8_arr:
    D_ARRAY .enum, eEyeDir
    d_byte Left,      6
    d_byte DownLeft,  5
    d_byte Down,      4
    d_byte DownRight, 3
    d_byte Right,     2
    D_END
_EyeOffsetY_u8_arr:
    D_ARRAY .enum, eEyeDir
    d_byte Left,      4
    d_byte DownLeft,  3
    d_byte Down,      2
    d_byte DownRight, 3
    d_byte Right,     4
    D_END
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_CryptWinch_Draw
    ldx #kSpikeballPlatformIndex  ; param: spikeball platform index
    jmp FuncA_Objects_DrawWinchMachineWithSpikeball
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Room init function for the BossCrypt room.
.PROC FuncA_Room_BossCrypt_EnterRoom
_InitBoss:
    ldax #DataC_Boss_Crypt_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    beq _BossIsAlive
_BossIsDead:
    rts
_BossIsAlive:
    lda #eBossMode::Waiting
    sta Zp_RoomState + sState::Current_eBossMode
    lda #kBossInitHealth
    sta Zp_RoomState + sState::BossHealth_u8
    lda #120  ; 2 seconds
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #kBossInitPosX
    sta Zp_RoomState + sState::BossGoalPosX_u8
    lda #kBossInitPosY
    sta Zp_RoomState + sState::BossGoalPosY_u8
    fall FuncA_Room_BossCrypt_SetBossEyeDir
.ENDPROC

;;; Sets Boss_eEyeDir so that the boss's eye is looking at the player avatar.
;;; Note that this is called from the room's Enter_func_ptr, so no PRGA bank
;;; can be assumed.
.PROC FuncA_Room_BossCrypt_SetBossEyeDir
    jsr FuncA_Room_SetPointToBossBodyCenter
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

;;; Room tick function for the BossCrypt room.
.PROC FuncA_Room_BossCrypt_TickRoom
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Moves the center of the boss closer to the boss's goal position by one
;;; frame tick.
.PROC FuncA_Room_BossCrypt_MoveBossTowardGoal
    ldx #kBossBodyPlatformIndex  ; param: platform index
_ApplyVelocityX:
    lda Zp_RoomState + sState::BossSubX_u8
    add Zp_RoomState + sState::BossVelX_i16 + 0
    sta Zp_RoomState + sState::BossSubX_u8
    lda Ram_PlatformLeft_i16_0_arr + kBossBodyPlatformIndex
    adc Zp_RoomState + sState::BossVelX_i16 + 1
    sta Zp_PointX_i16 + 0
    lda #0
    sta Zp_PointX_i16 + 1
    lda #127  ; param: max move by
    jsr Func_MovePlatformLeftTowardPointX  ; preserves X
_ApplyVelocityY:
    lda Zp_RoomState + sState::BossSubY_u8
    add Zp_RoomState + sState::BossVelY_i16 + 0
    sta Zp_RoomState + sState::BossSubY_u8
    lda Ram_PlatformTop_i16_0_arr + kBossBodyPlatformIndex
    adc Zp_RoomState + sState::BossVelY_i16 + 1
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    lda #127  ; param: max move by
    jsr Func_MovePlatformTopTowardPointY
_AccelerateTowardGoalX:
    ;; Compute the (signed) delta from the boss's current X-position to its
    ;; goal X-position, in pixels, storing it in YA.
    ldy #0
    lda Zp_RoomState + sState::BossGoalPosX_u8
    sub #kBossWidthPx / 2
    sub Ram_PlatformLeft_i16_0_arr + kBossBodyPlatformIndex
    bge @nonneg
    dey  ; now Y is $ff
    @nonneg:
    ;; Use the position delta in pixels as an acceleration in subpixels per
    ;; frame, adding it to the boss's current velocity, storing the updated
    ;; velocity in T1X.
    add Zp_RoomState + sState::BossVelX_i16 + 0
    tax     ; new X-velocity (lo)
    tya     ; acceleration (hi)
    adc Zp_RoomState + sState::BossVelX_i16 + 1
    sta T1  ; new X-velocity (hi)
_ApplyDragX:
    ;; Divide the updated velocity by 16 to get a (negative) drag force,
    ;; storing it in YA.  We do this signed division by multiplying by 16, then
    ;; chopping off the last byte to divide by 256.
    ldy #0
    stx T0  ; new X-velocity (lo)
    .repeat 4
    asl T0
    rol a
    .endrepeat
    bpl @nonneg
    dey  ; now Y is $ff
    @nonneg:
    ;; Subtract the (negative) drag force in YA from the new velocity in T1X,
    ;; storing the resulting velocity in AX.
    sta T0   ; negative drag force (lo)
    txa      ; new X-velocity (lo)
    sub T0   ; negative drag force (lo)
    tax      ; new X-velocity (lo)
    tya      ; negative drag force (hi)
    rsbc T1  ; new X-velocity (hi)
    ;; Clamp the new velocity to +/- kBossMaxSpeedX.
    bpl @movingRight
    @movingLeft:
    cmp #<-kBossMaxSpeedX
    bge @setVelToAX
    lda #<-kBossMaxSpeedX
    ldx #0
    beq @setVelToAX  ; unconditional
    @movingRight:
    cmp #kBossMaxSpeedX
    blt @setVelToAX
    lda #kBossMaxSpeedX
    ldx #0
    @setVelToAX:
    stax Zp_RoomState + sState::BossVelX_i16
_AccelerateTowardGoalY:
    ;; Compute the (signed) delta from the boss's current Y-position to its
    ;; goal Y-position, in pixels, storing it in YA.
    ldy #0
    lda Zp_RoomState + sState::BossGoalPosY_u8
    sub #kBossHeightPx / 2
    sub Ram_PlatformTop_i16_0_arr + kBossBodyPlatformIndex
    bge @nonneg
    dey  ; now Y is $ff
    @nonneg:
    ;; Use the position delta in pixels as an acceleration in subpixels per
    ;; frame, adding it to the boss's current velocity, storing the updated
    ;; velocity in T1X.
    add Zp_RoomState + sState::BossVelY_i16 + 0
    tax     ; new Y-velocity (lo)
    tya     ; acceleration (hi)
    adc Zp_RoomState + sState::BossVelY_i16 + 1
    sta T1  ; new Y-velocity (hi)
_ApplyDragY:
    ;; Divide the updated velocity by 64 to get a (negative) drag force,
    ;; storing it in YA.  We do this signed division by multiplying by 4, then
    ;; chopping off the last byte to divide by 256.
    ldy #0
    stx T0  ; new Y-velocity (lo)
    .repeat 2
    asl T0
    rol a
    .endrepeat
    bpl @nonneg
    dey  ; now Y is $ff
    @nonneg:
    ;; Subtract the (negative) drag force in YA from the new velocity in T1X,
    ;; storing the resulting velocity in AX.
    sta T0   ; negative drag force (lo)
    txa      ; new Y-velocity (lo)
    sub T0   ; negative drag force (lo)
    tax      ; new Y-velocity (lo)
    tya      ; negative drag force (hi)
    rsbc T1  ; new Y-velocity (hi)
    ;; Clamp the new velocity to +/- kBossMaxSpeedY.
    bpl @movingDown
    @movingUp:
    cmp #<-kBossMaxSpeedY
    bge @setVelToAX
    lda #<-kBossMaxSpeedY
    ldx #0
    beq @setVelToAX  ; unconditional
    @movingDown:
    cmp #kBossMaxSpeedY
    blt @setVelToAX
    lda #kBossMaxSpeedY
    ldx #0
    @setVelToAX:
    stax Zp_RoomState + sState::BossVelY_i16
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_BossCryptWinch_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_BossCryptWinch_TryMove
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    .assert eDir::Up = 0, error
    txa
    beq _MoveUp
    cpx #eDir::Down
    beq _MoveDown
_MoveHorz:
    cpx #eDir::Left
    beq @moveLeft
    @moveRight:
    cpy #kWinchMaxGoalX
    bge _Error
    iny
    bne @checkFloor  ; unconditional
    @moveLeft:
    tya
    beq _Error
    dey
    @checkFloor:
    lda DataA_Machine_BossCryptFloor_u8_arr, y
    cmp Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    blt _Error
    sty Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveUp:
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    beq _Error
    dec Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveDown:
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    cmp DataA_Machine_BossCryptFloor_u8_arr, y
    bge _Error
    inc Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

;;; Helper function for FuncC_Boss_CryptWinch_Tick; moves the the
;;; BossCryptWinch machine towards its goal position.
;;; @return Z Set if the winch has reached its goal position.
.PROC FuncA_Machine_BossCryptWinch_TickMove
    ldy #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Machine_ExpireFireballsWithinSolidPlatform  ; preserves Y
    lda #eActor::ProjEmber  ; param: actor type
    jsr FuncA_Machine_ExpireProjectilesWithinSolidPlatform
_MoveVert:
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the spikeball, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #kBlockHeightPx
    add #kSpikeballMinPlatformTop
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kSpikeballMinPlatformTop < $100, error
    .linecont -
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    beq _StillMoving
    ;; Move the spikeball vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    bne _Return  ; still moving
_MoveHorz:
    ;; Calculate the desired X-position for the left edge of the winch, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    mul #kBlockWidthPx
    add #kWinchMinPlatformLeft
    sta Zp_PointX_i16 + 0
    lda #0
    sta Zp_PointX_i16 + 1
    ;; Move the winch horizontally, if necessary.
    jsr FuncA_Machine_GetWinchHorzSpeed  ; returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z and A
    beq _Return  ; reached goal
    ;; If the winch moved, move the spikeball platform too.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz  ; preserves X
_StillMoving:
    lda #1  ; clear Z to indicate that the winch hasn't yet reached its goal
_Return:
    rts
.ENDPROC

.PROC FuncA_Machine_BossCryptWinch_TryAct
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda DataA_Machine_BossCryptFloor_u8_arr, y  ; param: new Z-goal
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

.PROC DataA_Machine_BossCryptFloor_u8_arr
    .byte 8, 8, 1, 9, 9, 9, 5, 1, 9, 9
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC DataA_Terrain_BossCryptInit_sXfer_arr
    .assert kBossWidthTiles = 6, error
    .assert kBossHeightTiles = 4, error
    ;; Row 0:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossRow0Start
    .assert kTileIdBgAnimBossCryptFirst = $48, error
    d_xfer_data $48, $49, $4a, $4b, $4c, $4d
    ;; Row 1:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossRow1Start
    .assert kTileIdBgBossCryptEyeWhiteFirst = $a4, error
    d_xfer_data $4e, $4f, $a8, $aa, $50, $51
    ;; Row 2:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossRow2Start
    .assert kTileIdBgBossCryptEyeWhiteFirst = $a4, error
    d_xfer_data $58, $59, $a9, $ab, $5a, $5b
    ;; Row 3:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossRow3Start
    d_xfer_data $52, $53, $54, $55, $56, $57
    ;; Nametable attributes to color eyeball red:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_BossEyeAttrs
    d_xfer_data $04
    d_xfer_terminator
.ENDPROC

;;; @prereq Rendering is disabled.
;;; @prereq Rendering is disabled.
.PROC FuncA_Terrain_BossCrypt_FadeInRoom
    ldx #4    ; param: num bytes to write
    ldy #$50  ; param: attribute value
    lda #$32  ; param: initial byte offset
    jsr Func_WriteToUpperAttributeTable
    ldax #DataA_Terrain_BossCryptInit_sXfer_arr  ; param: data pointer
    jmp Func_DirectPpuTransfer
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the boss's zone in the BossCrypt
;;; room.  Sets the horizontal and vertical scroll so as to make the boss's BG
;;; tiles appear to move.
;;; @thread IRQ
.PROC Int_BossCryptZoneTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda #kBossZoneBottomY - kBossZoneTopY - 1  ; param: latch value
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_BossCryptZoneBottomIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #2  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the lower
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #3 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda Zp_Active_sIrq + sIrq::Param2_byte  ; boss scroll-Y
    sta Hw_PpuScroll_w2
    and #$38
    mul #4
    sta Zp_IrqTmp_byte  ; ((Y & $38) << 2)
    lda Zp_Active_sIrq + sIrq::Param1_byte  ; boss scroll-X
    tax  ; new scroll-X value
    div #8
    ora Zp_IrqTmp_byte
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom of the boss's zone in the
;;; BossCrypt room.  Sets the horizontal and vertical scroll so as to make the
;;; bottom of the room look normal.
;;; @thread IRQ
.PROC Int_BossCryptZoneBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam4  ; preserves Y
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #7  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #0 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda #kBossZoneBottomY  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    lda #(kBossZoneBottomY & $38) << 2
    ;; We should now be in the second HBlank (and X is zero).
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
