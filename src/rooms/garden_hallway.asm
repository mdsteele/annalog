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
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr

;;;=========================================================================;;;

;;; The machine index for the GardenHallwayLift machine in this room.
kLiftMachineIndex = 0

;;; The platform index for the GardenHallwayLift machine.
kLiftPlatformIndex = 0

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 0
kLiftMaxGoalY = 9

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $00a0
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Hallway_sRoom
.PROC DataC_Garden_Hallway_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0210
    d_byte Flags_bRoom, eArea::Garden
    d_byte MinimapStartRow_u8, 8
    d_byte MinimapStartCol_u8, 6
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_hallway1.room"
    .incbin "out/data/garden_hallway2.room"
    .assert * - :- = 50 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenHallwayLift
    d_byte Breaker_eFlag, eFlag::BreakerGarden
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $130
    d_byte ScrollGoalY_u8, $20
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncC_Garden_HallwayLift_Init
    d_addr ReadReg_func_ptr, FuncC_Garden_HallwayLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Garden_HallwayLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Garden_HallwayLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncC_Garden_HallwayLift_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0160
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $1e
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00c1
    d_word Top_i16,   $007e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $1e
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0191
    d_word Top_i16,   $00ae
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01b0
    d_word Top_i16,   $00ce
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01e0
    d_word Top_i16,   $00ce
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0250
    d_word Top_i16,   $00ce
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0290
    d_word Top_i16,   $00ce
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_word PosX_i16, $0067
    d_word PosY_i16, $0080
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00a8
    d_word PosY_i16, $00c8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_word PosX_i16, $0217
    d_word PosY_i16, $0040
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 29
    d_byte Target_u8, kLiftMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::TempleEntry
    d_byte SpawnBlock_u8, 12
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::GardenCrossroad
    d_byte SpawnBlock_u8, 12
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Garden_HallwayLift_Init
    .assert * = FuncC_Garden_HallwayLift_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Garden_HallwayLift_Reset
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

.PROC FuncC_Garden_HallwayLift_ReadReg
    lda #kLiftMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Garden_HallwayLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncC_Garden_HallwayLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;
