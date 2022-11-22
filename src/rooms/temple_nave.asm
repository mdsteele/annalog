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
.INCLUDE "../machines/shared.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_TempleAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_TempleAreaName_u8_arr
.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncA_Machine_CarriageMoveTowardGoalHorz
.IMPORT FuncA_Machine_CarriageMoveTowardGoalVert
.IMPORT FuncA_Machine_CarriageTryMove
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawCarriageMachine
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_RoomState

;;;=========================================================================;;;

;;; The machine indices for the TempleNaveLowerCarriage and
;;; TempleNaveUpperCarriage machines.
kLowerCarriageMachineIndex = 0
kUpperCarriageMachineIndex = 1

;;; The platform indices for the TempleNaveLowerCarriage and
;;; TempleNaveUpperCarriage machines.
kLowerCarriagePlatformIndex = 0
kUpperCarriagePlatformIndex = 1

;;; The initial and maximum permitted horizontal and vertical goal values for
;;; the TempleNaveLowerCarriage machine.
kLowerCarriageInitGoalX = 0
kLowerCarriageMaxGoalX = 9
kLowerCarriageInitGoalY = 0
kLowerCarriageMaxGoalY = 6

;;; The minimum, initial, and maximum X-positions for the left side of the
;;; TempleNaveLowerCarriage platform.
.LINECONT+
kLowerCarriageMinPlatformLeft = $00c0
kLowerCarriageInitPlatformLeft = \
    kLowerCarriageMinPlatformLeft + kLowerCarriageInitGoalX * kBlockWidthPx
kLowerCarriageMaxPlatformLeft = \
    kLowerCarriageMinPlatformLeft + kLowerCarriageMaxGoalX * kBlockWidthPx
.LINECONT-

;;; The maximum, initial, and minumum Y-positions for the top of the
;;; TempleNaveLowerCarriage platform.
.LINECONT+
kLowerCarriageMaxPlatformTop = $0120
kLowerCarriageInitPlatformTop = \
    kLowerCarriageMaxPlatformTop - kLowerCarriageInitGoalY * kBlockHeightPx
kLowerCarriageMinPlatformTop = \
    kLowerCarriageMaxPlatformTop - kLowerCarriageMaxGoalY * kBlockHeightPx
.LINECONT-

;;; The initial and maximum permitted horizontal and vertical goal values for
;;; the TempleNaveUpperCarriage machine.
kUpperCarriageInitGoalX = 9
kUpperCarriageMaxGoalX = 9
kUpperCarriageInitGoalY = 0
kUpperCarriageMaxGoalY = 7

;;; The minimum, initial, and maximum X-positions for the left side of the
;;; TempleNaveUpperCarriage platform.
.LINECONT+
kUpperCarriageMinPlatformLeft = $00c0
kUpperCarriageInitPlatformLeft = \
    kUpperCarriageMinPlatformLeft + kUpperCarriageInitGoalX * kBlockWidthPx
kUpperCarriageMaxPlatformLeft = \
    kUpperCarriageMinPlatformLeft + kUpperCarriageMaxGoalX * kBlockWidthPx
.LINECONT-

;;; The maximum, initial, and minumum Y-positions for the top of the
;;; TempleNaveUpperCarriage platform.
.LINECONT+
kUpperCarriageMaxPlatformTop = $00a0
kUpperCarriageInitPlatformTop = \
    kUpperCarriageMaxPlatformTop - kUpperCarriageInitGoalY * kBlockHeightPx
kUpperCarriageMinPlatformTop = \
    kUpperCarriageMaxPlatformTop - kUpperCarriageMaxGoalY * kBlockHeightPx
.LINECONT-

;;;=========================================================================;;;

;;; Enum for the steps of the TempleNaveLowerCarriage machine's reset sequence
;;; (listed in reverse order).
.ENUM eLowerResetSeq
    BottomLeft = 0  ; last step: move down to Y=0, then left to X=0
    MiddleRight     ; move down to Y=3, then right to X=9
    TopLeftish      ; move across top to X=2
.ENDENUM

;;; Enum for the steps of the TempleNaveUpperCarriage machine's reset sequence
;;; (listed in reverse order).
.ENUM eUpperResetSeq
    BottomRight = 0  ; last step: move down to Y=0, then right to X=9
    LeftEdge         ; move left to X=0
    UpperLeft        ; move up/down to Y=6, then left to X=0
.ENDENUM

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; Which step of its reset sequence the TempleNaveLowerCarriage is on.
    LowerCarriageReset_eLowerResetSeq .byte
    ;; Which step of its reset sequence the TempleNaveUpperCarriage is on.
    UpperCarriageReset_eUpperResetSeq .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Nave_sRoom
