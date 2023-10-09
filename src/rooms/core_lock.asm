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
.INCLUDE "../machines/lift.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Core_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_LiftTick
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT Func_Noop
.IMPORT Ppu_ChrBgAnimStatic
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Chr0cBank_u8
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; The machine indices for the CoreLockLift* machines in this room.
kLift1MachineIndex = 0
kLift2MachineIndex = 1
kLift3MachineIndex = 2

;;; The platform indices for the CoreLockLift* machines in this room.
kLift1PlatformIndex = 0
kLift2PlatformIndex = 1
kLift3PlatformIndex = 2

;;; The initial and maximum permitted values for each lift's Y-goal.
kLiftInitGoalY = 0
kLiftMaxGoalY = 2

;;; The maximum and initial Y-positions for the top of each lift platform.
kLift1MaxPlatformTop = $0070
kLift1InitPlatformTop = kLift1MaxPlatformTop - kLiftInitGoalY * kBlockHeightPx
kLift2MaxPlatformTop = $0050
kLift2InitPlatformTop = kLift2MaxPlatformTop - kLiftInitGoalY * kBlockHeightPx
kLift3MaxPlatformTop = $0030
kLift3InitPlatformTop = kLift3MaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;;=========================================================================;;;

.SEGMENT "PRGC_Core"

.EXPORT DataC_Core_Lock_sRoom
.PROC DataC_Core_Lock_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, eArea::Core
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 12
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 3
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Core_Lock_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/data/core_lock.room"
    .assert * - :- = 18 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kLift1MachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreLockLift1
    d_byte Breaker_eFlag, eFlag::BreakerTemple
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLift1PlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CoreLockLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Core_LockLift1_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CoreLockLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_CoreLockLift1_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncA_Room_CoreLockLift_InitReset
    D_END
    .assert * - :- = kLift2MachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreLockLift2
    d_byte Breaker_eFlag, eFlag::BreakerMine
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLift2PlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CoreLockLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Core_LockLift2_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CoreLockLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_CoreLockLift2_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncA_Room_CoreLockLift_InitReset
    D_END
    .assert * - :- = kLift3MachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreLockLift3
    d_byte Breaker_eFlag, eFlag::BreakerShadow
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLift3PlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CoreLockLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Core_LockLift3_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CoreLockLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_CoreLockLift3_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncA_Room_CoreLockLift_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLift1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLiftMachineWidthPx
    d_byte HeightPx_u8, kLiftMachineHeightPx
    d_word Left_i16, $0050
    d_word Top_i16, kLift1InitPlatformTop
    D_END
    .assert * - :- = kLift2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLiftMachineWidthPx
    d_byte HeightPx_u8, kLiftMachineHeightPx
    d_word Left_i16, $0080
    d_word Top_i16, kLift2InitPlatformTop
    D_END
    .assert * - :- = kLift3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLiftMachineWidthPx
    d_byte HeightPx_u8, kLiftMachineHeightPx
    d_word Left_i16, $00b0
    d_word Top_i16, kLift3InitPlatformTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   ;; TODO: add Gronta actor for cutscene
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 4
    d_byte Target_byte, kLift1MachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 7
    d_byte Target_byte, kLift2MachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 10
    d_byte Target_byte, kLift3MachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CoreWest
    d_byte SpawnBlock_u8, 10
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CoreBoss
    d_byte SpawnBlock_u8, 4
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Core_Lock_DrawRoom
    ;; If the temple breaker hasn't been activated yet, disable the BG circuit
    ;; animation.
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerTemple
    bne @done
    lda #<.bank(Ppu_ChrBgAnimStatic)
    sta Zp_Chr0cBank_u8
    @done:
    rts
.ENDPROC

.PROC FuncC_Core_LockLift1_ReadReg
    lda #kLift1MaxPlatformTop + kTileHeightPx
    bne FuncC_Core_LockLift_ReadReg  ; unconditional
.ENDPROC

.PROC FuncC_Core_LockLift2_ReadReg
    lda #kLift2MaxPlatformTop + kTileHeightPx
    bne FuncC_Core_LockLift_ReadReg  ; unconditional
.ENDPROC

.PROC FuncC_Core_LockLift3_ReadReg
    lda #kLift3MaxPlatformTop + kTileHeightPx
    .assert * = FuncC_Core_LockLift_ReadReg, error, "fallthrough"
.ENDPROC

.PROC FuncC_Core_LockLift_ReadReg
    ldx Zp_MachineIndex_u8
    .assert kLift1MachineIndex = kLift1PlatformIndex, error
    .assert kLift2MachineIndex = kLift2PlatformIndex, error
    .assert kLift3MachineIndex = kLift3PlatformIndex, error
    sub Ram_PlatformTop_i16_0_arr, x
    div #kBlockHeightPx
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CoreLockLift_InitReset
    ldx Zp_MachineIndex_u8
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_CoreLockLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncA_Machine_CoreLockLift1_Tick
    ldax #kLift1MaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_LiftTick
.ENDPROC

.PROC FuncA_Machine_CoreLockLift2_Tick
    ldax #kLift2MaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_LiftTick
.ENDPROC

.PROC FuncA_Machine_CoreLockLift3_Tick
    ldax #kLift3MaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_LiftTick
.ENDPROC

;;;=========================================================================;;;
