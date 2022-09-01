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
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_LavaAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_LavaAreaName_u8_arr
.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_DrawBoilerValve
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjSteamUp
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjUpgrade
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; The machine index for the LavaFlowerBoiler machine in this room.
kBoilerMachineIndex = 0

;;; Platform indices for various parts of the LavaFlowerBoiler machine.
kBoilerPlatformIndex = 0
kValvePlatformIndex  = 1
kPipe1PlatformIndex  = 2
kPipe2PlatformIndex  = 3

;;; The number of frames between valve angles when animating a boiler valve.
.DEFINE kValveAnimSlowdown 2

;;; How many frames a boiler machine spends for various operations.
kBoilerActCountdown = 32
kBoilerWriteCountdown = 24

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_Flower_sRoom
.PROC DataC_Lava_Flower_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $08
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 14
    d_byte MinimapStartCol_u8, 16
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjUpgrade)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_LavaAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_LavaAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, 0
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/lava_flower.room"
    .assert * - :- = 18 * 16, error
_Machines_sMachine_arr:
:   .assert * - :- = kBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaFlowerBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Winch  ; TODO
    d_word ScrollGoalX_u16, $08
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "V", 0, 0, 0
    d_byte MainPlatform_u8, kBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Lava_FlowerBoiler_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Lava_FlowerBoiler_WriteReg
    d_addr TryMove_func_ptr, Func_MachineError
    d_addr TryAct_func_ptr, FuncC_Lava_FlowerBoiler_TryAct
    d_addr Tick_func_ptr, FuncC_Lava_FlowerBoiler_Tick
    d_addr Draw_func_ptr, FuncA_Objects_LavaFlowerBoiler_Draw
    d_addr Reset_func_ptr, FuncC_Lava_FlowerBoiler_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00b0
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kValvePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e4
    d_word Top_i16,   $0064
    D_END
    .assert * - :- = kPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0050
    D_END
    .assert * - :- = kPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0070
    d_word Top_i16,   $00d0
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $180
    d_byte HeightPx_u8,  $20
    d_word Left_i16,   $0000
    d_word Top_i16,    $00d3
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 11
    d_byte Target_u8, kBoilerMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Flower
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 13
    d_byte Target_u8, eFlag::FlowerLava
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::LavaFlower  ; TODO
    d_byte SpawnBlock_u8, 4
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::LavaFlower  ; TODO
    d_byte SpawnBlock_u8, 4
    D_END
.ENDPROC

.PROC FuncC_Lava_FlowerBoiler_Reset
    ldx Zp_MachineIndex_u8
    lda #0
    sta Ram_MachineGoalVert_u8_arr, x
    rts
.ENDPROC

.PROC FuncC_Lava_FlowerBoiler_ReadReg
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    rts
.ENDPROC

.PROC FuncC_Lava_FlowerBoiler_WriteReg
    txa  ; value to write
    ldx Zp_MachineIndex_u8
    sta Ram_MachineGoalVert_u8_arr, x
    lda #kBoilerWriteCountdown
    rts
.ENDPROC

.PROC FuncC_Lava_FlowerBoiler_TryAct
    ;; Determine which pipe the steam should exit out of (or fail if both pipes
    ;; are blocked).
    ldy Zp_MachineIndex_u8
    ldx Ram_MachineGoalVert_u8_arr, y  ; valve angle (0-9)
    ldy _ValvePipePlatformIndex_u8_arr10, x  ; pipe platform index
    cpy #kMaxPlatforms
    blt _SpawnSteam
    sec  ; failure
    rts
_SpawnSteam:
    ;; At this point, Y holds the platform index for the pipe that the steam
    ;; should shoot from.  Set X to the actor index for the steam.
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @done
    ;; Calculate the steam's X-position.
    lda Ram_PlatformLeft_i16_0_arr, y
    add #kTileWidthPx / 2
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, y
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    ;; Calculate the steam's Y-position.
    lda Ram_PlatformTop_i16_0_arr, y
    sub #kTileHeightPx
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, y
    sbc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Spawn the steam.
    jsr Func_InitActorProjSteamUp
    @done:
    lda #kBoilerActCountdown
    clc  ; success
    rts
_ValvePipePlatformIndex_u8_arr10:
:   .byte kPipe1PlatformIndex
    .byte kPipe1PlatformIndex
    .byte $ff
    .byte kPipe2PlatformIndex
    .byte kPipe2PlatformIndex
    .byte $ff
    .byte kPipe1PlatformIndex
    .byte kPipe1PlatformIndex
    .byte $ff
    .byte kPipe2PlatformIndex
    .assert * - :- = 10, error
.ENDPROC

.PROC FuncC_Lava_FlowerBoiler_Tick
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    mul #kValveAnimSlowdown
    cmp Ram_MachineParam1_u8_arr, x
    blt @decrement
    bne @increment
    jmp Func_MachineFinishResetting
    @increment:
    inc Ram_MachineParam1_u8_arr, x
    rts
    @decrement:
    dec Ram_MachineParam1_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_LavaFlowerBoiler_Draw
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_Light:
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @done
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
    ;; TODO: draw rest of machine
_Valve:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, x
    div #kValveAnimSlowdown  ; param: valve angle
    ldx #kValvePlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawBoilerValve
.ENDPROC

;;;=========================================================================;;;
