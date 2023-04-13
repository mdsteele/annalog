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
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Crypt_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GetWinchHorzSpeed
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WinchReachedGoal
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawBoss
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_DrawWinchSpikeball
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Objects_SetShapePosToSpikeballCenter
.IMPORT FuncA_Room_InitBoss
.IMPORT FuncA_Room_TickBoss
.IMPORT Func_AckIrqAndLatchWindowFromParam3
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorProjEmber
.IMPORT Func_InitActorProjFireball
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineParams
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ppu_ChrBgAnimB0
.IMPORT Ppu_ChrObjCrypt
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr0cBank_u8
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
kWinchInitGoalX = 4
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

;;;=========================================================================;;;

;;; The higher the number, the more slowly the boss tracks towards its goal
;;; position.
.DEFINE kBossMoveXSlowdown 2
.DEFINE kBossMoveYSlowdown 2

;;; The maximum speed that the boss is allowed to move, in pixels per frame.
kBossMaxXSpeed = 1
kBossMaxYSpeed = 1

;;; How far the boss should move horizontally when hurt, in pixels.
kBossHurtMoveDistPx = 60

;;;=========================================================================;;;

;;; The OBJ tile ID for the first of the two side wall tiles.
kTileIdObjSideWallFirst = $c0
;;; The OBJ palette number to use for the side walls.
kPaletteObjSideWall = 0
;;; The OBJ tile ID for the pupil of the boss's eye.
kTileIdObjBossPupil = $c2
;;; The OBJ palette number to use for the pupil of the boss's eye.
kPaletteObjBossPupil = 0

;;;=========================================================================;;;

;;; Modes that the boss in this room can be in.
.ENUM eBossMode
    Dead
    Firing    ; moving to goal position, shooting fireballs
    Strafing  ; moving from one side of the room to the other, dropping embers
    Hurt      ; just got hit, moving away and eye blinking
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

;;; Enum for the steps of the CryptTombWinch machine's reset sequence (listed
;;; in reverse order).
.ENUM eResetSeq
    Middle = 0  ; last step: move to mid-center position
    TopCenter   ; move up to top, then move horizontally to center
.ENDENUM

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
    d_byte MinimapStartRow_u8, 12
    d_byte MinimapStartCol_u8, 0
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCrypt)
    d_addr Tick_func_ptr, FuncC_Boss_Crypt_TickRoom
    d_addr Draw_func_ptr, FuncC_Boss_Crypt_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Boss_Crypt_EnterRoom
    d_addr FadeIn_func_ptr, FuncC_Boss_Crypt_FadeInRoom
    D_END
_TerrainData:
:   .incbin "out/data/boss_crypt.room"
    .assert * - :- = 16 * 16, error
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
    d_addr WriteReg_func_ptr, FuncC_Boss_CryptWinch_WriteReg
    d_addr TryMove_func_ptr, FuncC_Boss_CryptWinch_TryMove
    d_addr TryAct_func_ptr, FuncC_Boss_CryptWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Boss_CryptWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_BossCryptWinch_Draw
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
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $0e
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
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $00de
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kBossDoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::CryptTomb
    D_END
    .assert * - :- = kBossUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be an upgrade
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 2
    d_byte Target_u8, eFlag::UpgradeOpWait
    D_END
    .assert * - :- = kBossBreakerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; will be a breaker
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 2
    d_byte Target_u8, eFlag::BreakerCrypt
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 13
    d_byte Target_u8, kWinchMachineIndex
    D_END
    .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 4
    d_byte Target_u8, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 11
    d_byte Target_u8, sState::LeverRight_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Boss_Crypt_sBoss
    D_STRUCT sBoss
    d_byte Boss_eFlag, eFlag::BossCrypt
    d_byte BodyPlatform_u8, kBossBodyPlatformIndex
    d_addr Tick_func_ptr, FuncC_Boss_Crypt_TickBoss
    d_addr Draw_func_ptr, FuncC_Boss_Crypt_DrawBoss
    D_END
.ENDPROC

.PROC FuncC_Boss_CryptWinch_ReadReg
    cmp #$c
    beq _ReadL
    cmp #$d
    beq _ReadR
    cmp #$e
    beq _ReadX
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex
    sub #kSpikeballMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kWinchPlatformIndex
    sub #kWinchMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
_ReadL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_ReadR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

.PROC FuncC_Boss_CryptWinch_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncC_Boss_CryptWinch_TryMove
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
    lda DataC_Boss_CryptFloor_u8_arr, y
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
    cmp DataC_Boss_CryptFloor_u8_arr, y
    bge _Error
    inc Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Boss_CryptWinch_TryAct
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda DataC_Boss_CryptFloor_u8_arr, y  ; param: new Z-goal
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

