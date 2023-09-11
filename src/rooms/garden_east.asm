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

.IMPORT DataA_Room_Garden_sTileset
.IMPORT FuncA_Dialog_AddQuestMarker
.IMPORT FuncA_Machine_BridgeTick
.IMPORT FuncA_Machine_BridgeTryMove
.IMPORT FuncA_Machine_CannonTick
.IMPORT FuncA_Machine_CannonTryAct
.IMPORT FuncA_Machine_CannonTryMove
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawBridgeMachine
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Room_AreActorsWithinDistance
.IMPORT FuncA_Room_FindGrenadeActor
.IMPORT FuncA_Room_MachineCannonReset
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_MachineBridgeReadRegY
.IMPORT Func_MachineCannonReadRegY
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeSmall
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_DialogAnsweredYes_bool
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Corra in this room.
kCorraActorIndex = 0
;;; The talk device indices for Corra in this room.
kCorraDeviceIndexLeft = 1
kCorraDeviceIndexRight = 0

;;; The device indices for the levers in this room.
kLeverBridgeDeviceIndex = 3
kLeverCannonDeviceIndex = 5

;;; The actor index for the vinebug that can be killed with the cannon.
kKillableVinebugActorIndex = 3

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
    LeverBridge_u8 .byte
    LeverCannon_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_East_sRoom
.PROC DataC_Garden_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, bRoom::Tall | eArea::Garden
    d_byte MinimapStartRow_u8, 8
    d_byte MinimapStartCol_u8, 10
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Garden_East_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Garden_East_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_east.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kBridgeMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenEastBridge
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::BridgeRight
    d_word ScrollGoalX_u16, $d0
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_byte MainPlatform_u8, kBridgePivotPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_EastBridge_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Garden_EastBridge_WriteReg
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
    .linecont +
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | \
                           bMachine::Act | bMachine::WriteC
    .linecont -
    d_byte Status_eDiagram, eDiagram::CannonLeft
    d_word ScrollGoalX_u16, $b0
    d_byte ScrollGoalY_u8, $9f
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_byte MainPlatform_u8, kCannonPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_EastCannon_ReadReg
    d_addr WriteReg_func_ptr, FuncC_Garden_EastCannon_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_CannonTryMove
    d_addr TryAct_func_ptr, FuncC_Garden_EastCannon_TryAct
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
:   .assert * - :- = kCorraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $0080
    d_word PosY_i16, $0098
    d_byte Param_byte, kTileIdMermaidCorraFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_word PosX_i16, $00f7
    d_word PosY_i16, $0040
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_word PosX_i16, $0157
    d_word PosY_i16, $0060
    d_byte Param_byte, 0
    D_END
    .assert * - :- = kKillableVinebugActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadVinebug
    d_word PosX_i16, $00a7
    d_word PosY_i16, $0118
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $01c0
    d_word PosY_i16, $0108
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00d0
    d_word PosY_i16, $0158
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kCorraDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eDialog::GardenEastCorra
    D_END
    .assert * - :- = kCorraDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eDialog::GardenEastCorra
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kBridgeMachineIndex
    D_END
    .assert * - :- = kLeverBridgeDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 27
    d_byte Target_byte, sState::LeverBridge_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 21
    d_byte Target_byte, kCannonMachineIndex
    D_END
    .assert * - :- = kLeverCannonDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 16
    d_byte Target_byte, sState::LeverCannon_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::GardenCrossroad
    d_byte SpawnBlock_u8, 7
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 1
    d_byte Destination_eRoom, eRoom::GardenFlower
    d_byte SpawnBlock_u8, 23
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::GardenTunnel
    d_byte SpawnBlock_u8, 19
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Garden_East_EnterRoom
    ;; Remove Corra from this room if the player has already met with the
    ;; mermaid queen.
    flag_bit Sram_ProgressFlags_arr, eFlag::MermaidHut1MetQueen
    beq @done
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kCorraActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexRight
    @done:
    rts
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Garden_East_TickRoom
    ;; If the vinebug is already gone, then we're done.
    lda Ram_ActorType_eActor_arr + kKillableVinebugActorIndex
    cmp #eActor::BadVinebug
    bne _Done
_FindGrenade:
    ;; Find the actor index for the grenade in flight (if any).  If we don't
    ;; find one, then we're done.
    jsr FuncA_Room_FindGrenadeActor  ; returns C and X
    bcs _Done
