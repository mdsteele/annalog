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
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_GetWinchHorzSpeed
.IMPORT Func_GetWinchVertSpeed
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Func_WinchStartFalling
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; The machine index for the CryptTombWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptTombWinch machine, the crusher that
;;; hangs from its chain, and the breakable floor.
kWinchPlatformIndex      = 0
kSpikeballPlatformIndex  = 1
kWeakFloor1PlatformIndex = 2
kWeakFloor2PlatformIndex = 3

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
kSpikeballMinPlatformTop = $22
kSpikeballInitPlatformTop = \
    kSpikeballMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;; Various OBJ tile IDs used for drawing the CryptTombWinch machine.
kTileIdSpikeballFirst = $b8

;;; The OBJ palette number used for various parts of the CryptTombWinch
;;; machine.
kSpikeballPalette = 0

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
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_Tomb_sRoom
.PROC DataC_Crypt_Tomb_sRoom
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
:   .incbin "out/data/crypt_tomb.room"
    .assert * - :- = 17 * 16, error
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
    d_addr Init_func_ptr, FuncC_Crypt_TombWinch_Init
    d_addr ReadReg_func_ptr, FuncC_Crypt_TombWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Crypt_TombWinch_TryMove
    d_addr TryAct_func_ptr, FuncC_Crypt_TombWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Crypt_TombWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CryptTombWinch_Draw
    d_addr Reset_func_ptr, FuncC_Crypt_TombWinch_Reset
    d_byte Padding
    .res kMachinePadding
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
    .assert kSpikeballPlatformIndex = 1, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $0d
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kWinchInitPlatformLeft + 2
    d_word Top_i16, kSpikeballInitPlatformTop
    D_END
    .assert kWeakFloor1PlatformIndex = 2, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0030
    d_word Top_i16,   $00a0
    D_END
    .assert kWeakFloor2PlatformIndex = 3, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00c0
    d_word Top_i16,   $0080
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0010
    d_word Top_i16,   $00ae
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00d0
    d_word Top_i16,   $00ae
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_byte WidthPx_u8,  $50
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
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 9
    d_byte Target_u8, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 5
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 7
    d_byte Target_u8, sState::LeverRight_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_u8, eRoom::CryptTomb  ; TODO
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CryptSouth
    d_byte SpawnBlock_u8, 7
    D_END
.ENDPROC

.PROC FuncC_Crypt_TombWinch_ReadReg
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

.PROC FuncC_Crypt_TombWinch_TryMove
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
    lda DataC_Crypt_TombFloor_u8_arr, y
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
    cmp DataC_Crypt_TombFloor_u8_arr, y
    bge _Error
    inc Ram_RoomState + sState::WinchGoalZ_u8
    lda #kWinchMoveDownCooldown
    clc  ; success
    rts
_Error:
    sec  ; failure
    rts
.ENDPROC

.PROC FuncC_Crypt_TombWinch_TryAct
    ldy Ram_RoomState + sState::WinchGoalX_u8
    lda DataC_Crypt_TombFloor_u8_arr, y
    tax  ; new goal Z
    sub Ram_RoomState + sState::WinchGoalZ_u8  ; param: fall distance
    stx Ram_RoomState + sState::WinchGoalZ_u8
    jmp Func_WinchStartFalling  ; returns C and A
.ENDPROC

.PROC FuncC_Crypt_TombWinch_Tick
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
    jsr Func_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the spikeball vertically, as necessary.
    jsr Func_MovePlatformTopToward  ; returns Z
    beq @done
    rts
    @done:
    lda #0
    sta Ram_MachineParam1_u8_arr + kWinchMachineIndex  ; stop falling
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
    jsr Func_GetWinchHorzSpeed  ; preserves X, returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftToward  ; preserves X, returns Z and A
    beq @done
    ;; If the winch moved, move the spikeball platform too.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @done:
_Finished:
    lda Ram_RoomState + sState::WinchReset_eResetSeq
    jeq Func_MachineFinishResetting
    .assert * = FuncC_Crypt_TombWinch_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_TombWinch_Reset
    lda Ram_RoomState + sState::WinchGoalX_u8
    cmp #3
    blt _Outer
    cmp #6
    blt _Inner
_Outer:
    lda #kWinchInitGoalX
    sta Ram_RoomState + sState::WinchGoalX_u8
    lda #0
    sta Ram_RoomState + sState::WinchGoalZ_u8
    lda #eResetSeq::TopCenter
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    rts
_Inner:
    .assert * = FuncC_Crypt_TombWinch_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Crypt_TombWinch_Init
    lda #kWinchInitGoalX
    sta Ram_RoomState + sState::WinchGoalX_u8
    lda #kWinchInitGoalZ
    sta Ram_RoomState + sState::WinchGoalZ_u8
    lda #0
    sta Ram_RoomState + sState::WinchReset_eResetSeq
    rts
.ENDPROC

.PROC DataC_Crypt_TombFloor_u8_arr
    .byte 9, 0, 0, 5, 5, 5, 0, 5, 5, 7
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the CryptTombWinch machine.
.PROC FuncA_Objects_CryptTombWinch_Draw
_Winch:
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex  ; param: chain
    jsr FuncA_Objects_DrawWinchMachine
_Spikeball:
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda Zp_ShapePosX_i16 + 0
    add #6
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    lda Zp_ShapePosY_i16 + 0
    add #6
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #0
    sta Zp_ShapePosY_i16 + 1
    lda #kSpikeballPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; returns C and Y
    bcs @done
    lda #kTileIdSpikeballFirst + 0
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdSpikeballFirst + 1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdSpikeballFirst + 2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdSpikeballFirst + 3
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
