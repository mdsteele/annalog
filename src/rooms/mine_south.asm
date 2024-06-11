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
.INCLUDE "../actors/wasp.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/hoist.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Mine_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_HoistMoveTowardGoal
.IMPORT FuncA_Machine_HoistTryMove
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawHoistGirder
.IMPORT FuncA_Objects_DrawHoistMachine
.IMPORT FuncA_Objects_DrawHoistPulley
.IMPORT FuncA_Objects_DrawHoistRopeToPulley
.IMPORT FuncA_Objects_DrawTrolleyGirder
.IMPORT FuncA_Objects_DrawTrolleyMachine
.IMPORT FuncA_Objects_DrawTrolleyRopeWithLength
.IMPORT Func_MovePlatformHorz
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr

;;;=========================================================================;;;

;;; The machine index for the MineSouthTrolley machine in this room.
kTrolleyMachineIndex = 0
;;; The machine index for the MineSouthHoist machine in this room.
kHoistMachineIndex = 1

;;; The platform indices for the MineSouthTrolley machine and its girder.
kTrolleyPlatformIndex = 0
kTrolleyGirderPlatformIndex  = 1
;;; The platform indices for the MineSouthHoist machine and its pulley and
;;; girder.
kHoistPlatformIndex = 2
kHoistPulleyPlatformIndex = 3
kHoistGirderPlatformIndex = 4

;;; The initial and maximum permitted horizontal goal values for the trolley.
kTrolleyInitGoalX = 1
kTrolleyMaxGoalX = 9

;;; The initial and maximum permitted values for the hoist's Z-goal.
kHoistInitGoalZ = 4
kHoistMaxGoalZ  = 9

;;; The minimum and initial X-positions for the left of the trolley machine.
.LINECONT +
kTrolleyMinPlatformLeft = $0100
kTrolleyInitPlatformLeft = \
    kTrolleyMinPlatformLeft + kTrolleyInitGoalX * kBlockWidthPx
.LINECONT -

;;; The minimum and initial room pixel position for the top edge of the hoist
;;; girder.
.LINECONT +
kHoistGirderMinPlatformTop = $0080
kHoistGirderInitPlatformTop = \
    kHoistGirderMinPlatformTop + kBlockHeightPx * kHoistInitGoalZ
.LINECONT +

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_South_sRoom
.PROC DataC_Mine_South_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, bRoom::Tall | eArea::Mine
    d_byte MinimapStartRow_u8, 11
    d_byte MinimapStartCol_u8, 22
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
:   .incbin "out/rooms/mine_south.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kTrolleyMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineSouthTrolley
    d_byte Breaker_eFlag, eFlag::BreakerLava
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Trolley
    d_word ScrollGoalX_u16, $0d0
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, kTrolleyPlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_SouthTrolley_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mine_SouthTrolley_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MineSouthTrolley_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MineSouthTrolley_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MineSouthTrolley_Draw
    d_addr Reset_func_ptr, FuncC_Mine_SouthTrolley_InitReset
    D_END
    .assert * - :- = kHoistMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineSouthHoist
    d_byte Breaker_eFlag, eFlag::BreakerLava
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::HoistRight
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $20
    d_byte RegNames_u8_arr4, 0, 0, 0, "Z"
    d_byte MainPlatform_u8, kHoistPlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_SouthHoist_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mine_SouthHoist_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MineSouthHoist_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MineSouthHoist_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MineSouthHoist_Draw
    d_addr Reset_func_ptr, FuncC_Mine_SouthHoist_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kTrolleyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $0e
    d_word Left_i16, kTrolleyInitPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kTrolleyGirderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16, kTrolleyInitPlatformLeft - kTileWidthPx
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kHoistPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kHoistMachineWidthPx
    d_byte HeightPx_u8, kHoistMachineHeightPx
    d_word Left_i16,  $0190
    d_word Top_i16,   $0090
    D_END
    .assert * - :- = kHoistPulleyPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01e8
    d_word Top_i16,   $0040
    D_END
    .assert * - :- = kHoistGirderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01e8
    d_word Top_i16, kHoistGirderInitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e0
    d_word Top_i16,   $012e
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadWasp
    d_word PosX_i16, $0040
    d_word PosY_i16, $00c8
    d_byte Param_byte, (bBadWasp::ThetaMask & $80) | (bBadWasp::DeltaMask & -2)
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadWasp
    d_word PosX_i16, $0100
    d_word PosY_i16, $0110
    d_byte Param_byte, (bBadWasp::ThetaMask & $40) | (bBadWasp::DeltaMask & 3)
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadWasp
    d_word PosX_i16, $0070
    d_word PosY_i16, $0030
    d_byte Param_byte, (bBadWasp::ThetaMask & $c0) | (bBadWasp::DeltaMask & 2)
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadWasp
    d_word PosX_i16, $00e0
    d_word PosY_i16, $0040
    d_byte Param_byte, (bBadWasp::ThetaMask & $00) | (bBadWasp::DeltaMask & 3)
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 13
    d_byte BlockCol_u8, 24
    d_byte Target_byte, kTrolleyMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 31
    d_byte Target_byte, kHoistMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::MineDrift
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::MineEntry
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 1
    d_byte Destination_eRoom, eRoom::MinePit
    d_byte SpawnBlock_u8, 25
    d_byte SpawnAdjust_byte, $c1
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Mine_SouthTrolley_InitReset
    lda #kTrolleyInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kTrolleyMachineIndex
    rts
