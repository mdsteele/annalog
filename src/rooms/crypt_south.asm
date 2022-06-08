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
.INCLUDE "../machine.inc"
.INCLUDE "../machines/winch.inc"
.INCLUDE "../macros.inc"
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
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The machine index for the CryptSouthWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptSouthWinch machine, the crusher that
;;; hangs from its chain, and the breakable floor.
kWinchPlatformIndex        = 0
kCrusherUpperPlatformIndex = 1
kCrusherSpikePlatformIndex = 2
kWeakFloorPlatformIndex    = 3

;;; The initial and maximum permitted values for sState::WinchGoalX_u8.
kWinchInitGoalX = 0
kWinchMaxGoalX  = 9
;;; The initial and maximum permitted values for sState::WinchGoalZ_u8.
kWinchInitGoalZ = 5
kWinchMaxGoalZ  = 17

;;; The minimum and initial room pixel position for the left edge of the winch.
.LINECONT +
kWinchMinPlatformLeft = $40
kWinchInitPlatformLeft = \
    kWinchMinPlatformLeft + kBlockWidthPx * kWinchInitGoalX
.LINECONT +

;;; The minimum and initial room pixel position for the top edge of the
;;; crusher.
.LINECONT +
kCrusherMinPlatformTop = $40
kCrusherInitPlatformTop = \
    kCrusherMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;; Various OBJ tile IDs used for drawing the CryptSouthWinch machine.
kTileIdCrusherUpperLeft  = $b4
kTileIdCrusherUpperRight = $b6
kTileIdCrusherSpikes     = $b5

;;; The OBJ palette number used for various parts of the CryptSouthWinch
;;; machine.
kWinchCrusherPalette = 0

;;;=========================================================================;;;

;;; Enum for the steps of the CryptSouthWinch machine's reset sequence (listed
;;; in reverse order).
.ENUM eResetSeq
    Down = 0  ; last step: move down to initial position
    UpLeft    ; move up (if necessary), then move left
.ENDENUM

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The goal values for the CryptSouthWinch machine's X and Z registers.
    WinchGoalX_u8 .byte
    WinchGoalZ_u8 .byte
    ;; Which step of its reset sequence the CryptSouthWinch machine is on.
    WinchReset_eResetSeq .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_South_sRoom
.PROC DataC_Crypt_South_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 1
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrUpgrade)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
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
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/crypt_south.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
    .assert kWinchMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptSouthWinch
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, "W", "X", "Z"
    d_addr Init_func_ptr, FuncC_Crypt_SouthWinch_Init
    d_addr ReadReg_func_ptr, FuncC_Crypt_SouthWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Crypt_SouthWinch_TryMove
    d_addr TryAct_func_ptr, FuncC_Crypt_SouthWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Crypt_SouthWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CryptSouthWinch_Draw
    d_addr Reset_func_ptr, FuncC_Crypt_SouthWinch_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kWinchPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert kCrusherUpperPlatformIndex = 1, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $08
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16, kCrusherInitPlatformTop
    D_END
    .assert kCrusherSpikePlatformIndex = 2, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $0e
    d_byte HeightPx_u8, $06
    d_word Left_i16, kWinchInitPlatformLeft + 1
    d_word Top_i16, kCrusherInitPlatformTop + kTileHeightPx
    D_END
    .assert kWeakFloorPlatformIndex = 3, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00c0
    d_word Top_i16,   $00a0
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0040
    d_word Top_i16,   $00ae
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e0
    d_word Top_i16,   $009e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $c0
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $015e
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 9
    d_byte Target_u8, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 9
    d_byte Target_u8, kWinchMachineIndex
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CryptSouth  ; TODO
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CryptSouth  ; TODO
    d_byte SpawnBlock_u8, 3
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CryptTomb
    d_byte SpawnBlock_u8, 19
    D_END
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_ReadReg
    cmp #$f
    beq _ReadZ
    cmp #$e
    beq _ReadX
_ReadW:
    lda #1
    ldx Zp_AvatarPlatformIndex_u8
    cpx #kCrusherUpperPlatformIndex
    beq @done
    lda #0
    @done:
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kWinchPlatformIndex
    sub #kWinchMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kCrusherUpperPlatformIndex
    sub #kCrusherMinPlatformTop - kTileHeightPx
    sta Zp_Tmp1_byte
    lda Ram_PlatformTop_i16_1_arr + kCrusherUpperPlatformIndex
    sbc #0
    .assert kBlockHeightPx = 16, error
    .repeat 4
    lsr a
    ror Zp_Tmp1_byte
    .endrepeat
    lda Zp_Tmp1_byte
    cmp #9
    blt @done
    lda #9
    @done:
    rts
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_TryMove
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
    lda DataC_Crypt_SouthFloor_u8_arr, y
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
    cmp DataC_Crypt_SouthFloor_u8_arr, y
    bge _Error
    inc Ram_RoomState + sState::WinchGoalZ_u8
    lda #kWinchMoveDownCooldown
    clc  ; success
    rts
