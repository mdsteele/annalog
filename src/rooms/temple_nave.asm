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
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/carriage.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Temple_sTileset
.IMPORT DataA_Text0_TempleNaveAlexBoost1_u8_arr
.IMPORT DataA_Text0_TempleNaveAlexBoost2_u8_arr
.IMPORT DataA_Text0_TempleNaveAlexStand_Part1_u8_arr
.IMPORT DataA_Text0_TempleNaveAlexStand_Part2_u8_arr
.IMPORT DataA_Text0_TempleNaveAlexStand_Part3_u8_arr
.IMPORT FuncA_Machine_CarriageTryMove
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawCarriageMachine
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0
;;; The talk device indices for Alex in this room.
kAlexStandingDeviceIndexRight = 0
kAlexStandingDeviceIndexLeft  = 1
kAlexBoostingDeviceIndex      = 2
;;; The platform index for Alex when he's giving Anna a boost.
kAlexBoostingPlatformIndex = 2
;;; The platform index for the crate that Alex leaves behind after you enter
;;; the crypt.
kCratePlatformIndex = 3

;;; The room pixel X-position that the Alex actor should be at when giving Anna
;;; a boost.
kAlexBoostingPositionX = $0068

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
.LINECONT +
kLowerCarriageMinPlatformLeft = $00c0
kLowerCarriageInitPlatformLeft = \
    kLowerCarriageMinPlatformLeft + kLowerCarriageInitGoalX * kBlockWidthPx
kLowerCarriageMaxPlatformLeft = \
    kLowerCarriageMinPlatformLeft + kLowerCarriageMaxGoalX * kBlockWidthPx
.LINECONT -

;;; The maximum, initial, and minumum Y-positions for the top of the
;;; TempleNaveLowerCarriage platform.
.LINECONT +
kLowerCarriageMaxPlatformTop = $0120
kLowerCarriageInitPlatformTop = \
    kLowerCarriageMaxPlatformTop - kLowerCarriageInitGoalY * kBlockHeightPx
kLowerCarriageMinPlatformTop = \
    kLowerCarriageMaxPlatformTop - kLowerCarriageMaxGoalY * kBlockHeightPx
.LINECONT -

;;; The initial and maximum permitted horizontal and vertical goal values for
;;; the TempleNaveUpperCarriage machine.
kUpperCarriageInitGoalX = 9
kUpperCarriageMaxGoalX = 9
kUpperCarriageInitGoalY = 0
kUpperCarriageMaxGoalY = 7

;;; The minimum, initial, and maximum X-positions for the left side of the
;;; TempleNaveUpperCarriage platform.
.LINECONT +
kUpperCarriageMinPlatformLeft = $00c0
kUpperCarriageInitPlatformLeft = \
    kUpperCarriageMinPlatformLeft + kUpperCarriageInitGoalX * kBlockWidthPx
kUpperCarriageMaxPlatformLeft = \
    kUpperCarriageMinPlatformLeft + kUpperCarriageMaxGoalX * kBlockWidthPx
.LINECONT -

;;; The maximum, initial, and minumum Y-positions for the top of the
;;; TempleNaveUpperCarriage platform.
.LINECONT +
kUpperCarriageMaxPlatformTop = $00a0
kUpperCarriageInitPlatformTop = \
    kUpperCarriageMaxPlatformTop - kUpperCarriageInitGoalY * kBlockHeightPx
kUpperCarriageMinPlatformTop = \
    kUpperCarriageMaxPlatformTop - kUpperCarriageMaxGoalY * kBlockHeightPx
