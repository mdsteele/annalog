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
.INCLUDE "../actors/toddler.inc"
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT FuncA_Objects_DrawStepstonePlatform
.IMPORT FuncC_Prison_DrawGatePlatform
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjPrison
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0

;;; Dialog indices for the kids in this room.
kAlexCellDialogIndex = 0
kAlexFreeDialogIndex = 1
kBrunoDialogIndex    = 2
kMarieDialogIndex    = 3
kNoraDialogIndex     = 4

;;; Device indices for various talk devices in this room.
kAlexCellDeviceIndex      = 0
kAlexFreeRightDeviceIndex = 1
kAlexFreeLeftDeviceIndex  = 2
kFirstNonTalkDeviceIndex  = 9

;;; The platform index for the stepstone that appears after talking to Alex.
kStepstonePlatformIndex = 1

;;; The platform index for the prison gate in this room.
kGatePlatformIndex = 0

;;; The initial and minimum room pixel Y-positions for the top of the prison
;;; gate platform.
kGatePlatformInitTop = $00a0
kGatePlatformMinTop  = kGatePlatformInitTop - $1d

;;; The room pixel X-position that the Alex actor should walk to after the
;;; prison gate is opened.
kAlexFreePositionX = $0090

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the lever in this room.
    GateLever_u1 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

.EXPORT DataC_Prison_Upper_sRoom
.PROC DataC_Prison_Upper_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $00
    d_word MaxScrollX_u16, $0100
    d_byte Flags_bRoom, eArea::Prison
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 5
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPrison)
    d_addr Tick_func_ptr, FuncC_Prison_Upper_TickRoom
    d_addr Draw_func_ptr, FuncC_Prison_Upper_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    .linecont +
    d_addr Dialogs_sDialog_ptr_arr_ptr, \
           DataA_Dialog_PrisonUpper_sDialog_ptr_arr
    .linecont -
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, FuncC_Prison_Upper_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/prison_upper.room"
    .assert * - :- = 33 * 16, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kGatePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $0d
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0063
    d_word Top_i16, kGatePlatformInitTop
    D_END
    ;; Stepping stone on right side of eastern cell:
    .assert * - :- = kStepstonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $06
    d_word Left_i16,  $0199
    d_word Top_i16,   $008c
    D_END
    ;; Ledge above Alex's cell:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0070
    d_word Top_i16,   $0078
    D_END
    ;; Ledge to the left of upper cell:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0078
    D_END
    ;; Floor step in front of eastern passage:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01b0
    d_word Top_i16,   $00b8
    D_END
    ;; Ceiling corner above eastern passage:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $01d8
    d_word Top_i16,   $0080
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0050
    d_word PosY_i16, $00b8
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0110
    d_word PosY_i16, $0078
    d_byte Param_byte, bNpcChild::Pri | eNpcChild::PonytailStanding
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcToddler
    d_word PosX_i16, $0128
    d_word PosY_i16, $0078
    d_byte Param_byte, bNpcToddler::Pri | 17
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0160
    d_word PosY_i16, $00b8
    d_byte Param_byte, bNpcChild::Pri | eNpcChild::CrewcutStanding
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0190
    d_word PosY_i16, $00b8
    d_byte Param_byte, bNpcChild::Pri | eNpcChild::BobcutStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kAlexCellDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 7
    d_byte Target_u8, kAlexCellDialogIndex
    D_END
    .assert * - :- = kAlexFreeRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; becomes TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 8
    d_byte Target_u8, kAlexFreeDialogIndex
    D_END
    .assert * - :- = kAlexFreeLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; becomes TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 9
    d_byte Target_u8, kAlexFreeDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 16
    d_byte Target_u8, kNoraDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 17
    d_byte Target_u8, kNoraDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 21
    d_byte Target_u8, kBrunoDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 22
    d_byte Target_u8, kBrunoDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 24
    d_byte Target_u8, kMarieDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 25
    d_byte Target_u8, kMarieDialogIndex
    D_END
    .assert * - :- = kFirstNonTalkDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 4
    d_byte Target_u8, sState::GateLever_u1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonCrossroad
    d_byte SpawnBlock_u8, 10
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Prison_Upper_InitRoom
    ;; If the kids have already been freed, remove them (and also open the gate
    ;; and place the stepstone).
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    bne _RemoveKids
    ;; Otherwise, if the gate has already been opened, move Alex and open the
    ;; gate.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperGateOpened
    bne _MoveAlex
    ;; Otherwise, if Anna has already talked to Alex, place the stepstone.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperTalkedToAlex
    bne _PlaceStepstone
    rts
_RemoveKids:
    ;; Remove talk devices.
    lda #eDevice::None
    ldx #kFirstNonTalkDeviceIndex - 1
    @deviceLoop:
    sta Ram_DeviceType_eDevice_arr, x
    dex
    .assert kFirstNonTalkDeviceIndex < $80, error
    bpl @deviceLoop
    ;; Remove actors.
    .assert eActor::None = eDevice::None, error
    ldx #kMaxActors - 1
    @actorLoop:
    sta Ram_ActorType_eActor_arr, x
    dex
    .assert kMaxActors < $80, error
    bpl @actorLoop
    bmi _OpenGate  ; unconditional