_Error:
    sec  ; failure
    rts
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_TryAct
    ldy Ram_RoomState + sState::WinchGoalX_u8
    lda DataC_Crypt_SouthFloor_u8_arr, y
    tax  ; new goal Z
    sub Ram_RoomState + sState::WinchGoalZ_u8  ; param: fall distance
    stx Ram_RoomState + sState::WinchGoalZ_u8
    jmp FuncA_Machine_WinchStartFalling  ; returns C and A
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_Tick
_MoveVert:
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the crusher, storing it in Zp_PlatformGoal_i16.
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    lda Ram_RoomState + sState::WinchGoalZ_u8
    mul #16
    .assert kWinchMaxGoalZ >= 16, error  ; The multiplication may carry.
    .assert kWinchMaxGoalZ < 32, error  ; There can only be one carry bit.
    rol Zp_PlatformGoal_i16 + 1  ; Handle carry bit from multiplication.
    add #kCrusherMinPlatformTop
    sta Zp_PlatformGoal_i16 + 0
    lda Zp_PlatformGoal_i16 + 1
    adc #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kCrusherUpperPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the crusher vertically, as necessary.
    jsr Func_MovePlatformTopToward  ; returns Z and A
    beq @done
    ;; If the crusher moved, move the crusher's other platform too.
    ldx #kCrusherSpikePlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @done:
    lda #0
    sta Ram_MachineParam1_u8_arr + kWinchMachineIndex  ; stop falling
_MoveHorz:
    ;; Calculate the desired X-position for the left edge of the winch, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    lda Ram_RoomState + sState::WinchGoalX_u8
    mul #kBlockWidthPx
    add #kWinchMinPlatformLeft
    sta Zp_PlatformGoal_i16 + 0
    ;; Move the winch horizontally, if necessary.
    jsr FuncA_Machine_GetWinchHorzSpeed  ; returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftToward  ; returns Z and A
    beq @done
    ;; If the winch moved, move the crusher platforms too.
    pha  ; move delta
    ldx #kCrusherUpperPlatformIndex  ; param: platform index
    jsr Func_MovePlatformHorz
    pla  ; param: move delta
    ldx #kCrusherSpikePlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @done:
_Finished:
    lda Ram_RoomState + sState::WinchReset_eResetSeq
    jeq Func_MachineFinishResetting
    .assert * = FuncC_Crypt_SouthWinch_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_Reset
    lda Ram_RoomState + sState::WinchGoalX_u8
    .assert kWinchInitGoalX = 0, error
    beq FuncC_Crypt_SouthWinch_Init
    lda #kWinchInitGoalX
    sta Ram_RoomState + sState::WinchGoalX_u8
    lda Ram_RoomState + sState::WinchGoalZ_u8
    cmp #3
    blt @left
    @up:
    lda #2
    sta Ram_RoomState + sState::WinchGoalZ_u8
    @left:
    lda #eResetSeq::UpLeft
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    rts
.ENDPROC

.PROC FuncC_Crypt_SouthWinch_Init
    lda #kWinchInitGoalX
    sta Ram_RoomState + sState::WinchGoalX_u8
    lda #kWinchInitGoalZ
    sta Ram_RoomState + sState::WinchGoalZ_u8
    lda #0
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    rts
.ENDPROC

.PROC DataC_Crypt_SouthFloor_u8_arr
    .byte 6, 2, 6, 4, 6, 3, 6, 5, 17, 3
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the CryptSouthWinch machine.
.PROC FuncA_Objects_CryptSouthWinch_Draw
_Winch:
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Ram_PlatformTop_i16_0_arr + kCrusherUpperPlatformIndex  ; param: chain
    jsr FuncA_Objects_DrawWinchMachine
_Crusher:
    ldx #kCrusherSpikePlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda Zp_ShapePosX_i16 + 0
    add #7
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    lda #kWinchCrusherPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    lda #kTileIdCrusherUpperLeft
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdCrusherUpperRight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdCrusherSpikes
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_Chain:
    jsr FuncA_Objects_MoveShapeUpOneTile
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    sta Zp_ShapePosX_i16 + 1
    ldx #kWinchPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

;;;=========================================================================;;;
