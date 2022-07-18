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
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
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
.IMPORT FuncA_Objects_DrawBridgeMachine
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitGrenadeActor
.IMPORT Func_IsFlagSet
.IMPORT Func_MachineError
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_RoomState
.IMPORTZP Zp_PlatformGoal_i16

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
;;; The maximum permitted value for sState::BridgeAngle_u8.
kBridgeMaxAngle = $10
;;; How many frames the bridge machine spends per move operation.
kBridgeMoveUpCountdown = kBridgeMaxAngle + $10
kBridgeMoveDownCountdown = kBridgeMaxAngle / 2

;;; The machine index for the GardenEastCannon machine.
kCannonMachineIndex = 1
;;; The platform index for the GardenEastCannon machine.
kCannonPlatformIndex = 0
;;; Initial room pixel position for grenades shot from the cannon.
kCannonGrenadeInitPosX = $00e8
kCannonGrenadeInitPosY = $0138

;;; The number of movable segments in the drawbridge (i.e. NOT including the
;;; fixed segment).
.DEFINE kNumMovableBridgeSegments 6
;;; The platform index for the fixed bridge segment that the rest of the bridge
;;; pivots around.
kBridgePivotPlatformIndex = 1
;;; Room pixel position for the top-left corner of the fixed bridge segment.
kBridgePivotPosY = $0080
kBridgePivotPosX = $0168

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverBridge_u1 .byte
    LeverCannon_u1 .byte
    ;; The current angle of the bridge (from 0 to kBridgeMaxAngle, inclusive).
    BridgeAngle_u8 .byte
    ;; The goal value of the GardenEastBridge machine's Y register.
    BridgeGoalY_u8 .byte
    ;; The current aim angle of the GardenEastCannon machine (0-255).
    CannonAngle_u8 .byte
    ;; The goal value of the GardenEastCannon machine's Y register.
    CannonGoalY_u8 .byte
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
    d_byte MinimapWidth_u8, 2
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
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_east.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
    .assert kBridgeMachineIndex = 0, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenEastBridge
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $d0
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_EastBridge_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Garden_EastBridge_TryMove
    d_addr TryAct_func_ptr, Func_MachineError
    d_addr Tick_func_ptr, FuncC_Garden_EastBridge_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenEastBridge_Draw
    d_addr Reset_func_ptr, FuncC_Garden_EastBridge_Reset
    D_END
    .assert kCannonMachineIndex = 1, error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::GardenEastCannon
    d_byte Conduit_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $b0
    d_byte ScrollGoalY_u8, $9f
    d_byte RegNames_u8_arr4, "L", 0, 0, "Y"
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_Garden_EastCannon_ReadReg
    d_addr WriteReg_func_ptr, Func_MachineError
    d_addr TryMove_func_ptr, FuncC_Garden_EastCannon_TryMove
    d_addr TryAct_func_ptr, FuncC_Garden_EastCannon_TryAct
    d_addr Tick_func_ptr, FuncC_Garden_EastCannon_Tick
    d_addr Draw_func_ptr, FuncA_Objects_GardenEastCannon_Draw
    d_addr Reset_func_ptr, FuncC_Garden_EastCannon_Reset
    D_END
_Platforms_sPlatform_arr:
:   .assert kCannonPlatformIndex = 0, error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlockWidthPx
    d_byte HeightPx_u8, kBlockHeightPx
    d_word Left_i16, kCannonGrenadeInitPosX - kTileWidthPx
    d_word Top_i16,  kCannonGrenadeInitPosY - kTileHeightPx
    D_END
    .assert kBridgePivotPlatformIndex = 1, error
    .repeat kNumMovableBridgeSegments + 1, index
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kTileWidthPx
    d_byte HeightPx_u8, kTileHeightPx
    d_word Left_i16, kBridgePivotPosX + kTileWidthPx * index
    d_word Top_i16, kBridgePivotPosY
    D_END
    .endrepeat
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
    .assert kMermaidActorIndex = 0, error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Mermaid
    d_byte TileRow_u8, 19
    d_byte TileCol_u8, 16
    d_byte Param_byte, kTileIdMermaidAdultFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Vinebug
    d_byte TileRow_u8, 8
    d_byte TileCol_u8, 31
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Vinebug
    d_byte TileRow_u8, 12
    d_byte TileCol_u8, 43
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Vinebug
    d_byte TileRow_u8, 37
    d_byte TileCol_u8, 21
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 33
    d_byte TileCol_u8, 56
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Crawler
    d_byte TileRow_u8, 43
    d_byte TileCol_u8, 26
    d_byte Param_byte, 0
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    .assert kMermaidDeviceIndexRight = 0, error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 7
    d_byte Target_u8, kMermaidDialogIndex
    D_END
    .assert kMermaidDeviceIndexLeft = 1, error
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
    lda Ram_RoomState + sState::BridgeAngle_u8
    cmp #kBridgeMaxAngle / 2  ; now carry bit is 1 if angle >= this
    lda #0
    rol a  ; shift in carry bit, now A is 0 or 1
    rts
    @readL:
    lda Ram_RoomState + sState::LeverBridge_u1
    rts