.PROC FuncC_Boss_CryptWinch_Tick
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
    bne @move
    rts
    @move:
    ;; Move the spikeball vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
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
    beq @reachedGoal
    ;; If the winch moved, move the spikeball platform too.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @reachedGoal:
_Finished:
    lda Zp_RoomState + sState::Winch_eResetSeq
    jeq FuncA_Machine_WinchReachedGoal
    .assert * = FuncC_Boss_CryptWinch_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Boss_CryptWinch_Reset
    jsr Func_ResetWinchMachineParams
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
    .assert * = FuncC_Boss_CryptWinch_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Boss_CryptWinch_Init
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    lda #0
    sta Zp_RoomState + sState::Winch_eResetSeq
    rts
.ENDPROC

.PROC DataC_Boss_CryptFloor_u8_arr
    .byte 8, 8, 1, 9, 9, 9, 5, 1, 9, 9
.ENDPROC

.PROC DataC_Boss_CryptInitTransfer_arr
    .assert kBossWidthTiles = 6, error
    .assert kBossHeightTiles = 4, error
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow0Start  ; transfer destination
    .byte 6
    .byte $ec, $ed, $ee, $ef, $f0, $f1
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow1Start  ; transfer destination
    .byte 6
    .byte $f2, $f3, $a4, $a6, $f4, $f5
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow2Start  ; transfer destination
    .byte 6
    .byte $fc, $fd, $a5, $a7, $fe, $ff
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossRow3Start  ; transfer destination
    .byte 6
    .byte $f6, $f7, $f8, $f9, $fa, $fb
    ;; Nametable attributes to color eyeball red:
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_BossEyeAttrs  ; transfer destination
    .byte 1
    .byte $04
.ENDPROC

;;; Room init function for the BossCrypt room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Crypt_EnterRoom
    jsr FuncC_Boss_Crypt_SetBossEyeDir
_InitBoss:
    ldax #FuncC_Boss_Crypt_sBoss  ; param: sBoss ptr
    jsr FuncA_Room_InitBoss  ; sets Z if boss is alive
    bne _BossIsDead
_BossIsAlive:
    lda #eBossMode::Firing
    sta Zp_RoomState + sState::Current_eBossMode
    lda #3
    sta Zp_RoomState + sState::BossHealth_u8
    lda #120  ; 2 seconds
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #kBossInitPosX
    sta Zp_RoomState + sState::BossGoalPosX_u8
    lda #kBossInitPosY
    sta Zp_RoomState + sState::BossGoalPosY_u8
_BossIsDead:
    rts
.ENDPROC

.PROC FuncC_Boss_Crypt_FadeInRoom
    ldy #0
    ldx Zp_PpuTransferLen_u8
    @loop:
    lda DataC_Boss_CryptInitTransfer_arr, y
    iny
    sta Ram_PpuTransfer_arr, x
    inx
    cpy #.sizeof(DataC_Boss_CryptInitTransfer_arr)
    blt @loop
    stx Zp_PpuTransferLen_u8
    rts
.ENDPROC

;;; Room tick function for the BossCrypt room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Crypt_TickRoom
    .assert eBossMode::Dead = 0, error
    lda Zp_RoomState + sState::Current_eBossMode  ; param: zero if boss dead
    jmp FuncA_Room_TickBoss
.ENDPROC

;;; Performs per-frame upates for the boss in this room.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Crypt_TickBoss
    jsr FuncC_Boss_Crypt_CheckForSpikeballHit
    jsr FuncC_Boss_Crypt_MoveBossTowardGoal
    ;; TODO: redraw eye tiles as needed
    jsr FuncC_Boss_Crypt_SetBossEyeDir
_CoolDown:
    lda Zp_RoomState + sState::BossCooldown_u8
    beq _CheckMode
    dec Zp_RoomState + sState::BossCooldown_u8
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
    D_TABLE eBossMode
    d_entry table, Dead,     Func_Noop
    d_entry table, Firing, _BossFiring
    d_entry table, Strafing, _BossStrafing
    d_entry table, Hurt,     _BossHurt
    D_END
.ENDREPEAT
_BossFiring:
    ;; If the boss is still cooling down, we're done.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; If the boss has already fired all its fireballs for now, then pick a new
    ;; goal position.
    lda Zp_RoomState + sState::BossFireCount_u8
    beq _PickNewGoal
    ;; Otherwise, shoot some fireballs.
    ;; TODO: shoot a spray of three fireballs, not just one
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @done
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    ;; TODO: Aim fireball at player avatar.
    lda #64  ; param: aim angle
    jsr Func_InitActorProjFireball
    lda #60  ; 1.0 seconds
    sta Zp_RoomState + sState::BossCooldown_u8
    dec Zp_RoomState + sState::BossFireCount_u8
    @done:
    rts
