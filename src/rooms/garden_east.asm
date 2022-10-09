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
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/bridge.inc"
.INCLUDE "../machines/cannon.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_GardenAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_GardenAreaName_u8_arr
.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Machine_BridgeTick
.IMPORT FuncA_Machine_BridgeTryMove
.IMPORT FuncA_Machine_CannonTick
.IMPORT FuncA_Machine_CannonTryAct
.IMPORT FuncA_Machine_CannonTryMove
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Objects_DrawBridgeMachine
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT Func_IsFlagSet
.IMPORT Func_MachineBridgeReadRegY
.IMPORT Func_MachineCannonReadRegY
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_DialogAnsweredYes_bool

;;;=========================================================================;;;

;;; The actor index for the mermaid in this room.
kMermaidActorIndex = 0
;;; The dialog index for the mermaid in this room.
kMermaidDialogIndex = 0
;;; The talk devices indices for the mermaid in this room.
kMermaidDeviceIndexLeft = 1
kMermaidDeviceIndexRight = 0

;;; The machine index for the GardenEastBridge machine.
kBridgeMachineIndex = 0

;;; The machine index for the GardenEastCannon machine.
kCannonMachineIndex = 1
;;; The platform index for the GardenEastCannon machine.
kCannonPlatformIndex = 0

;;; The number of movable segments in the drawbridge (i.e. NOT including the
;;; fixed segment).
.DEFINE kNumMovableBridgeSegments 6
;;; The platform index for the fixed bridge segment that the rest of the bridge
;;; pivots around.
kBridgePivotPlatformIndex = 1
;;; Room pixel position for the top-left corner of the fixed bridge segment.
kBridgePivotPosX = $0168
kBridgePivotPosY = $0080

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverBridge_u1 .byte
    LeverCannon_u1 .byte
.ENDSTRUCT

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_East_sRoom
.PROC DataC_Garden_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 8
    d_byte MinimapStartCol_u8, 10
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_GardenAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_GardenAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Dialogs_sDialog_ptr_arr_ptr, DataA_Dialog_GardenEast_sDialog_ptr_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, FuncC_Garden_EastBridge_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_east.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kBridgeMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenEastBridge
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $d0
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_byte MainPlatform_u8, kBridgePivotPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_EastBridge_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_BridgeTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncC_Garden_EastBridge_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenEastBridge_Draw
    d_addr Reset_func_ptr, FuncC_Garden_EastBridge_Reset
    D_END
    .assert * - :- = kCannonMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenEastCannon
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $b0
    d_byte ScrollGoalY_u8, $9f
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_byte MainPlatform_u8, kCannonPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_EastCannon_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CannonTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CannonTryAct
    d_addr Tick_func_ptr, FuncA_Machine_CannonTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCannonMachine
    d_addr Reset_func_ptr, FuncC_Garden_EastCannon_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCannonPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlockWidthPx
    d_byte HeightPx_u8, kBlockHeightPx
    d_word Left_i16, $00e0
    d_word Top_i16,  $0130
    D_END
    .assert * - :- = kBridgePivotPlatformIndex * .sizeof(sPlatform), error
    .repeat kNumMovableBridgeSegments + 1, index
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kTileWidthPx
    d_byte HeightPx_u8, kTileHeightPx
    d_word Left_i16, kBridgePivotPosX + kTileWidthPx * index
    d_word Top_i16, kBridgePivotPosY
    D_END
    .endrepeat
    ;; Water:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $70
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0040
    d_word Top_i16,   $0094
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0160
    d_word Top_i16,   $00c4
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kMermaidActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_byte TileRow_u8, 19
    d_byte TileCol_u8, 16
    d_byte Param_byte, kTileIdMermaidAdultFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_byte TileRow_u8, 8
    d_byte TileCol_u8, 31
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_byte TileRow_u8, 12
    d_byte TileCol_u8, 43
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_byte TileRow_u8, 37
    d_byte TileCol_u8, 21
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadCrawler
    d_byte TileRow_u8, 33
    d_byte TileCol_u8, 56
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadCrawler
    d_byte TileRow_u8, 43
    d_byte TileCol_u8, 26
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kMermaidDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 7
    d_byte Target_u8, kMermaidDialogIndex
    D_END
    .assert * - :- = kMermaidDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 8
    d_byte Target_u8, kMermaidDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 13
    d_byte Target_u8, kBridgeMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 27
    d_byte Target_u8, sState::LeverBridge_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 21
    d_byte Target_u8, kCannonMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Lever
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 16
    d_byte Target_u8, sState::LeverCannon_u1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::GardenCrossroad
    d_byte SpawnBlock_u8, 7
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::GardenTunnel
    d_byte SpawnBlock_u8, 19
    D_END