.PROC DataC_Temple_Nave_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0c
    d_word MaxScrollX_u16, $0110
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_TempleAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_TempleAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
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
:   .incbin "out/data/temple_nave.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLowerCarriageMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::TempleNaveLowerCarriage
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Carriage
    d_word ScrollGoalX_u16, $0098
    d_byte ScrollGoalY_u8, $a0
    d_byte RegNames_u8_arr4, 0, 0, "X", "Y"
    d_byte MainPlatform_u8, kLowerCarriagePlatformIndex
    d_addr Init_func_ptr, FuncC_Temple_NaveLowerCarriage_Init
    d_addr ReadReg_func_ptr, FuncC_Temple_NaveLowerCarriage_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Temple_NaveLowerCarriage_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Temple_NaveLowerCarriage_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCarriageMachine
    d_addr Reset_func_ptr, FuncC_Temple_NaveLowerCarriage_Reset
    D_END
    .assert * - :- = kUpperCarriageMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::TempleNaveUpperCarriage
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Carriage
    d_word ScrollGoalX_u16, $0098
    d_byte ScrollGoalY_u8, $18
    d_byte RegNames_u8_arr4, 0, 0, "X", "Y"
    d_byte MainPlatform_u8, kUpperCarriagePlatformIndex
    d_addr Init_func_ptr, FuncC_Temple_NaveUpperCarriage_Init
    d_addr ReadReg_func_ptr, FuncC_Temple_NaveUpperCarriage_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Temple_NaveUpperCarriage_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Temple_NaveUpperCarriage_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCarriageMachine
    d_addr Reset_func_ptr, FuncC_Temple_NaveUpperCarriage_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLowerCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16, kLowerCarriageInitPlatformLeft
    d_word Top_i16, kLowerCarriageInitPlatformTop
    D_END
    .assert * - :- = kUpperCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16, kUpperCarriageInitPlatformLeft
    d_word Top_i16, kUpperCarriageInitPlatformTop
    D_END
    ;; Upward spikes near upper carriage area:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $1e
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e1
    d_word Top_i16,   $004e
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0e
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0181
    d_word Top_i16,   $006e
    D_END
    ;; Downward spikes in lower carriage area:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $0e
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00d1
    d_word Top_i16,   $00da
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $2e
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0101
    d_word Top_i16,   $00da
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $1e
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0141
    d_word Top_i16,   $00da
    D_END
    ;; Spikes on western shelf:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $5f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0020
    d_word Top_i16,   $00ee
    D_END
    ;; Spikes on eastern shelf:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, $4f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01b1
    d_word Top_i16,   $00de
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_byte TileRow_u8, 15
    d_byte TileCol_u8, 12
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 14
    d_byte Target_u8, kUpperCarriageMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 20
    d_byte Target_u8, kLowerCarriageMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::TempleNave  ; TODO
    d_byte SpawnBlock_u8, 3
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::TemplePit
    d_byte SpawnBlock_u8, 21
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::TempleFlower
    d_byte SpawnBlock_u8, 3
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::TempleLobby
    d_byte SpawnBlock_u8, 21
    D_END
.ENDPROC

;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Temple_NaveLowerCarriage_ReadReg
    cmp #$f
    beq _ReadY
_ReadX:
    .assert kLowerCarriageMinPlatformLeft - kTileWidthPx < $100, error
    lda Ram_PlatformLeft_i16_0_arr + kLowerCarriagePlatformIndex
    sub #kLowerCarriageMinPlatformLeft - kTileWidthPx
    .linecont+
    .assert kLowerCarriageMaxPlatformLeft - \
            kLowerCarriageMinPlatformLeft < $100, error
    .linecont-
    div #kBlockWidthPx
    rts
_ReadY:
    .assert kLowerCarriageMaxPlatformTop + kTileHeightPx >= $100, error
    lda #<(kLowerCarriageMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kLowerCarriagePlatformIndex
    .linecont+
    .assert kLowerCarriageMaxPlatformTop - \
            kLowerCarriageMinPlatformTop < $100, error
    .linecont-
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Temple_NaveLowerCarriage_TryMove
    lda #kLowerCarriageMaxGoalX  ; param: max goal horz
    ldy #kLowerCarriageMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_CarriageTryMove
.ENDPROC

.PROC FuncC_Temple_NaveLowerCarriage_Tick
_MoveVert:
    ldax #kLowerCarriageMaxPlatformTop
    jsr FuncA_Machine_CarriageMoveTowardGoalVert  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ldax #kLowerCarriageMinPlatformLeft
    jsr FuncA_Machine_CarriageMoveTowardGoalHorz  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_ReachedGoal:
    lda Ram_RoomState + sState::LowerCarriageReset_eLowerResetSeq
    bne FuncC_Temple_NaveLowerCarriage_Reset
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

