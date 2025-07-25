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
.INCLUDE "../audio.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/carriage.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../music.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncA_Machine_CarriageTryMove
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawCarriageMachine
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_ProgressFlags_arr
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The device index for the upgrade in this room.
kUpgradeDeviceIndex = 0

;;; The eFlag value for the upgrade in this room.
kUpgradeFlag = eFlag::UpgradeOpTil

;;; The machine index for the TempleFoyerCarriage machine in this room.
kCarriageMachineIndex = 0

;;; The platform index for the TempleFoyerCarriage machine in this room.
kCarriagePlatformIndex = 0

;;; The initial and maximum permitted horizontal and vertical goal values for
;;; the TempleFoyerCarriage machine.
kCarriageInitGoalX = 9
kCarriageMaxGoalX = 9
kCarriageInitGoalY = 0
kCarriageMaxGoalY = 9

;;; The minimum, initial, and maximum X-positions for the left side of the
;;; carriage platform.
.LINECONT +
kCarriageMinPlatformLeft = $00d0
kCarriageInitPlatformLeft = \
    kCarriageMinPlatformLeft + kCarriageInitGoalX * kBlockWidthPx
kCarriageMaxPlatformLeft = \
    kCarriageMinPlatformLeft + kCarriageMaxGoalX * kBlockWidthPx
.LINECONT -

;;; The maximum, initial, and minumum Y-positions for the top of the carriage
;;; platform.
.LINECONT +
kCarriageMaxPlatformTop = $0120
kCarriageInitPlatformTop = \
    kCarriageMaxPlatformTop - kCarriageInitGoalY * kBlockHeightPx
kCarriageMinPlatformTop = \
    kCarriageMaxPlatformTop - kCarriageMaxGoalY * kBlockHeightPx
.LINECONT -

;;;=========================================================================;;;

;;; Enum for the steps of the TempleFoyerCarriage machine's reset sequence
;;; (listed in reverse order).
.ENUM eResetSeq
    BottomRight = 0  ; last step: move to bottom-right position
    Middle           ; move up/down (if necessary), then move right to X=5
.ENDENUM

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; Which step of its reset sequence the TempleFoyerCarriage machine is on.
    CarriageReset_eResetSeq .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Foyer_sRoom
.PROC DataC_Temple_Foyer_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $0108
    d_byte Flags_bRoom, bRoom::Tall | eArea::Temple
    d_byte MinimapStartRow_u8, 6
    d_byte MinimapStartCol_u8, 3
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
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
    d_addr Enter_func_ptr, FuncC_Temple_Foyer_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/temple_foyer.room"
    .assert * - :- = 34 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kCarriageMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::TempleFoyerCarriage
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Carriage
    d_word ScrollGoalX_u16, $00b8
    d_byte ScrollGoalY_u8, $90
    d_byte RegNames_u8_arr4, 0, 0, "X", "Y"
    d_byte MainPlatform_u8, kCarriagePlatformIndex
    d_addr Init_func_ptr, FuncC_Temple_FoyerCarriage_Init
    d_addr ReadReg_func_ptr, FuncC_Temple_FoyerCarriage_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_TempleFoyerCarriage_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Temple_FoyerCarriage_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCarriageMachine
    d_addr Reset_func_ptr, FuncC_Temple_FoyerCarriage_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCarriagePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kCarriageMachineWidthPx
    d_byte HeightPx_u8, kCarriageMachineHeightPx
    d_word Left_i16, kCarriageInitPlatformLeft
    d_word Top_i16, kCarriageInitPlatformTop
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $00f8
    d_word PosY_i16, $0068
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $0158
    d_word PosY_i16, $0068
    d_byte Param_byte, bObj::FlipV
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kUpgradeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Upgrade
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 28
    d_byte Target_byte, kUpgradeFlag
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 16
    d_byte BlockCol_u8, 26
    d_byte Target_byte, kCarriageMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 12
    d_byte Target_byte, eFlag::PaperManual1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::TempleNave
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CryptEscape
    d_byte SpawnBlock_u8, 21
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::TempleEntry
    d_byte SpawnBlock_u8, 20
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Temple_Foyer_EnterRoom
    ;; Clear the music flag, which tells the Temple music to transition from
    ;; "stately" to "upbeat".
    lda #bMusic::UsesFlag | 0
    sta Zp_Next_sAudioCtrl + sAudioCtrl::MusicFlag_bMusic
    ;; Remove the upgrade if it's already been collected.
    flag_bit Ram_ProgressFlags_arr, kUpgradeFlag
    beq @done
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kUpgradeDeviceIndex
    @done:
    rts
.ENDPROC

;;; @param A The register to read ($c-$f).
;;; @return A The value of the register (0-9).
.PROC FuncC_Temple_FoyerCarriage_ReadReg
    cmp #$f
    beq _ReadY
_ReadX:
    .assert kCarriageMinPlatformLeft - kTileWidthPx < $100, error
    lda Ram_PlatformLeft_i16_0_arr + kCarriagePlatformIndex
    sub #kCarriageMinPlatformLeft - kTileWidthPx
    .assert kCarriageMaxPlatformLeft - kCarriageMinPlatformLeft < $100, error
    div #kBlockWidthPx
    rts
_ReadY:
    .assert kCarriageMaxPlatformTop + kTileHeightPx >= $100, error
    lda #<(kCarriageMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kCarriagePlatformIndex
    .assert kCarriageMaxPlatformTop - kCarriageMinPlatformTop < $100, error
    div #kBlockWidthPx
    rts
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Temple_FoyerCarriage_Tick
_MoveVert:
    ldax #kCarriageMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ldax #kCarriageMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_ReachedGoal:
    lda Zp_RoomState + sState::CarriageReset_eResetSeq
    jeq FuncA_Machine_ReachedGoal
    fall FuncC_Temple_FoyerCarriage_Reset
.ENDPROC

.PROC FuncC_Temple_FoyerCarriage_Reset
    lda Ram_MachineGoalHorz_u8_arr + kCarriageMachineIndex
    cmp #5
    bge _MoveToBottomRight
    cmp #4
    blt _MoveVertBeforeMiddle
    lda Ram_MachineGoalVert_u8_arr + kCarriageMachineIndex
    cmp #9
    blt _MoveStraightToMiddle
_MoveVertBeforeMiddle:
    lda #8
    sta Ram_MachineGoalVert_u8_arr + kCarriageMachineIndex
_MoveStraightToMiddle:
    lda #5
    sta Ram_MachineGoalHorz_u8_arr + kCarriageMachineIndex
    lda #eResetSeq::Middle
    sta Zp_RoomState + sState::CarriageReset_eResetSeq
    rts
_MoveToBottomRight:
    lda #eResetSeq::BottomRight
    sta Zp_RoomState + sState::CarriageReset_eResetSeq
    fall FuncC_Temple_FoyerCarriage_Init
.ENDPROC

.PROC FuncC_Temple_FoyerCarriage_Init
    lda #kCarriageInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kCarriageMachineIndex
    lda #kCarriageInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kCarriageMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_TempleFoyerCarriage_TryMove
    lda #kCarriageMaxGoalX  ; param: max goal horz
    ldy #kCarriageMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_CarriageTryMove
.ENDPROC

;;;=========================================================================;;;
