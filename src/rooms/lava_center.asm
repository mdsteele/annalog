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
.INCLUDE "../actors/lavaball.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/blaster.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/crate.inc"
.INCLUDE "../platforms/lava.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Lava_sTileset
.IMPORT FuncA_Machine_BlasterTick
.IMPORT FuncA_Machine_BlasterTryAct
.IMPORT FuncA_Machine_BlasterWriteRegM
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_AnimateLavaTerrain
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawBlasterMachine
.IMPORT FuncA_Objects_DrawBlasterMirror
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncA_Room_PlaySfxThudSmall
.IMPORT FuncA_Room_ReflectFireblastsOffMirror
.IMPORT FuncA_Room_ResetLever
.IMPORT FuncA_Room_TurnProjectilesToSmokeIfConsoleOpen
.IMPORT FuncA_Terrain_FadeInTallRoomWithLava
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsActorWithinDistanceOfPoint
.IMPORT Func_IsFlagSet
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MachineBlasterReadRegM
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_PlaySfxBaddieDeath
.IMPORT Func_PlaySfxPoof
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Ppu_ChrObjLava
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState3_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for the hothead in this room.
kHotheadActorIndex = 2

;;; The device index for the lever in this room.
kLeverDeviceIndex = 1

;;; The machine index for the LavaCenterBlaster machine in this room.
kBlasterMachineIndex = 0

;;; The platform indices for the LavaCenterBlaster machine in this room.
kBlasterPlatformIndex = 6
kMirror1PlatformIndex = 7
kMirror2PlatformIndex = 8
kMirror3PlatformIndex = 9

;;; The initial value for the blaster's M register.
kBlasterInitGoalM = 7
;;; The initial and maximum permitted values for the blaster's X register.
kBlasterInitGoalX = 4
kBlasterMaxGoalX  = 5

;;; The minimum and initial X-positions for the left of the blaster platform.
.LINECONT +
kBlasterMinPlatformLeft = $0090
kBlasterInitPlatformLeft = \
    kBlasterMinPlatformLeft + kBlasterInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

;;; Enum for the hanging crates in this room.
.ENUM eCrate
    Crate1
    Crate2
    Crate3
    NUM_VALUES
.ENDENUM

;;; The platform indices for the crates and crate chains in this room.
kCrate1PlatformIndex = eCrate::Crate1
kCrate2PlatformIndex = eCrate::Crate2
kCrate3PlatformIndex = eCrate::Crate3
kChain1PlatformIndex = 3
kChain2PlatformIndex = 4
kChain3PlatformIndex = 5

;;; The room pixel Y-position of the bottom of each droppable crate when it's
;;; resting on the floor.
kCrate1MaxTop = $0061
kCrate2MaxTop = $0101
kCrate3MaxTop = $0061

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the lever in this room.
    Lever_u8            .byte
    ;; The current Y subpixel position of each droppable crate, indexed by
    ;; eCrate value.
    CrateSubY_u8_arr    .res eCrate::NUM_VALUES
    ;; The current Y-velocity of each droppable crate, in subpixels per frame,
    ;; indexed by eCrate value.
    CrateVelY_i16_0_arr .res eCrate::NUM_VALUES
    CrateVelY_i16_1_arr .res eCrate::NUM_VALUES
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Lava"

