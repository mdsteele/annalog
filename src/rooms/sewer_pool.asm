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
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_DrawMultiplexerMachine
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjSewer
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The number of movable platforms for the SewerPoolMultiplexer machine.
.DEFINE kMultiplexerNumPlatforms 5

;;; The machine index for the SewerPoolMultiplexer machine.
kMultiplexerMachineIndex = 0
;;; The main platform index for the SewerPoolMultiplexer machine.
kMultiplexerMainPlatformIndex = kMultiplexerNumPlatforms

;;; The initial and maximum vertical goal value for the multiplexer's movable
;;; platforms.
kMultiplexerInitGoalY = 5
kMultiplexerMaxGoalY = 9

;;; The maximum and initial room pixel Y-positions for the top of the
;;; multiplexer's movable platforms.
.LINECONT +
kMultiplexerMaxPlatformTop = $00b0
kMultiplexerInitPlatformTop = \
    kMultiplexerMaxPlatformTop - kMultiplexerInitGoalY * kBlockHeightPx
.LINECONT -

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The vertical goal value for each movable platform of the multiplexer
    ;; machine, by platform index.
    MultiplexerGoalVert_u8_arr .res kMultiplexerNumPlatforms
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Sewer"

.EXPORT DataC_Sewer_Pool_sRoom
.PROC DataC_Sewer_Pool_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0110
    d_byte Flags_bRoom, eArea::Sewer
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 17
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
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/sewer_pool.room"
    .assert * - :- = 34 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kMultiplexerMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::SewerPoolMultiplexer
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Multiplexer
    d_word ScrollGoalX_u16, $0110
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "J", 0, 0, "Y"
    d_byte MainPlatform_u8, kMultiplexerMainPlatformIndex
    d_addr Init_func_ptr, FuncC_Sewer_PoolMultiplexer_InitReset
    d_addr ReadReg_func_ptr, FuncC_Sewer_PoolMultiplexer_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Sewer_PoolMultiplexer_WriteReg
    d_addr TryMove_func_ptr, FuncC_Sewer_PoolMultiplexer_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Sewer_PoolMultiplexer_Tick
    d_addr Draw_func_ptr, FuncA_Objects_SewerPoolMultiplexer_Draw
    d_addr Reset_func_ptr, FuncC_Sewer_PoolMultiplexer_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .repeat kMultiplexerNumPlatforms, index
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16, $0170 + $10 * index
    d_word Top_i16, kMultiplexerInitPlatformTop
    D_END
    .endrepeat
    .assert * - :- = kMultiplexerMainPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $01c0
    d_word Top_i16,   $0060
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $190
    d_byte HeightPx_u8,  $20
    d_word Left_i16,   $0040
    d_word Top_i16,    $00c4
    D_END
    ;; Terrain spikes:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $190
    d_byte HeightPx_u8,  $08
    d_word Left_i16,   $0040
    d_word Top_i16,    $00de
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0040
    d_word Top_i16,   $00d6
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00a0
    d_word Top_i16,   $00d6
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0130
    d_word Top_i16,   $00d6
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
    d_byte BlockCol_u8, 29
    d_byte Target_byte, kMultiplexerMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::SewerPool  ; TODO FactoryEast
    d_byte SpawnBlock_u8, 8
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::SewerPool  ; TODO SewerSouth
    d_byte SpawnBlock_u8, 5
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Returns the platform index currently selected by the J register of the
;;; SewerPoolMultiplexer machine.
;;; @return Y The platform index.
.PROC FuncC_Sewer_PoolMultiplexer_GetPlatformIndex
    lda Ram_MachineGoalHorz_u8_arr + kMultiplexerMachineIndex  ; J register
    cmp #kMultiplexerNumPlatforms
    blt @setIndex
    sbc #kMultiplexerNumPlatforms  ; carry is already set
    @setIndex:
    tay
    rts
.ENDPROC

.PROC FuncC_Sewer_PoolMultiplexer_InitReset
    lda #kMultiplexerInitGoalY
    ldx #kMultiplexerNumPlatforms - 1
    @loop:
    sta Zp_RoomState + sState::MultiplexerGoalVert_u8_arr, x
    dex
    bpl @loop
    inx  ; now X is zero
    stx Ram_MachineGoalHorz_u8_arr + kMultiplexerMachineIndex  ; J register
    rts
.ENDPROC

.PROC FuncC_Sewer_PoolMultiplexer_ReadReg
    cmp #$f
    beq _ReadY
_ReadJ:
    lda Ram_MachineGoalHorz_u8_arr + kMultiplexerMachineIndex  ; J register
    rts
_ReadY:
    jsr FuncC_Sewer_PoolMultiplexer_GetPlatformIndex  ; returns Y
    lda #kMultiplexerMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr, y
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Sewer_PoolMultiplexer_WriteReg
    sta Ram_MachineGoalHorz_u8_arr + kMultiplexerMachineIndex  ; J register
    rts
.ENDPROC

.PROC FuncC_Sewer_PoolMultiplexer_TryMove
    jsr FuncC_Sewer_PoolMultiplexer_GetPlatformIndex  ; returns Y
    lda Zp_RoomState + sState::MultiplexerGoalVert_u8_arr, y
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    cmp #kMultiplexerMaxGoalY
    bge @error
    tax  ; goal vert
    inx
    bne @success  ; unconditional
    @moveDown:
    tax  ; goal vert
    beq @error
    dex
    @success:
    txa
    sta Zp_RoomState + sState::MultiplexerGoalVert_u8_arr, y
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncC_Sewer_PoolMultiplexer_Tick
    lda #0
    pha  ; num platforms done
    ldx #kMultiplexerNumPlatforms - 1
_Loop:
    ;; Calculate the desired Y-position for the top edge of the platform, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    lda Zp_RoomState + sState::MultiplexerGoalVert_u8_arr, x
    mul #kBlockHeightPx
    sta T0  ; goal delta
    lda #<kMultiplexerMaxPlatformTop
    sub T0  ; goal delta
    sta Zp_PointY_i16 + 0
    lda #>kMultiplexerMaxPlatformTop
    sbc #0
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the machine (faster if resetting).
    ldy Ram_MachineStatus_eMachine_arr + kMultiplexerMachineIndex
    lda #2
    cpy #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the machine vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; preserves X; returns Z
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

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_SewerPoolMultiplexer_Draw
    ldx #kMultiplexerNumPlatforms  ; param: num platforms
    jmp FuncA_Objects_DrawMultiplexerMachine
.ENDPROC

;;;=========================================================================;;;
