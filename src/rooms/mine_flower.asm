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
.INCLUDE "../machines/hoist.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/girder.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "mine_west.inc"

.IMPORT DataA_Room_Mine_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_HoistMoveTowardGoal
.IMPORT FuncA_Machine_HoistTryMove
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_DrawHoistMachine
.IMPORT FuncA_Objects_DrawHoistPulley
.IMPORT FuncA_Objects_DrawHoistRopeToPulley
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.IMPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformTop_i16_0_arr

;;;=========================================================================;;;

;;; The machine indices for the MineFlowerHoistWest and MineFlowerHoistEast
;;; machines.
kHoistWestMachineIndex = 0
kHoistEastMachineIndex = 1

;;; The primary platform indices for the MineFlowerHoistWest and
;;; MineFlowerHoistEast machines.
kHoistWestPlatformIndex = 0
kHoistEastPlatformIndex = 1
;;; Platform indices for the two pulleys.
kPulleyWestPlatformIndex = 2
kPulleyEastPlatformIndex = 3
;;; The platform indices for the spikes/ceilings/floors of the cages.
kCageWestSpikePlatformIndex = 4
kCageWestUpperPlatformIndex = 5
kCageWestLowerPlatformIndex = 6
kCageEastSpikePlatformIndex = 7
kCageEastUpperPlatformIndex = 8
kCageEastLowerPlatformIndex = 9

;;; The width and height for each platform that makes up the cages.
kCagePlatformWidth = kTileWidthPx * 2
kCagePlatformHeight = kTileHeightPx - 1

;;; The vertical distance, in pixels, between the tops of the upper and lower
;;; platforms in each cage.
kCagePlatformSpacing = $18

;;; The room pixel X-positions of the left sides of the cages.
kCageWestPlatformLeft = $80
kCageEastPlatformLeft = $91

;;; The initial and maximum permitted values for the western hoist's Z-goal.
kHoistWestInitGoalZ = 3
kHoistWestMaxGoalZ  = 5
;;; The initial and maximum permitted values for the eastern hoist's Z-goal.
kHoistEastInitGoalZ = 2
kHoistEastMaxGoalZ  = 4

;;; The minimum and initial room pixel position for the top edges of the
;;; western and eastern cages.
.LINECONT +
kCageWestMinTop = $0020
kCageWestInitTop = kCageWestMinTop + kBlockHeightPx * kHoistWestInitGoalZ
kCageEastMinTop = $0070
kCageEastInitTop = kCageEastMinTop + kBlockHeightPx * kHoistEastInitGoalZ
.LINECONT +

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_Flower_sRoom
.PROC DataC_Mine_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Mine
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 18
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_RespawnFlowerDeviceIfDropped
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/mine_flower.room"
    .assert * - :- = 17 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kHoistWestMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineFlowerHoistWest
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::HoistRight
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, 0, 0, 0, "Z"
    d_byte MainPlatform_u8, kHoistWestPlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_FlowerHoistWest_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mine_FlowerHoistWest_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MineFlowerHoistWest_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MineFlowerHoistWest_Tick
    d_addr Draw_func_ptr, FuncC_Mine_FlowerHoistWest_Draw
    d_addr Reset_func_ptr, FuncC_Mine_FlowerHoistWest_InitReset
    D_END
    .assert * - :- = kHoistEastMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineFlowerHoistEast
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::HoistLeft
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, 0, 0, 0, "Z"
    d_byte MainPlatform_u8, kHoistEastPlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_FlowerHoistEast_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mine_FlowerHoistEast_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MineFlowerHoistEast_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MineFlowerHoistEast_Tick
    d_addr Draw_func_ptr, FuncC_Mine_FlowerHoistEast_Draw
    d_addr Reset_func_ptr, FuncC_Mine_FlowerHoistEast_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kHoistWestPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kHoistMachineWidthPx
    d_byte HeightPx_u8, kHoistMachineHeightPx
    d_word Left_i16, $0040
    d_word Top_i16,  $0040
    D_END
    .assert * - :- = kHoistEastPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kHoistMachineWidthPx
    d_byte HeightPx_u8, kHoistMachineHeightPx
    d_word Left_i16, $00c0
    d_word Top_i16,  $0080
    D_END
    .assert * - :- = kPulleyWestPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0080
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kPulleyEastPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0098
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kCageWestSpikePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kCagePlatformWidth - 2
    d_byte HeightPx_u8, kCagePlatformHeight
    d_word Left_i16, kCageWestPlatformLeft + 1
    d_word Top_i16, kCageWestInitTop - 2
    D_END
    .assert * - :- = kCageWestUpperPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kCagePlatformWidth
    d_byte HeightPx_u8, kCagePlatformHeight
    d_word Left_i16, kCageWestPlatformLeft
    d_word Top_i16, kCageWestInitTop
    D_END
    .assert * - :- = kCageWestLowerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kCagePlatformWidth
    d_byte HeightPx_u8, kCagePlatformHeight
    d_word Left_i16, kCageWestPlatformLeft
    d_word Top_i16, kCageWestInitTop + kCagePlatformSpacing
    D_END
    .assert * - :- = kCageEastSpikePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kCagePlatformWidth - 2
    d_byte HeightPx_u8, kCagePlatformHeight
    d_word Left_i16, kCageEastPlatformLeft + 1
    d_word Top_i16, kCageEastInitTop - 2
    D_END
    .assert * - :- = kCageEastUpperPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kCagePlatformWidth
    d_byte HeightPx_u8, kCagePlatformHeight
    d_word Left_i16, kCageEastPlatformLeft
    d_word Top_i16, kCageEastInitTop
    D_END
    .assert * - :- = kCageEastLowerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kCagePlatformWidth
    d_byte HeightPx_u8, kCagePlatformHeight
    d_word Left_i16, kCageEastPlatformLeft
    d_word Top_i16, kCageEastInitTop + kCagePlatformSpacing
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kFlowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eFlag::FlowerMine
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_byte, kHoistWestMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kHoistEastMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 1
    d_byte Target_byte, eFlag::PaperJerome09
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MineWest
    d_byte SpawnBlock_u8, 11
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Mine_FlowerHoistWest_ReadReg
    lda Ram_PlatformTop_i16_0_arr + kCageWestUpperPlatformIndex
    sub #kCageWestMinTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Mine_FlowerHoistEast_ReadReg
    lda Ram_PlatformTop_i16_0_arr + kCageEastUpperPlatformIndex
    sub #kCageEastMinTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Mine_FlowerHoistWest_Draw
    ldx #kPulleyWestPlatformIndex  ; param: platform index
    ldy Ram_PlatformTop_i16_0_arr + kCageWestUpperPlatformIndex  ; param: rope
    jsr FuncA_Objects_DrawHoistPulley
    ldx #kCageWestLowerPlatformIndex  ; param: platform index
    jsr FuncC_Mine_Flower_DrawCage
    ldx #kPulleyWestPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistRopeToPulley
    lda Ram_PlatformTop_i16_0_arr + kCageWestUpperPlatformIndex  ; param: rope
    jmp FuncA_Objects_DrawHoistMachine
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Mine_FlowerHoistEast_Draw
    ldx #kPulleyEastPlatformIndex  ; param: platform index
    ldy Ram_PlatformTop_i16_0_arr + kCageEastUpperPlatformIndex  ; param: rope
    jsr FuncA_Objects_DrawHoistPulley
    ldx #kCageEastLowerPlatformIndex  ; param: platform index
    jsr FuncC_Mine_Flower_DrawCage
    ldx #kPulleyEastPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistRopeToPulley
    lda Ram_PlatformTop_i16_0_arr + kCageEastUpperPlatformIndex  ; param: rope
    jmp FuncA_Objects_DrawHoistMachine
