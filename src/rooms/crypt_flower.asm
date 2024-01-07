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
.INCLUDE "../devices/flower.inc"
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
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.IMPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineState
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Ppu_ChrObjCrypt
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_PointY_i16

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
kUpperGirderMinPlatformTop = $4a
kUpperGirderInitPlatformTop = \
    kUpperGirderMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_Flower_sRoom
.PROC DataC_Crypt_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, eArea::Crypt
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 3
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
    d_addr Enter_func_ptr, FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
    d_addr FadeIn_func_ptr, FuncA_Terrain_CryptFlower_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_RespawnFlowerDeviceIfDropped
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/crypt_flower.room"
    .assert * - :- = 17 * 15, error
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
    d_addr Init_func_ptr, FuncA_Room_CryptFlowerWinch_InitReset
    d_addr ReadReg_func_ptr, FuncC_Crypt_FlowerWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CryptFlowerWinch_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CryptFlowerWinch_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CryptFlowerWinch_Tick
    d_addr Draw_func_ptr, FuncC_Crypt_FlowerWinch_Draw
    d_addr Reset_func_ptr, FuncA_Room_CryptFlowerWinch_InitReset
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
    ;; Little terrain stone blocks around the winch machine:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $1d
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0081
    d_word Top_i16,   $000c
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
    d_byte Type_eActor, eActor::BadBat
    d_word PosX_i16, $00c8
    d_word PosY_i16, $0020
    d_byte Param_byte, eDir::Down
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadSpider
    d_word PosX_i16, $00c0
    d_word PosY_i16, $0078
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kFlowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eFlag::FlowerCrypt
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 4
    d_byte Target_byte, kWinchMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CryptEast
    d_byte SpawnBlock_u8, 3
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
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

;;; Draws the CryptFlowerWinch machine.
.PROC FuncC_Crypt_FlowerWinch_Draw
    ;; Draw the winch itself.
    lda Ram_PlatformTop_i16_0_arr + kUpperGirderPlatformIndex  ; param: chain
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
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CryptFlowerWinch_InitReset
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp Func_ResetWinchMachineState
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_CryptFlowerWinch_TryMove
    lda #kWinchMaxGoalZ  ; param: max goal
    jmp FuncA_Machine_GenericTryMoveZ
.ENDPROC

.PROC FuncA_Machine_CryptFlowerWinch_TryAct
    lda #kWinchMaxGoalZ  ; param: new Z-goal
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

.PROC FuncA_Machine_CryptFlowerWinch_Tick
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the upper girder, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #kBlockHeightPx
    add #kUpperGirderMinPlatformTop
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kUpperGirderMinPlatformTop < $100, error
    .linecont -
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kUpperGirderPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the upper girder vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; returns Z and A
    beq @reachedGoal
    ;; If the girder moved, move the other girder too.
    ldx #kLowerGirderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @reachedGoal:
    jmp FuncA_Machine_WinchReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC FuncA_Terrain_CryptFlower_FadeInRoom
    ldx #4    ; param: num bytes to write
    ldy #$50  ; param: attribute value
    lda #$12  ; param: initial byte offset
    jsr Func_WriteToUpperAttributeTable
    ldx #7    ; param: num bytes to write
    ldy #$05  ; param: attribute value
    lda #$31  ; param: initial byte offset
    jmp Func_WriteToUpperAttributeTable
.ENDPROC

;;;=========================================================================;;;