.ENDPROC

.PROC FuncC_Garden_EastBridge_InitRoom
    ;; Remove the mermaid from this room if the player has already met with the
    ;; mermaid queen.
    ldx #eFlag::MermaidHut1MetQueen
    jsr Func_IsFlagSet  ; clears Z if flag is set
    beq @done
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kMermaidActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kMermaidDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kMermaidDeviceIndexRight
    @done:
    rts
.ENDPROC

.PROC FuncC_Garden_EastBridge_ReadReg
    cmp #$c
    beq @readL
    @readY:
    jmp Func_MachineBridgeReadRegY
    @readL:
    lda Ram_RoomState + sState::LeverBridge_u1
    rts
.ENDPROC

.PROC FuncC_Garden_EastBridge_Tick
    lda #kBridgePivotPlatformIndex  ; param: fixed segment platform index
    ldx #kBridgePivotPlatformIndex + kNumMovableBridgeSegments  ; param: last
    jmp FuncA_Machine_BridgeTick
.ENDPROC

.PROC FuncC_Garden_EastBridge_Reset
    lda #0
    sta Ram_MachineGoalVert_u8_arr + kBridgeMachineIndex
    rts
.ENDPROC

.PROC FuncC_Garden_EastCannon_ReadReg
    cmp #$c
    beq @readL
    @readY:
    jmp Func_MachineCannonReadRegY
    @readL:
    lda Ram_RoomState + sState::LeverCannon_u1
    rts
.ENDPROC

.PROC FuncC_Garden_EastCannon_Reset
    lda #0
    sta Ram_MachineGoalVert_u8_arr + kCannonMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the GardenEastBridge machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_GardenEastBridge_Draw
    ldx #kBridgePivotPlatformIndex + kNumMovableBridgeSegments  ; param: last
    jmp FuncA_Objects_DrawBridgeMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the GardenEast room.
.PROC DataA_Dialog_GardenEast_sDialog_ptr_arr
:   .assert * - :- = kMermaidDialogIndex * kSizeofAddr, error
    .addr _Mermaid_sDialog
_Mermaid_sDialog:
    .addr _MermaidInitialFunc
_MermaidInitialFunc:
    ldx #eFlag::GardenEastTalkedToMermaid  ; param: flag
    jsr Func_IsFlagSet  ; clears Z if flag is set
    bne @alreadyTalked
    ldya #_MermaidQuestion_sDialog
    rts
    @alreadyTalked:
    ldya #_MermaidLater_sDialog
    rts
_MermaidQuestion_sDialog:
    .word ePortrait::Mermaid
    .byte "Are you...a human?$"
    .byte "A real human girl?%"
    .addr _MermaidQuestionFunc
_MermaidQuestionFunc:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #_MermaidNoAnswer_sDialog
    rts
    @yes:
    ldya #_MermaidYesAnswer_sDialog
    rts
_MermaidNoAnswer_sDialog:
    .word ePortrait::Mermaid
    .byte "Ha! You can't fool me.#"
_MermaidYesAnswer_sDialog:
    .word ePortrait::Mermaid
    .byte "But...humans aren't$"
    .byte "supposed to be down$"
    .byte "here! I've never even$"
    .byte "met one before.#"
_MermaidLater_sDialog:
    .word ePortrait::Mermaid
    .byte "You should meet with$"
    .byte "our queen. She will$"
    .byte "know what to do with$"
    .byte "you.#"
    .addr _MermaidSetFlagFunc
_MermaidSetFlagFunc:
    ldx #eFlag::GardenEastTalkedToMermaid  ; param: flag
    jsr Func_IsFlagSet  ; preserves X, clears Z if flag is set
    bne @alreadyTalked
    jsr Func_SetFlag
    ;; TODO: Play sound effect for new quest marker
    @alreadyTalked:
    ldya #_MermaidMarkMap_sDialog
    rts
_MermaidMarkMap_sDialog:
    .word ePortrait::Mermaid
    .byte "I'll mark her hut on$"
    .byte "your map.#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
