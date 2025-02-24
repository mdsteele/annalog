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
.INCLUDE "../actors/adult.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/crate.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Core_sTileset
.IMPORT DataA_Text0_CoreSouthCorra_AlreadyHelped_u8_arr
.IMPORT DataA_Text0_CoreSouthCorra_HelloAgain1_u8_arr
.IMPORT DataA_Text0_CoreSouthCorra_HelloAgain2_u8_arr
.IMPORT DataA_Text0_CoreSouthCorra_HelloAgain3_u8_arr
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightHalfTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointVert
.IMPORT Func_Noop
.IMPORT Func_PlaySfxPoof
.IMPORT Func_PlaySfxSecretUnlocked
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetPlatformTopToPointY
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorSubX_u8_arr
.IMPORT Ram_ActorSubY_u8_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Corra in this room.
kCorraActorIndex = 0
;;; The talk device indices for Corra in this room.
kCorraDeviceIndexLeft = 1
kCorraDeviceIndexRight = 0

;;; The platform indices for the crates anchored/floating in the water.
kCrate1PlatformIndex = 0
kCrate2PlatformIndex = 1
kCrate3PlatformIndex = 2
;;; The platform indices for the underwater anchors that the crates are/were
;;; chained to.
kAnchor1PlatformIndex = 3
kAnchor2PlatformIndex = 4
kAnchor3PlatformIndex = 5

;;; The room pixel Y-position for the top of each floating crate when that
;;; crate is at the surface of the water (and the player avatar is not standing
;;; on it).
kCrate2FloatingPositionY = $012a
kCrate3FloatingPositionY = $008f

;;; The OBJ palette number to use for drawing crate chains/anchors.
kPaletteObjAnchor = 0

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; A timer that ticks up each frame and is used to make the floating crates
    ;; bob up and down in the water.
    WaterBobTimer_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Core"

.EXPORT DataC_Core_South_sRoom
.PROC DataC_Core_South_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte Flags_bRoom, bRoom::Tall | eArea::Core
    d_byte MinimapStartRow_u8, 4
    d_byte MinimapStartCol_u8, 12
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_CoreSouth_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_CoreSouth_TickRoom
    d_addr Draw_func_ptr, FuncC_Core_South_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/core_south.room"
    .assert * - :- = 17 * 24, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCrate1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0060
    d_word Top_i16,   $0151
    D_END
    .assert * - :- = kCrate2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00b8
    d_word Top_i16, kCrate2FloatingPositionY
    D_END
    .assert * - :- = kCrate3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0080
    d_word Top_i16,   $00c1
    D_END
    .assert * - :- = kAnchor1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0064
    d_word Top_i16,   $0168
    D_END
    .assert * - :- = kAnchor2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00bc
    d_word Top_i16,   $0160
    D_END
    .assert * - :- = kAnchor3PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0084
    d_word Top_i16,   $00e8
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $4c
    d_word Left_i16,  $0050
    d_word Top_i16,   $00a4
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $b0
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0040
    d_word Top_i16,   $0134
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kCorraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0060
    d_word PosY_i16, $00a8
    d_byte Param_byte, eNpcAdult::MermaidCorra
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $00c0
    d_word PosY_i16, $0038
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGrub
    d_word PosX_i16, $0058
    d_word PosY_i16, $0058
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $00c8
    d_word PosY_i16, $00f8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $0058
    d_word PosY_i16, $00f8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadFish
    d_word PosX_i16, $00a0
    d_word PosY_i16, $0140
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kCorraDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eDialog::CoreSouthCorra
    D_END
    .assert * - :- = kCorraDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eDialog::CoreSouthCorra
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::FactoryUpper
    d_byte SpawnBlock_u8, 18
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::CoreJunction
    d_byte SpawnBlock_u8, 9
    d_byte SpawnAdjust_byte, $f1
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Core_South_DrawRoom
_Anchors:
    ldx #kAnchor1PlatformIndex
    @loop:
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    ldy #kPaletteObjAnchor  ; param: object flags
    lda #kTileIdObjCrateAnchor  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    inx
    cpx #kAnchor3PlatformIndex + 1
    blt @loop