_BossStrafing:
    ;; If the boss is still cooling down, we're done.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; If the boss has already dropped all its embers for this strafing run,
    ;; then pick a new goal position.
    lda Zp_RoomState + sState::BossFireCount_u8
    beq _PickNewGoal
    ;; Otherwise, drop an ember.
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @done
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_InitActorProjEmber
    lda #15  ; 0.25 seconds
    sta Zp_RoomState + sState::BossCooldown_u8
    dec Zp_RoomState + sState::BossFireCount_u8
    @done:
    rts
_BossHurt:
    ;; If the boss is still cooling down, we're done.
    lda Zp_RoomState + sState::BossCooldown_u8
    bne @done
    ;; If the boss is at zero health, it dies.  Otherwise, pick a new goal
    ;; position.
    lda Zp_RoomState + sState::BossHealth_u8
    bne _PickNewGoal
    .assert eBossMode::Dead = 0, error
    sta Zp_RoomState + sState::Current_eBossMode
    @done:
    rts
_PickNewGoal:
    ;; TODO: if at edge of room, 50% chance to start strafing
    ;; Pick a new random horizontal goal position.
    jsr Func_GetRandomByte  ; returns A
    and #$07
    tax
    ;; TODO: Avoid picking a goal that would run the boss into the spikeball.
    lda _GoalPosX_u8_arr8, x
    sta Zp_RoomState + sState::BossGoalPosX_u8
    ;; Pick a new random vertical goal position.
    jsr Func_GetRandomByte  ; returns A
    and #$0f
    add #kBossZoneTopY + kBossHeightPx / 2
    sta Zp_RoomState + sState::BossGoalPosY_u8
    ;; Commence firing.
    lda #eBossMode::Firing
    sta Zp_RoomState + sState::Current_eBossMode
    lda #60  ; 1.0 seconds
    sta Zp_RoomState + sState::BossCooldown_u8
    lda #3
    sta Zp_RoomState + sState::BossFireCount_u8
    rts
_GoalPosX_u8_arr8:
    .byte $38, $48, $68, $78, $88, $98, $b8, $c8
.ENDPROC

;;; Checks if the winch spikeball is falling and has hit the boss's eye; if so,
;;; damages the boss.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Boss_Crypt_CheckForSpikeballHit
    ;; If the boss got hit recently, don't check for another hit yet.
    lda Zp_RoomState + sState::Current_eBossMode
    cmp #eBossMode::Hurt
    beq @done
    ;; Check if the spikeball has hit the center of the boss's eye.
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    ldy #kSpikeballPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done
    ;; Damage the boss.
    lda #eBossMode::Hurt
    sta Zp_RoomState + sState::Current_eBossMode
    dec Zp_RoomState + sState::BossHealth_u8
    lda #45  ; 0.75 seconds
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
    ;; TODO: play a sound
    @done:
    rts
.ENDPROC

;;; Moves the center of the boss closer to the boss's goal position by one
;;; frame tick.
.PROC FuncC_Boss_Crypt_MoveBossTowardGoal
    lda Zp_RoomState + sState::BossGoalPosX_u8
    sub #kBossWidthPx / 2
    sta Zp_PointX_i16 + 0
    lda Zp_RoomState + sState::BossGoalPosY_u8
    sub #kBossHeightPx / 2
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointX_i16 + 1
    sta Zp_PointY_i16 + 1
    ldx #kBossBodyPlatformIndex  ; param: platform index
    lda #kBossMaxXSpeed  ; param: max move by
    jsr Func_MovePlatformLeftTowardPointX  ; preserves X
    lda #kBossMaxYSpeed  ; param: max move by
    jmp Func_MovePlatformTopTowardPointY
.ENDPROC

