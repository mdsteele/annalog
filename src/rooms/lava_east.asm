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
.INCLUDE "../machine.inc"
.INCLUDE "../machines/boiler.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_LavaAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_LavaAreaName_u8_arr
.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_BoilerTick
.IMPORT FuncA_Machine_BoilerWriteReg
.IMPORT FuncA_Machine_EmitSteamRightFromPipe
.IMPORT FuncA_Machine_EmitSteamUpFromPipe
.IMPORT FuncA_Objects_DrawBoilerMachine
.IMPORT FuncA_Objects_DrawBoilerValve1
.IMPORT FuncA_Objects_DrawBoilerValve2
.IMPORT Func_MachineBoilerReadReg
.IMPORT Func_MachineBoilerReset
.IMPORT Func_MachineError
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The machine indices for the LavaEastUpperBoiler and LavaEastLowerBoiler
;;; machines.
kUpperBoilerMachineIndex = 0
kLowerBoilerMachineIndex = 1

;;; Platform indices for various parts of the LavaWestUpperBoiler machine.
kUpperBoilerPlatformIndex = 0
kUpperValve1PlatformIndex = 1
kUpperValve2PlatformIndex = 2
kUpperPipe1PlatformIndex  = 3
kUpperPipe2PlatformIndex  = 4
kUpperPipe3PlatformIndex  = 5

;;; Platform indices for various parts of the LavaWestLowerBoiler machine.
kLowerBoilerPlatformIndex = 6
kLowerValve1PlatformIndex = 7
kLowerValve2PlatformIndex = 8
kLowerPipe1PlatformIndex  = 9
kLowerPipe2PlatformIndex  = 10

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_East_sRoom
.PROC DataC_Lava_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 17
    d_byte MinimapWidth_u8, 2
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjLava)
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
    d_addr FadeIn_func_ptr, FuncC_Lava_East_FadeInRoom
    D_END
_TerrainData:
:   .incbin "out/data/lava_east.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kUpperBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaEastUpperBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteC | bMachine::WriteD
    d_byte Status_eDiagram, eDiagram::Winch  ; TODO
    d_word ScrollGoalX_u16, $090
    d_byte ScrollGoalY_u8, $20
    d_byte RegNames_u8_arr4, "V", "U", 0, 0
    d_byte MainPlatform_u8, kUpperBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineBoilerReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BoilerWriteReg
    d_addr TryMove_func_ptr, Func_MachineError
    d_addr TryAct_func_ptr, FuncC_Lava_EastUpperBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncA_Objects_LavaEastUpperBoiler_Draw
    d_addr Reset_func_ptr, Func_MachineBoilerReset
    D_END
    .assert * - :- = kLowerBoilerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaEastLowerBoiler
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteC | bMachine::WriteD
    d_byte Status_eDiagram, eDiagram::Winch  ; TODO
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $b8
    d_byte RegNames_u8_arr4, "V", "U", 0, 0
    d_byte MainPlatform_u8, kLowerBoilerPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineBoilerReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_BoilerWriteReg
    d_addr TryMove_func_ptr, Func_MachineError
    d_addr TryAct_func_ptr, FuncC_Lava_EastLowerBoiler_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_BoilerTick
    d_addr Draw_func_ptr, FuncA_Objects_LavaEastLowerBoiler_Draw
    d_addr Reset_func_ptr, Func_MachineBoilerReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kUpperBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0120
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- = kUpperValve1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0114
    d_word Top_i16,   $0094
    D_END
    .assert * - :- = kUpperValve2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0134
    d_word Top_i16,   $0074
    D_END
    .assert * - :- = kUpperPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0110
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kUpperPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0148
    d_word Top_i16,   $0050
    D_END
    .assert * - :- = kUpperPipe3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0138
    d_word Top_i16,   $0088
    D_END
    .assert * - :- = kLowerBoilerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $18
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0138
    d_word Top_i16,   $0120
    D_END
    .assert * - :- = kLowerValve1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0164
    d_word Top_i16,   $0124
    D_END
    .assert * - :- = kLowerValve2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0154
    d_word Top_i16,   $0104
    D_END
    .assert * - :- = kLowerPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0178
    d_word Top_i16,   $00e8
    D_END
    .assert * - :- = kLowerPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0180
    d_word Top_i16,   $0130
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $220
    d_byte HeightPx_u8,  $20
    d_word Left_i16,   $0000
    d_word Top_i16,    $0163
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8,  4
    d_byte BlockCol_u8, 12
    d_byte Target_u8, kUpperBoilerMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 29
    d_byte Target_u8, kLowerBoilerMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::LavaShaft
    d_byte SpawnBlock_u8, 4
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::LavaFlower
    d_byte SpawnBlock_u8, 15
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::LavaEast  ; TODO
    d_byte SpawnBlock_u8, 4
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::LavaEast  ; TODO
    d_byte SpawnBlock_u8, 15
    D_END
.ENDPROC

