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
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_CryptAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_CryptAreaName_u8_arr
.IMPORT DataA_Room_Crypt_sTileset
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Machine_WinchStopFalling
.IMPORT FuncA_Objects_DrawChainWithLength
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_DrawWinchSpikeball
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Objects_SetShapePosToSpikeballCenter
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Ppu_ChrUpgrade
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_PlatformGoal_i16

;;;=========================================================================;;;

;;; The machine index for the CryptWestWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptWestWinch machine and its spikeballs.
kWinchPlatformIndex = 0
kSpikeball1PlatformIndex = 1
kNumSpikeballPlatforms = 4

;;; The initial and maximum permitted values for sState::WinchGoalY_u8.
kWinchInitGoalZ = 2
kWinchMaxGoalZ  = 4

;;; The room pixel position for the left edge of the winch platform.
kWinchPlatformLeft = $78
kSpikeballPlatformLeft = kWinchPlatformLeft + 2

;;; The lengths of the chains between spikeballs, in tiles.
kChain12Tiles = 7
kChain23Tiles = 10
kChain34Tiles = 5

;;; The minimum and initial room pixel positions for the top edges of the
;;; various spikeballs.
.LINECONT +
kSpikeball1MinPlatformTop = $32
kSpikeball1InitPlatformTop = \
    kSpikeball1MinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
kSpikeball2InitPlatformTop = \
    kSpikeball1InitPlatformTop + kBlockHeightPx + kChain12Tiles * kTileHeightPx
kSpikeball3InitPlatformTop = \
    kSpikeball2InitPlatformTop + kBlockHeightPx + kChain23Tiles * kTileHeightPx
kSpikeball4InitPlatformTop = \
    kSpikeball3InitPlatformTop + kBlockHeightPx + kChain34Tiles * kTileHeightPx
.LINECONT +

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The goal value for the CryptWestWinch machine's Z register.
    WinchGoalZ_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_West_sRoom
.PROC DataC_Crypt_West_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 9
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
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/crypt_west.room"
    .assert * - :- = 17 * 24, error
_Machines_sMachine_arr:
    .assert kWinchMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptWestWinch
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Z"
    d_addr Init_func_ptr, _Winch_Init
    d_addr ReadReg_func_ptr, FuncC_Crypt_WestWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Crypt_WestWinch_TryMove
    d_addr TryAct_func_ptr, FuncC_Crypt_WestWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Crypt_WestWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CryptWestWinch_Draw
    d_addr Reset_func_ptr, _Winch_Reset
    D_END
_Platforms_sPlatform_arr:
    .assert kWinchPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert kSpikeball1PlatformIndex = 1, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kSpikeballPlatformLeft
    d_word Top_i16, kSpikeball1InitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kSpikeballPlatformLeft
    d_word Top_i16, kSpikeball2InitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kSpikeballPlatformLeft
    d_word Top_i16, kSpikeball3InitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kSpikeballPlatformLeft
    d_word Top_i16, kSpikeball4InitPlatformTop
    D_END
    .assert kNumSpikeballPlatforms = 4, error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 5
    d_byte Target_u8, kWinchMachineIndex
    D_END
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CryptWest  ; TODO
    d_byte SpawnBlock_u8, 3
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::CryptSouth
    d_byte SpawnBlock_u8, 20
    D_END
_Winch_Init:
_Winch_Reset:
    lda #kWinchInitGoalZ
    sta Ram_RoomState + sState::WinchGoalZ_u8
    rts
.ENDPROC

.PROC FuncC_Crypt_WestWinch_ReadReg
    lda Ram_PlatformTop_i16_0_arr + kSpikeball1PlatformIndex
    sub #kSpikeball1MinPlatformTop - kTileHeightPx
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Crypt_WestWinch_TryMove
    ldy Ram_RoomState + sState::WinchGoalZ_u8
    txa
    .assert eDir::Up = 0, error
    beq @moveUp
    @moveDown:
    cpy #kWinchMaxGoalZ
    bge @error
    iny
    lda #kWinchMoveDownCooldown
    bne @success  ; unconditional
    @moveUp:
    tya
    beq @error
    dey
    lda #kWinchMoveUpCooldown
    @success:
    sty Ram_RoomState + sState::WinchGoalZ_u8
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
.ENDPROC

.PROC FuncC_Crypt_WestWinch_TryAct
    lda #kWinchMaxGoalZ
    sta Ram_RoomState + sState::WinchGoalZ_u8
    jmp FuncA_Machine_WinchStartFalling  ; returns C and A
.ENDPROC

.PROC FuncC_Crypt_WestWinch_Tick
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the uppermost spikeball, storing it in Zp_PlatformGoal_i16.
    lda Ram_RoomState + sState::WinchGoalZ_u8
    mul #kBlockHeightPx
    add #kSpikeball1MinPlatformTop
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kSpikeball1MinPlatformTop < $100, error
    .linecont -
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kSpikeball1PlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the uppermost spikeball vertically, as necessary.
    jsr Func_MovePlatformTopToward  ; preserves X, returns Z and A
    beq @reachedGoal
    ;; If the spikeball moved, move the other spikeballs too.
    inx
    @loop:
    pha  ; param: move delta
    jsr Func_MovePlatformVert  ; preserves X
    pla  ; move delta
    inx
    cpx #kSpikeball1PlatformIndex + kNumSpikeballPlatforms
    blt @loop
    rts
    ;; Otherwise, we're done.
    @reachedGoal:
    jsr FuncA_Machine_WinchStopFalling
    jmp Func_MachineFinishResetting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the CryptWestWinch machine.
.PROC FuncA_Objects_CryptWestWinch_Draw
_Winch:
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Ram_PlatformTop_i16_0_arr + kSpikeball1PlatformIndex  ; param: chain
    jsr FuncA_Objects_DrawWinchMachine
_Spikeballs:
    ldx #kSpikeball1PlatformIndex  ; param: platform index
    @loop:
    jsr FuncA_Objects_SetShapePosToSpikeballCenter  ; preserves X
    jsr FuncA_Objects_DrawWinchSpikeball  ; preserves X
    inx
    cpx #kSpikeball1PlatformIndex + kNumSpikeballPlatforms
    blt @loop
_Chains:
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    ldx #kChain34Tiles  ; param: chain length in tiles
    jsr FuncA_Objects_DrawChainWithLength
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_MoveShapeUpOneTile
    ldx #kChain23Tiles  ; param: chain length in tiles
    jsr FuncA_Objects_DrawChainWithLength
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_MoveShapeUpOneTile
    ldx #kChain12Tiles  ; param: chain length in tiles
    jsr FuncA_Objects_DrawChainWithLength
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_MoveShapeUpOneTile
    ldx #kWinchPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

;;;=========================================================================;;;