.EXPORT DataC_Lava_Center_sRoom
.PROC DataC_Lava_Center_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Lava
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 17
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjLava)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_LavaCenter_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_FadeInTallRoomWithLava
    d_addr Tick_func_ptr, FuncA_Room_LavaCenter_TickRoom
    d_addr Draw_func_ptr, FuncC_Lava_Center_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/lava_center.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kBlasterMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::LavaCenterBlaster
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Blaster
    d_word ScrollGoalX_u16, $0010
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "M", "L", "X", 0
    d_byte MainPlatform_u8, kBlasterPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_LavaCenterBlaster_Init
    d_addr ReadReg_func_ptr, FuncC_Lava_CenterBlaster_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LavaCenterBlaster_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_LavaCenterBlaster_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_BlasterTryAct
    d_addr Tick_func_ptr, FuncA_Machine_LavaCenterBlaster_Tick
    d_addr Draw_func_ptr, FuncC_Lava_CenterBlaster_Draw
    d_addr Reset_func_ptr, FuncA_Room_LavaCenterBlaster_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCrate1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0040
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kCrate2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00d0
    d_word Top_i16,   $00b0
    D_END
    .assert * - :- = kCrate3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00f0
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kChain1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0044
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kChain2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00d4
    d_word Top_i16,   $00a0
    D_END
    .assert * - :- = kChain3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00f4
    d_word Top_i16,   $0020
    D_END
    .assert * - :- = kBlasterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlasterMachineWidthPx
    d_byte HeightPx_u8, kBlasterMachineHeightPx
    d_word Left_i16, kBlasterInitPlatformLeft
    d_word Top_i16, $0010
    D_END
    .assert * - :- = kMirror1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00a4
    d_word Top_i16,   $0024
    D_END
    .assert * - :- = kMirror2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0044
    d_word Top_i16,   $0134
    D_END
    .assert * - :- = kMirror3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00e4
    d_word Top_i16,   $0134
    D_END
    ;; Lava:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $120
    d_byte HeightPx_u8, kLavaPlatformHeightPx
    d_word Left_i16,   $0000
    d_word Top_i16, kLavaPlatformTopTallRoom
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadLavaball
    d_word PosX_i16, $0074
    d_word PosY_i16, kLavaballStartYTall
    d_byte Param_byte, 7
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadLavaball
    d_word PosX_i16, $00c0
    d_word PosY_i16, kLavaballStartYTall
    d_byte Param_byte, 6
    D_END
    .assert * - :- = kHotheadActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadHotheadHorz
    d_word PosX_i16, $00ac
    d_word PosY_i16, $00a8
    d_byte Param_byte, bObj::FlipH
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 7
    d_byte Target_byte, kBlasterMachineIndex
    D_END
    .assert * - :- = kLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 14
    d_byte BlockCol_u8, 10
    d_byte Target_byte, sState::Lever_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::LavaShaft
    d_byte SpawnBlock_u8, 6
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::LavaFlower
    d_byte SpawnBlock_u8, 15
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 0
    d_byte Destination_eRoom, eRoom::LavaEast
    d_byte SpawnBlock_u8, 3
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | bPassage::SameScreen | 1
    d_byte Destination_eRoom, eRoom::LavaEast
    d_byte SpawnBlock_u8, 13
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Lava_Center_DrawRoom
_Crates:
    ldx #kCrate1PlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawCratePlatform
    ldx #kCrate2PlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawCratePlatform
    ldx #kCrate3PlatformIndex  ; param: platform index
    jsr FuncA_Objects_DrawCratePlatform
_Chain1:
    ldx #kChain1PlatformIndex  ; param: platform index
    ldy #3  ; param: num chain links
    flag_bit Sram_ProgressFlags_arr, eFlag::LavaCenterChain1Broken
    beq @draw
    dey
    @draw:
    jsr FuncC_Lava_Center_DrawChainPlatform
_Chain2:
    ldx #kChain2PlatformIndex  ; param: platform index
    ldy #1  ; param: num chain links
    flag_bit Sram_ProgressFlags_arr, eFlag::LavaCenterChain2Broken
    beq @draw
    dey
    @draw:
    jsr FuncC_Lava_Center_DrawChainPlatform
_Chain3:
    ldx #kChain3PlatformIndex  ; param: platform index
    ldy #1  ; param: num chain links
    flag_bit Sram_ProgressFlags_arr, eFlag::LavaCenterChain3Broken
    beq @draw
    dey
    @draw:
    jsr FuncC_Lava_Center_DrawChainPlatform
