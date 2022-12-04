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
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Pause_PrisonAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_PrisonAreaName_u8_arr
.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_LiftMoveTowardGoal
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT FuncC_Prison_DrawGatePlatform
.IMPORT Func_IsFlagSet
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjPrison
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_CameraCanScroll_bool
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The dialog index for the paper in this room.
kPaperDialogIndex = 0

;;; The minimum scroll-X value for this room.
kMinScrollX = $10

;;; The index of the passage that leads into the tunnel under the prison cell.
kTunnelPassageIndex = 1
;;; The index of the passage on the eastern side of the room.
kEasternPassageIndex = 2

;;; The machine indices for the machines in this room.
kLiftMachineIndex = 0
kBlasterMachineIndex = 1

;;; The platform index for the PrisonCellLift machine in this room.
kLiftPlatformIndex = 0
;;; The platform index for the prison cell gate.
kGatePlatformIndex = 1

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 0
kLiftMaxGoalY = 1

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $0080
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Cell_sRoom
.PROC DataC_Prison_Cell_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, kMinScrollX
    d_word MaxScrollX_u16, kMinScrollX + $100
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 5
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPrison)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Prison_Cell_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_PrisonAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_PrisonAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, DataA_Dialog_PrisonCell_sDialog_ptr_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, FuncC_Prison_Cell_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_cell.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncC_Prison_CellLift_Init
    d_addr ReadReg_func_ptr, FuncC_Prison_CellLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Prison_CellLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Prison_CellLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncC_Prison_CellLift_Reset
    D_END
    .assert * - :- = kBlasterMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellBlaster
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, 0  ; TODO
    d_addr Init_func_ptr, _Blaster_Init
    d_addr ReadReg_func_ptr, _Blaster_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_Error  ; TODO
    d_addr TryAct_func_ptr, FuncA_Machine_Error  ; TODO
    d_addr Tick_func_ptr, _Blaster_Tick
    d_addr Draw_func_ptr, FuncA_Objects_PrisonCellBlaster_Draw
    d_addr Reset_func_ptr, _Blaster_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0020
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    .assert * - :- = kGatePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $00f3
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 9
    d_byte Target_u8, kPaperDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 3
    d_byte Target_u8, kLiftMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 31
    d_byte Target_u8, kBlasterMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::PrisonEscape
    d_byte SpawnBlock_u8, 9
    D_END
    .assert * - :- = kTunnelPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::PrisonEscape
    d_byte SpawnBlock_u8, 20
    D_END
    .assert * - :- = kEasternPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonCrossroad
    d_byte SpawnBlock_u8, 11
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 1
    d_byte Destination_eRoom, eRoom::GardenLanding
    d_byte SpawnBlock_u8, 25
    D_END
_Blaster_Init:
    ;; TODO
    rts
_Blaster_ReadReg:
    lda #0  ; TODO
    rts
_Blaster_Tick:
    ;; TODO
    rts
_Blaster_Reset:
    ;; TODO
    rts
.ENDPROC

;;; Called when the player avatar enters the PrisonCell room.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncC_Prison_Cell_EnterRoom
    sta Zp_Tmp1_byte  ; bSpawn value
    ldx #eFlag::PrisonCellReachedTunnel  ; param: flag
    jsr Func_IsFlagSet  ; preserves X and Zp_Tmp*, returns Z
    bne @done
    lda Zp_Tmp1_byte  ; bSpawn value
    cmp #bSpawn::IsPassage | kEasternPassageIndex
    beq @setFlag
    cmp #bSpawn::IsPassage | kTunnelPassageIndex
    bne _LockScrolling
    @setFlag:
    jsr Func_SetFlag
    @done:
    rts
_LockScrolling:
    lda #0
    sta Zp_CameraCanScroll_bool
    sta Zp_RoomScrollY_u8
    .assert >kMinScrollX = 0, error
    sta Zp_RoomScrollX_u16 + 1
    .assert <kMinScrollX > 0, error
    lda #kMinScrollX
    sta Zp_RoomScrollX_u16 + 0
    rts
.ENDPROC

;;; Draw function for the PrisonCell room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Prison_Cell_DrawRoom
    ldx #kGatePlatformIndex  ; param: platform index
    jmp FuncC_Prison_DrawGatePlatform
.ENDPROC

.PROC FuncC_Prison_CellLift_Init
    .assert * = FuncC_Prison_CellLift_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Prison_CellLift_Reset
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

.PROC FuncC_Prison_CellLift_ReadReg
    lda #kLiftMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Prison_CellLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncC_Prison_CellLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_LiftMoveTowardGoal  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the PrisonCell room.
.PROC DataA_Dialog_PrisonCell_sDialog_ptr_arr
:   .assert * - :- = kPaperDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_PrisonCell_Paper_sDialog
.ENDPROC

.PROC DataA_Dialog_PrisonCell_Paper_sDialog
    .word ePortrait::Paper
    .byte "Day 87: By now there's$"
    .byte "probably not much time$"
    .byte "left to finish this.#"
    .word ePortrait::Paper
    .byte "I'm going to start$"
    .byte "pinning up all these$"
    .byte "pages. Maybe someday$"
    .byte "someone'll find them.#"
    .word ePortrait::Paper
    .byte "By then, I'm sure I'll$"
    .byte "be long gone.#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_PrisonCellBlaster_Draw
    ;; TODO
    rts
.ENDPROC

;;;=========================================================================;;;
