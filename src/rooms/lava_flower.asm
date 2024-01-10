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
.INCLUDE "../actors/lavaball.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/flower.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/boiler.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_BoilerFinishEmittingSteam
.IMPORT FuncA_Machine_BoilerTick
.IMPORT FuncA_Machine_BoilerWriteReg
.IMPORT FuncA_Machine_EmitSteamUpFromPipe
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Objects_DrawBoilerMachine
.IMPORT FuncA_Objects_DrawBoilerValve1
.IMPORT FuncA_Room_MachineBoilerReset
.IMPORT FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_RespawnFlowerDeviceIfDropped
.IMPORT FuncA_Terrain_FadeInShortRoomWithLava
.IMPORT Func_MachineBoilerReadReg
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device index for the lever in this room.
kLeverDeviceIndex = 1

;;; The machine index for the LavaFlowerBoiler machine in this room.
kBoilerMachineIndex = 0

;;; Platform indices for various parts of the LavaFlowerBoiler machine.
kBoilerPlatformIndex = 0
kValvePlatformIndex  = 1
kPipe1PlatformIndex  = 2
kPipe2PlatformIndex  = 3

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the lever in this room.
    Lever_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_Flower_sRoom
.PROC DataC_Lava_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $08
    d_byte Flags_bRoom, eArea::Lava
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 16
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjLava)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_RemoveFlowerDeviceIfCarriedOrDelivered
    d_addr FadeIn_func_ptr, FuncA_Terrain_FadeInShortRoomWithLava
    d_addr Tick_func_ptr, FuncA_Room_RespawnFlowerDeviceIfDropped
    d_addr Draw_func_ptr, FuncA_Objects_AnimateLavaTerrain
    D_END
_TerrainData:
:   .incbin "out/rooms/lava_flower.room"
    .assert * - :- = 18 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaFlowerBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteCE
    d_byte Status_eDiagram, eDiagram::Boiler
    d_word ScrollGoalX_u16, $08
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", 0, "V", 0
    d_byte MainPlatform_u8, kBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Lava_FlowerBoiler_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LavaWestBoiler_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_LavaFlowerBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncC_Lava_FlowerBoiler_Draw
    d_addr Reset_func_ptr, FuncA_Room_LavaWestBoiler_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00a8
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kValvePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00d4
    d_word Top_i16,   $0064
    D_END
    .assert * - :- = kPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00c0
    d_word Top_i16,   $0050
    D_END
    .assert * - :- = kPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0070
    d_word Top_i16,   $00c8
    D_END
    ;; Spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $3e
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00b2
    d_word Top_i16,   $001a
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0052
    d_word Top_i16,   $007a
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $120
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopShortRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadLavaball
    d_word PosX_i16, $008e
    d_word PosY_i16, kLavaballStartYShort
    d_byte Param_byte, 5
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kFlowerDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 13
    d_byte Target_byte, eFlag::FlowerLava
    D_END
    .assert * - :- = kLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 10
    d_byte Target_byte, sState::Lever_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kBoilerMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::LavaWest
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::LavaCenter
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Lava_FlowerBoiler_ReadReg
    cmp #$c
    beq _ReadL
    jmp Func_MachineBoilerReadReg
_ReadL:
    lda Zp_RoomState + sState::Lever_u8
    rts
.ENDPROC

.PROC FuncC_Lava_FlowerBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kValvePlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawBoilerValve1
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_LavaWestBoiler_Reset
    ldx #kLeverDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    jmp FuncA_Room_MachineBoilerReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_LavaWestBoiler_WriteReg
    cpx #$c
    beq _WriteL
    jmp FuncA_Machine_BoilerWriteReg
_WriteL:
    ldx #kLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

;;; TryAct implemention for the LavaFlowerBoiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq PRGA_Machine is loaded.
.PROC FuncA_Machine_LavaFlowerBoiler_TryAct
    ;; Determine which pipe(s) the steam should exit out of.
    lda Ram_MachineGoalHorz_u8_arr + kBoilerMachineIndex  ; valve 1 angle
    and #$03
    tax  ; valve 1 angle (in tau/8 units, mod 4)
    ldy _ValvePipePlatformIndex_u8_arr4, x  ; param: pipe platform index
    bmi _Failure
    cpy #kPipe1PlatformIndex
    beq @pipe1
    ;; Emit upward steam from the chosen pipe(s).
    @pipe2:
    jsr FuncA_Machine_EmitSteamUpFromPipe
    jsr FuncA_Machine_BoilerFinishEmittingSteam
    ldy #kPipe1PlatformIndex
    @pipe1:
    jsr FuncA_Machine_EmitSteamUpFromPipe
    jmp FuncA_Machine_BoilerFinishEmittingSteam
_Failure:
    jmp FuncA_Machine_Error
_ValvePipePlatformIndex_u8_arr4:
    .byte kPipe1PlatformIndex
    .byte kPipe2PlatformIndex  ; (and also pipe 1)
    .byte $ff
    .byte $ff
.ENDPROC

;;;=========================================================================;;;