_LowerCrates:
    ldx #kCrate1PlatformIndex  ; param: platform index
    jsr FuncC_Core_South_DrawAnchoredCrate
    ldx #kCrate2PlatformIndex  ; param: platform index
    jsr FuncC_Core_South_DrawAnchoredCrate
_UpperCrates:
    ldx #kCrate3PlatformIndex  ; param: platform index
    fall FuncC_Core_South_DrawAnchoredCrate
.ENDPROC

;;; Draws a platform that is a stack of one or more wooden crates with a chain
;;; hanging off the bottom.  The platform height should be a multiple of
;;; kBlockHeightPx.
;;; @prereq PRGA_Objects is loaded.
;;; @param X The crate platform index.
.PROC FuncC_Core_South_DrawAnchoredCrate
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeRightHalfTile  ; preserves X
    ;; Move shape down by (platform height - 1).
    lda Ram_PlatformBottom_i16_0_arr, x
    clc
    sbc Ram_PlatformTop_i16_0_arr, x
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X
    ;; Draw the chain.
    ldy #kPaletteObjAnchor  ; param: object flags
    lda #kTileIdObjCrateChainFull  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    ldy #kPaletteObjAnchor  ; param: object flags
    lda #kTileIdObjCrateChainHalf  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    ;; Draw the crate(s).
    jmp FuncA_Objects_DrawCratePlatform
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CoreSouth_EnterRoom
_CheckIfKidsAreFreedYet:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    beq @done
    jsr _RemoveCorra
    jmp _ReleaseCrates
    @done:
_CheckIfCratesHaveBeenReleased:
    flag_bit Sram_ProgressFlags_arr, eFlag::CoreSouthCorraHelped
    beq @done
    jsr _ReleaseCrates
    @done:
_CheckIfCorraIsWaiting:
    flag_bit Sram_ProgressFlags_arr, eFlag::CoreSouthCorraWaiting
    bne _Return
_RemoveCorra:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kCorraActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexRight
_Return:
    rts
_ReleaseCrates:
    ldx #eFlag::CoreSouthCorraHelped  ; param: flag
    jsr Func_SetFlag
    ldax #kCrate3FloatingPositionY
    stax Zp_PointY_i16
    ldy #kCrate3PlatformIndex  ; param: platform index
    jmp Func_SetPlatformTopToPointY
.ENDPROC

.PROC FuncA_Room_CoreSouth_TickRoom
    inc Zp_RoomState + sState::WaterBobTimer_u8
_TickCrate3:
    ;; If Corra hasn't yet released the stacked crates from their anchor, then
    ;; don't move them.
    flag_bit Sram_ProgressFlags_arr, eFlag::CoreSouthCorraHelped
    beq @done
    ldax #kCrate3FloatingPositionY
    stax Zp_PointY_i16
    ldx #kCrate3PlatformIndex  ; param: crate platform index
    jsr FuncA_Room_CoreSouth_TickCrate
    @done:
_TickCrate2:
    ldax #kCrate2FloatingPositionY
    stax Zp_PointY_i16
    ldx #kCrate2PlatformIndex  ; param: crate platform index
    fall FuncA_Room_CoreSouth_TickCrate
.ENDPROC

;;; Performs per-frame updates for a floating crate in this room.
;;; @prereq Zp_PointY_i16 is set to the floating Y-position for the crate.
;;; @param X The crate platform index.
.PROC FuncA_Room_CoreSouth_TickCrate
_WeighDown:
    ;; If the player avqtar is standing on the crate, shift the goal position
    ;; downward.
    cpx Zp_AvatarPlatformIndex_u8
    bne @done
    lda #7  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    @done:
_BobInWater:
    ;; Make the crate bob up and down in the water.
    txa  ; platform index
    add Zp_RoomState + sState::WaterBobTimer_u8
    div #8
    mod #8
    tay  ; water bob index
    lda _WaterBobOffset_i8_arr8, y  ; param: signed offset
    jsr Func_MovePointVert  ; preserves X
_MoveCrate:
    lda #1  ; param: max move by
    jmp Func_MovePlatformTopTowardPointY