.LINECONT -

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
    d_byte Flags_bRoom, bRoom::Tall | eArea::Temple
    d_byte MinimapStartRow_u8, 5
    d_byte MinimapStartCol_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Temple_Nave_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Temple_Nave_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/temple_nave.room"
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
    d_addr TryMove_func_ptr, FuncA_Machine_TempleNaveLowerCarriage_TryMove
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
    d_addr TryMove_func_ptr, FuncA_Machine_TempleNaveUpperCarriage_TryMove
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
    d_word WidthPx_u16, kCarriageMachineWidthPx
    d_byte HeightPx_u8, kCarriageMachineHeightPx
    d_word Left_i16, kLowerCarriageInitPlatformLeft
    d_word Top_i16, kLowerCarriageInitPlatformTop
    D_END
    .assert * - :- = kUpperCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kCarriageMachineWidthPx
    d_byte HeightPx_u8, kCarriageMachineHeightPx
    d_word Left_i16, kUpperCarriageInitPlatformLeft
    d_word Top_i16, kUpperCarriageInitPlatformTop
    D_END
    .assert * - :- = kAlexBoostingPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $09
    d_byte HeightPx_u8, $0d
    d_word Left_i16,  $0064
    d_word Top_i16,   $0153
    D_END
    .assert * - :- = kCratePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0067
    d_word Top_i16,   $0150
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
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0090
    d_word PosY_i16, $0158
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $0060
    d_word PosY_i16, $0078
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kAlexStandingDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; becomes TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eDialog::TempleNaveAlexStand
    D_END
    .assert * - :- = kAlexStandingDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; becomes TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eDialog::TempleNaveAlexStand
    D_END
    .assert * - :- = kAlexBoostingDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; becomes TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eDialog::TempleNaveAlexBoost2
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 14
    d_byte Target_byte, kUpperCarriageMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 20
    d_byte Target_byte, kLowerCarriageMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::TempleWest
    d_byte SpawnBlock_u8, 3
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::TemplePit
    d_byte SpawnBlock_u8, 21
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::TempleFlower
    d_byte SpawnBlock_u8, 3
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::TempleFoyer
    d_byte SpawnBlock_u8, 21
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Temple_Nave_EnterRoom
_Crate:
    ;; Once Anna visits the crypt, remove Alex and leave a crate behind.
    flag_bit Sram_ProgressFlags_arr, eFlag::CryptLandingDroppedIn
    beq @noCrate
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kCratePlatformIndex
    .assert ePlatform::Solid <> 0, error
    bne _RemoveAlex  ; unconditional
    @noCrate:
_AlexBoosting:
    ;; If Anna has already talked to Alex, put him in the boosting position.
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleNaveTalkedToAlex
    beq @notBoosting
    ldya #kAlexBoostingPositionX
    sty Ram_ActorPosX_i16_1_arr + kAlexActorIndex
    sta Ram_ActorPosX_i16_0_arr + kAlexActorIndex
    lda #eNpcChild::AlexBoosting
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    lda #$ff
    sta Ram_ActorState2_byte_arr + kAlexActorIndex
    lda #eDevice::TalkLeft
    sta Ram_DeviceType_eDevice_arr + kAlexBoostingDeviceIndex
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kAlexBoostingPlatformIndex
    rts
    @notBoosting:
_AlexStanding:
    ;; If Alex is waiting for Anna, leave him in his standing position.
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleNaveAlexWaiting
    beq @notWaiting
    lda #eDevice::TalkLeft
    sta Ram_DeviceType_eDevice_arr + kAlexStandingDeviceIndexLeft
    lda #eDevice::TalkRight
    sta Ram_DeviceType_eDevice_arr + kAlexStandingDeviceIndexRight
    rts
    @notWaiting:
_RemoveAlex:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    rts
.ENDPROC

.PROC FuncC_Temple_Nave_DrawRoom
    ldx #kCratePlatformIndex
    jmp FuncA_Objects_DrawCratePlatform
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
    .linecont +
    .assert kLowerCarriageMaxPlatformLeft - \
            kLowerCarriageMinPlatformLeft < $100, error
    .linecont -
    div #kBlockWidthPx
    rts
_ReadY:
    .assert kLowerCarriageMaxPlatformTop + kTileHeightPx >= $100, error
    lda #<(kLowerCarriageMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kLowerCarriagePlatformIndex
    .linecont +
    .assert kLowerCarriageMaxPlatformTop - \
            kLowerCarriageMinPlatformTop < $100, error
    .linecont -
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Temple_NaveLowerCarriage_Tick
_MoveVert:
    ldax #kLowerCarriageMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ldax #kLowerCarriageMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_ReachedGoal:
    lda Zp_RoomState + sState::LowerCarriageReset_eLowerResetSeq
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
    sta Zp_RoomState + sState::LowerCarriageReset_eLowerResetSeq
    rts
_MoveToTopLeftish:
    lda #2
    sta Ram_MachineGoalHorz_u8_arr + kLowerCarriageMachineIndex
    lda #eLowerResetSeq::TopLeftish
    sta Zp_RoomState + sState::LowerCarriageReset_eLowerResetSeq
    rts
_MoveToBottomLeft:
    lda #eLowerResetSeq::BottomLeft
    sta Zp_RoomState + sState::LowerCarriageReset_eLowerResetSeq
    fall FuncC_Temple_NaveLowerCarriage_Init
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
    .linecont +
    .assert kUpperCarriageMaxPlatformLeft - \
            kUpperCarriageMinPlatformLeft < $100, error
    .linecont -
    div #kBlockWidthPx
    rts