_Lava:
    jmp FuncA_Objects_AnimateLavaTerrain
.ENDPROC

;;; Draws a crate anchor and chain.
;;; @prereq PRGA_Objects is loaded.
;;; @param X The anchor platform index.
;;; @param Y The number of chain links to draw.
;;; @preserve X
.PROC FuncC_Lava_Center_DrawChainPlatform
    sty T2  ; num chain links
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X and T0+
    ldy #bObj::FlipV  ; param: object flags
    lda #kTileIdObjCrateAnchor  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    ldy #bObj::FlipV  ; param: object flags
    lda #kTileIdObjCrateChainHalf  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    lda T2  ; num chain links
    beq @done
    @loop:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X and T0+
    ldy #bObj::FlipV  ; param: object flags
    lda #kTileIdObjCrateChainFull  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    dec T2  ; num chain links
    bne @loop
    @done:
    rts
.ENDPROC

.PROC FuncC_Lava_CenterBlaster_ReadReg
    cmp #$d
    beq _ReadL
    cmp #$e
    beq _ReadX
    jmp Func_MachineBlasterReadRegM
_ReadL:
    lda Zp_RoomState + sState::Lever_u8
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kBlasterPlatformIndex
    sub #kBlasterMinPlatformLeft - kTileHeightPx
    div #kBlockWidthPx
    rts
.ENDPROC

;;; Draws the LavaCenterBlaster machine.
.PROC FuncC_Lava_CenterBlaster_Draw
_Mirrors:
    ldx #kMirror3PlatformIndex
    @loop:
    jsr FuncA_Objects_DrawBlasterMirror  ; preserves X
    dex
    .assert kMirror1PlatformIndex > 0, error
    cpx #kMirror1PlatformIndex
    bge @loop
_Blaster:
    jmp FuncA_Objects_DrawBlasterMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; The "chain broken" flag associated with each crate in this room, indexed by
;;; eCrate value.
.PROC DataA_Room_LavaCenter_CrateFlag_eFlag_arr
    D_ARRAY .enum, eCrate
    d_byte Crate1, eFlag::LavaCenterChain1Broken
    d_byte Crate2, eFlag::LavaCenterChain2Broken
    d_byte Crate3, eFlag::LavaCenterChain3Broken
    D_END
.ENDPROC

;;; Sets C if the "chain broken" flag is set for the specified hanging crate.
;;; @param X The eCrate value (i.e. platform index) of the crate.
;;; @return C Set if the flag is set.
;;; @preserve X
.PROC FuncA_Room_LavaCenter_IsCrateFlagSet
    stx T0  ; eCrate value (i.e. platform index)
    lda DataA_Room_LavaCenter_CrateFlag_eFlag_arr, x
    tax  ; param: flag
    jsr Func_IsFlagSet  ; preserves T0+
    bne @isSet
    @isClear:
    ldx T0  ; eCrate value (i.e. platform index)
    clc
    rts
    @isSet:
    ldx T0  ; eCrate value (i.e. platform index)
    sec
    rts
.ENDPROC

.PROC DataA_Room_LavaCenter_ChainPlatform_u8_arr
    D_ARRAY .enum, eCrate
    d_byte Crate1, kChain1PlatformIndex
    d_byte Crate2, kChain2PlatformIndex
    d_byte Crate3, kChain3PlatformIndex
    D_END
.ENDPROC

;;; The room pixel Y-position of the bottom of each droppable crate when it's
;;; resting on the floor, indexed by eCrate value.
.PROC DataA_Room_LavaCenter_CrateMaxTop_i16_0_arr
    D_ARRAY .enum, eCrate
    d_byte Crate1, <kCrate1MaxTop
    d_byte Crate2, <kCrate2MaxTop
    d_byte Crate3, <kCrate3MaxTop
    D_END
