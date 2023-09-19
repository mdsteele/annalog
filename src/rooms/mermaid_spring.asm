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
.INCLUDE "../actors/child.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/pump.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Mermaid_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_DrawPumpMachine
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjSewer
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0
;;; The talk device indices for Alex in this room.
kAlexDeviceIndexLeft = 4
kAlexDeviceIndexRight = 3

;;; The device index for the MermaidSpringPump console.
kConsoleDeviceIndex = 1
;;; The device index for the lever at the bottom of the hot spring.
kLeverDeviceIndex = 2

;;; The machine index for the MermaidSpringPump machine.
kPumpMachineIndex = 0
;;; The platform index for the MermaidSpringPump machine.
kPumpPlatformIndex = 0
;;; The platform index for the movable water.
kWaterPlatformIndex = 1
;;; The platform index for the sand plugging up the bottom of the hot spring.
kSandPlatformIndex = 2

;;; The initial and maximum permitted vertical goal values for the pump.
kPumpInitGoalY = 9
kPumpMaxGoalY = 9

;;; The maximum, initial, and minimum Y-positions for the top of the movable
;;; water platform.
kWaterMaxPlatformTop = $0104
kWaterInitPlatformTop = kWaterMaxPlatformTop - kPumpInitGoalY * kBlockHeightPx
kWaterMinPlatformTop = kWaterMaxPlatformTop - kPumpMaxGoalY * kBlockHeightPx

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the lever at the bottom of the hot spring.
    Lever_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Spring_sRoom
.PROC DataC_Mermaid_Spring_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $0008
    d_byte Flags_bRoom, bRoom::Tall | eArea::Mermaid
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 14
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjSewer)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mermaid_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, DataA_Room_MermaidSpring_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, DataA_Room_MermaidSpring_TickRoom
    d_addr Draw_func_ptr, DataC_Mermaid_Spring_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_spring.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kPumpMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MermaidSpringPump
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Boiler  ; TODO
    d_word ScrollGoalX_u16, $08
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kPumpPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_MermaidSpringPump_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mermaid_SpringPump_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MermaidSpringPump_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_MermaidSpringPump_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MermaidSpringPump_Draw
    d_addr Reset_func_ptr, FuncA_Room_MermaidSpringPump_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kPumpPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00d8
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kWaterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $ff
    d_word Left_i16,  $0060
    d_word Top_i16, kWaterInitPlatformTop
    D_END
    .assert * - :- = kSandPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0070
    d_word Top_i16,   $0110
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $00b0
    d_word PosY_i16, $0068
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eDialog::MermaidSpringSign
    D_END
    .assert * - :- = kConsoleDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kPumpMachineIndex
    D_END
    .assert * - :- = kLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverCeiling
    d_byte BlockRow_u8, 15
    d_byte BlockCol_u8, 7
    d_byte Target_byte, sState::Lever_u8
    D_END
    .assert * - :- = kAlexDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eDialog::MermaidSpringAlex
    D_END
    .assert * - :- = kAlexDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eDialog::MermaidSpringAlex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::MermaidVillage
    d_byte SpawnBlock_u8, 4
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MermaidEast
    d_byte SpawnBlock_u8, 4
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::LavaWest
    d_byte SpawnBlock_u8, 7
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC DataC_Mermaid_Spring_DrawRoom
_Console:
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidSpringConsoleFixed
    beq @done
    ;; TODO: draw console monitor
    @done:
_Sand:
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidSpringUnplugged
    bne @done
    ;; TODO: draw sand platform
    @done:
    rts
.ENDPROC

.PROC FuncC_Mermaid_SpringPump_ReadReg
    .assert kWaterMaxPlatformTop + kTileHeightPx >= $100, error
    lda #<(kWaterMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kWaterPlatformIndex
    .assert kWaterMaxPlatformTop - kWaterMinPlatformTop < $100, error
    div #kBlockHeightPx
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_MermaidSpringPump_TryMove
    lda #kPumpMaxGoalY  ; param: max vertical goal
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

