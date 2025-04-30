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
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/lever.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/water.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Factory_sTileset
.IMPORT DataA_Text0_FactoryEastCorra_End_u8_arr
.IMPORT DataA_Text0_FactoryEastCorra_Intro_u8_arr
.IMPORT DataA_Text0_FactoryEastCorra_Mid1_u8_arr
.IMPORT DataA_Text0_FactoryEastCorra_Mid2_u8_arr
.IMPORT DataA_Text0_FactoryEastCorra_Mid3_u8_arr
.IMPORT DataA_Text0_FactoryEastCorra_No_u8_arr
.IMPORT DataA_Text0_FactoryEastCorra_Question_u8_arr
.IMPORT DataA_Text0_FactoryEastCorra_Yes_u8_arr
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetWaterObjTileId
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_Noop
.IMPORT Func_PlaySfxLeverOn
.IMPORT Func_PlaySfxSecretUnlocked
.IMPORT Func_PlaySfxSplash
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjGarden
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorSubX_u8_arr
.IMPORT Ram_ActorSubY_u8_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for Corra in this room.
kCorraActorIndex = 0
;;; The talk device indices for Corra in this room.
kCorraDeviceIndexLeft = 1
kCorraDeviceIndexRight = 0

;;; The device index for the underwater lever.
kLeverDeviceIndex = 2

;;; The platform index for the water that can be raised.
kMovableWaterPlatformIndex = 1

;;; The initial and minimum room pixel Y-position for the top of the movable
;;; water platform.
kInitWaterTop = $00d4
kMinWaterTop  = $0094

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the underwater lever.
    Lever_u8       .byte
    ;; If true ($ff), draw the waterfall; if false ($00) don't.
    Waterfall_bool .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Factory"

.EXPORT DataC_Factory_East_sRoom
.PROC DataC_Factory_East_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Factory
    d_byte MinimapStartRow_u8, 6
    d_byte MinimapStartCol_u8, 16
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Factory_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Factory_East_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Factory_East_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/factory_east.room"
    .assert * - :- = 18 * 24, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $80
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0050
    d_word Top_i16,   $0134
    D_END
    .assert * - :- = kMovableWaterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $00c0
    d_word Top_i16, kInitWaterTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kCorraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0080
    d_word PosY_i16, $0138
    d_byte Param_byte, eNpcAdult::MermaidCorra
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $00a8
    d_word PosY_i16, $0058
    d_byte Param_byte, bObj::FlipV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $00b8
    d_word PosY_i16, $0068
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kCorraDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eDialog::FactoryEastCorra
    D_END
    .assert * - :- = kCorraDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eDialog::FactoryEastCorra
    D_END
    .assert * - :- = kLeverDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 6
    d_byte Target_byte, sState::Lever_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::FactoryPass
    d_byte SpawnBlock_u8, 18
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::SewerPool
    d_byte SpawnBlock_u8, 17
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::SewerFaucet
    d_byte SpawnBlock_u8, 13
    d_byte SpawnAdjust_byte, $e9
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Factory_East_EnterRoom
    ;; Corra doesn't appear in this room until you've met up with Alex in
    ;; FactoryVault.
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryVaultTalkedToAlex
    beq @removeCorra
    ;; Once you reach the upper sewers, Corra leaves this room.
    flag_bit Sram_ProgressFlags_arr, eFlag::SewerFaucetEnteredUpperSewer
    beq @keepCorra
    ;; To be safe, set the flag for Corra having helped here if you've already
    ;; reached the city (although normally, it is impossible to reach the city
    ;; without Corra helping here).
    ldx #eFlag::FactoryEastCorraHelped  ; param: flag
    jsr Func_SetFlag
    @removeCorra:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kCorraActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexRight
    @keepCorra:
_Lever:
    ;; If Corra has already helped you in this room, flip the lever and raise
    ;; the water level.
    flag_bit Sram_ProgressFlags_arr, eFlag::FactoryEastCorraHelped
    beq @done
    inc Zp_RoomState + sState::Lever_u8
    .assert >kMinWaterTop = >kInitWaterTop, error
    lda #<kMinWaterTop
    sta Ram_PlatformTop_i16_0_arr + kMovableWaterPlatformIndex
    @done:
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Factory_East_DrawRoom
_DrawWaterfall:
    bit Zp_RoomState + sState::Waterfall_bool
    bpl @done
    ldx #kMovableWaterPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    jsr FuncA_Objects_MoveShapeUpHalfTile
    ;; Determine the waterfall tile ID.
    lda Zp_FrameCounter_u8
    div #2
    mod #4
    sta T2  ; waterfall animation (0-3)
    ;; Draw the waterfall object.
    lda #$14  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    ldy #kPaletteObjWater  ; param: object flags
    lda T2  ; waterfall animation (0-3)
    .assert kTileIdObjPlatformWaterfallFirst .mod 4 = 0, error
    ora #kTileIdObjPlatformWaterfallFirst
    jsr FuncA_Objects_Draw1x1Shape  ; preserves T2+
    ;; Draw the sewage objects.
    ldx #9
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    ldy #kPaletteObjWater  ; param: object flags
    lda T2  ; waterfall animation (0-3)
    .assert kTileIdObjPlatformSewageFirst .mod 4 = 0, error
    ora #kTileIdObjPlatformSewageFirst
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    dex
    bne @loop
    @done:
_DrawWaterSurface:
    ldx #kMovableWaterPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    ;; Draw the water objects.
    jsr FuncA_Objects_GetWaterObjTileId  ; returns A
    sta T2  ; water tile ID
    ldx #6
    @loop:
    ldy #kPaletteObjWater | bObj::Pri  ; param: object flags
    lda T2  ; param: water tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and T0+
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_FactoryEastCorraHelping_sCutscene
.PROC DataA_Cutscene_FactoryEastCorraHelping_sCutscene
    act_SetActorState2 kCorraActorIndex, $ff
    act_SetActorFlags kCorraActorIndex, bObj::FlipH
    act_RepeatFunc 60, _SwimDownFunc
    act_RepeatFunc 40, _AnimateSwimmingDownFunc
    act_CallFunc _FlipLeverFunc
    act_ForkStart 1, _SwimBackUp_sCutscene
    act_WaitFrames 15
    act_CallFunc _TurnOnWaterfallFunc
    act_WaitFrames 10
    act_WaitUntilZ _RaiseWaterLevelFunc
    act_WaitFrames 15
    act_CallFunc _TurnOffWaterfallFunc
    act_WaitFrames 15
    act_RunDialog eDialog::FactoryEastCorra
    act_ContinueExploring
_SwimBackUp_sCutscene:
    act_RepeatFunc 40, _AnimateSwimmingDownFunc
    act_SetActorFlags kCorraActorIndex, 0
    act_RepeatFunc 40, _SwimUpFunc
    act_SetActorState1 kCorraActorIndex, eNpcAdult::MermaidCorra
    act_WaitFrames 15
    act_SetActorState2 kCorraActorIndex, 0
    act_WaitFrames 120
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
    sub #$50
    sta Ram_ActorSubX_u8_arr + kCorraActorIndex
    lda Ram_ActorPosX_i16_0_arr + kCorraActorIndex
    sbc #0
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
_FlipLeverFunc:
    jsr Func_PlaySfxLeverOn
    lda #kLeverAnimCountdown
    sta Ram_DeviceAnim_u8_arr + kLeverDeviceIndex
    inc Zp_RoomState + sState::Lever_u8
    ldx #eFlag::FactoryEastCorraHelped  ; param: flag
    jmp Func_SetFlag
_TurnOnWaterfallFunc:
    dec Zp_RoomState + sState::Waterfall_bool  ; change from $00 to $ff
    jmp Func_PlaySfxSplash
_RaiseWaterLevelFunc:
    lda Zp_FrameCounter_u8
    and #$03
    bne @done
    .assert >kMinWaterTop = >kInitWaterTop, error
    dec Ram_PlatformTop_i16_0_arr + kMovableWaterPlatformIndex
    lda Ram_PlatformTop_i16_0_arr + kMovableWaterPlatformIndex
    cmp #<kMinWaterTop
    @done:
    rts
_TurnOffWaterfallFunc:
    inc Zp_RoomState + sState::Waterfall_bool  ; change from $ff to $00
    rts
_SwimUpFunc:
    lda Ram_ActorSubY_u8_arr + kCorraActorIndex
    sub #$c0
    sta Ram_ActorSubY_u8_arr + kCorraActorIndex
    lda Ram_ActorPosY_i16_0_arr + kCorraActorIndex
    sbc #0
    sta Ram_ActorPosY_i16_0_arr + kCorraActorIndex
    lda Ram_ActorSubX_u8_arr + kCorraActorIndex
    add #$78
    sta Ram_ActorSubX_u8_arr + kCorraActorIndex
    lda Ram_ActorPosX_i16_0_arr + kCorraActorIndex
    adc #0
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

.EXPORT DataA_Dialog_FactoryEastCorra_sDialog
.PROC DataA_Dialog_FactoryEastCorra_sDialog
    dlg_IfSet FactoryEastCorraHelped, _AlreadyHelped_sDialog
_Intro_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_FactoryEastCorra_Intro_u8_arr
    dlg_Text MermaidCorra, DataA_Text0_FactoryEastCorra_Question_u8_arr
    dlg_IfYes _Yes_sDialog
_No_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_FactoryEastCorra_No_u8_arr
    dlg_Goto _OfferHelp_sDialog
_Yes_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_FactoryEastCorra_Yes_u8_arr
_OfferHelp_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_FactoryEastCorra_Mid1_u8_arr
    dlg_Text MermaidCorra, DataA_Text0_FactoryEastCorra_Mid2_u8_arr
    dlg_Text MermaidCorra, DataA_Text0_FactoryEastCorra_Mid3_u8_arr
    dlg_Cutscene eCutscene::FactoryEastCorraHelping
_AlreadyHelped_sDialog:
    dlg_Text MermaidCorra, DataA_Text0_FactoryEastCorra_End_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
