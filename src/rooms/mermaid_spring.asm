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
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/console.inc"
.INCLUDE "../devices/dialog.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/pump.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/water.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../scroll.inc"

.IMPORT DataA_Room_Mermaid_sTileset
.IMPORT DataA_Text0_MermaidSpringAlex_Part1_u8_arr
.IMPORT DataA_Text0_MermaidSpringAlex_Part2_u8_arr
.IMPORT DataA_Text0_MermaidSpringAlex_Part3_u8_arr
.IMPORT DataA_Text0_MermaidSpringAlex_Part4_u8_arr
.IMPORT DataA_Text0_MermaidSpringAlex_Part5_u8_arr
.IMPORT DataA_Text0_MermaidSpringSign_Closed_u8_arr
.IMPORT DataA_Text0_MermaidSpringSign_Open_u8_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_PumpTick
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawMonitorPlatform
.IMPORT FuncA_Objects_DrawPumpMachine
.IMPORT FuncA_Objects_DrawRocksPlatformHorz
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitActorSmokeRaindrop
.IMPORT FuncA_Room_SpawnExplosionAtPoint
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeFracture
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjSewer
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0
;;; The talk device indices for Alex in this room.
kAlexDeviceIndexLeft = 4
kAlexDeviceIndexRight = 3

;;; The platform index for the fixable console monitor in this room.
kMonitorPlatformIndex = 3

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
;;; The platform index for the rocks plugging up the bottom of the hot spring.
kRocksPlatformIndex = 2

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
    ;; The current state of the lever at the bottom of the hot spring.
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
    d_addr Enter_func_ptr, FuncA_Room_MermaidSpring_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_MermaidSpring_TickRoom
    d_addr Draw_func_ptr, FuncC_Mermaid_Spring_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/mermaid_spring.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kPumpMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MermaidSpringPump
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Pump
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
    d_addr Draw_func_ptr, FuncC_Mermaid_SpringPump_Draw
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
    .assert * - :- = kRocksPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0070
    d_word Top_i16,   $0110
    D_END
    .assert * - :- = kMonitorPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00c0
    d_word Top_i16,   $0060
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
    d_byte Type_eDevice, eDevice::ConsoleFloor
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
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MermaidEast
    d_byte SpawnBlock_u8, 4
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::LavaWest
    d_byte SpawnBlock_u8, 8
    d_byte SpawnAdjust_byte, $f0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Mermaid_Spring_DrawRoom
    ldx #kRocksPlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawRocksPlatformHorz
    ldx #kMonitorPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawMonitorPlatform
.ENDPROC

.PROC FuncC_Mermaid_SpringPump_ReadReg
    .assert kWaterMaxPlatformTop + kTileHeightPx >= $100, error
    lda #<(kWaterMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kWaterPlatformIndex
    .assert kWaterMaxPlatformTop - kWaterMinPlatformTop < $100, error
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Mermaid_SpringPump_Draw
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
    lda Zp_FrameCounter_u8
    div #8
    mod #4
    .assert kTileIdObjPlatformHotSpringFirst .mod 4 = 0, error
    ora #kTileIdObjPlatformHotSpringFirst  ; param: tile ID
    ldy #kPaletteObjHotSpring | bObj::Pri  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
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

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_MermaidSpringPump_TryMove
    lda #kPumpMaxGoalY  ; param: max vertical goal
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncA_Machine_MermaidSpringPump_Tick
    ldx #kWaterPlatformIndex  ; param: water platform index
    ldya #kWaterMaxPlatformTop  ; param: max water platform top
    jmp FuncA_Machine_PumpTick
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_MermaidSpringPump_InitReset
    lda #kPumpInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kPumpMachineIndex
    rts
.ENDPROC

.PROC FuncA_Room_MermaidSpring_EnterRoom
_Alex:
    ;; If Alex isn't here yet, or the spring is drained, remove him.
    flag_bit Sram_ProgressFlags_arr, eFlag::CityOutskirtsTalkedToAlex
    beq @removeAlex
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidSpringUnplugged
    beq @keepAlex
    @removeAlex:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexRight
    @keepAlex:
_Console:
    ;; If the console hasn't been fixed, remove its device and lock scrolling.
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidSpringConsoleFixed
    bne @done
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    ;; Hide the monitor platform offscreen.
    lda #$02
    sta Ram_PlatformLeft_i16_1_arr + kMonitorPlatformIndex
    ;; Remove console device.
    ;; Lock scroll-Y to top of room.
    lda #bScroll::LockVert
    sta Zp_Camera_bScroll
    lda #0
    sta Zp_RoomScrollY_u8
    @done:
_DrainSpring:
    ;; If the spring has already been drained, remove the water and disable the
    ;; machine.
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidSpringUnplugged
    beq @done
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kWaterPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kRocksPlatformIndex
    .assert ePlatform::Zone = 1, error
    sta Zp_RoomState + sState::Lever_u8
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    lda #eMachine::Halted
    sta Ram_MachineStatus_eMachine_arr + kPumpMachineIndex
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_MermaidSpring_TickRoom
    ;; If the lever hasn't been flipped yet, do nothing.
    lda Zp_RoomState + sState::Lever_u8
    beq @return
    ;; Set the flag; if it was already set, do nothing else.
    ldx #eFlag::MermaidSpringUnplugged
    jsr Func_SetFlag  ; sets C if flag was already set
    bcc @unplug
    @return:
    rts
    @unplug:
    ;; TODO: disable the machine