_ReadY:
    .assert kUpperCarriageMaxPlatformTop + kTileHeightPx < $100, error
    lda #kUpperCarriageMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kUpperCarriagePlatformIndex
    .linecont +
    .assert kUpperCarriageMaxPlatformTop - \
            kUpperCarriageMinPlatformTop < $100, error
    .linecont -
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Temple_NaveUpperCarriage_Tick
_MoveVert:
    ldax #kUpperCarriageMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ldax #kUpperCarriageMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_ReachedGoal:
    lda Zp_RoomState + sState::UpperCarriageReset_eUpperResetSeq
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
    sta Zp_RoomState + sState::UpperCarriageReset_eUpperResetSeq
    rts
_MoveToUpperLeft:
    lda #6
    sta Ram_MachineGoalVert_u8_arr + kUpperCarriageMachineIndex
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kUpperCarriageMachineIndex
    lda #eUpperResetSeq::UpperLeft
    sta Zp_RoomState + sState::UpperCarriageReset_eUpperResetSeq
    rts
_MoveToBottomRight:
    lda #eUpperResetSeq::BottomRight
    sta Zp_RoomState + sState::UpperCarriageReset_eUpperResetSeq
    fall FuncC_Temple_NaveUpperCarriage_Init
.ENDPROC

.PROC FuncC_Temple_NaveUpperCarriage_Init
    lda #kUpperCarriageInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kUpperCarriageMachineIndex
    lda #kUpperCarriageInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kUpperCarriageMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_TempleNaveLowerCarriage_TryMove
    lda #kLowerCarriageMaxGoalX  ; param: max goal horz
    ldy #kLowerCarriageMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_CarriageTryMove
.ENDPROC

.PROC FuncA_Machine_TempleNaveUpperCarriage_TryMove
    lda #kUpperCarriageMaxGoalX  ; param: max goal horz
    ldy #kUpperCarriageMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_CarriageTryMove
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_TempleNaveAlexBoosting_sCutscene
.PROC DataA_Cutscene_TempleNaveAlexBoosting_sCutscene
    ;; Animate Alex and Anna looking towards the machinery as the camera slowly
    ;; pans.
    act_SetActorState2 kAlexActorIndex, $ff
    act_SetActorFlags kAlexActorIndex, 0
    act_SetAvatarFlags kPaletteObjAvatarNormal
    act_ScrollSlowX $0074
    act_WaitFrames 90
    ;; Make Alex talk more, then walk over to his boosting position.
    act_RunDialog eDialog::TempleNaveAlexBoost1
    act_MoveNpcAlexWalk kAlexActorIndex, kAlexBoostingPositionX
    ;; Animate Alex turning around, crouching down, and raising his arms to
    ;; give Anna a boost.
    act_SetActorFlags kAlexActorIndex, 0
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 50
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexKneeling
    act_WaitFrames 20
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexBoosting
    act_WaitFrames 30
    act_CallFunc _SetUpBoostingPlatform
    act_RunDialog eDialog::TempleNaveAlexBoost2
    act_ContinueExploring
_SetUpBoostingPlatform:
    ;; Set up the device/platform for Alex giving Anna a boost.
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kAlexStandingDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kAlexStandingDeviceIndexRight
    lda #eDevice::TalkLeft
    sta Ram_DeviceType_eDevice_arr + kAlexBoostingDeviceIndex
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kAlexBoostingPlatformIndex
    ;; Set the flag indicating that Alex is now in the boosting position.
    ldx #eFlag::TempleNaveTalkedToAlex  ; param: flag
    jmp Func_SetFlag
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TempleNaveAlexStand_sDialog
.PROC DataA_Dialog_TempleNaveAlexStand_sDialog
    dlg_Text ChildAlex, DataA_Text0_TempleNaveAlexStand_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text0_TempleNaveAlexStand_Part2_u8_arr
    dlg_Text ChildAlex, DataA_Text0_TempleNaveAlexStand_Part3_u8_arr
    dlg_Cutscene eCutscene::TempleNaveAlexBoosting
.ENDPROC

.EXPORT DataA_Dialog_TempleNaveAlexBoost1_sDialog
.PROC DataA_Dialog_TempleNaveAlexBoost1_sDialog
    dlg_Text ChildAlex, DataA_Text0_TempleNaveAlexBoost1_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TempleNaveAlexBoost2_sDialog
.PROC DataA_Dialog_TempleNaveAlexBoost2_sDialog
    dlg_Text ChildAlex, DataA_Text0_TempleNaveAlexBoost2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
