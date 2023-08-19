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
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/pump.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Sewer_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.IMPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjSewer
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The machine index for the SewerFlowerPump machine.
kPumpMachineIndex = 0
;;; The platform index for the SewerFlowerPump machine.
kPumpPlatformIndex = 0
;;; The platform index for the movable water.
kWaterPlatformIndex = 1

;;; The initial and maximum permitted vertical goal values for the pump.
kPumpInitGoalY = 5
kPumpMaxGoalY = 5

;;; The maximum, initial, and minimum Y-positions for the top of the movable
;;; water platform.
kWaterMaxPlatformTop = $00ca
kWaterInitPlatformTop = kWaterMaxPlatformTop - kPumpInitGoalY * kBlockHeightPx
kWaterMinPlatformTop = kWaterMaxPlatformTop - kPumpMaxGoalY * kBlockHeightPx

;;;=========================================================================;;;

.SEGMENT "PRGC_Sewer"

.EXPORT DataC_Sewer_Flower_sRoom
.PROC DataC_Sewer_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $00
    d_byte Flags_bRoom, eArea::Sewer
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 18
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjSewer)
    d_addr Tick_func_ptr, FuncA_Room_RespawnFlowerDeviceIfDropped
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Sewer_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/sewer_flower.room"
    .assert * - :- = 17 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kPumpMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::SewerFlowerPump
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Boiler  ; TODO
    d_word ScrollGoalX_u16, $0
    d_byte ScrollGoalY_u8, $38
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kPumpPlatformIndex
    d_addr Init_func_ptr, FuncC_Sewer_FlowerPump_Init
    d_addr ReadReg_func_ptr, FuncC_Sewer_FlowerPump_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Sewer_FlowerPump_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Sewer_FlowerPump_Tick
    d_addr Draw_func_ptr, FuncA_Objects_SewerFlowerPump_Draw
    d_addr Reset_func_ptr, FuncC_Sewer_FlowerPump_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kPumpPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $14
    d_word Left_i16,  $0088
    d_word Top_i16,   $00bc
    D_END
    .assert * - :- = kWaterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $70
    d_word Left_i16,  $0010
    d_word Top_i16, kWaterInitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0020
    d_word Top_i16,   $00de
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a0
    d_word Top_i16,   $008e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   ;; TODO: add baddies?
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kFlowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eFlag::FlowerSewer
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 6
    d_byte Target_byte, kPumpMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::SewerWest
    d_byte SpawnBlock_u8, 10
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Sewer_FlowerPump_Reset
    .assert * = FuncC_Sewer_FlowerPump_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Sewer_FlowerPump_Init
    lda #kPumpInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kPumpMachineIndex
    rts
.ENDPROC

.PROC FuncC_Sewer_FlowerPump_ReadReg
    .assert kWaterMaxPlatformTop + kTileHeightPx < $100, error
    lda #kWaterMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kWaterPlatformIndex
    .assert kWaterMaxPlatformTop - kWaterMinPlatformTop < $100, error
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Sewer_FlowerPump_TryMove
    lda #kPumpMaxGoalY  ; param: max vertical goal
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncC_Sewer_FlowerPump_Tick
    ;; Calculate the desired Y-position for the top edge of the water, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kPumpMachineIndex
    .assert kPumpMaxGoalY * kBlockHeightPx < $100, error
    mul #kBlockHeightPx
    sta T0  ; goal delta
    .assert kWaterMaxPlatformTop < $100, error
    lda #kWaterMaxPlatformTop
    sub T0  ; goal delta
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the water (faster if resetting).
    lda Ram_MachineStatus_eMachine_arr + kPumpMachineIndex
    cmp #eMachine::Resetting
    beq @fullSpeed
    lda Ram_MachineSlowdown_u8_arr + kPumpMachineIndex
    beq @canMove
    rts
    @canMove:
    lda #kPumpWaterSlowdown
    sta Ram_MachineSlowdown_u8_arr + kPumpMachineIndex
    @fullSpeed:
    lda #1
    ;; Move the water vertically, as necessary.
    ldx #kWaterPlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_SewerFlowerPump_Draw
    ;; TODO: draw the pump machine itself
_WaterLeft:
    ;; Determine the position for the leftmost water object.
    ldx #kWaterPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda Ram_PlatformTop_i16_0_arr + kWaterPlatformIndex
    sub #kWaterMinPlatformTop & $f0
    div #kBlockHeightPx
    tay  ; row index
    lda _WaterOffsetL_u8_arr, y  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves Y
    ;; Determine the water tile ID.
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    tax
    lda _WaterTileIds_u8_arr4, x
    sta T2  ; water tile ID
    ;; Determine the width of the left side of the water in tiles, and draw
    ;; that many objects.
    ldx _WaterWidthL_u8_arr, y
    sty T3  ; row index
    jsr _DrawWaterObjects  ; preserves T2+
_WaterRight:
    ldy T3  ; row index
    lda _WaterOffsetR_u8_arr, y  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves Y
    ;; Determine the width of the right side of the water in tiles, and draw
    ;; that many objects.
    ldx _WaterWidthR_u8_arr, y
_DrawWaterObjects:
    @loop:
    ldy #kPaletteObjWater  ; param: object flags
    lda T2  ; param: water tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and T0+
    dex
    bne @loop
    rts
_WaterTileIds_u8_arr4:
    .byte kTileIdObjWaterFirst + 0
    .byte kTileIdObjWaterFirst + 1
    .byte kTileIdObjWaterFirst + 2
    .byte kTileIdObjWaterFirst + 1
_WaterOffsetL_u8_arr:
    .byte $00, $10, $00, $00, $00, $10, $10
_WaterWidthL_u8_arr:
    .byte 4, 2, 4, 2, 4, 3, 3
_WaterOffsetR_u8_arr:
    .byte $10, $10, $20, $20, $10, $00, $00
_WaterWidthR_u8_arr:
    .byte 2, 4, 2, 4, 2, 3, 3
.ENDPROC

;;;=========================================================================;;;