_RemoveRocksAndWater:
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kRocksPlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kWaterPlatformIndex
    jsr Func_PlaySfxExplodeFracture
    lda #30  ; param: num frames
    jsr Func_ShakeRoom
_AnimateFallingWater:
    lda #0
    sta Zp_PointX_i16 + 1
    sta Zp_PointY_i16 + 1
    lda #$f6
    sta Zp_PointY_i16 + 0
    ldy #3
    @loop:
    lda _RaindropPosX_u8_arr, y
    sta Zp_PointX_i16 + 0
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @done  ; no more actor slots available
    jsr Func_SetActorCenterToPoint  ; preserves X and Y
    sty T0  ; loop index
    jsr FuncA_Room_InitActorSmokeRaindrop  ; preserves X and T0+
    ldy T0  ; loop index
    lda _RaindropVelY_u8_arr, y
    sta Ram_ActorVelY_i16_0_arr, x
    dey
    bpl @loop
    @done:
_AnimateExplodingRocks:
    ldy #kRocksPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter
    lda #kTileWidthPx
    jsr Func_MovePointLeftByA
    jsr FuncA_Room_SpawnExplosionAtPoint
    lda #kTileWidthPx * 2
    jsr Func_MovePointRightByA
    jmp FuncA_Room_SpawnExplosionAtPoint
_RaindropPosX_u8_arr:
    .byte $74, $84, $8c, $7c
_RaindropVelY_u8_arr:
    .byte $20, $00, $40, $80
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_MermaidSpringFixConsole_sCutscene
.PROC DataA_Cutscene_MermaidSpringFixConsole_sCutscene
    act_ForkStart 1, _WalkAvatar_sCutscene
    act_MoveNpcAlexWalk kAlexActorIndex, $00ba
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 45
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexKneeling
    act_WaitFrames 15
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexBoosting
    act_CallFunc _InitMonitorPlatform
    act_WaitUntilZ _LiftMonitorPlatform
    act_WaitFrames 60
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexKneeling
    act_WaitUntilZ _DropMonitorPlatform
    act_WaitFrames 15
    act_CallFunc _FixConsole
    act_SetDeviceAnim kConsoleDeviceIndex, kConsoleAnimCountdown
    act_SetScrollFlags 0
    act_WaitFrames 70
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 45
    act_MoveNpcAlexWalk kAlexActorIndex, $00b0
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_SetActorState2 kAlexActorIndex, 0
    act_RunDialog eDialog::MermaidSpringAlex
    act_ContinueExploring
_WalkAvatar_sCutscene:
    act_MoveAvatarWalk $00a0 | kTalkRightAvatarOffset
    act_SetAvatarPose eAvatar::Standing
    act_SetAvatarFlags kPaletteObjAvatarNormal
    act_ForkStop $ff
_InitMonitorPlatform:
    lda #$00
    sta Ram_PlatformLeft_i16_1_arr + kMonitorPlatformIndex
    lda #$b2
    sta Ram_PlatformLeft_i16_0_arr + kMonitorPlatformIndex
    lda #$64
    sta Ram_PlatformTop_i16_0_arr + kMonitorPlatformIndex
    rts
_LiftMonitorPlatform:
    ldax #$0059
    stax Zp_PointY_i16
    ldx #kMonitorPlatformIndex  ; param: platform index
    lda #2  ; param: max move by
    jmp Func_MovePlatformTopTowardPointY  ; returns Z
_DropMonitorPlatform:
    ldax #$0060
    stax Zp_PointY_i16
    ldx #$c0
    stax Zp_PointX_i16
    ldx #kMonitorPlatformIndex  ; param: platform index
    lda #4  ; param: max move by
    jsr Func_MovePlatformLeftTowardPointX  ; preserves X
    lda #1  ; param: max move by
    jmp Func_MovePlatformTopTowardPointY  ; returns Z
_FixConsole:
    ;; TODO: play a sound for the console turning on
    lda #eDevice::ConsoleFloor
    sta Ram_DeviceType_eDevice_arr + kConsoleDeviceIndex
    ldx #eFlag::MermaidSpringConsoleFixed  ; param: flag
    jmp Func_SetFlag
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidSpringAlex_sDialog
.PROC DataA_Dialog_MermaidSpringAlex_sDialog
    dlg_IfSet MermaidSpringConsoleFixed, _Fixed_sDialog
_Intro_sDialog:
    dlg_Text ChildAlex, DataA_Text0_MermaidSpringAlex_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text0_MermaidSpringAlex_Part2_u8_arr
    dlg_Text ChildAlex, DataA_Text0_MermaidSpringAlex_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text0_MermaidSpringAlex_Part4_u8_arr
    dlg_Cutscene eCutscene::MermaidSpringFixConsole
_Fixed_sDialog:
    dlg_Text ChildAlex, DataA_Text0_MermaidSpringAlex_Part5_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_MermaidSpringSign_sDialog
.PROC DataA_Dialog_MermaidSpringSign_sDialog
    dlg_IfSet MermaidSpringUnplugged, _Closed_sDialog
_Open_sDialog:
    dlg_Text Sign, DataA_Text0_MermaidSpringSign_Open_u8_arr
    dlg_Done
_Closed_sDialog:
    dlg_Text Sign, DataA_Text0_MermaidSpringSign_Closed_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
