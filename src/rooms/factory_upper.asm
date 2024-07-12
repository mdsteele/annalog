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
.INCLUDE "../machines/rotor.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_RotorMoveCarriage
.IMPORT FuncA_Machine_RotorTick
.IMPORT FuncA_Machine_RotorTryMove
.IMPORT FuncA_Objects_DrawRotorCarriage
.IMPORT FuncA_Objects_DrawRotorMachine
.IMPORT FuncA_Objects_DrawRotorWheelLarge
.IMPORT FuncA_Objects_DrawRotorWheelSmall
.IMPORT FuncA_Objects_SetWheelChr04Bank
.IMPORT FuncA_Room_MachineRotorReset
.IMPORT Func_MachineRotorReadRegT
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjFactory
.IMPORT Ram_MachineState1_byte_arr

;;;=========================================================================;;;

;;; The machine index for the FactoryUpperRotor machine.
kRotorMachineIndex = 0

;;; The platform indices used for the FactoryUpperRotor machine.
kRotorPlatformIndex            = 0
kTopSmWheelCenterPlatformIndex = 1
kBotSmWheelCenterPlatformIndex = 2
kTopLgWheelCenterPlatformIndex = 3
kBotLgWheelCenterPlatformIndex = 4
kTopRotorCarriagePlatformIndex = 5
kBotRotorCarriagePlatformIndex = 6

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_Upper_sRoom
.PROC DataC_Factory_Upper_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Factory
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 11
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFactory)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncA_Objects_SetWheelChr04Bank
    D_END
_TerrainData:
:   .incbin "out/rooms/factory_upper.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kRotorMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::FactoryUpperRotor
    d_byte Breaker_eFlag, eFlag::BreakerTemple
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Rotor
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $58
    d_byte RegNames_u8_arr4, 0, 0, "T", 0
    d_byte MainPlatform_u8, kRotorPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineRotorReadRegT
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_RotorTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Factory_UpperRotor_Tick
    d_addr Draw_func_ptr, FuncC_Factory_UpperRotor_Draw
    d_addr Reset_func_ptr, FuncA_Room_MachineRotorReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kRotorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorMachineWidthPx
    d_byte HeightPx_u8, kRotorMachineHeightPx
    d_word Left_i16,  $0058
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kTopSmWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0060
    d_word Top_i16,   $0090
    D_END
    .assert * - :- = kBotSmWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $00c0
    d_word Top_i16,   $00d0
    D_END
    .assert * - :- = kTopLgWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0090
    d_word Top_i16,   $0090
    D_END
    .assert * - :- = kBotLgWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0090
    d_word Top_i16,   $00d0
    D_END
    .assert * - :- = kTopRotorCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorCarriageWidthPx
    d_byte HeightPx_u8, kRotorCarriageHeightPx
    d_word Left_i16,  $0088
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kBotRotorCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorCarriageWidthPx
    d_byte HeightPx_u8, kRotorCarriageHeightPx
    d_word Left_i16,  $006c
    d_word Top_i16,   $00cc
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00a0
    d_word PosY_i16, $0038
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0048
    d_word PosY_i16, $0058
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0080
    d_word PosY_i16, $0128
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 14
    d_byte Target_byte, kRotorMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eFlag::PaperManual4
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::FactoryLock
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CoreSouth
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::FactoryWest
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::FactoryAccess
    d_byte SpawnBlock_u8, 19
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Factory_UpperRotor_Tick
    jsr FuncA_Machine_RotorTick
_MoveUpperCarriage:
    lda Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    add #$c0  ; param: carriage angle
    ldx #kTopLgWheelCenterPlatformIndex  ; param: center platform index
    ldy #kTopRotorCarriagePlatformIndex  ; param: carriage platform index
    jsr FuncA_Machine_RotorMoveCarriage
_MoveLowerCarriage:
    lda #$80
    sub Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    ldx #kBotLgWheelCenterPlatformIndex  ; param: center platform index
    ldy #kBotRotorCarriagePlatformIndex  ; param: carriage platform index
    jmp FuncA_Machine_RotorMoveCarriage
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Factory_UpperRotor_Draw
    jsr FuncA_Objects_DrawRotorMachine
_TopCarriage:
    ldx #kTopRotorCarriagePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRotorCarriage
_BottomCarriage:
    ldx #kBotRotorCarriagePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRotorCarriage
_TopLargeWheel:
    lda Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    ldx #kTopLgWheelCenterPlatformIndex  ; param: center platform index
    jsr FuncA_Objects_DrawRotorWheelLarge
_BottomLargeWheel:
    lda #$20
    sub Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    ldx #kBotLgWheelCenterPlatformIndex  ; param: center platform index
    jsr FuncA_Objects_DrawRotorWheelLarge
_TopSmallWheel:
    lda Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    mul #2
    eor #$ff
    add #$40  ; param: rotation angle
    ldx #kTopSmWheelCenterPlatformIndex  ; param: center platform index
    jsr FuncA_Objects_DrawRotorWheelSmall
_BottomSmallWheel:
    lda Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    mul #2  ; param: rotation angle
    ldx #kBotSmWheelCenterPlatformIndex  ; param: center platform index
    jmp FuncA_Objects_DrawRotorWheelSmall
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PaperManual4_sDialog
.PROC DataA_Dialog_PaperManual4_sDialog
    dlg_Text Paper, DataA_Text1_PaperManual4_Page1_u8_arr
    dlg_Text Paper, DataA_Text1_PaperManual4_Page2_u8_arr
    dlg_Text Paper, DataA_Text1_PaperManual4_Page3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text1"

.PROC DataA_Text1_PaperManual4_Page1_u8_arr
    .byte "CPU FIELD MANUAL p.4:$"
    .byte "Common register names:$"
    .byte " F:flag    D:distance$"
    .byte " J:index   K:key/lock#"
.ENDPROC

.PROC DataA_Text1_PaperManual4_Page2_u8_arr
    .byte "L/R:lever  M:mirror$"
    .byte "  P:power  S:sensor$"
    .byte "  T:turn   U:upper$"
    .byte "  V:valve  W:weight#"
.ENDPROC

.PROC DataA_Text1_PaperManual4_Page3_u8_arr
    .byte " X:horzizontal offset$"
    .byte " Y:vertical ascent$"
    .byte " Z:vertical descent#"
.ENDPROC

;;;=========================================================================;;;
