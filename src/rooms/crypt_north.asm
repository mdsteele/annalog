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
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveZ
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_LiftTick
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Machine_WinchReachedGoal
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT FuncA_Objects_DrawWinchChain
.IMPORT FuncA_Objects_DrawWinchMachine
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineState
.IMPORT Func_WriteToLowerAttributeTable
.IMPORT Ppu_ChrObjCrypt
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The machine indices for the CryptNorthWinch and CryptNorthLift machines in
;;; this room.
kWinchMachineIndex = 0
kLiftMachineIndex = 1

;;; The platform indices for the CryptNorthWinch machine, its girder, and the
;;; CryptNorthLift machine.
kWinchPlatformIndex = 0
kGirderPlatformIndex = 1
kLiftPlatformIndex = 2

;;; The initial and maximum permitted values for the winch's Z-goal.
kWinchInitGoalZ = 0
kWinchMaxGoalZ  = 9

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 0
kLiftMaxGoalY = 9

;;; The minimum and initial room pixel position for the top edge of the girder.
.LINECONT +
kGirderMinPlatformTop = $0072
kGirderInitPlatformTop = \
    kGirderMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;; The maximum, initial, and minimum Y-positions for the top of the lift
;;; platform.
kLiftMaxPlatformTop = $0110
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx
kLiftMinPlatformTop = kLiftMaxPlatformTop - kLiftMaxGoalY * kBlockHeightPx

;;;=========================================================================;;;

.SEGMENT "PRGC_Crypt"

.EXPORT DataC_Crypt_North_sRoom
.PROC DataC_Crypt_North_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Crypt
    d_byte MinimapStartRow_u8, 8
    d_byte MinimapStartCol_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCrypt)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncA_Terrain_CryptNorth_FadeInRoom
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/crypt_north.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptNorthWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $0010
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, "W", 0, "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncC_Crypt_NorthWinch_InitReset
    d_addr ReadReg_func_ptr, FuncC_Crypt_NorthWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CryptNorthWinch_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CryptNorthWinch_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CryptNorthWinch_Tick
    d_addr Draw_func_ptr, FuncC_Crypt_NorthWinch_Draw
    d_addr Reset_func_ptr, FuncC_Crypt_NorthWinch_InitReset
    D_END
    .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CryptNorthLift
    d_byte Breaker_eFlag, eFlag::BreakerCrypt
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $0010
    d_byte ScrollGoalY_u8, $c0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncC_Crypt_NorthLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Crypt_NorthLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CryptNorthLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_CryptNorthLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncC_Crypt_NorthLift_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWinchPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0068
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kGirderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0064
    d_word Top_i16, kGirderInitPlatformTop
    D_END
    .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $00e0
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $60
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0030
    d_word Top_i16,   $010e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $90
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0040
    d_word Top_i16,   $015e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 4
    d_byte Target_byte, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 8
    d_byte Target_byte, kLiftMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CryptLanding
    d_byte SpawnBlock_u8, 6
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CryptEscape
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CryptNest
    d_byte SpawnBlock_u8, 19
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Crypt_NorthWinch_ReadReg
    cmp #$f
    beq _ReadZ
_ReadW:
    lda #1
    ldx Zp_AvatarPlatformIndex_u8
    cpx #kGirderPlatformIndex
    beq @done
    lda #0
    @done:
    rts
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kGirderPlatformIndex
    sub #kGirderMinPlatformTop - kTileHeightPx
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Crypt_NorthLift_ReadReg
    .assert kLiftMaxPlatformTop + kTileHeightPx >= $100, error
    lda #<(kLiftMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    .assert kLiftMaxPlatformTop - kLiftMinPlatformTop < $100, error
    div #kBlockHeightPx
    rts
.ENDPROC

;;; Draws the CryptNorthWinch machine.
.PROC FuncC_Crypt_NorthWinch_Draw
    ;; Draw the winch itself.
    lda Ram_PlatformTop_i16_0_arr + kGirderPlatformIndex  ; param: chain
    jsr FuncA_Objects_DrawWinchMachine
    ;; Draw the girder.
    ldx #kGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawGirderPlatform
    ;; Draw the chain between the girder and the winch.
    jsr FuncA_Objects_MoveShapeLeftOneTile
    jmp FuncA_Objects_DrawWinchChain
.ENDPROC

.PROC FuncC_Crypt_NorthWinch_InitReset
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp Func_ResetWinchMachineState
.ENDPROC

.PROC FuncC_Crypt_NorthLift_InitReset
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_CryptNorthWinch_TryMove
    lda #kWinchMaxGoalZ  ; param: max goal
    jmp FuncA_Machine_GenericTryMoveZ
.ENDPROC

.PROC FuncA_Machine_CryptNorthWinch_TryAct
    lda #kWinchMaxGoalZ  ; param: new Z-goal
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

.PROC FuncA_Machine_CryptNorthWinch_Tick
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the upper girder, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #kBlockHeightPx
    add #<kGirderMinPlatformTop
    sta Zp_PointY_i16 + 0
    lda #0
    adc #>kGirderMinPlatformTop
    sta Zp_PointY_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kGirderPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the girder vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; returns Z and A
    jeq FuncA_Machine_WinchReachedGoal
    rts
.ENDPROC

.PROC FuncA_Machine_CryptNorthLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncA_Machine_CryptNorthLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_LiftTick
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

.PROC FuncA_Terrain_CryptNorth_FadeInRoom
    ldx #2    ; param: num bytes to write
    ldy #$10  ; param: attribute value
    lda #$02  ; param: initial byte offset
    jsr Func_WriteToLowerAttributeTable
    ldx #3    ; param: num bytes to write
    ldy #$05  ; param: attribute value
    lda #$1b  ; param: initial byte offset
    jmp Func_WriteToLowerAttributeTable
.ENDPROC

;;;=========================================================================;;;
