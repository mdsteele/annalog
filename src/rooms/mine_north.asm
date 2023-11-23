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
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/conveyor.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Mine_sTileset
.IMPORT FuncA_Machine_ConveyorWriteReg
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawConveyorMachine
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_Noop
.IMPORT Func_TryPushAvatarHorz
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_AvatarSubX_u8
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverUpperDeviceIndex = 0
kLeverLowerDeviceIndex = 1

;;; The machine index for the MineNorthConveyor machine in this room.
kConveyorMachineIndex = 0

;;; The platform index for the MineNorthConveyor machine's main platform.
kConveyorMainPlatformIndex = 6

;;; Push speeds for the various conveyor gear settings.
kConveyorPushMin = $060
kConveyorPushMed = $100
kConveyorPushMax = $190

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverUpper_u8     .byte
    LeverLower_u8     .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_North_sRoom
.PROC DataC_Mine_North_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, bRoom::Tall | eArea::Mine
    d_byte MinimapStartRow_u8, 9
    d_byte MinimapStartCol_u8, 21
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
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
:   .incbin "out/rooms/mine_north.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kConveyorMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineNorthConveyor
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::WriteCE | bMachine::WriteD
    d_byte Status_eDiagram, eDiagram::HoistRight  ; TODO
    d_word ScrollGoalX_u16, $100
    d_byte ScrollGoalY_u8, $70
    d_byte RegNames_u8_arr4, "U", "G", "L", 0
    d_byte MainPlatform_u8, kConveyorMainPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Mine_NorthConveyor_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_MineNorthConveyor_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MineNorthConveyor_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawConveyorMachine
    d_addr Reset_func_ptr, FuncA_Room_MineNorthConveyor_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   ;; Conveyor belts:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0080
    d_word Top_i16,   $0090
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0130
    d_word Top_i16,   $0090
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01b0
    d_word Top_i16,   $0090
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16,   $0100
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0100
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0170
    d_word Top_i16,   $0100
    D_END
    .assert * - :- = kConveyorMainPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kConveyorMainPlatformWidthPx
    d_byte HeightPx_u8, kConveyorMainPlatformHeightPx
    d_word Left_i16,  $01b0
    d_word Top_i16,   $00a8
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $a0
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00d0
    d_word Top_i16,   $015e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01d0
    d_word Top_i16,   $0166
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadWasp
    d_word PosX_i16, $0180
    d_word PosY_i16, $0068
    d_byte Param_byte, (bBadWasp::ThetaMask & $40) | (bBadWasp::DeltaMask & -2)
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadWasp
    d_word PosX_i16, $0148
    d_word PosY_i16, $00e0
    d_byte Param_byte, (bBadWasp::ThetaMask & $00) | (bBadWasp::DeltaMask & -3)
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kLeverUpperDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 30
    d_byte Target_byte, sState::LeverUpper_u8
    D_END
    .assert * - :- = kLeverLowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 27
    d_byte Target_byte, sState::LeverLower_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kConveyorMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 18
    d_byte Target_byte, eFlag::PaperJerome09
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::MineNorth  ; TODO
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::MineCenter
    d_byte SpawnBlock_u8, 20
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::MineEast
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::MineEast
    d_byte SpawnBlock_u8, 20
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::SewerTrap
    d_byte SpawnBlock_u8, 11
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Mine_NorthConveyor_ReadReg
    cmp #$c
    beq _RegU
    cmp #$e
    beq _RegL
_RegG:
    lda Ram_MachineGoalHorz_u8_arr + kConveyorMachineIndex  ; conveyor gear
    rts
_RegU:
    lda Zp_RoomState + sState::LeverUpper_u8
    rts
_RegL:
    lda Zp_RoomState + sState::LeverLower_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_MineNorthConveyor_Reset
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kConveyorMachineIndex  ; conveyor gear
    ldx #kLeverUpperDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverLowerDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_MineNorthConveyor_WriteReg
    cpx #$c
    beq _WriteU
    cpx #$e
    beq _WriteL
    jmp FuncA_Machine_ConveyorWriteReg
