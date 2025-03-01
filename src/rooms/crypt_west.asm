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

.IMPORT DataA_Room_Crypt_sTileset
.IMPORT FuncA_Machine_GenericTryMoveZ
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_WinchReachedGoal
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Objects_DrawChainWithLength
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_DrawWinchSpikeball
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToSpikeballCenter
.IMPORT Func_DivAByBlockSizeAndClampTo9
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineState
.IMPORT Ppu_ChrObjCrypt
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The machine index for the CryptWestWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptWestWinch machine and its spikeballs.
kWinchPlatformIndex = 0
kSpikeball1PlatformIndex = 1
kNumSpikeballPlatforms = 4

;;; The initial and maximum permitted values for the winch's Z-goal.
kWinchInitGoalZ = 2
kWinchMaxGoalZ  = 4

;;; The room pixel position for the left edge of the winch platform.
kWinchPlatformLeft = $78
kSpikeballPlatformLeft = kWinchPlatformLeft + 2

;;; The lengths of the chains between spikeballs, in tiles.
kChain12Tiles = 7
kChain23Tiles = 8
kChain34Tiles = 7

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

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_West_sRoom
.PROC DataC_Crypt_West_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0000
    d_byte Flags_bRoom, bRoom::Tall | eArea::Crypt
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 0
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCrypt)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/crypt_west.room"
    .assert * - :- = 17 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptWestWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncC_Crypt_WestWinch_InitReset
    d_addr ReadReg_func_ptr, FuncC_Crypt_WestWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CryptWestWinch_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CryptWestWinch_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CryptWestWinch_Tick
    d_addr Draw_func_ptr, FuncC_Crypt_WestWinch_Draw
    d_addr Reset_func_ptr, FuncC_Crypt_WestWinch_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWinchPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kSpikeball1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kSpikeballWidthPx
    d_byte HeightPx_u8, kSpikeballHeightPx
    d_word Left_i16, kSpikeballPlatformLeft
    d_word Top_i16, kSpikeball1InitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kSpikeballWidthPx
    d_byte HeightPx_u8, kSpikeballHeightPx
    d_word Left_i16, kSpikeballPlatformLeft
    d_word Top_i16, kSpikeball2InitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kSpikeballWidthPx
    d_byte HeightPx_u8, kSpikeballHeightPx
    d_word Left_i16, kSpikeballPlatformLeft
    d_word Top_i16, kSpikeball3InitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kSpikeballWidthPx
    d_byte HeightPx_u8, kSpikeballHeightPx
    d_word Left_i16, kSpikeballPlatformLeft
    d_word Top_i16, kSpikeball4InitPlatformTop
    D_END
    .assert kNumSpikeballPlatforms = 4, error
    ;; Little terrain stone blocks around the winch machine:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $1d
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0071
    d_word Top_i16,   $000c
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBat
    d_word PosX_i16, $00d8
    d_word PosY_i16, $00c8
    d_byte Param_byte, eDir::Up
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBat
    d_word PosX_i16, $0038
    d_word PosY_i16, $00b8
    d_byte Param_byte, eDir::Down
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 3
    d_byte Target_byte, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 5
    d_byte Target_byte, kWinchMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::CryptNest
    d_byte SpawnBlock_u8, 12
    d_byte SpawnAdjust_byte, $f9
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::CryptSouth
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Crypt_WestWinch_ReadReg
    lda Ram_PlatformTop_i16_0_arr + kSpikeball1PlatformIndex
    sub #kSpikeball1MinPlatformTop - kTileHeightPx  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Crypt_WestWinch_Draw
    lda Ram_PlatformTop_i16_0_arr + kSpikeball1PlatformIndex  ; param: chain
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
    lda #kBlockHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    ldx #kChain23Tiles  ; param: chain length in tiles
    jsr FuncA_Objects_DrawChainWithLength
    lda #kBlockHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    ldx #kChain12Tiles  ; param: chain length in tiles
    jsr FuncA_Objects_DrawChainWithLength
    lda #kBlockHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

.PROC FuncC_Crypt_WestWinch_InitReset
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp Func_ResetWinchMachineState
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_CryptWestWinch_TryMove
    lda #kWinchMaxGoalZ  ; param: max goal
    jmp FuncA_Machine_GenericTryMoveZ
.ENDPROC

.PROC FuncA_Machine_CryptWestWinch_TryAct
    lda #kWinchMaxGoalZ  ; param: new Z-goal
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

.PROC FuncA_Machine_CryptWestWinch_Tick
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the uppermost spikeball, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #kBlockHeightPx
    add #kSpikeball1MinPlatformTop
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kSpikeball1MinPlatformTop < $100, error
    .linecont -
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kSpikeball1PlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the uppermost spikeball vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; preserves X, returns Z and A
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
    jmp FuncA_Machine_WinchReachedGoal
.ENDPROC

;;;=========================================================================;;;