_WaterBobOffset_i8_arr8:
    .byte 1, 1, 0, <-1, <-1, <-1, 0, 1
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_CoreSouthCorraHelping_sCutscene
.PROC DataA_Cutscene_CoreSouthCorraHelping_sCutscene
    act_SetCutsceneFlags bCutscene::RoomTick
    act_SetActorState2 kCorraActorIndex, $ff
    act_RepeatFunc 123, _SwimDownFunc
    act_RepeatFunc 40, _AnimateSwimmingDownFunc
    act_CallFunc _ReleaseCratesFunc
    act_ForkStart 1, _DelayedSecretJingle_sCutscene
    act_RepeatFunc 40, _AnimateSwimmingDownFunc
    act_SetActorFlags kCorraActorIndex, bObj::FlipH
    act_RepeatFunc 82, _SwimUpFunc
    act_SetActorState1 kCorraActorIndex, eNpcAdult::MermaidCorra
    act_WaitFrames 15
    act_SetActorState2 kCorraActorIndex, 0
    act_WaitFrames 15
    act_RunDialog eDialog::CoreSouthCorra
    act_ContinueExploring
_DelayedSecretJingle_sCutscene:
    act_WaitFrames 70
    act_CallFunc Func_PlaySfxSecretUnlocked
    act_ForkStop $ff
_SwimDownFunc:
    lda Ram_ActorSubY_u8_arr + kCorraActorIndex
    add #$80
    sta Ram_ActorSubY_u8_arr + kCorraActorIndex
    lda Ram_ActorPosY_i16_0_arr + kCorraActorIndex
    adc #0
    sta Ram_ActorPosY_i16_0_arr + kCorraActorIndex
    lda Ram_ActorSubX_u8_arr + kCorraActorIndex
    add #$40
    sta Ram_ActorSubX_u8_arr + kCorraActorIndex
    lda Ram_ActorPosX_i16_0_arr + kCorraActorIndex
    adc #0
    sta Ram_ActorPosX_i16_0_arr + kCorraActorIndex
_AnimateSwimmingDownFunc:
    ldy #eNpcAdult::CorraSwimmingDown1
    lda Zp_FrameCounter_u8
    and #$08
    beq @setState1
    ldy #eNpcAdult::CorraSwimmingDown2
    @setState1:
    sty Ram_ActorState1_byte_arr + kCorraActorIndex
    rts
_ReleaseCratesFunc:
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @doneSmoke
    ldy #kAnchor3PlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_InitActorSmokeExplosion
    @doneSmoke:
    jsr Func_PlaySfxPoof
    ldx #eFlag::CoreSouthCorraHelped  ; param: flag
    jmp Func_SetFlag
_SwimUpFunc:
    lda Ram_ActorSubY_u8_arr + kCorraActorIndex
    sub #$c0
    sta Ram_ActorSubY_u8_arr + kCorraActorIndex
    lda Ram_ActorPosY_i16_0_arr + kCorraActorIndex
    sbc #0
    sta Ram_ActorPosY_i16_0_arr + kCorraActorIndex
    lda Ram_ActorSubX_u8_arr + kCorraActorIndex
    sub #$60
    sta Ram_ActorSubX_u8_arr + kCorraActorIndex
    lda Ram_ActorPosX_i16_0_arr + kCorraActorIndex
    sbc #0
    sta Ram_ActorPosX_i16_0_arr + kCorraActorIndex
_AnimateSwimmingUpFunc:
    ldy #eNpcAdult::CorraSwimmingUp1
    lda Zp_FrameCounter_u8
    and #$08
    beq @setState1
    ldy #eNpcAdult::CorraSwimmingUp2
    @setState1:
    sty Ram_ActorState1_byte_arr + kCorraActorIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CoreSouthCorra_sDialog
.PROC DataA_Dialog_CoreSouthCorra_sDialog
    dlg_IfSet CoreSouthCorraHelped, _AlreadyHelped_sDialog
_HelloAgain_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_CoreSouthCorra_HelloAgain1_u8_arr
    dlg_Text MermaidCorra, DataA_Text0_CoreSouthCorra_HelloAgain2_u8_arr
    dlg_Text MermaidCorra, DataA_Text0_CoreSouthCorra_HelloAgain3_u8_arr
    dlg_Cutscene eCutscene::CoreSouthCorraHelping
_AlreadyHelped_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_CoreSouthCorra_AlreadyHelped_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
