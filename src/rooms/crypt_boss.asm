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

.IMPORT DataA_Pause_CryptAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_CryptAreaName_u8_arr
.IMPORT DataA_Room_Crypt_sTileset
.IMPORT FuncA_Machine_GetWinchHorzSpeed
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Machine_WinchStopFalling
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_DrawWinchSpikeball
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Objects_SetShapePosToSpikeballCenter
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineParams
.IMPORT Int_WindowTopIrq
.IMPORT Ppu_ChrObjUpgrade
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_IrqTmp_byte
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; The machine index for the CryptTombWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptTombWinch machine, the spikeball that
;;; hangs from its chain, and the side walls.
kWinchPlatformIndex      = 0
kSpikeballPlatformIndex  = 1
kLeftWallPlatformIndex   = 2
kRightWallPlatformIndex  = 3

;;; The initial and maximum permitted values for sState::WinchGoalX_u8.
kWinchInitGoalX = 4
kWinchMaxGoalX  = 9

;;; The initial and maximum values for sState::WinchGoalZ_u8.
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
kBossStartRow = 6
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
.LINECONT -

;;; The initial room pixel position for the center of the boss's eye.
kBossInitPosX = $a8
kBossInitPosY = $78

;;; The OBJ tile ID for the first of the two side wall tiles.
kTileIdFirstSideWall = $c0

;;; The OBJ palette number to use for the side walls.
kSideWallPalette = 0

;;; The OBJ tile ID for the pupil of the boss's eye.
kTileIdBossPupil = $c2

;;; The OBJ palette number to use for the pupil of the boss's eye.
kBossPupilPalette = 0

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
    LeverLeft_u1  .byte
    LeverRight_u1 .byte
    ;; The goal values for the CryptTombWinch machine's X and Z registers.
    WinchGoalX_u8 .byte
    WinchGoalZ_u8 .byte
    ;; Which step of its reset sequence the CryptTombWinch machine is on.
    WinchReset_eResetSeq .byte
    ;; The room pixel position of the center of the boss's eye.
    BossPosX_u8   .byte
    BossPosY_u8   .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_Boss_sRoom
.PROC DataC_Crypt_Boss_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 11
    d_byte MinimapStartCol_u8, 0
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjUpgrade)
    d_addr Tick_func_ptr, FuncC_Crypt_Boss_TickRoom
    d_addr Draw_func_ptr, FuncC_Crypt_Boss_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_CryptAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_CryptAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, FuncC_Crypt_Boss_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncC_Crypt_Boss_FadeInRoom
    D_END
_TerrainData:
:   .incbin "out/data/crypt_boss.room"
    .assert * - :- = 16 * 16, error
_Machines_sMachine_arr:
    .assert kWinchMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptTombWinch
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, "L", "R", "X", "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncC_Crypt_BossWinch_Init
    d_addr ReadReg_func_ptr, FuncC_Crypt_BossWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Crypt_BossWinch_TryMove
    d_addr TryAct_func_ptr, FuncC_Crypt_BossWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Crypt_BossWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CryptBossWinch_Draw
    d_addr Reset_func_ptr, FuncC_Crypt_BossWinch_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kWinchPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16,   $0020
    D_END
    .assert kSpikeballPlatformIndex = 1, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kWinchInitPlatformLeft + 2
    d_word Top_i16, kSpikeballInitPlatformTop
    D_END
    .assert kLeftWallPlatformIndex = 2, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0018
    d_word Top_i16,   $0060
    D_END
    .assert kRightWallPlatformIndex = 3, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0060
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $00de
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 13
    d_byte Target_u8, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 4
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 11
    d_byte Target_u8, sState::LeverRight_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::UnlockedDoor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::CryptTomb
    D_END
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Crypt_BossWinch_ReadReg
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
    lda Ram_RoomState + sState::LeverLeft_u1
    rts
_ReadR:
    lda Ram_RoomState + sState::LeverRight_u1
    rts
.ENDPROC

.PROC FuncC_Crypt_BossWinch_TryMove
    ldy Ram_RoomState + sState::WinchGoalX_u8
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
    lda DataC_Crypt_BossFloor_u8_arr, y
    cmp Ram_RoomState + sState::WinchGoalZ_u8
    blt _Error
    sty Ram_RoomState + sState::WinchGoalX_u8
    lda #kWinchMoveHorzCooldown
    clc  ; success
    rts
_MoveUp:
    lda Ram_RoomState + sState::WinchGoalZ_u8
    beq _Error
    dec Ram_RoomState + sState::WinchGoalZ_u8
    lda #kWinchMoveUpCooldown
    clc  ; success
    rts
_MoveDown:
    ;; TODO: check for weak floor collision
    lda Ram_RoomState + sState::WinchGoalZ_u8
    cmp DataC_Crypt_BossFloor_u8_arr, y
    bge _Error
    inc Ram_RoomState + sState::WinchGoalZ_u8
    lda #kWinchMoveDownCooldown
    clc  ; success
    rts