.ENDPROC

;;; Draws the girder platforms, connecting rope, and spikes for one of the
;;; cages in this room, and leaves the shape position ready to feed into
;;; FuncA_Objects_DrawHoistRopeToPulley.
;;; @prereq PRGA_Objects is loaded.
;;; @param X The platform index for the lower platform of the cage.
.PROC FuncC_Mine_Flower_DrawCage
    ;; Draw lower girder:
    jsr FuncA_Objects_DrawGirderPlatform
    ;; Draw connecting rope:
    jsr _MoveUpLeft
    jsr _DrawRope
    jsr _DrawRope
    jsr FuncA_Objects_MoveShapeRightOneTile
    ;; Draw upper girder and spikes:
    ldy #kPaletteObjHoistRope  ; param: object flags
    lda #kTileIdObjMineCageFirst  ; param: tile ID
    jsr FuncA_Objects_Draw2x2Shape  ; returns C and Y
    bcs @done
    lda #kTileIdObjPlatformGirder
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_MoveUpLeft:
    jsr FuncA_Objects_MoveShapeLeftOneTile
    jmp FuncA_Objects_MoveShapeUpOneTile
_DrawRope:
    ldy #kPaletteObjHoistRope  ; param: object flags
    lda #kTileIdObjHoistRopeVert  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    jmp FuncA_Objects_MoveShapeUpOneTile
.ENDPROC

.PROC FuncC_Mine_FlowerHoistWest_InitReset
    lda #kHoistWestInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kHoistWestMachineIndex
    rts
.ENDPROC

.PROC FuncC_Mine_FlowerHoistEast_InitReset
    lda #kHoistEastInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kHoistEastMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_MineFlowerHoistWest_TryMove
    lda #kHoistWestMaxGoalZ  ; param: max goal vert
    jmp FuncA_Machine_HoistTryMove
.ENDPROC

.PROC FuncA_Machine_MineFlowerHoistWest_Tick
    ldx #kCageWestUpperPlatformIndex  ; param: platform index
    ldya #kCageWestMinTop  ; param: min platform top
    jsr FuncA_Machine_HoistMoveTowardGoal  ; returns C and A
    jcs FuncA_Machine_ReachedGoal
    pha  ; move by
    ldx #kCageWestSpikePlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    pla  ; param: move by
    ldx #kCageWestLowerPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
.ENDPROC

.PROC FuncA_Machine_MineFlowerHoistEast_TryMove
    lda #kHoistEastMaxGoalZ  ; param: max goal vert
    jmp FuncA_Machine_HoistTryMove
.ENDPROC

.PROC FuncA_Machine_MineFlowerHoistEast_Tick
    ldx #kCageEastUpperPlatformIndex  ; param: platform index
    ldya #kCageEastMinTop  ; param: min platform top
    jsr FuncA_Machine_HoistMoveTowardGoal  ; returns C and A
    jcs FuncA_Machine_ReachedGoal
    pha  ; move by
    ldx #kCageEastSpikePlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    pla  ; param: move by
    ldx #kCageEastLowerPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
.ENDPROC

;;;=========================================================================;;;