.ENDPROC

.PROC FuncC_Mine_SouthTrolley_ReadReg
    lda Ram_PlatformLeft_i16_0_arr + kTrolleyPlatformIndex
    sub #<(kTrolleyMinPlatformLeft - kTileWidthPx)
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Mine_SouthHoist_InitReset
    lda #kHoistInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kHoistMachineIndex
    rts
.ENDPROC

.PROC FuncC_Mine_SouthHoist_ReadReg
    lda Ram_PlatformTop_i16_0_arr + kHoistGirderPlatformIndex
    sub #kHoistGirderMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_MineSouthTrolley_TryMove
    lda #kTrolleyMaxGoalX  ; param: max goal
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_MineSouthTrolley_Tick
    ;; Move the trolley horizontally, as necessary.
    ldax #kTrolleyMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z and A
    beq @done
    ;; If the trolley moved, move the girder platform too.
    ldx #kTrolleyGirderPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

.PROC FuncA_Machine_MineSouthHoist_TryMove
    lda #kHoistMaxGoalZ  ; param: max goal vert
    jmp FuncA_Machine_HoistTryMove
.ENDPROC

.PROC FuncA_Machine_MineSouthHoist_Tick
    ldx #kHoistGirderPlatformIndex  ; param: platform index
    ldya #kHoistGirderMinPlatformTop  ; param: min platform top
    jsr FuncA_Machine_HoistMoveTowardGoal  ; returns C
    jcs FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_MineSouthTrolley_Draw
    jsr FuncA_Objects_DrawTrolleyMachine
    ldx #5  ; param: num rope tiles
    jsr FuncA_Objects_DrawTrolleyRopeWithLength
    ldx #kTrolleyGirderPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawTrolleyGirder
.ENDPROC

.PROC FuncA_Objects_MineSouthHoist_Draw
    ldx #kHoistPulleyPlatformIndex  ; param: platform index
    ldy Ram_PlatformTop_i16_0_arr + kHoistGirderPlatformIndex  ; param: rope
    jsr FuncA_Objects_DrawHoistPulley
    ldx #kHoistGirderPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistGirder
    ldx #kHoistPulleyPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistRopeToPulley
    lda Ram_PlatformTop_i16_0_arr + kHoistGirderPlatformIndex  ; param: rope
    jmp FuncA_Objects_DrawHoistMachine
.ENDPROC

;;;=========================================================================;;;