_Error:
    sec  ; failure
    rts
.ENDPROC

.PROC FuncC_Crypt_BossWinch_TryAct
    ldy Ram_RoomState + sState::WinchGoalX_u8
    lda DataC_Crypt_BossFloor_u8_arr, y
    sta Ram_RoomState + sState::WinchGoalZ_u8
    jmp FuncA_Machine_WinchStartFalling  ; returns C and A
.ENDPROC

.PROC FuncC_Crypt_BossWinch_Tick
_MoveVert:
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the spikeball, storing it in Zp_PlatformGoal_i16.
    lda Ram_RoomState + sState::WinchGoalZ_u8
    mul #kBlockHeightPx
    add #kSpikeballMinPlatformTop
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kSpikeballMinPlatformTop < $100, error
    .linecont -
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the spikeball vertically, as necessary.
    jsr Func_MovePlatformTopToward  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
    jsr FuncA_Machine_WinchStopFalling
_MoveHorz:
    ;; Calculate the desired X-position for the left edge of the winch, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    lda Ram_RoomState + sState::WinchGoalX_u8
    mul #kBlockWidthPx
    add #kWinchMinPlatformLeft
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Move the winch horizontally, if necessary.
    jsr FuncA_Machine_GetWinchHorzSpeed  ; preserves X, returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftToward  ; preserves X, returns Z and A
    beq @reachedGoal
    ;; If the winch moved, move the spikeball platform too.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @reachedGoal:
_Finished:
    lda Ram_RoomState + sState::WinchReset_eResetSeq
    jeq Func_MachineFinishResetting
    .assert * = FuncC_Crypt_BossWinch_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_BossWinch_Reset
    jsr Func_ResetWinchMachineParams
    lda Ram_RoomState + sState::WinchGoalX_u8
    cmp #3
    blt _Outer
    cmp #7
    blt _Inner
_Outer:
    lda #kWinchInitGoalX
    sta Ram_RoomState + sState::WinchGoalX_u8
    lda #1
    sta Ram_RoomState + sState::WinchGoalZ_u8
    lda #eResetSeq::TopCenter
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    rts
_Inner:
    .assert * = FuncC_Crypt_BossWinch_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_BossWinch_Init
    lda #kWinchInitGoalX
    sta Ram_RoomState + sState::WinchGoalX_u8
    lda #kWinchInitGoalZ
    sta Ram_RoomState + sState::WinchGoalZ_u8
    lda #0
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    rts
.ENDPROC

.PROC DataC_Crypt_BossFloor_u8_arr
    .byte 8, 8, 1, 9, 9, 9, 5, 1, 9, 9
.ENDPROC

.PROC DataC_Crypt_BossInitTransfer_arr
    .assert kBossWidthTiles = 6, error
    .assert kBossHeightTiles = 4, error
    ;; Row 0:
    .byte kPpuCtrlFlagsHorz
    .byte >Ppu_BossRow0Start  ; transfer destination (hi)
    .byte <Ppu_BossRow0Start  ; transfer destination (lo)
    .byte 6
    .byte $ec, $ed, $ee, $ef, $f0, $f1
    ;; Row 1:
    .byte kPpuCtrlFlagsHorz
    .byte >Ppu_BossRow1Start  ; transfer destination (hi)
    .byte <Ppu_BossRow1Start  ; transfer destination (lo)
    .byte 6
    .byte $f2, $f3, $a4, $a6, $f4, $f5
    ;; Row 2:
    .byte kPpuCtrlFlagsHorz
    .byte >Ppu_BossRow2Start  ; transfer destination (hi)
    .byte <Ppu_BossRow2Start  ; transfer destination (lo)
    .byte 6
    .byte $fc, $fd, $a5, $a7, $fe, $ff
    ;; Row 3:
    .byte kPpuCtrlFlagsHorz
    .byte >Ppu_BossRow3Start  ; transfer destination (hi)
    .byte <Ppu_BossRow3Start  ; transfer destination (lo)
    .byte 6
    .byte $f6, $f7, $f8, $f9, $fa, $fb
.ENDPROC

.PROC FuncC_Crypt_Boss_InitRoom
    lda #kBossInitPosX
    sta Ram_RoomState + sState::BossPosX_u8
    lda #kBossInitPosY
    sta Ram_RoomState + sState::BossPosY_u8
    rts
.ENDPROC

.PROC FuncC_Crypt_Boss_FadeInRoom
    ldy #0
    ldx Zp_PpuTransferLen_u8
    @loop:
    lda DataC_Crypt_BossInitTransfer_arr, y
    iny
    sta Ram_PpuTransfer_arr, x
    inx
    cpy #.sizeof(DataC_Crypt_BossInitTransfer_arr)
    blt @loop
    stx Zp_PpuTransferLen_u8
    rts
.ENDPROC