.ENDPROC
.PROC DataA_Room_LavaCenter_CrateMaxTop_i16_1_arr
    D_ARRAY .enum, eCrate
    d_byte Crate1, >kCrate1MaxTop
    d_byte Crate2, >kCrate2MaxTop
    d_byte Crate3, >kCrate3MaxTop
    D_END
.ENDPROC

.PROC FuncA_Room_LavaCenter_EnterRoom
    ldx #eCrate::NUM_VALUES - 1
    @loop:
    jsr FuncA_Room_LavaCenter_IsCrateFlagSet  ; preserves X, returns C
    bcc @continue
    lda DataA_Room_LavaCenter_CrateMaxTop_i16_0_arr, x
    sta Zp_PointY_i16 + 0
    lda DataA_Room_LavaCenter_CrateMaxTop_i16_1_arr, x
    sta Zp_PointY_i16 + 1
    lda #127  ; param: max move by
    jsr Func_MovePlatformTopTowardPointY  ; preserves X
    @continue:
    dex
    .assert eCrate::NUM_VALUES <= $80, error
    bpl @loop
    rts
.ENDPROC

.PROC FuncA_Room_LavaCenter_TickRoom
    lda #eActor::ProjFireblast  ; param: projectile type
    jsr FuncA_Room_TurnProjectilesToSmokeIfConsoleOpen
_Crates:
    ldx #eCrate::NUM_VALUES - 1
    @loop:
    jsr FuncA_Room_LavaCenter_TickCrate  ; preserves X
    dex
    .assert eCrate::NUM_VALUES <= $80, error
    bpl @loop
_CheckIfFireblastHitsHothead:
    ;; If the hothead is already gone, then we're done.
    lda Ram_ActorType_eActor_arr + kHotheadActorIndex
    cmp #eActor::BadHotheadHorz
    beq @checkFireblasts
    cmp #eActor::BadHotheadVert
    bne @done
    ;; Check each fireblast in the room to see if it has hit the hothead.
    @checkFireblasts:
    ldx #kHotheadActorIndex  ; param: actor index
    jsr Func_SetPointToActorCenter
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjFireblast
    bne @continue
    lda #6  ; param: distance
    jsr Func_IsActorWithinDistanceOfPoint  ; preserves X, returns C
    bcc @continue
    ;; Remove the fireblast and destroy the hothead.
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    ldx #kHotheadActorIndex  ; param: actor index
    jsr Func_InitActorSmokeExplosion
    jsr Func_PlaySfxBaddieDeath
    jmp @done
    @continue:
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
    @done:
_Mirrors:
    ldx #kBlasterMachineIndex  ; param: blaster machine index
    ldy #kMirror3PlatformIndex  ; param: mirror platform index
    @loop:
    jsr FuncA_Room_ReflectFireblastsOffMirror  ; preserves X and Y
    dey
    .assert kMirror1PlatformIndex > 0, error
    cpy #kMirror1PlatformIndex
    bge @loop
    rts
.ENDPROC

;;; Performs per-frame updates for a crate in this room.
;;; @param X The eCrate value (i.e. platform index) of the crate.
;;; @preserve X
.PROC FuncA_Room_LavaCenter_TickCrate
    ;; If the crate's chain hasn't been broken yet, we're done.
    jsr FuncA_Room_LavaCenter_IsCrateFlagSet  ; preserves X, returns C
    bcs FuncA_Room_LavaCenter_TickFallingCrate  ; preserves X
    fall FuncA_Room_LavaCenter_TickHangingCrate  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a crate in this room that's still hanging.
