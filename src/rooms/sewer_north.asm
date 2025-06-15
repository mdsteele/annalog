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
.INCLUDE "../machines/pump.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/water.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Sewer_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawMultiplexerMachineMainPlatform
.IMPORT FuncA_Objects_DrawValveShape
.IMPORT FuncA_Objects_GetWaterObjTileId
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_InitActorSmokeWaterfall
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_PlaySfxSplash
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorState4_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState3_byte_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 0
kLeverRightDeviceIndex = 1

;;; The number of valves in this room.
.DEFINE kNumValves 10

;;; The machine index for the SewerNorthMultiplexer machine in this room.
kMultiplexerMachineIndex = 0
;;; The main platform index for the SewerNorthMultiplexer machine.
kMultiplexerMainPlatformIndex = 0
;;; The platform index for the zone containing all the valves.
kValvesPlatformIndex = 1
;;; The platform indices for the pipes that water can come out of.
kPipe1PlatformIndex = 2
kPipe2PlatformIndex = 3
kPipe3PlatformIndex = 4
kPipe4PlatformIndex = 5
kPipe5PlatformIndex = 6
;;; The platform indices for the pools of water in this room.
kWestWaterPlatformIndex   = 7
kCenterWaterPlatformIndex = 8
kEastWaterPlatformIndex   = 9

;;; When the east or west water surface is at this room pixel Y-position or
;;; higher, the water should be drawn wide instead of narrow.
kWideWaterTop = $b0

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8  .byte
    LeverRight_u8 .byte
    ;; The platform index for the pipe that's currently pouring water, or $ff
    ;; if none.
    ActivePipePlatformIndex_u8 .byte
    ;; The actor index for the waterfall smoke that's currently pouring out of
    ;; the active pipe, or $ff if none.
    ActiveWaterfallActorIndex_u8 .byte
    ;; The goal position for each valve, in (tau/8) units (0-9).
    ValveGoal_u8_arr  .byte kNumValves
    ;; The current angle for each valve, in (tau/32) units (0-36).
    ValveAngle_u8_arr .byte kNumValves
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Sewer"

.EXPORT DataC_Sewer_North_sRoom
.PROC DataC_Sewer_North_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, eArea::Sewer
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 20
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjLava)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Sewer_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Sewer_North_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Sewer_North_TickRoom
    d_addr Draw_func_ptr, FuncC_Sewer_North_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/sewer_north.room"
    .assert * - :- = 34 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kMultiplexerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::SewerNorthMultiplexer
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::WriteCDEF
    d_byte Status_eDiagram, eDiagram::MultiplexerValve
    d_word ScrollGoalX_u16, $0010
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", "J", "V"
    d_byte MainPlatform_u8, kMultiplexerMainPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Sewer_NorthMultiplexer_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_SewerNorthMultiplexer_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_SewerNorthMultiplexer_Tick
    d_addr Draw_func_ptr, FuncC_Sewer_NorthMultiplexer_Draw
    d_addr Reset_func_ptr, FuncC_Sewer_NorthMultiplexer_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kMultiplexerMainPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0038
    d_word Top_i16,   $0020
    D_END
    .assert * - :- = kValvesPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $178
    d_byte HeightPx_u8,  $08
    d_word Left_i16,   $0054
    d_word Top_i16,    $0024
    D_END
    .assert * - :- = kPipe1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0048
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kPipe2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a0
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kPipe3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kPipe4PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0168
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kPipe5PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01c8
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kWestWaterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0040
    d_word Top_i16,   $00c4
    D_END
    .assert * - :- = kCenterWaterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $f0
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0090
    d_word Top_i16,   $00b4
    D_END
    .assert * - :- = kEastWaterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $01b0
    d_word Top_i16,   $00c4
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 7
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 25
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 16
    d_byte Target_byte, kMultiplexerMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::SewerWest
    d_byte SpawnBlock_u8, 6
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::SewerEast
    d_byte SpawnBlock_u8, 8
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Sewer_North_DrawRoom
    jsr FuncA_Objects_GetWaterObjTileId  ; returns A
    sta T2  ; water tile ID
_DrawWestWaterSurface:
    ldx #kWestWaterPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X and T0+
    jsr _DrawWaterTilePair  ; preserves T0+
    lda Ram_PlatformTop_i16_0_arr + kWestWaterPlatformIndex
    cmp #kWideWaterTop
    bge @done
    jsr _DrawWaterTilePair  ; preserves T0+
    @done:
_DrawEastWaterSurface:
    ldx #kEastWaterPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves T0+
    lda Ram_PlatformTop_i16_0_arr + kEastWaterPlatformIndex
    cmp #kWideWaterTop
    bge @skip
    jsr _DrawWaterTilePair  ; preserves T0+
    jmp _DrawWaterTilePair
    @skip:
    lda #kTileWidthPx * 2
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves T0+
_DrawWaterTilePair:
    ldx #2
    @loop:
    ldy #kPaletteObjWater  ; param: object flags
    lda T2  ; param: water tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and T0+
    dex
    bne @loop
    rts
.ENDPROC

.PROC FuncC_Sewer_NorthMultiplexer_ReadReg
    cmp #$d
    blt _ReadL
    beq _ReadR
    cmp #$e
    beq _ReadJ
_ReadV:
    ldx Ram_MachineState1_byte_arr + kMultiplexerMachineIndex  ; J register
    lda Zp_RoomState + sState::ValveAngle_u8_arr, x
    add #kBoilerValveAnimSlowdown / 2
    div #kBoilerValveAnimSlowdown
    rts
_ReadJ:
    lda Ram_MachineState1_byte_arr + kMultiplexerMachineIndex  ; J register
    rts
_ReadL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_ReadR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Sewer_NorthMultiplexer_Draw
    jsr FuncC_Sewer_North_GetNumCorrectValves  ; returns X
    stx T2  ; num correct valves
    ldx #kValvesPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves T0+
    ldx #0
    @loop:
    ;; For valve index 7, if the number of correct valves is 8 (that is, the
    ;; water is flowing past this valve, but not the next one), then the water
    ;; is doubling back through the other side of this valve.
    cpx #7
    bne @notBothSides
    lda T2  ; num correct valves
    cmp #8
    bne @notBothSides
    ldy #eValveInput::BothSides  ; param: input pipe position
    .assert eValveInput::BothSides <> 0, error
    bne @drawValve  ; unconditional
    @notBothSides:
    ;; Otherwise, if the water is flowing to or past this valve, then pass in
    ;; the active input pipe position, and otherwise pass eValveInput::None.
    ldy #eValveInput::None  ; param: input pipe position
    cpx T2  ; num correct valves
    blt @activeInput
    bne @drawValve
    @activeInput:
    ldy _ValveInput_eValveInput_arr, x  ; param: input pipe position
    @drawValve:
    ;; Draw the valve at its current angle.
    lda Zp_RoomState + sState::ValveAngle_u8_arr, x  ; param: valve angle
    jsr FuncA_Objects_DrawValveShape  ; preserves X and T2+
    lda _ValveOffset_u8_arr, x
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X and T0+
    inx
    cpx #kNumValves
    blt @loop
    jmp FuncA_Objects_DrawMultiplexerMachineMainPlatform
_ValveOffset_u8_arr:
    .byte $20, $30, $20, $20, $40, $30, $20, $30, $20, $00
_ValveInput_eValveInput_arr:
    .byte eValveInput::LeftHalfOfTopEdge
    .byte eValveInput::BottomHalfOfLeftEdge
    .byte eValveInput::LeftHalfOfTopEdge
    .byte eValveInput::LeftHalfOfTopEdge
    .byte eValveInput::BottomHalfOfLeftEdge
    .byte eValveInput::BottomHalfOfLeftEdge
    .byte eValveInput::LeftHalfOfBottomEdge
    .byte eValveInput::TopHalfOfLeftEdge
    .byte eValveInput::TopHalfOfLeftEdge
    .byte eValveInput::TopHalfOfLeftEdge
.ENDPROC

.PROC FuncC_Sewer_North_EnterRoom
    ;; Set active pipe/waterfall indices to $ff.
    dec Zp_RoomState + sState::ActivePipePlatformIndex_u8
    dec Zp_RoomState + sState::ActiveWaterfallActorIndex_u8
    rts
.ENDPROC

;;; Finds the waterfall smoke actor, if any, that is currently pouring water
;;; into the specified water platform.
;;; @param Y The platform index of the water.
;;; @return C Set if no waterfall actor is pouring into this water.
;;; @return X The actor index of the waterfall (if any).
;;; @preserve Y
.PROC FuncC_Sewer_FindWaterfallPouringIntoWater
    sty T0  ; water platform index
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::SmokeWaterfall
    bne @continue  ; not a waterfall actor
    lda Ram_ActorState4_byte_arr, x  ; has hit water (boolean)
    bpl @continue  ; this waterfall hasn't hit water yet
    lda Ram_ActorState1_byte_arr, x  ; water platform index
    cmp T0  ; water platform index
    bne @continue
    clc  ; Clear C to indicate that a waterfall is pouring into the water.
    rts
    @continue:
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
    sec  ; Set C to indicate that no waterfall is pouring into the water.
    rts