;;; Sets Boss_eEyeDir so that the boss's eye is looking at the player avatar.
;;; Note that this is called from the room's Enter_func_ptr, so no PRGA bank
;;; can be assumed.
.PROC FuncC_Boss_Crypt_SetBossEyeDir
    ldy #kBossBodyPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    ;; Compute the avatar's Y-position relative to the boss.
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_PointY_i16 + 0
    bge @setYOffset
    lda #0
    @setYOffset:
    sta T0  ; avatar Y-offset
    ;; Compute the avatar's X-position relative to the boss.
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_PointX_i16 + 0
    blt @avatarToTheLeft
    @avatarToTheRight:
    sta T1  ; avatar X-offset
    div #2
    cmp T0  ; avatar Y-offset
    bge @lookRight
    lda T0  ; avatar Y-offset
    div #2
    cmp T1  ; avatar X-offset
    bge @lookDown
    @lookDownRight:
    ldx #eEyeDir::DownRight
    .assert eEyeDir::DownRight <> 0, error
    bne @setEyeDir  ; unconditional
    @lookRight:
    ldx #eEyeDir::Right
    .assert eEyeDir::Right <> 0, error
    bne @setEyeDir  ; unconditional
    @lookDown:
    ldx #eEyeDir::Down
    .assert eEyeDir::Down <> 0, error
    bne @setEyeDir  ; unconditional
    @avatarToTheLeft:
    eor #$ff  ; negate (off by one, but close enough)
    sta T1  ; avatar X-offset
    div #2
    cmp T0  ; avatar Y-offset
    bge @lookLeft
    lda T0  ; avatar Y-offset
    div #2
    cmp T1  ; avatar X-offset
    bge @lookDown
    @lookDownLeft:
    ldx #eEyeDir::DownLeft
    .assert eEyeDir::DownLeft <> 0, error
    bne @setEyeDir  ; unconditional
    @lookLeft:
    ldx #eEyeDir::Left
    @setEyeDir:
    stx Zp_RoomState + sState::Boss_eEyeDir
    rts
.ENDPROC

;;; Draw function for the BossTemple room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Crypt_DrawRoom
    ldx #kLeftWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_BossCrypt_DrawSideWall
    ldx #kRightWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_BossCrypt_DrawSideWall
    jmp FuncA_Objects_DrawBoss
.ENDPROC

;;; Draw function for the crypt boss.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Boss_Crypt_DrawBoss
_AnimateTentacles:
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    add #<.bank(Ppu_ChrBgAnimB0)
    sta Zp_Chr0cBank_u8
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
    ;; and the top of the window (if any), and set that as Param3_byte.
    lda <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    sub #kBossZoneBottomY
    add Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param3_byte)  ; window latch
    ;; Set up our own sIrq struct to handle boss movement.
    lda #kBossZoneTopY - 1
    sub Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    ldax #Int_BossCryptZoneTopIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    ;; Compute PPU scroll values for the boss zone.
    lda #kBossStartCol * kTileWidthPx + kBossWidthPx / 2
    sub Zp_ShapePosX_i16 + 0
    sta <(Zp_Buffered_sIrq + sIrq::Param1_byte)  ; boss scroll-X
    lda #kBossStartRow * kTileHeightPx + kBossHeightPx / 2 + kBossZoneTopY
    sub Zp_ShapePosY_i16 + 0
    sta <(Zp_Buffered_sIrq + sIrq::Param2_byte)  ; boss scroll-Y
_DrawBossPupil:
    ldx Zp_RoomState + sState::Boss_eEyeDir
    lda _EyeOffsetX_u8_arr, x  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X
    lda _EyeOffsetY_u8_arr, x  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    ldy #kPaletteObjBossPupil  ; param: object flags
    lda #kTileIdObjBossPupil  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
_EyeOffsetX_u8_arr:
    D_ENUM eEyeDir
    d_byte Left,      6
    d_byte DownLeft,  5
    d_byte Down,      4
    d_byte DownRight, 3
    d_byte Right,     2
    D_END
_EyeOffsetY_u8_arr:
    D_ENUM eEyeDir
    d_byte Left,      4
    d_byte DownLeft,  3
    d_byte Down,      2
    d_byte DownRight, 3
    d_byte Right,     4
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the boss's zone in the BossCrypt
;;; room.  Sets the horizontal and vertical scroll so as to make the boss's BG
;;; tiles appear to move.
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
    lda <(Zp_Active_sIrq + sIrq::Param2_byte)  ; boss scroll-Y
    sta Hw_PpuScroll_w2
    and #$38
    mul #4
    sta Zp_IrqTmp_byte  ; ((Y & $38) << 2)
    lda <(Zp_Active_sIrq + sIrq::Param1_byte)  ; boss scroll-X
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
.PROC Int_BossCryptZoneBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam3  ; preserves Y
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

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for one of the two side walls.
;;; @param X The platform index for the side wall to draw.
.PROC FuncA_Objects_BossCrypt_DrawSideWall
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx #6
    @loop:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    txa
    and #$01
    adc #kTileIdObjSideWallFirst  ; carry is already clear
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjSideWall
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    dex
    bne @loop
    rts
.ENDPROC

;;; Draws the BossCryptWinch machine.
.PROC FuncA_Objects_BossCryptWinch_Draw
    lda Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex  ; param: chain
    jsr FuncA_Objects_DrawWinchMachine
_Spikeball:
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToSpikeballCenter
    jsr FuncA_Objects_DrawWinchSpikeball
_Chain:
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    ldx #kWinchPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

;;;=========================================================================;;;
