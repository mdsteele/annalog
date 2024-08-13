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
.INCLUDE "../machines/multiplexer.inc"
.INCLUDE "../machines/shared.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Sewer_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GetMultiplexerMoveSpeed
.IMPORT FuncA_Machine_MultiplexerWriteRegJ
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_DrawMultiplexerMachine
.IMPORT FuncA_Room_SewagePushAvatar
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjSewer
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The number of movable platforms for the SewerWestMultiplexer machine.
.DEFINE kMultiplexerNumPlatforms 10

;;; The machine index for the SewerWestMultiplexer machine.
kMultiplexerMachineIndex = 0
;;; The main platform index for the SewerWestMultiplexer machine.
kMultiplexerMainPlatformIndex = kMultiplexerNumPlatforms

;;; The initial horizontal goal value for the multiplexer's movable platforms.
kMultiplexerInitGoalX = 0

;;; The minimum and initial X-positions for the left side of the multiplexer's
;;; movable platforms.
.LINECONT +
kMultiplexerMinPlatformLeft = $0044
kMultiplexerInitPlatformLeft = \
    kMultiplexerMinPlatformLeft + kMultiplexerInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The horizontal goal value for each movable platform of the multiplexer
    ;; machine, by platform index.
    MultiplexerGoalHorz_u8_arr .res kMultiplexerNumPlatforms
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Sewer"

.EXPORT DataC_Sewer_West_sRoom
.PROC DataC_Sewer_West_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Sewer
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 19
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjSewer)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Sewer_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_SewagePushAvatar
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/sewer_west.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kMultiplexerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::SewerWestMultiplexer
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Multiplexer
    d_word ScrollGoalX_u16, $0010
    d_byte ScrollGoalY_u8, $c8
    d_byte RegNames_u8_arr4, "J", 0, "X", 0
    d_byte MainPlatform_u8, kMultiplexerMainPlatformIndex
    d_addr Init_func_ptr, FuncC_Sewer_WestMultiplexer_InitReset
    d_addr ReadReg_func_ptr, FuncC_Sewer_WestMultiplexer_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_SewerWestMultiplexer_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_SewerWestMultiplexer_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_SewerWestMultiplexer_Tick
    d_addr Draw_func_ptr, FuncC_Sewer_WestMultiplexer_Draw
    d_addr Reset_func_ptr, FuncC_Sewer_WestMultiplexer_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .repeat kMultiplexerNumPlatforms, index
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16, kMultiplexerInitPlatformLeft
    d_word Top_i16, $0130 - $10 * index
    D_END
    .endrepeat
    .assert * - :- = kMultiplexerMainPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0040
    d_word Top_i16,   $0150
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kMultiplexerMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::SewerPipe
    d_byte SpawnBlock_u8, 7
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::SewerNorth
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::CityDrain
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, $f0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Bottom | 0
    d_byte Destination_eRoom, eRoom::SewerSouth
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, $6b
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Sewer_WestMultiplexer_InitReset
    lda #0
    sta Ram_MachineState1_byte_arr + kMultiplexerMachineIndex  ; J register
    sta Ram_MachineState2_byte_arr + kMultiplexerMachineIndex  ; platform index
    .assert kMultiplexerInitGoalX = 0, error
    ldx #kMultiplexerNumPlatforms - 1
    @loop:
    sta Zp_RoomState + sState::MultiplexerGoalHorz_u8_arr, x
    dex
    bpl @loop
    rts
.ENDPROC

.PROC FuncC_Sewer_WestMultiplexer_ReadReg
    cmp #$e
    beq _ReadX
_ReadJ:
    lda Ram_MachineState1_byte_arr + kMultiplexerMachineIndex  ; J register
    rts
_ReadX:
    ldy Ram_MachineState2_byte_arr + kMultiplexerMachineIndex  ; platform index
    lda Ram_PlatformLeft_i16_0_arr, y
    sub #<(kMultiplexerMinPlatformLeft - kTileWidthPx)
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Sewer_WestMultiplexer_Draw
    ldx #kMultiplexerNumPlatforms  ; param: num platforms
    jmp FuncA_Objects_DrawMultiplexerMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncA_Machine_SewerWestMultiplexer_WriteReg
    ldx #kMultiplexerNumPlatforms  ; param: number of movable platforms
    jmp FuncA_Machine_MultiplexerWriteRegJ
.ENDPROC

.PROC FuncA_Machine_SewerWestMultiplexer_TryMove
    ldy Ram_MachineState1_byte_arr + kMultiplexerMachineIndex  ; J register
    lda Zp_RoomState + sState::MultiplexerGoalHorz_u8_arr, y
    cpx #eDir::Right
    bne @moveLeft
    @moveRight:
    cmp _MaxGoalX_u8_arr, y
    bge @error
    tax
    inx
    bne @success  ; unconditional
    @moveLeft:
    tax
    beq @error
    dex
    @success:
    txa
    sta Zp_RoomState + sState::MultiplexerGoalHorz_u8_arr, y
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
_MaxGoalX_u8_arr:
:   .byte 9, 9, 9, 9, 9, 2, 9, 9, 9, 9
    .assert * - :- = kMultiplexerNumPlatforms, error
.ENDPROC

.PROC FuncA_Machine_SewerWestMultiplexer_Tick
    lda #0
    pha  ; num platforms done
    ldx #kMultiplexerNumPlatforms - 1
_Loop:
    ;; Calculate the desired X-position for the left edge of the platform, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Zp_RoomState + sState::MultiplexerGoalHorz_u8_arr, x
    mul #kBlockWidthPx
    add #<kMultiplexerMinPlatformLeft
    sta Zp_PointX_i16 + 0
    lda #0
    adc #>kMultiplexerMinPlatformLeft
    sta Zp_PointX_i16 + 1
    ;; Move the machine horizontally, as necessary.
    jsr FuncA_Machine_GetMultiplexerMoveSpeed  ; preserves X, returns A
    jsr Func_MovePlatformLeftTowardPointX  ; preserves X; returns Z
    bne @moved
    pla  ; num platforms done
    add #1
    pha  ; num platforms done
    @moved:
    dex
    bpl _Loop
_Finish:
    pla  ; num platforms done
    cmp #kMultiplexerNumPlatforms
    bne @notReachedGoal
    jmp FuncA_Machine_ReachedGoal
    @notReachedGoal:
    rts
.ENDPROC

;;;=========================================================================;;;