;;; Tick function for the CryptBoss room.
.PROC FuncC_Crypt_Boss_TickRoom
    ;; TODO: Implement motion and fireballs for boss.
    inc Ram_RoomState + sState::BossPosX_u8
    rts
.ENDPROC

;;; Draw function for the CryptBoss room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Crypt_Boss_DrawRoom
    ldx #kLeftWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_CryptBoss_DrawSideWall
    ldx #kRightWallPlatformIndex  ; param: platform index
    jsr FuncA_Objects_CryptBoss_DrawSideWall
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
    ldax #Int_CryptBossZoneTopIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    ;; Compute PPU scroll values for the boss zone.
    lda #kBossStartCol * kTileWidthPx + kBossWidthPx / 2
    sub Ram_RoomState + sState::BossPosX_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param1_byte)  ; boss scroll-X
    lda #kBossStartRow * kTileHeightPx + kBossHeightPx / 2 + kBossZoneTopY
    sub Ram_RoomState + sState::BossPosY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param2_byte)  ; boss scroll-Y
_DrawBossPupil:
    ;; Compute the avatar's Y-position relative to the boss.
    lda Zp_AvatarPosY_i16 + 0
    sub Ram_RoomState + sState::BossPosY_u8
    bge @setYOffset
    lda #0
    @setYOffset:
    sta Zp_Tmp1_byte  ; avatar Y-offset
    ;; Compute the avatar's X-position relative to the boss.
    lda Zp_AvatarPosX_i16 + 0
    sub Ram_RoomState + sState::BossPosX_u8
    blt @avatarToTheLeft
    @avatarToTheRight:
    sta Zp_Tmp2_byte  ; avatar X-offset
    div #2
    cmp Zp_Tmp1_byte  ; avatar Y-offset
    bge @lookRight
    lda Zp_Tmp1_byte  ; avatar Y-offset
    div #2
    cmp Zp_Tmp2_byte  ; avatar X-offset
    bge @lookDown
    @lookDownRight:
    ldx #3
    bne @setShapePos  ; unconditional
    @lookRight:
    ldx #4
    bne @setShapePos  ; unconditional
    @lookDown:
    ldx #2
    bne @setShapePos  ; unconditional
    @avatarToTheLeft:
    eor #$ff  ; negate (off by one, but close enough)
    sta Zp_Tmp2_byte  ; avatar X-offset
    div #2
    cmp Zp_Tmp1_byte  ; avatar Y-offset
    bge @lookLeft
    lda Zp_Tmp1_byte  ; avatar Y-offset
    div #2
    cmp Zp_Tmp2_byte  ; avatar X-offset
    bge @lookDown
    @lookDownLeft:
    ldx #1
    bne @setShapePos  ; unconditional
    @lookLeft:
    ldx #0
    @setShapePos:
    lda Ram_RoomState + sState::BossPosX_u8
    sub _EyeOffsetX_u8_arr, x
    sta Zp_ShapePosX_i16 + 0
    lda #0
    sta Zp_ShapePosX_i16 + 1
    lda Ram_RoomState + sState::BossPosY_u8
    sub _EyeOffsetY_u8_arr, x
    sta Zp_ShapePosY_i16 + 0
    lda #0
    sta Zp_ShapePosY_i16 + 1
    ;; Allocate the object for the pupil.
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kTileIdBossPupil
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kBossPupilPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
    rts
_EyeOffsetX_u8_arr:
    .byte 6, 5, 4, 3, 2
_EyeOffsetY_u8_arr:
    .byte 4, 3, 2, 3, 4
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the boss's zone in the CryptBoss
;;; room.  Sets the horizontal and vertical scroll so as to make the boss's BG
;;; tiles appear to move.
.PROC Int_CryptBossZoneTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    ;; Set up the latch value for next IRQ.
    lda #kBossZoneBottomY - kBossZoneTopY - 1
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; Update Zp_NextIrq_int_ptr for the next IRQ.
    ldax #Int_CryptBossZoneBottomIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #5  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the lower
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #$0c  ; nametable number << 2 (so $0c for nametable 3)
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
;;; CryptBoss room.  Sets the horizontal and vertical scroll so as to make the
;;; bottom of the room look normal.
.PROC Int_CryptBossZoneBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    ;; Set up the latch value for next IRQ.
    lda <(Zp_Buffered_sIrq + sIrq::Param3_byte)  ; window latch
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; Update Zp_NextIrq_int_ptr for the next IRQ.
    ldax #Int_WindowTopIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #9  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #$00  ; nametable number << 2 (so $00 for nametable 0)
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
.PROC FuncA_Objects_CryptBoss_DrawSideWall
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx #6
    @loop:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    txa
    and #$01
    add #kTileIdFirstSideWall
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kSideWallPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    dex
    bne @loop
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the winch machine in this room.
.PROC FuncA_Objects_CryptBossWinch_Draw
_Winch:
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex  ; param: chain
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
