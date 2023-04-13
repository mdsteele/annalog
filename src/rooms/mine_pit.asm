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
.IMPORT FuncA_Machine_GenericTryMoveZ
.IMPORT FuncA_Machine_HoistMoveTowardGoal
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawHoistGirder
.IMPORT FuncA_Objects_DrawHoistMachine
.IMPORT FuncA_Objects_DrawHoistPulley
.IMPORT FuncA_Objects_DrawHoistRopeToPulley
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The device index for the upgrade in this room.
kUpgradeDeviceIndex = 0

;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeOpSync

;;; The machine indices for the MinePitHoistWest and MinePitHoistEast machines.
kHoistWestMachineIndex = 0
kHoistEastMachineIndex = 1

;;; The primary platform indices for the MinePitHoistWest and MinePitHoistEast
;;; machines.
kHoistWestPlatformIndex = 0
kHoistEastPlatformIndex = 1
;;; Platform indices for the two pulleys.
kPulleyWestPlatformIndex = 2
kPulleyEastPlatformIndex = 3
;;; Platform indices for the two girders.
kGirderWestPlatformIndex = 4
kGirderEastPlatformIndex = 5

;;; The initial and maximum permitted values for the western hoist's Z-goal.
kHoistWestInitGoalZ = 2
kHoistWestMaxGoalZ  = 3
;;; The initial and maximum permitted values for the eastern hoist's Z-goal.
kHoistEastInitGoalZ = 1
kHoistEastMaxGoalZ  = 4

;;; The minimum and initial room pixel position for the top edges of the
;;; western and eastern girders.
.LINECONT +
kGirderWestMinPlatformTop = $0020
kGirderWestInitPlatformTop = \
    kGirderWestMinPlatformTop + kBlockHeightPx * kHoistWestInitGoalZ
kGirderEastMinPlatformTop = $0074
kGirderEastInitPlatformTop = \
    kGirderEastMinPlatformTop + kBlockHeightPx * kHoistEastInitGoalZ
.LINECONT +

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_Pit_sRoom
.PROC DataC_Mine_Pit_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $00
    d_byte Flags_bRoom, eArea::Mine
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 22
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Mine_Pit_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mine_pit.room"
    .assert * - :- = 16 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kHoistWestMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MinePitHoistWest
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::HoistRight
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Z"
    d_byte MainPlatform_u8, kHoistWestPlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_PitHoistWest_Init
    d_addr ReadReg_func_ptr, FuncC_Mine_PitHoistWest_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Mine_PitHoistWest_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Mine_PitHoistWest_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MinePitHoistWest_Draw
    d_addr Reset_func_ptr, FuncC_Mine_PitHoistWest_Reset
    D_END
    .assert * - :- = kHoistEastMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MinePitHoistEast
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::HoistLeft
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Z"
    d_byte MainPlatform_u8, kHoistEastPlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_PitHoistEast_Init
    d_addr ReadReg_func_ptr, FuncC_Mine_PitHoistEast_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Mine_PitHoistEast_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Mine_PitHoistEast_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MinePitHoistEast_Draw
    d_addr Reset_func_ptr, FuncC_Mine_PitHoistEast_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kHoistWestPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kHoistMachineWidthPx
    d_byte HeightPx_u8, kHoistMachineHeightPx
    d_word Left_i16,  $0020
    d_word Top_i16,   $0050
    D_END
    .assert * - :- = kHoistEastPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kHoistMachineWidthPx
    d_byte HeightPx_u8, kHoistMachineHeightPx
    d_word Left_i16,  $00b0
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kPulleyWestPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0068
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kPulleyEastPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0090
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kGirderWestPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0068
    d_word Top_i16, kGirderWestInitPlatformTop
    D_END
    .assert * - :- = kGirderEastPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0089
    d_word Top_i16, kGirderEastInitPlatformTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 5
    d_byte Target_u8, kUpgradeFlag
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 2
    d_byte Target_u8, kHoistWestMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 13
    d_byte Target_u8, kHoistEastMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::MineSouth
    d_byte SpawnBlock_u8, 8
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Mine_Pit_EnterRoom
    flag_bit Sram_ProgressFlags_arr, kUpgradeFlag
    beq @done
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    @done:
    rts
.ENDPROC

.PROC FuncC_Mine_PitHoistWest_Init
    .assert * = FuncC_Mine_PitHoistWest_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Mine_PitHoistWest_Reset
    lda #kHoistWestInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kHoistWestMachineIndex
    rts
.ENDPROC

.PROC FuncC_Mine_PitHoistWest_ReadReg
    lda Ram_PlatformTop_i16_0_arr + kGirderWestPlatformIndex
    sub #kGirderWestMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Mine_PitHoistWest_TryMove
    lda #kHoistWestMaxGoalZ  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveZ
.ENDPROC

.PROC FuncC_Mine_PitHoistWest_Tick
    ldx #kGirderWestPlatformIndex  ; param: platform index
    ldya #kGirderWestMinPlatformTop  ; param: min platform top
    jsr FuncA_Machine_HoistMoveTowardGoal  ; returns C
    jcs FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncC_Mine_PitHoistEast_Init
    .assert * = FuncC_Mine_PitHoistEast_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Mine_PitHoistEast_Reset
    lda #kHoistEastInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kHoistEastMachineIndex
    rts
.ENDPROC

.PROC FuncC_Mine_PitHoistEast_ReadReg
    lda Ram_PlatformTop_i16_0_arr + kGirderEastPlatformIndex
    sub #kGirderEastMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Mine_PitHoistEast_TryMove
    lda #kHoistEastMaxGoalZ  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveZ
.ENDPROC

.PROC FuncC_Mine_PitHoistEast_Tick
    ldx #kGirderEastPlatformIndex  ; param: platform index
    ldya #kGirderEastMinPlatformTop  ; param: min platform top
    jsr FuncA_Machine_HoistMoveTowardGoal  ; returns C
    jcs FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_MinePitHoistWest_Draw
    ldx #kPulleyWestPlatformIndex  ; param: platform index
    ldy Ram_PlatformTop_i16_0_arr + kGirderWestPlatformIndex  ; param: rope
    jsr FuncA_Objects_DrawHoistPulley
    ldx #kGirderWestPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistGirder
    ldx #kPulleyWestPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistRopeToPulley
    lda Ram_PlatformTop_i16_0_arr + kGirderWestPlatformIndex  ; param: rope
    jmp FuncA_Objects_DrawHoistMachine
.ENDPROC

.PROC FuncA_Objects_MinePitHoistEast_Draw
    ldx #kPulleyEastPlatformIndex  ; param: platform index
    ldy Ram_PlatformTop_i16_0_arr + kGirderEastPlatformIndex  ; param: rope
    jsr FuncA_Objects_DrawHoistPulley
    ldx #kGirderEastPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistGirder
    ldx #kPulleyEastPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawHoistRopeToPulley
    lda Ram_PlatformTop_i16_0_arr + kGirderEastPlatformIndex  ; param: rope
    jmp FuncA_Objects_DrawHoistMachine
.ENDPROC

;;;=========================================================================;;;