;;; @param X The eCrate value (i.e. platform index) of the crate.
;;; @preserve X
.PROC FuncA_Room_LavaCenter_TickHangingCrate
    stx T0  ; eCrate value (i.e. platform index)
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjFireblast
    bne @continue
    ;; Check if the fireblast hits the chain:
    jsr Func_SetPointToActorCenter  ; preserves X and T0+
    ldy T0  ; eCrate value (i.e. platform index)
    lda DataA_Room_LavaCenter_ChainPlatform_u8_arr, y
    tay  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X and T0+, returns C
    bcc @continue
    stx T1  ; actor index
    ldy T0  ; eCrate value (i.e. platform index)
    ldx DataA_Room_LavaCenter_CrateFlag_eFlag_arr, y  ; param: flag
    jsr Func_SetFlag  ; preserves T0+
    ldx T1  ; actor index
    jsr Func_InitActorSmokeExplosion  ; preserves X and T0+
    jsr Func_PlaySfxPoof  ; preserves X and T0+
    @continue:
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
    ldx T0  ; eCrate value (i.e. platform index)
    rts
.ENDPROC

;;; Performs per-frame updates for a crate in this room whose chain is broken.
;;; @param X The eCrate value (i.e. platform index) of the crate.
;;; @preserve X
.PROC FuncA_Room_LavaCenter_TickFallingCrate
    ;; Calculate how far above the floor the crate is.  If it's resting on the
    ;; floor, we're done.
    lda DataA_Room_LavaCenter_CrateMaxTop_i16_0_arr, x
    sub Ram_PlatformTop_i16_0_arr, x
    beq _Return
    sta T0  ; crate dist above floor
_ApplyGravity:
    lda Zp_RoomState + sState::CrateVelY_i16_0_arr, x
    add #<kAvatarGravity
    sta Zp_RoomState + sState::CrateVelY_i16_0_arr, x
    lda Zp_RoomState + sState::CrateVelY_i16_1_arr, x
    adc #>kAvatarGravity
    sta Zp_RoomState + sState::CrateVelY_i16_1_arr, x
_ApplyVelocity:
    ;; Update subpixels, and calculate the number of whole pixels to move,
    ;; storing the latter in A.
    lda Zp_RoomState + sState::CrateSubY_u8_arr, x
    add Zp_RoomState + sState::CrateVelY_i16_0_arr, x
    sta Zp_RoomState + sState::CrateSubY_u8_arr, x
    lda #0
    adc Zp_RoomState + sState::CrateVelY_i16_1_arr, x
_MaybeHitFloor:
    ;; If the number of pixels to move this frame is >= the distance above the
    ;; floor, then the crate is hitting the floor this frame.
    cmp T0  ; crate dist above floor
    blt @noHit
    jsr FuncA_Room_PlaySfxThudSmall  ; preserves X and T0+
    ;; Zero the crate's velocity, and move it to exactly hit the floor.
    lda #0
    sta Zp_RoomState + sState::CrateSubY_u8_arr, x
    sta Zp_RoomState + sState::CrateVelY_i16_0_arr, x
    sta Zp_RoomState + sState::CrateVelY_i16_1_arr, x
    lda T0  ; crate dist above floor
    @noHit:
_MoveCratePlatform:
    jmp Func_MovePlatformVert  ; preserves X
_Return:
    rts
.ENDPROC

.PROC FuncA_Room_LavaCenterBlaster_Init
    lda #kBlasterInitGoalM * kBlasterMirrorAnimSlowdown
    sta Ram_MachineState3_byte_arr + kBlasterMachineIndex  ; mirror anim
    fall FuncA_Room_LavaCenterBlaster_Reset
.ENDPROC

.PROC FuncA_Room_LavaCenterBlaster_Reset
    lda #kBlasterInitGoalM
    sta Ram_MachineState1_byte_arr + kBlasterMachineIndex  ; mirror goal
    lda #kBlasterInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kBlasterMachineIndex
    ldx #kLeverDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_LavaCenterBlaster_WriteReg
    cpx #$d
    beq _WriteL
    jmp FuncA_Machine_BlasterWriteRegM
_WriteL:
    ldx #kLeverDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_LavaCenterBlaster_TryMove
    lda #kBlasterMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_LavaCenterBlaster_Tick
    ldax #kBlasterMinPlatformLeft  ; param: min platform left
    jmp FuncA_Machine_BlasterTick
.ENDPROC

;;;=========================================================================;;;
