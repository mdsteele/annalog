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
.INCLUDE "../actors/firefly.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/hoist.inc"
.INCLUDE "../machines/lift.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Mine_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_HoistMoveTowardGoal
.IMPORT FuncA_Machine_HoistTryMove
.IMPORT FuncA_Machine_LiftTick
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_DrawHoistMachine
.IMPORT FuncA_Objects_DrawHoistPulley
.IMPORT FuncA_Objects_DrawHoistRopeToPulley
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr

;;;=========================================================================;;;

;;; The machine indices for the MineEastHoist and MineEastLift machines.
kHoistMachineIndex = 0
kLiftMachineIndex  = 1

;;; The platform indices for the machines in this room.
kHoistPlatformIndex       = 0
kPulleyPlatformIndex      = 1
kUpperGirderPlatformIndex = 2
kLowerGirderPlatformIndex = 3
kLiftPlatformIndex        = 4

;;; The initial and maximum permitted values for the hoist's Z-goal.
kHoistInitGoalZ = 4
kHoistMaxGoalZ  = 9

;;; The room pixel X-position of the left sides of the girder platforms.
kGirderPlatformLeft = $009d

;;; The vertical distance between the tops of the two girder platforms.
kGirderSpacingTiles = 5
kGirderSpacingPx = kTileHeightPx * kGirderSpacingTiles

;;; The minimum and initial room pixel position for the top edge of the hoist
;;; girders.
.LINECONT +
kLowerGirderMinPlatformTop = $0080
kLowerGirderInitPlatformTop = \
    kLowerGirderMinPlatformTop + kBlockHeightPx * kHoistInitGoalZ
kUpperGirderInitPlatformTop = kLowerGirderInitPlatformTop - kGirderSpacingPx
.LINECONT +

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 7
kLiftMaxGoalY = 7

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $00e0
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_East_sRoom
.PROC DataC_Mine_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte Flags_bRoom, bRoom::Tall | eArea::Mine
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 23
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
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/mine_east.room"
    .assert * - :- = 17 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kHoistMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineEastHoist
    d_byte Breaker_eFlag, eFlag::BreakerLava
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::HoistLeft
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $10
    d_byte RegNames_u8_arr4, 0, 0, 0, "Z"
    d_byte MainPlatform_u8, kHoistPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_MineEastHoist_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mine_EastHoist_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MineEastHoist_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MineEastHoist_Tick
    d_addr Draw_func_ptr, FuncC_Mine_EastHoist_Draw
    d_addr Reset_func_ptr, FuncA_Room_MineEastHoist_InitReset
    D_END
    .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineEastLift
    d_byte Breaker_eFlag, eFlag::BreakerLava
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_MineEastLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mine_EastLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MineEastLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MineEastLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncA_Room_MineEastLift_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kHoistPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kHoistMachineWidthPx
    d_byte HeightPx_u8, kHoistMachineHeightPx
    d_word Left_i16,  $00c0
    d_word Top_i16,   $0040
    D_END
    .assert * - :- = kPulleyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a0
    d_word Top_i16,   $0020
    D_END
    .assert * - :- = kUpperGirderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16, kGirderPlatformLeft
    d_word Top_i16, kUpperGirderInitPlatformTop
    D_END
    .assert * - :- = kLowerGirderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16, kGirderPlatformLeft
    d_word Top_i16, kLowerGirderInitPlatformTop
    D_END
    .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLiftMachineWidthPx
    d_byte HeightPx_u8, kLiftMachineHeightPx
    d_word Left_i16,  $00c4
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00b1
    d_word Top_i16,   $010e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00c0
    d_word Top_i16,   $0106
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadFirefly
    d_word PosX_i16, $00e4
    d_word PosY_i16, $00b0
    d_byte Param_byte, (bBadFirefly::ThetaMask & $00) | bBadFirefly::FlipH
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 7
    d_byte Target_byte, kHoistMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kLiftMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 15
    d_byte Target_byte, eFlag::PaperJerome26
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::MineNorth
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::MineNorth
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Mine_EastHoist_ReadReg
    lda Ram_PlatformTop_i16_0_arr + kLowerGirderPlatformIndex
    sub #kLowerGirderMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Mine_EastLift_ReadReg
    .assert kLiftMaxPlatformTop + kTileHeightPx < $100, error
    lda #kLiftMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Mine_EastHoist_Draw
_Pulley:
    ldx #kPulleyPlatformIndex  ; param: platform index
    ldy Ram_PlatformTop_i16_0_arr + kUpperGirderPlatformIndex  ; param: rope
    jsr FuncA_Objects_DrawHoistPulley
_LowerGirder:
    ldx #kLowerGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawGirderPlatform
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    ldx #kGirderSpacingTiles - 1
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile
    ldy #kPaletteObjHoistRope  ; param: object flags
    lda #kTileIdObjHoistRopeVert  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    dex
    bne @loop
_UpperGirder:
    ldx #kUpperGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawGirderPlatform
    jsr FuncA_Objects_MoveShapeLeftHalfTile
    ldx #kPulleyPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistRopeToPulley
_Hoist:
    lda Ram_PlatformTop_i16_0_arr + kUpperGirderPlatformIndex  ; param: rope
    jmp FuncA_Objects_DrawHoistMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_MineEastHoist_InitReset
    lda #kHoistInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kHoistMachineIndex
    rts
.ENDPROC

.PROC FuncA_Room_MineEastLift_InitReset
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_MineEastHoist_TryMove
    lda #kHoistMaxGoalZ  ; param: max goal vert
    jmp FuncA_Machine_HoistTryMove
.ENDPROC

.PROC FuncA_Machine_MineEastHoist_Tick
    ldx #kLowerGirderPlatformIndex  ; param: platform index
    ldya #kLowerGirderMinPlatformTop  ; param: min platform top
    jsr FuncA_Machine_HoistMoveTowardGoal  ; returns C and A
    jcs FuncA_Machine_ReachedGoal
    ldx #kUpperGirderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
.ENDPROC

.PROC FuncA_Machine_MineEastLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncA_Machine_MineEastLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_LiftTick
.ENDPROC

;;;=========================================================================;;;
