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
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Hut_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjVillage
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

kMachineInitPlatformTop = $90
kMachineMoveCountdown = $10

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    MachineGoalY_u8_arr .res 2
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut6_sRoom
.PROC DataC_Mermaid_Hut6_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Mermaid
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 16
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjVillage)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Hut_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_hut6.room"
    .assert * - :- = 16 * 16, error
_Machines_sMachine_arr:
    ;; TODO: replace these with real machines for this room
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenCrossroadLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, 0
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Mermaid_Hut6Machine_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Mermaid_Hut6Machine_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Mermaid_Hut6Machine_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MermaidHut6Machine_Draw
    d_addr Reset_func_ptr, FuncC_Mermaid_Hut6Machine_Reset
    D_END
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::PrisonCellLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, 1
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Mermaid_Hut6Machine_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Mermaid_Hut6Machine_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Mermaid_Hut6Machine_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MermaidHut6Machine_Draw
    d_addr Reset_func_ptr, FuncC_Mermaid_Hut6Machine_Reset
    D_END
_Platforms_sPlatform_arr:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0050
    d_word Top_i16, kMachineInitPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0070
    d_word Top_i16, kMachineInitPlatformTop
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 5
    d_byte Target_u8, 0  ; TODO: use constant
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 7
    d_byte Target_u8, 1  ; TODO: use constant
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 9
    d_byte Target_u8, eRoom::MermaidEast
    D_END
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Mermaid_Hut6Machine_Reset
    ldx Zp_MachineIndex_u8
    lda #0
    sta Zp_RoomState + sState::MachineGoalY_u8_arr, x
    rts
.ENDPROC

.PROC FuncC_Mermaid_Hut6Machine_ReadReg
    ldx Zp_MachineIndex_u8
    lda #kMachineInitPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr, x
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Mermaid_Hut6Machine_TryMove
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    ldx Zp_MachineIndex_u8
    lda Zp_RoomState + sState::MachineGoalY_u8_arr, x
    bne @error
    inc Zp_RoomState + sState::MachineGoalY_u8_arr, x
    jmp FuncA_Machine_StartWorking
    @moveDown:
    ldx Zp_MachineIndex_u8
    lda Zp_RoomState + sState::MachineGoalY_u8_arr, x
    beq @error
    dec Zp_RoomState + sState::MachineGoalY_u8_arr, x
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Mermaid_Hut6Machine_Tick
    ldx Zp_MachineIndex_u8
    ;; Calculate the desired Y-position for the top edge of the lift, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    lda Zp_RoomState + sState::MachineGoalY_u8_arr, x
    mul #kBlockHeightPx  ; fits in one byte
    sta Zp_Tmp1_byte
    lda #kMachineInitPlatformTop
    sub Zp_Tmp1_byte
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the lift (faster if resetting).
    lda #1
    ldy Ram_MachineStatus_eMachine_arr, x
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the lift vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; returns Z and A
    beq @done
    rts
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_MermaidHut6Machine_Draw
    ldx Zp_MachineIndex_u8  ; param: platform index
    jmp FuncA_Objects_DrawGirderPlatform
.ENDPROC

;;;=========================================================================;;;
