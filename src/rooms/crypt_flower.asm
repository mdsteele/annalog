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
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineParams
.IMPORT Ppu_ChrObjUpgrade
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_PlatformGoal_i16

;;;=========================================================================;;;

;;; The machine index for the CryptFlowerWinch machine in this room.
kWinchMachineIndex = 0

;;; The platform indices for the CryptFlowerWinch machine and its girders.
kWinchPlatformIndex       = 0
kUpperGirderPlatformIndex = 1
kLowerGirderPlatformIndex = 2

;;; The initial and maximum permitted values for sState::WinchGoalY_u8.
kWinchInitGoalZ = 3
kWinchMaxGoalZ  = 5

;;; The minimum and initial room pixel position for the top edge of the upper
;;; girder.
.LINECONT +
kUpperGirderMinPlatformTop = $48
kUpperGirderInitPlatformTop = \
    kUpperGirderMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The goal value for the CryptFlowerWinch machine's Z register.
    WinchGoalZ_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_Flower_sRoom
.PROC DataC_Crypt_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 3
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjUpgrade)
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
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/crypt_flower.room"
    .assert * - :- = 17 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptFlowerWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, "W", 0, "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, _Winch_Init
    d_addr ReadReg_func_ptr, FuncC_Crypt_FlowerWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Crypt_FlowerWinch_TryMove
    d_addr TryAct_func_ptr, FuncC_Crypt_FlowerWinch_TryAct
    d_addr Tick_func_ptr, FuncC_Crypt_FlowerWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CryptFlowerWinch_Draw
    d_addr Reset_func_ptr, _Winch_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWinchPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0088
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kUpperGirderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0084
    d_word Top_i16, kUpperGirderInitPlatformTop
    D_END
    .assert * - :- = kLowerGirderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0084
    d_word Top_i16, kUpperGirderInitPlatformTop + $28
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $2f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $005e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $1f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a1
    d_word Top_i16,   $005e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $d0
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $00ce
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadSpider
    d_byte TileRow_u8, 15
    d_byte TileCol_u8, 24
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 4
    d_byte Target_u8, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 4
    d_byte Target_u8, eFlag::FlowerCrypt
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CryptFlower  ; TODO
    d_byte SpawnBlock_u8, 3
    D_END
_Winch_Init:
_Winch_Reset:
    lda #kWinchInitGoalZ
    sta Ram_RoomState + sState::WinchGoalZ_u8
    jmp Func_ResetWinchMachineParams
.ENDPROC

.PROC FuncC_Crypt_FlowerWinch_ReadReg
    cmp #$f
    beq _ReadZ
_ReadW:
    lda #1
    ldx Zp_AvatarPlatformIndex_u8
    cpx #kUpperGirderPlatformIndex
    beq @done
    cpx #kLowerGirderPlatformIndex
    beq @done
    lda #0
    @done:
    rts
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kUpperGirderPlatformIndex
    sub #kUpperGirderMinPlatformTop - kTileHeightPx
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Crypt_FlowerWinch_TryMove
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

.PROC FuncC_Crypt_FlowerWinch_TryAct
    lda #kWinchMaxGoalZ
    sta Ram_RoomState + sState::WinchGoalZ_u8
    jmp FuncA_Machine_WinchStartFalling  ; returns C and A
.ENDPROC

.PROC FuncC_Crypt_FlowerWinch_Tick
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the upper girder, storing it in Zp_PlatformGoal_i16.
    lda Ram_RoomState + sState::WinchGoalZ_u8
    mul #kBlockHeightPx
    add #kUpperGirderMinPlatformTop
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kUpperGirderMinPlatformTop < $100, error
    .linecont -
    sta Zp_PlatformGoal_i16 + 0
    lda #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kUpperGirderPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the upper girder vertically, as necessary.
    jsr Func_MovePlatformTopToward  ; returns Z and A
    beq @reachedGoal
    ;; If the girder moved, move the other girder too.
    ldx #kLowerGirderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @reachedGoal:
    jsr FuncA_Machine_WinchStopFalling
    jmp Func_MachineFinishResetting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the CryptFlowerWinch machine.
.PROC FuncA_Objects_CryptFlowerWinch_Draw
    ;; Draw the winch machine.
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Ram_PlatformTop_i16_0_arr + kUpperGirderPlatformIndex  ; param: chain
    jsr FuncA_Objects_DrawWinchMachine
    ;; Draw the two girders.
    ldx #kUpperGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawGirderPlatform
    ldx #kLowerGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawGirderPlatform
    ;; Draw the chain between the two girders.
    jsr FuncA_Objects_MoveShapeLeftOneTile
    ldx #4  ; param: chain length in tiles
    jsr FuncA_Objects_DrawChainWithLength
    ;; Draw the chain between the top girder and the winch.
    jsr FuncA_Objects_MoveShapeUpOneTile
    ldx #kWinchPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

;;;=========================================================================;;;