.ENDPROC

.PROC FuncC_Garden_EastBridge_TryMove
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    lda Ram_RoomState + sState::BridgeGoalY_u8
    bne @error
    inc Ram_RoomState + sState::BridgeGoalY_u8
    lda #kBridgeMoveUpCountdown
    clc  ; clear C to indicate success
    rts
    @moveDown:
    lda Ram_RoomState + sState::BridgeGoalY_u8
    beq @error
    dec Ram_RoomState + sState::BridgeGoalY_u8
    lda #kBridgeMoveDownCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
.ENDPROC

.PROC FuncC_Garden_EastBridge_Tick
    lda Ram_RoomState + sState::BridgeGoalY_u8
    beq _MoveDown
_MoveUp:
    ldy Ram_RoomState + sState::BridgeAngle_u8
    cpy #kBridgeMaxAngle
    beq _Finished
    iny
    bne _SetAngle  ; unconditional
_MoveDown:
    ldy Ram_RoomState + sState::BridgeAngle_u8
    beq _Finished
    dey
    dey
    bpl @noUnderflow
    ldy #0
    @noUnderflow:
_SetAngle:
    sty Ram_RoomState + sState::BridgeAngle_u8
    ;; Loop through each consequtive pair of bridge segments, starting with the
    ;; fixed pivot segment and the first movable segment.
    ldx #kBridgePivotPlatformIndex
    @loop:
    ;; Position the next segment vertically relative to the previous segment.
    ldy Ram_RoomState + sState::BridgeAngle_u8
    lda Ram_PlatformTop_i16_0_arr, x
    sub _Delta_u8_arr, y
    sta Zp_PlatformGoal_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_PlatformGoal_i16 + 1
    inx
    lda #127  ; param: max distance to move by
    jsr Func_MovePlatformTopToward  ; preserves X
    dex
    ;; Position the next segment horizontally relative to the previous segment.
    lda #kBridgeMaxAngle
    sub Ram_RoomState + sState::BridgeAngle_u8
    tay
    lda Ram_PlatformLeft_i16_0_arr, x
    add _Delta_u8_arr, y
    sta Zp_PlatformGoal_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    adc #0
    sta Zp_PlatformGoal_i16 + 1
    inx
    lda #127  ; param: max distance to move by
    jsr Func_MovePlatformLeftToward  ; preserves X
    ;; Continue to the next pair of segments.
    cpx #kBridgePivotPlatformIndex + kNumMovableBridgeSegments
    blt @loop
    rts
_Finished:
    jmp Func_MachineFinishResetting
_Delta_u8_arr:
    ;; [int(round(8 * sin(x * pi/32))) for x in range(0, 17)]
:   .byte 0, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 7, 7, 8, 8, 8, 8
    .assert * - :- = kBridgeMaxAngle + 1, error
.ENDPROC

.PROC FuncC_Garden_EastBridge_Reset
    lda #0
    sta Ram_RoomState + sState::BridgeGoalY_u8
    rts
.ENDPROC

.PROC FuncC_Garden_EastCannon_ReadReg
    cmp #$c
    beq @readL
    @readY:
    lda Ram_RoomState + sState::CannonAngle_u8
    and #$80
    asl a
    rol a
    rts
    @readL:
    lda Ram_RoomState + sState::LeverCannon_u1
    rts