.PROC FuncC_Temple_NaveLowerCarriage_Reset
    ldy Ram_MachineGoalVert_u8_arr + kLowerCarriageMachineIndex
    ldx Ram_MachineGoalHorz_u8_arr + kLowerCarriageMachineIndex
    cpy #6
    blt @notTop
    cpx #2
    bne _MoveToTopLeftish
    @notTop:
    cpy #3
    blt _MoveToBottomLeft
    bne _MoveToMiddleRight
    cpx #9
    beq _MoveToBottomLeft
_MoveToMiddleRight:
    lda #9
    sta Ram_MachineGoalHorz_u8_arr + kLowerCarriageMachineIndex
    lda #3
    sta Ram_MachineGoalVert_u8_arr + kLowerCarriageMachineIndex
    lda #eLowerResetSeq::MiddleRight
    sta Ram_RoomState + sState::LowerCarriageReset_eLowerResetSeq
    rts
_MoveToTopLeftish:
    lda #2
    sta Ram_MachineGoalHorz_u8_arr + kLowerCarriageMachineIndex
    lda #eLowerResetSeq::TopLeftish
    sta Ram_RoomState + sState::LowerCarriageReset_eLowerResetSeq
    rts
_MoveToBottomLeft:
    lda #eLowerResetSeq::BottomLeft
    sta Ram_RoomState + sState::LowerCarriageReset_eLowerResetSeq
    .assert * = FuncC_Temple_NaveLowerCarriage_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Temple_NaveLowerCarriage_Init
    lda #kLowerCarriageInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLowerCarriageMachineIndex
    lda #kLowerCarriageInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLowerCarriageMachineIndex
    rts
.ENDPROC

;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Temple_NaveUpperCarriage_ReadReg
    cmp #$f
    beq _ReadY
_ReadX:
    .assert kUpperCarriageMinPlatformLeft - kTileWidthPx < $100, error
    lda Ram_PlatformLeft_i16_0_arr + kUpperCarriagePlatformIndex
    sub #kUpperCarriageMinPlatformLeft - kTileWidthPx
    .linecont+
    .assert kUpperCarriageMaxPlatformLeft - \
            kUpperCarriageMinPlatformLeft < $100, error
    .linecont-
    div #kBlockWidthPx
    rts
_ReadY:
    .assert kUpperCarriageMaxPlatformTop + kTileHeightPx < $100, error
    lda #kUpperCarriageMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kUpperCarriagePlatformIndex
    .linecont+
    .assert kUpperCarriageMaxPlatformTop - \
            kUpperCarriageMinPlatformTop < $100, error
    .linecont-
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Temple_NaveUpperCarriage_TryMove
    lda #kUpperCarriageMaxGoalX  ; param: max goal horz
    ldy #kUpperCarriageMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_CarriageTryMove
.ENDPROC

.PROC FuncC_Temple_NaveUpperCarriage_Tick
_MoveVert:
    ldax #kUpperCarriageMaxPlatformTop
    jsr FuncA_Machine_CarriageMoveTowardGoalVert  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ldax #kUpperCarriageMinPlatformLeft
    jsr FuncA_Machine_CarriageMoveTowardGoalHorz  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_ReachedGoal:
    lda Ram_RoomState + sState::UpperCarriageReset_eUpperResetSeq
    bne FuncC_Temple_NaveUpperCarriage_Reset
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

.PROC FuncC_Temple_NaveUpperCarriage_Reset
    ldx Ram_MachineGoalHorz_u8_arr + kUpperCarriageMachineIndex
    beq _MoveToBottomRight
    ldy Ram_MachineGoalVert_u8_arr + kUpperCarriageMachineIndex
    cpy #5
    bge _MoveToUpperLeft
    cpy #3
    blt _MoveToBottomRight
_MoveToLeftEdge:
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kUpperCarriageMachineIndex
    lda #eUpperResetSeq::LeftEdge
    sta Ram_RoomState + sState::UpperCarriageReset_eUpperResetSeq
    rts
_MoveToUpperLeft:
    lda #6
    sta Ram_MachineGoalVert_u8_arr + kUpperCarriageMachineIndex
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kUpperCarriageMachineIndex
    lda #eUpperResetSeq::UpperLeft
    sta Ram_RoomState + sState::UpperCarriageReset_eUpperResetSeq
    rts
_MoveToBottomRight:
    lda #eUpperResetSeq::BottomRight
    sta Ram_RoomState + sState::UpperCarriageReset_eUpperResetSeq
    .assert * = FuncC_Temple_NaveUpperCarriage_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Temple_NaveUpperCarriage_Init
    lda #kUpperCarriageInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kUpperCarriageMachineIndex
    lda #kUpperCarriageInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kUpperCarriageMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;