_WriteU:
    ldx #kLeverUpperDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteL:
    ldx #kLeverLowerDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_MineNorthConveyor_Tick
    ldx Ram_MachineGoalHorz_u8_arr + kConveyorMachineIndex  ; conveyor gear
    ;; Check if the player avatar is currently standing on one of the conveyor
    ;; belts.
    lda Zp_AvatarPlatformIndex_u8
    cmp #kConveyorMainPlatformIndex
    bge _NotOnConveyor
_OnConveyor:
    ;; While the player avatar is on a conveyor belt, push them at the belt's
    ;; current speed (but without changing the avatar's velocity).
    lda _PushVelX_i16_0_arr10, x
    add Zp_AvatarSubX_u8
    sta Zp_AvatarSubX_u8
    lda _PushVelX_i16_1_arr10, x
    adc #0
    sta Zp_AvatarPushDelta_i8
    jsr Func_TryPushAvatarHorz  ; preserves X
    ;; Mark the player avatar as being on a conveyor belt.
    lda #$ff
    sta Ram_MachineState2_byte_arr + kConveyorMachineIndex  ; avatar upon bool
    bne _Finish  ; unconditional
_NotOnConveyor:
    ;; When the player avatar first jumps/falls off of a conveyor belt, add a
    ;; velocity boost.
    bit Ram_MachineState2_byte_arr + kConveyorMachineIndex  ; avatar upon bool
    beq @done
    lda _PushVelX_i16_0_arr10, x
    add Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 0
    lda _PushVelX_i16_1_arr10, x
    adc Zp_AvatarVelX_i16 + 1
    sta Zp_AvatarVelX_i16 + 1
    ;; Mark the player avatar as no longer on a conveyor belt (by incrementing
    ;; the state boolean from $ff to $00).
    inc Ram_MachineState2_byte_arr + kConveyorMachineIndex  ; avatar upon bool
    @done:
_Finish:
    ;; Animate the conveyor belt terrain.
    lda _MotionOffset_i8_arr10, x
    add Ram_MachineState1_byte_arr + kConveyorMachineIndex  ; conveyor motion
    sta Ram_MachineState1_byte_arr + kConveyorMachineIndex  ; conveyor motion
    jmp FuncA_Machine_ReachedGoal
_PushVelX_i16_0_arr10:
    .byte                     0
    .byte <-kConveyorPushMin, 0, <kConveyorPushMin
    .byte <-kConveyorPushMed, 0, <kConveyorPushMed
    .byte <-kConveyorPushMax, 0, <kConveyorPushMax
_PushVelX_i16_1_arr10:
    .byte                     0
    .byte >-kConveyorPushMin, 0, >kConveyorPushMin
    .byte >-kConveyorPushMed, 0, >kConveyorPushMed
    .byte >-kConveyorPushMax, 0, >kConveyorPushMax
_MotionOffset_i8_arr10:
    .byte      0
    .byte <-3, 0, 3
    .byte <-6, 0, 6
    .byte <-9, 0, 9
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PaperJerome09_sDialog
.PROC DataA_Dialog_PaperJerome09_sDialog
    dlg_Text Paper, DataA_Text1_PaperJerome09_Page1_u8_arr
    dlg_Text Paper, DataA_Text1_PaperJerome09_Page2_u8_arr
    dlg_Text Paper, DataA_Text1_PaperJerome09_Page3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text1"

.PROC DataA_Text1_PaperJerome09_Page1_u8_arr
    .byte "Day 9: Meanwhile, the$"
    .byte "orcs value conviction.$"
    .byte "Honor. Valor. All fine$"
    .byte "qualities.#"
.ENDPROC

.PROC DataA_Text1_PaperJerome09_Page2_u8_arr
    .byte "But I fear they are$"
    .byte "fast losing sight of$"
    .byte "what they claim their$"
    .byte "convictions stand for.#"
.ENDPROC

.PROC DataA_Text1_PaperJerome09_Page3_u8_arr
    .byte "And so they, too, are$"
    .byte "no better than us$"
    .byte "humans.#"
.ENDPROC

;;;=========================================================================;;;