.ENDPROC

;;; Raises the water level of the specified water platform if a waterfall is
;;; pouring into it, otherwise lower it.
;;; @param Y The platform index of the water.
.PROC FuncC_Sewer_North_RaiseOrLowerWaterLevel
    jsr FuncC_Sewer_FindWaterfallPouringIntoWater  ; preserves Y; returns C, X
    bcs _LowerWater
_RaiseWater:
    lda Ram_PlatformTop_i16_0_arr, y
    cmp #$95
    blt _Return  ; already at maximum height
    ;; The water surface is moving up one pixel, so reduce the height of the
    ;; waterfall that's hitting the water surface by one (unless it was already
    ;; zero, in which case don't wrap around).
    lda Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    beq @doneWaterfall
    dec Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    @doneWaterfall:
    ;; Move the water platform up by one pixel.  Using Func_MovePlatformVert
    ;; here instead of just modifying Ram_PlatformTop_i16_0_arr ensures that
    ;; the player avatar will be carried correctly by the water if swimming in
    ;; it.
    tya  ; water platform index
    tax  ; param: plaform index
    lda #<-1  ; param: move delta
    jmp Func_MovePlatformVert
_LowerWater:
    lda Ram_PlatformTop_i16_0_arr, y
    cmp #$c4
    bge _Return  ; already at minimum height
    ;; Move the water platform down by one pixel.  Using Func_MovePlatformVert
    ;; here instead of just modifying Ram_PlatformTop_i16_0_arr ensures that
    ;; the player avatar will be carried correctly by the water if swimming in
    ;; it.
    tya  ; water platform index
    tax  ; param: plaform index
    lda #1  ; param: move delta
    jmp Func_MovePlatformVert
_Return:
    rts
.ENDPROC

;;; Determines how far the water is able to flow in this room.
;;; @return X The number of valves that have water flowing past them (0-10).
.PROC FuncC_Sewer_North_GetNumCorrectValves
    ldx #0
    ;; Valve 0:
    jsr _GetNextValve  ; advances X, returns A
    cmp #3
    bne _Finish
    ;; Valve 1:
    jsr _GetNextValve  ; advances X, returns A
    cmp #1
    bne _Finish
    ;; Valve 2:
    jsr _GetNextValve  ; advances X, returns A and Z
    beq _Finish
    ;; Valve 3:
    jsr _GetNextValve  ; advances X, returns A
    cmp #3
    bne _Finish
    ;; Valve 4:
    jsr _GetNextValve  ; advances X, returns A
    cmp #1
    bne _Finish
    ;; Valve 5:
    jsr _GetNextValve  ; advances X, returns A
    cmp #2
    bne _Finish
    ;; Valve 6:
    jsr _GetNextValve  ; advances X, returns A
    cmp #1
    bne _Finish
    ;; Valve 7:
    jsr _GetNextValve  ; advances X, returns A
    cmp #2
    bne _Finish
    ;; Valve 8:
    jsr _GetNextValve  ; advances X, returns A
    cmp #2
    bne _Finish
    ;; Valve 9:
    jsr _GetNextValve  ; advances X, returns A
    cmp #3
    beq _Return
_Finish:
    dex
_Return:
    rts
_GetNextValve:
    lda Zp_RoomState + sState::ValveAngle_u8_arr, x
    inx
    add #kBoilerValveAnimSlowdown / 2
    div #kBoilerValveAnimSlowdown
    mod #4
    rts
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Sewer_North_TickRoom
    inc Ram_MachineState3_byte_arr + kMultiplexerMachineIndex  ; wqter slowdown
    lda Ram_MachineState3_byte_arr + kMultiplexerMachineIndex  ; water slowdown
    cmp #kPumpWaterSlowdown
    blt @done
    lda #0
    sta Ram_MachineState3_byte_arr + kMultiplexerMachineIndex  ; water slowdown
    ldy #kWestWaterPlatformIndex  ; param: water platform index
    jsr FuncC_Sewer_North_RaiseOrLowerWaterLevel
    ldy #kEastWaterPlatformIndex  ; param: water platform index
    jsr FuncC_Sewer_North_RaiseOrLowerWaterLevel
    @done:
_UpdatePipe:
    jsr FuncC_Sewer_North_GetNumCorrectValves  ; returns X
    ldy _PipePlatformIndex_u8_arr, x
    cpy Zp_RoomState + sState::ActivePipePlatformIndex_u8
    beq _Return  ; no change to current pipe
    lda _WaterPlatformIndex_u8_arr, x
    sta T0  ; param: platform index for water below (if any)
    lda #$ff
    sta Zp_RoomState + sState::ActivePipePlatformIndex_u8
_ShutOffOldWaterfall:
    ldx Zp_RoomState + sState::ActiveWaterfallActorIndex_u8
    bmi @done  ; no currently-pouring waterfall actor
    lda #$ff
    sta Ram_ActorState3_byte_arr, x  ; is shut off (boolean)
    sta Zp_RoomState + sState::ActiveWaterfallActorIndex_u8
    @done:
_StartNewWaterfall:
    tya  ; pipe platform index
    bmi _Return  ; no active pipe
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
    bcs _Return  ; no free actor slots; we'll try again next frame
    stx Zp_RoomState + sState::ActiveWaterfallActorIndex_u8
    sty Zp_RoomState + sState::ActivePipePlatformIndex_u8
    jsr Func_SetPointToPlatformCenter  ; preserves X and T0+
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    lda T0  ; param: platform index for water below
    jsr FuncA_Room_InitActorSmokeWaterfall
    jmp Func_PlaySfxSplash
_GetNextValve:
    lda Zp_RoomState + sState::ValveAngle_u8_arr, x
    inx
    add #kBoilerValveAnimSlowdown / 2
    div #kBoilerValveAnimSlowdown
    mod #4
_Return:
    rts
_PipePlatformIndex_u8_arr:
    .byte kPipe1PlatformIndex
    .byte $ff
    .byte kPipe2PlatformIndex
    .byte $ff
    .byte kPipe3PlatformIndex
    .byte $ff
    .byte $ff
    .byte kPipe4PlatformIndex
    .byte kPipe4PlatformIndex
    .byte $ff
    .byte kPipe5PlatformIndex
_WaterPlatformIndex_u8_arr:
    .byte kWestWaterPlatformIndex
    .byte $ff
    .byte kCenterWaterPlatformIndex
    .byte $ff
    .byte kCenterWaterPlatformIndex
    .byte $ff
    .byte $ff
    .byte kCenterWaterPlatformIndex
    .byte kCenterWaterPlatformIndex
    .byte $ff
    .byte kEastWaterPlatformIndex
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Sewer_NorthMultiplexer_Reset
    lda #0
    sta Ram_MachineState1_byte_arr + kMultiplexerMachineIndex  ; J register
    ldx #kNumValves - 1
    @loop:
    sta Zp_RoomState + sState::ValveGoal_u8_arr, x
    dex
    .assert kNumValves <= $80, error
    bpl @loop
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_SewerNorthMultiplexer_WriteReg
    cpx #$d
    blt _WriteL
    beq _WriteR
    cpx #$e
    beq _WriteJ
_WriteV:
    ldx Ram_MachineState1_byte_arr + kMultiplexerMachineIndex  ; J register
    cmp Zp_RoomState + sState::ValveGoal_u8_arr, x
    beq _Return
    sta Zp_RoomState + sState::ValveGoal_u8_arr, x
    jmp FuncA_Machine_StartWorking
_WriteJ:
    sta Ram_MachineState1_byte_arr + kMultiplexerMachineIndex  ; J register
_Return:
    rts
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_SewerNorthMultiplexer_Tick
    ldy #0  ; num valves moved
    ldx #kNumValves - 1
    @loop:
    lda Zp_RoomState + sState::ValveGoal_u8_arr, x
    mul #kBoilerValveAnimSlowdown
    cmp Zp_RoomState + sState::ValveAngle_u8_arr, x
    beq @continue
    iny  ; num valves moved
    blt @decrement
    @increment:
    inc Zp_RoomState + sState::ValveAngle_u8_arr, x
    bne @continue  ; unconditional
    @decrement:
    dec Zp_RoomState + sState::ValveAngle_u8_arr, x
    @continue:
    dex
    .assert kNumValves <= $80, error
    bpl @loop
    tya  ; num valves moved
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;
