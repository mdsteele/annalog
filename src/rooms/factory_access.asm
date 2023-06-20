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
.INCLUDE "../machines/rotor.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_RotorMoveCarriage
.IMPORT FuncA_Machine_RotorTick
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_DrawRotorCarriage
.IMPORT FuncA_Objects_DrawRotorMachine
.IMPORT FuncA_Objects_DrawRotorWheelLarge
.IMPORT FuncA_Objects_DrawRotorWheelSmall
.IMPORT Func_MachineRotorReadRegT
.IMPORT Func_Noop
.IMPORT Ppu_ChrBgWheel
.IMPORT Ppu_ChrObjFactory
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORTZP Zp_Chr0cBank_u8

;;;=========================================================================;;;

;;; The machine index for the FactoryAccessRotor machine.
kRotorMachineIndex = 0

;;; The platform indices used for the FactoryAccessRotor machine.
kRotorPlatformIndex            = 0
kLargeWheelCenterPlatformIndex = 1
kSmallWheelCenterPlatformIndex = 2
kRotorCarriagePlatformIndex    = 3

;;; The initial goal position (0-7) for the FactoryAccessRotor machine.
kRotorInitGoalPosition = 0

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_Access_sRoom
.PROC DataC_Factory_Access_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Factory
    d_byte MinimapStartRow_u8, 6
    d_byte MinimapStartCol_u8, 12
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjFactory)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Factory_Access_DrawRoom
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
    D_END
_TerrainData:
:   .incbin "out/data/factory_access.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kRotorMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::FactoryAccessRotor
    d_byte Breaker_eFlag, eFlag::BreakerCrypt
    d_byte Flags_bMachine, bMachine::MoveH
    d_byte Status_eDiagram, eDiagram::Winch  ; TODO
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $50
    d_byte RegNames_u8_arr4, 0, 0, "T", 0
    d_byte MainPlatform_u8, kRotorPlatformIndex
    d_addr Init_func_ptr, FuncC_Factory_AccessRotor_InitReset
    d_addr ReadReg_func_ptr, Func_MachineRotorReadRegT
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Factory_AccessRotor_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Factory_AccessRotor_Tick
    d_addr Draw_func_ptr, FuncC_Factory_AccessRotor_Draw
    d_addr Reset_func_ptr, FuncC_Factory_AccessRotor_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kRotorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorMachineWidthPx
    d_byte HeightPx_u8, kRotorMachineHeightPx
    d_word Left_i16,  $0088
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kLargeWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0090
    d_word Top_i16,   $00c0
    D_END
    .assert * - :- = kSmallWheelCenterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $00
    d_byte HeightPx_u8, $00
    d_word Left_i16,  $0090
    d_word Top_i16,   $0090
    D_END
    .assert * - :- = kRotorCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kRotorCarriageWidthPx
    d_byte HeightPx_u8, kRotorCarriageHeightPx
    d_word Left_i16,  $0088
    d_word Top_i16,   $00d8
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   ;; TODO: add some baddies
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 5
    d_byte BlockCol_u8, 10
    d_byte Target_u8, kRotorMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::FactoryUpper
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::FactoryBridge
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::GardenFlower
    d_byte SpawnBlock_u8, 21
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::FactoryCenter
    d_byte SpawnBlock_u8, 19
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Factory_Access_DrawRoom
    lda #<.bank(Ppu_ChrBgWheel)
    sta Zp_Chr0cBank_u8
    rts
.ENDPROC

.PROC FuncC_Factory_AccessRotor_InitReset
    lda #kRotorInitGoalPosition
    sta Ram_MachineGoalHorz_u8_arr + kRotorMachineIndex  ; goal position (0-7)
    rts
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Factory_AccessRotor_TryMove
    lda Ram_MachineGoalHorz_u8_arr + kRotorMachineIndex  ; goal position (0-7)
    cpx #eDir::Right
    bne @moveLeft
    @moveRight:
    tax
    inx
    cpx #8
    blt @success
    ldx #0
    beq @success
    @moveLeft:
    tax
    dex
    bpl @success
    ldx #7
    @success:
    txa
    sta Ram_MachineGoalHorz_u8_arr + kRotorMachineIndex  ; goal position (0-7)
    jmp FuncA_Machine_StartWorking
.ENDPROC

.PROC FuncC_Factory_AccessRotor_Tick
    jsr FuncA_Machine_RotorTick
_MoveCarriage:
    lda Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    add #$40  ; param: carriage angle
    ldx #kLargeWheelCenterPlatformIndex  ; param: center platform index
    ldy #kRotorCarriagePlatformIndex  ; param: carriage platform index
    jmp FuncA_Machine_RotorMoveCarriage
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Factory_AccessRotor_Draw
    jsr FuncA_Objects_DrawRotorMachine
_Carriage:
    ldx #kRotorCarriagePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRotorCarriage
_LargeWheel:
    lda Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    ldx #kLargeWheelCenterPlatformIndex  ; param: center platform index
    jsr FuncA_Objects_DrawRotorWheelLarge
_SmallWheel:
    lda Ram_MachineState1_byte_arr + kRotorMachineIndex  ; rotor angle (0-255)
    mul #2
    eor #$ff
    add #$40  ; param: rotation angle
    ldx #kSmallWheelCenterPlatformIndex  ; param: center platform index
    jmp FuncA_Objects_DrawRotorWheelSmall
.ENDPROC

;;;=========================================================================;;;