_MoveAlex:
    ldya #kAlexFreePositionX
    sty Ram_ActorPosX_i16_1_arr + kAlexActorIndex
    sta Ram_ActorPosX_i16_0_arr + kAlexActorIndex
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kAlexCellDeviceIndex
    lda #eDevice::TalkRight
    sta Ram_DeviceType_eDevice_arr + kAlexFreeRightDeviceIndex
    lda #eDevice::TalkLeft
    sta Ram_DeviceType_eDevice_arr + kAlexFreeLeftDeviceIndex
_OpenGate:
    lda #1
    sta Ram_RoomState + sState::GateLever_u1
    ldx #kGatePlatformIndex  ; param: platform index
    lda #<(kGatePlatformMinTop - kGatePlatformInitTop)  ; param: delta
    jsr Func_MovePlatformVert
_PlaceStepstone:
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kStepstonePlatformIndex
    rts
.ENDPROC

.PROC FuncC_Prison_Upper_TickRoom
    ;; TODO: once gate is open, walk Alex out of the cell
    ;; TODO: once Alex is done walking, place his new talk devices
_CheckLever:
    ;; Check if the lever is flipped.
    lda Ram_RoomState + sState::GateLever_u1
    beq @done
    ;; If so, mark the gate as open...
    ldx #eFlag::PrisonUpperGateOpened
    jsr Func_SetFlag
    ;; ...and remove Alex's cell talk device.
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr + kAlexCellDeviceIndex
    @done:
_OpenGate:
    ;; If the gate has been opened, move it up into its open position.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperGateOpened
    beq @done
    ldax #kGatePlatformMinTop
    stax Zp_PointY_i16
    lda #1  ; param: move speed
    ldx #kGatePlatformIndex  ; param: platform index
    jmp Func_MovePlatformTopTowardPointY
    @done:
    rts
.ENDPROC

;;; Draw function for the PrisonUpper room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Prison_Upper_DrawRoom
    ldx #kStepstonePlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawStepstonePlatform
    ldx #kGatePlatformIndex  ; param: platform index
    jmp FuncC_Prison_DrawGatePlatform
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the PrisonUpper room.
.PROC DataA_Dialog_PrisonUpper_sDialog_ptr_arr
:   .assert * - :- = kAlexCellDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_PrisonUpper_AlexCell_sDialog
    .assert * - :- = kAlexFreeDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_PrisonUpper_AlexFree_sDialog
    .assert * - :- = kBrunoDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_PrisonUpper_Bruno_sDialog
    .assert * - :- = kMarieDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_PrisonUpper_Marie_sDialog
    .assert * - :- = kNoraDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_PrisonUpper_Nora_sDialog
.ENDPROC

.PROC DataA_Dialog_PrisonUpper_AlexCell_sDialog
    .word ePortrait::Alex
    .byte "Anna! Thank goodness$"
    .byte "you're here! The orcs$"
    .byte "threw us in here, but$"
    .byte "they're gone now.#"
    .addr _SetFlagFunc
_SetFlagFunc:
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kStepstonePlatformIndex
    ldx #eFlag::PrisonUpperTalkedToAlex  ; param: flag
    jsr Func_SetFlag
    ldya #_GetDoorOpen_sDialog
    rts
_GetDoorOpen_sDialog:
    .word ePortrait::Alex
    .byte "See if you can find a$"
    .byte "way to get this door$"
    .byte "open.#"
    .word ePortrait::Done
.ENDPROC

.PROC DataA_Dialog_PrisonUpper_AlexFree_sDialog
    .word ePortrait::Alex
    .byte "Thanks! That door was$"
    .byte "too heavy, but I think$"
    .byte "I can pick the locks$"
    .byte "on the other cells.#"
    .word ePortrait::Alex
    .byte "I'll let the others$"
    .byte "out, then scout ahead.$"
    .byte "Be right back.#"
    .addr _CutsceneFunc
_CutsceneFunc:
    ;; TODO: cutscene for Alex to free the other kids
    ldx #eFlag::PrisonUpperFreedKids  ; param: flag
    jsr Func_SetFlag
    ldya #_Finish_sDialog
    rts
_Finish_sDialog:
    .word ePortrait::Alex
    .byte "Bad news: the passage$"
    .byte "to the surface has$"
    .byte "has collapsed.#"
    ;; TODO: rest of cutscene/dialog
    .word ePortrait::Done
.ENDPROC

.PROC DataA_Dialog_PrisonUpper_Bruno_sDialog
    .word ePortrait::Man  ; TODO
    .byte "Are the adults OK?#"
    .word ePortrait::Done
.ENDPROC

.PROC DataA_Dialog_PrisonUpper_Marie_sDialog
    .addr _InitialFunc
_InitialFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperTalkedToAlex
    bne @stepstone
    ldya #_GoTalkToAlex_sDialog
    rts
    @stepstone:
    ldya #_Stepstone_sDialog
    rts
_GoTalkToAlex_sDialog:
    .word ePortrait::Marie
    .byte "It's Anna! Quick, go$"
    .byte "talk to Alex! He's in$"
    .byte "the cell up ahead.#"
    .word ePortrait::Done
_Stepstone_sDialog:
    .word ePortrait::Marie
    .byte "Do you see that one$"
    .byte "brick sticking out up$"
    .byte "there?#"
    .word ePortrait::Marie
    .byte "I think you could$"
    .byte "stand on it if you're$"
    .byte "careful.#"
    .word ePortrait::Done
.ENDPROC

.PROC DataA_Dialog_PrisonUpper_Nora_sDialog
    .word ePortrait::Girl
    .byte "My sister STILL keeps$"
    .byte "peeing her pants!#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