.ENDPROC

.PROC FuncC_Garden_EastCannon_TryMove
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    ldy Ram_RoomState + sState::CannonGoalY_u8
    bne @error
    iny
    bne @success  ; unconditional
    @moveDown:
    ldy Ram_RoomState + sState::CannonGoalY_u8
    beq @error
    dey
    @success:
    sty Ram_RoomState + sState::CannonGoalY_u8
    lda #kCannonMoveCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
.ENDPROC

.PROC FuncC_Garden_EastCannon_TryAct
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @doneGrenade
    lda #<kCannonGrenadeInitPosX
    sta Ram_ActorPosX_i16_0_arr, x
    .assert <kCannonGrenadeInitPosY <> <kCannonGrenadeInitPosX, error
    lda #<kCannonGrenadeInitPosY
    sta Ram_ActorPosY_i16_0_arr, x
    lda #>kCannonGrenadeInitPosX
    sta Ram_ActorPosX_i16_1_arr, x
    .assert >kCannonGrenadeInitPosY <> >kCannonGrenadeInitPosX, error
    lda #>kCannonGrenadeInitPosY
    sta Ram_ActorPosY_i16_1_arr, x
    lda Ram_RoomState + sState::CannonGoalY_u8
    ora #$02  ; param: aim angle (2-3)
    jsr Func_InitGrenadeActor
    @doneGrenade:
    lda #kCannonActCountdown
    clc  ; clear C to indicate success
    rts
.ENDPROC

.PROC FuncC_Garden_EastCannon_Tick
    lda Ram_RoomState + sState::CannonGoalY_u8
    beq @moveDown
    @moveUp:
    lda Ram_RoomState + sState::CannonAngle_u8
    add #$100 / kCannonMoveCountdown
    bcc @setAngle
    jsr Func_MachineFinishResetting
    lda #$ff
    bne @setAngle  ; unconditional
    @moveDown:
    lda Ram_RoomState + sState::CannonAngle_u8
    sub #$100 / kCannonMoveCountdown
    bge @setAngle
    jsr Func_MachineFinishResetting
    lda #0
    @setAngle:
    sta Ram_RoomState + sState::CannonAngle_u8
    rts
.ENDPROC

.PROC FuncC_Garden_EastCannon_Reset
    lda #0
    sta Ram_RoomState + sState::CannonGoalY_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the GardenEastBridge machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_GardenEastBridge_Draw
    ldy #kBridgePivotPlatformIndex  ; param: fixed segment platform index
    ldx #kBridgePivotPlatformIndex + kNumMovableBridgeSegments  ; param: last
    lda #0  ; param: horz flip
    jmp FuncA_Objects_DrawBridgeMachine
.ENDPROC

;;; Allocates and populates OAM slots for the GardenEastCannon machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.PROC FuncA_Objects_GardenEastCannon_Draw
    ldx #kCannonPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx Ram_RoomState + sState::CannonAngle_u8  ; param: aim angle
    ldy #bObj::FlipH  ; param: horz flip
    jmp FuncA_Objects_DrawCannonMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the GardenEast room.
.PROC DataA_Dialog_GardenEast_sDialog_ptr_arr
    .assert kMermaidDialogIndex = 0, error
    .addr _Mermaid_sDialog
_Mermaid_sDialog:
    .addr _MermaidInitialFunc
_MermaidInitialFunc:
    ldx #eFlag::GardenEastTalkedToMermaid  ; param: flag
    jsr Func_IsFlagSet  ; clears Z if flag is set
    bne @alreadyTalked
    ldya #_MermaidFirst_sDialog
    rts
    @alreadyTalked:
    ldya #_MermaidLater_sDialog
    rts
_MermaidFirst_sDialog:
    .word ePortrait::Woman
    .byte "Are you...a human?$"
    .byte "A real human girl?#"
    .word ePortrait::Woman
    .byte "But...humans aren't$"
    .byte "supposed to be down$"
    .byte "here! I've never even$"
    .byte "met one before.#"
_MermaidLater_sDialog:
    .word ePortrait::Woman
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
    .word ePortrait::Woman
    .byte "I'll mark her hut on$"
    .byte "your map.#"
    .byte 0
.ENDPROC

;;;=========================================================================;;;