;;; TODO: factor out common code with SewerFlower
.PROC FuncA_Machine_MermaidSpringPump_Tick
    ;; Calculate the desired Y-position for the top edge of the water, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kPumpMachineIndex
    .assert kPumpMaxGoalY * kBlockHeightPx < $100, error
    mul #kBlockHeightPx
    sta T0  ; goal delta
    .assert kWaterMaxPlatformTop >= $100, error
    lda #<kWaterMaxPlatformTop
    sub T0  ; goal delta
    sta Zp_PointY_i16 + 0
    lda #>kWaterMaxPlatformTop
    sbc #0
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the water (faster if resetting).
    lda Ram_MachineStatus_eMachine_arr + kPumpMachineIndex
    cmp #eMachine::Resetting
    beq @fullSpeed
    lda Ram_MachineSlowdown_u8_arr + kPumpMachineIndex
    beq @canMove
    rts
    @canMove:
    lda #kPumpWaterSlowdown
    sta Ram_MachineSlowdown_u8_arr + kPumpMachineIndex
    @fullSpeed:
    lda #1
    ;; Move the water vertically, as necessary.
    ldx #kWaterPlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_MermaidSpringPump_InitReset
    lda #kPumpInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kPumpMachineIndex
    rts
.ENDPROC

.PROC DataA_Room_MermaidSpring_EnterRoom
_Alex:
    ;; TODO: If Alex isn't here yet, or the spring is drained, remove him.
_Console:
    ;; If the console hasn't been fixed, remove its device.
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidSpringConsoleFixed
    bne @done
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    @done:
_DrainSpring:
    ;; If the spring has already been drained, remove the water and disable the
    ;; machine.
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidSpringUnplugged
    beq @done
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kWaterPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kSandPlatformIndex
    .assert ePlatform::Zone = 1, error
    sta Zp_RoomState + sState::Lever_u8
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    ;; TODO: Prevent the machine from executing.
    @done:
    rts
.ENDPROC

.PROC DataA_Room_MermaidSpring_TickRoom
    lda Zp_RoomState + sState::Lever_u8
    beq @done
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kWaterPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kSandPlatformIndex
    ldx #eFlag::MermaidSpringUnplugged
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs @done
    ;; TODO: start animating disappearing sand and falling water
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_MermaidSpringPump_Draw
    jsr FuncA_Objects_DrawPumpMachine
_Water:
    ;; Don't draw the water if it's been drained.
    lda Ram_PlatformType_ePlatform_arr + kWaterPlatformIndex
    cmp #ePlatform::Water
    bne @done
    ;; Determine the position for the leftmost water object.
    ldx #kWaterPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda Ram_PlatformTop_i16_0_arr + kWaterPlatformIndex
    sub #kWaterMinPlatformTop & $f8
    div #kTileHeightPx
    tay
    lda _WaterOffset_u8_arr, y  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves Y
    ;; Determine the width of the water in tiles, and draw that many objects.
    ldx _WaterWidth_u8_arr, y
    @loop:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    .assert kTileIdObjHotSpringFirst & $03 = 0, error
    ora #kTileIdObjHotSpringFirst
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjHotSpring | bObj::Pri
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X
    dex
    bne @loop
    @done:
    rts
_WaterOffset_u8_arr:
    .byte $10, $10, $10, $10, $10, $00, $00, $00
    .byte $00, $00, $10, $10, $10, $10, $20, $10
    .byte $10, $10, $10, $10
_WaterWidth_u8_arr:
    .byte 6, 6, 6, 6, 4, 6, 6, 6
    .byte 4, 6, 4, 6, 6, 6, 4, 6
    .byte 4, 4, 4, 4
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidSpringAlex_sDialog
.PROC DataA_Dialog_MermaidSpringAlex_sDialog
    dlg_Text ChildAlex, DataA_Text0_MermaidSpringAlex_u8_arr
    ;; TODO: play cutscene
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidSpringSign_sDialog
.PROC DataA_Dialog_MermaidSpringSign_sDialog
    dlg_Func _InitialFunc
_InitialFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidSpringUnplugged
    bne @unplugged
    ldya #_Open_sDialog
    rts
    @unplugged:
    ldya #_Closed_sDialog
    rts
_Open_sDialog:
    dlg_Text Sign, DataA_Text0_MermaidSpringSign_Open_u8_arr
    dlg_Done
_Closed_sDialog:
    dlg_Text Sign, DataA_Text0_MermaidSpringSign_Closed_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_MermaidSpringAlex_u8_arr
    .byte "TODO.#"
.ENDPROC

.PROC DataA_Text0_MermaidSpringSign_Open_u8_arr
    .byte "   - Hot Spring -$"
    .byte "Please enjoy a restful$"
    .byte "and relaxing soak.#"
.ENDPROC

.PROC DataA_Text0_MermaidSpringSign_Closed_u8_arr
    .byte "   - Hot Spring -$"
    .byte "Currently closed for$"
    .byte "maintenance.#"
.ENDPROC

;;;=========================================================================;;;