_CheckForCollision:
    ldy #kKillableVinebugActorIndex  ; param: other actor index
    lda #6  ; param: distance
    jsr FuncA_Room_AreActorsWithinDistance  ; preserves X, returns C
    bcc _Done
    ;; Explode the grenade.
    jsr Func_InitActorSmokeExplosion
    ;; Explode the vinebug.
    ldx #kKillableVinebugActorIndex  ; param: actor index
    jsr Func_InitActorSmokeExplosion
    jsr Func_PlaySfxExplodeSmall
    ;; TODO: maybe play a sound (on another channel) for vinebug dying?
_Done:
    rts
.ENDPROC

.PROC FuncC_Garden_EastBridge_ReadReg
    cmp #$c
    beq @readL
    @readY:
    jmp Func_MachineBridgeReadRegY
    @readL:
    lda Zp_RoomState + sState::LeverBridge_u8
    rts
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Garden_EastBridge_WriteReg
    ldx #kLeverBridgeDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Garden_EastBridge_Tick
    lda #kBridgePivotPlatformIndex  ; param: fixed segment platform index
    ldx #kBridgePivotPlatformIndex + kNumMovableBridgeSegments  ; param: last
    jmp FuncA_Machine_BridgeTick
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Garden_EastBridge_Reset
    lda #0
    sta Ram_MachineGoalVert_u8_arr + kBridgeMachineIndex
    ldx #kLeverBridgeDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

.PROC FuncC_Garden_EastCannon_ReadReg
    cmp #$c
    beq @readL
    @readY:
    jmp Func_MachineCannonReadRegY
    @readL:
    lda Zp_RoomState + sState::LeverCannon_u8
    rts
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Garden_EastCannon_WriteReg
    ldx #kLeverCannonDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

;;; @prereq PRGA_Machine is loaded.
.PROC FuncC_Garden_EastCannon_TryAct
    ;; Make the vinebug try to dodge the grenade.
    lda #1
    sta Ram_ActorState1_byte_arr + kKillableVinebugActorIndex
    lda Ram_MachineGoalVert_u8_arr + kCannonMachineIndex
    bne @dodgeDown
    @dodgeUp:
    lda #$d0
    ldy #$ff
    bne @dodge  ; unconditional
    @dodgeDown:
    lda #$60
    ldy #$00
    @dodge:
    sta Ram_ActorVelY_i16_0_arr + kKillableVinebugActorIndex
    sty Ram_ActorVelY_i16_1_arr + kKillableVinebugActorIndex
    ;; Fire a grenade.
    jmp FuncA_Machine_CannonTryAct
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Garden_EastCannon_Reset
    ldx #kLeverCannonDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    jmp FuncA_Room_MachineCannonReset
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

.EXPORT DataA_Dialog_GardenEastCorra_sDialog
.PROC DataA_Dialog_GardenEastCorra_sDialog
    dlg_Func _InitialFunc
_InitialFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::GardenEastTalkedToCorra
    bne @alreadyTalked
    ldya #_Question_sDialog
    rts
    @alreadyTalked:
    ldya #_Later_sDialog
    rts
_Question_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_GardenEastCorra_Question_u8_arr
    dlg_Func _QuestionFunc
_QuestionFunc:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #_NoAnswer_sDialog
    rts
    @yes:
    ldya #_YesAnswer_sDialog
    rts
_NoAnswer_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_GardenEastCorra_No_u8_arr
_YesAnswer_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_GardenEastCorra_Yes_u8_arr
_Later_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_GardenEastCorra_MeetQueen_u8_arr
    dlg_Func _SetFlagFunc
_SetFlagFunc:
    ldx #eFlag::GardenEastTalkedToCorra  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_MarkMap_sDialog
    rts
_MarkMap_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_GardenEastCorra_MarkMap_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_GardenEastCorra_Question_u8_arr
    .byte "Are you...a human?$"
    .byte "A real human girl?%"
.ENDPROC

.PROC DataA_Text0_GardenEastCorra_No_u8_arr
    .byte "Ha! You can't fool me.#"
.ENDPROC

.PROC DataA_Text0_GardenEastCorra_Yes_u8_arr
    .byte "But...humans aren't$"
    .byte "supposed to be down$"
    .byte "here! I've never even$"
    .byte "met one before.#"
.ENDPROC

.PROC DataA_Text0_GardenEastCorra_MeetQueen_u8_arr
    .byte "You should meet with$"
    .byte "our queen. She will$"
    .byte "know what to do with$"
    .byte "you.#"
.ENDPROC

.PROC DataA_Text0_GardenEastCorra_MarkMap_u8_arr
    .byte "I'll mark her hut on$"
    .byte "your map.#"
.ENDPROC

;;;=========================================================================;;;