;;; Sets two block rows of the lower nametable to use BG palette 1.
;;; @prereq Rendering is disabled.
.PROC FuncC_Lava_East_FadeInRoom
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable3_sName + sName::Attrs_u8_arr64 + $18
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
_Row7:
    lda #$50
    ldx #8
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_Row8:
    lda #$05
    ldx #8
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;; TryAct implemention for the LavaEastUpperBoiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq PRGA_Machine is loaded.
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.PROC FuncC_Lava_EastUpperBoiler_TryAct
_Valve1:
    ldy Zp_MachineIndex_u8
    ldx Ram_MachineGoalVert_u8_arr, y  ; valve 1 angle (0-9)
    ldy _Valve1ExitPlatformIndex_u8_arr10, x  ; platform index
    bmi _Failure
    cpy #kUpperValve2PlatformIndex
    beq _Valve2
    jsr FuncA_Machine_EmitSteamUpFromPipe
    jmp _Success
_Valve2:
    ldy Zp_MachineIndex_u8
    ldx Ram_MachineGoalHorz_u8_arr, y  ; valve 2 angle (0-9)
    ldy _Valve2ExitPlatformIndex_u8_arr10, x  ; platform index
    bmi _Failure
    jsr FuncA_Machine_EmitSteamRightFromPipe
_Success:
    lda #kBoilerActCountdown
    clc  ; success
    rts
_Failure:
    sec  ; failure
    rts
_Valve1ExitPlatformIndex_u8_arr10:
:   .byte kUpperValve2PlatformIndex
    .byte kUpperValve2PlatformIndex
    .byte $ff
    .byte kUpperPipe1PlatformIndex
    .byte kUpperPipe1PlatformIndex
    .byte $ff
    .byte kUpperValve2PlatformIndex
    .byte kUpperValve2PlatformIndex
    .byte $ff
    .byte kUpperPipe1PlatformIndex
    .assert * - :- = 10, error
_Valve2ExitPlatformIndex_u8_arr10:
:   .byte kUpperPipe3PlatformIndex
    .byte $ff
    .byte kUpperPipe2PlatformIndex
    .byte kUpperPipe2PlatformIndex
    .byte $ff
    .byte kUpperPipe3PlatformIndex
    .byte kUpperPipe3PlatformIndex
    .byte $ff
    .byte kUpperPipe2PlatformIndex
    .byte kUpperPipe2PlatformIndex
    .assert * - :- = 10, error
.ENDPROC

;;; TryAct implemention for the LavaEastLowerBoiler machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq PRGA_Machine is loaded.
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.PROC FuncC_Lava_EastLowerBoiler_TryAct
    lda #0
    sta Zp_Tmp1_byte  ; num steams emitted
_Pipe1:
    ldy Zp_MachineIndex_u8
    ldx Ram_MachineGoalHorz_u8_arr, y  ; valve 2 angle (0-9)
    ldy _Valve2ExitPlatformIndex_u8_arr10, x  ; platform index
    bmi @done
    ldy Zp_MachineIndex_u8
    ldx Ram_MachineGoalVert_u8_arr, y  ; valve 1 angle (0-9)
    ldy _Valve1PipePlatformIndex1_u8_arr10, x  ; platform index
    bmi @done
    jsr FuncA_Machine_EmitSteamRightFromPipe
    inc Zp_Tmp1_byte  ; num steams emitted
    @done:
_Pipe2:
    ldy Zp_MachineIndex_u8
    ldx Ram_MachineGoalVert_u8_arr, y  ; valve 1 angle (0-9)
    ldy _Valve1PipePlatformIndex2_u8_arr10, x  ; platform index
    bmi @done
    jsr FuncA_Machine_EmitSteamUpFromPipe
    inc Zp_Tmp1_byte  ; num steams emitted
    @done:
_Finish:
    lda Zp_Tmp1_byte  ; num steams emitted
    beq _Failure
_Success:
    lda #kBoilerActCountdown
    clc  ; success
    rts
_Failure:
    sec  ; failure
    rts
_Valve1PipePlatformIndex1_u8_arr10:
:   .byte $ff
    .byte $ff
    .byte kLowerPipe1PlatformIndex
    .byte kLowerPipe1PlatformIndex
    .byte kLowerPipe1PlatformIndex
    .byte $ff
    .byte $ff
    .byte $ff
    .byte kLowerPipe1PlatformIndex
    .byte kLowerPipe1PlatformIndex
    .assert * - :- = 10, error
_Valve1PipePlatformIndex2_u8_arr10:
:   .byte kLowerPipe2PlatformIndex
    .byte $ff
    .byte $ff
    .byte kLowerPipe2PlatformIndex
    .byte kLowerPipe2PlatformIndex
    .byte kLowerPipe2PlatformIndex
    .byte kLowerPipe2PlatformIndex
    .byte $ff
    .byte $ff
    .byte kLowerPipe2PlatformIndex
    .assert * - :- = 10, error
_Valve2ExitPlatformIndex_u8_arr10:
:   .byte $ff
    .byte $ff
    .byte kLowerValve1PlatformIndex
    .byte kLowerValve1PlatformIndex
    .byte $ff
    .byte $ff
    .byte $ff
    .byte $ff
    .byte kLowerValve1PlatformIndex
    .byte kLowerValve1PlatformIndex
    .assert * - :- = 10, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_LavaEastUpperBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kUpperValve1PlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawBoilerValve1
    ldx #kUpperValve2PlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawBoilerValve2
.ENDPROC

.PROC FuncA_Objects_LavaEastLowerBoiler_Draw
    jsr FuncA_Objects_DrawBoilerMachine
    ldx #kLowerValve1PlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawBoilerValve1
    ldx #kLowerValve2PlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawBoilerValve2
.ENDPROC

;;;=========================================================================;;;
