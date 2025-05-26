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
.INCLUDE "../actors/child.inc"
.INCLUDE "../actors/orc.inc"
.INCLUDE "../audio.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/console.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../music.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/core.inc"
.INCLUDE "../platforms/terminal.inc"
.INCLUDE "../portrait.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"
.INCLUDE "../sample.inc"
.INCLUDE "../scroll.inc"

.IMPORT DataA_Room_Outdoors_sTileset
.IMPORT DataA_Text0_TownOutdoorsAlex1_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex2_Part1_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex2_Part2_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex2_Part3_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex3_Attack1_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex3_Attack2_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex3_Explore1_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex3_Explore2_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex3_HandleThis_u8_arr
.IMPORT DataA_Text0_TownOutdoorsAlex3_WhaWhat_u8_arr
.IMPORT DataA_Text0_TownOutdoorsGronta_Search1_u8_arr
.IMPORT DataA_Text0_TownOutdoorsGronta_Search2_u8_arr
.IMPORT DataA_Text0_TownOutdoorsGronta_YesChief_u8_arr
.IMPORT DataA_Text0_TownOutdoorsIvan_Part1_u8_arr
.IMPORT DataA_Text0_TownOutdoorsIvan_Part2_u8_arr
.IMPORT DataA_Text0_TownOutdoorsSandra_Part1_u8_arr
.IMPORT DataA_Text0_TownOutdoorsSandra_Part2_u8_arr
.IMPORT DataA_Text0_TownOutdoorsSign_u8_arr
.IMPORT DataA_Text2_MaybeThisTimeWillBeDifferent_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleGaveRemote3A_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleGaveRemote3B_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleGaveRemote5_Part1_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleGaveRemote5_Part2_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleReactivate3_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleReactivate5A_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleReactivate5B_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater1_Part1_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater1_Part2_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater1_Part3_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater1_Part4_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater1_Part5_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater2_Part1_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater2_Part2_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater3_Part1_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater3_Part2_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater3_Part3_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater3_Part4_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part10_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part1_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part2_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part3_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part4_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part5_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part6_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part7_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part8_u8_arr
.IMPORT DataA_Text2_TownOutdoorsFinaleYearsLater4_Part9_u8_arr
.IMPORT FuncA_Cutscene_Finale_FadeRoomToBlack
.IMPORT FuncA_Cutscene_InitActorSmokeBeam
.IMPORT FuncA_Cutscene_PlaySfxBeam
.IMPORT FuncA_Cutscene_PlaySfxQuickWindup
.IMPORT FuncA_Cutscene_PlaySfxRumbling
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_DrawCoreInnerPlatform
.IMPORT FuncA_Objects_DrawCoreOuterPlatform
.IMPORT FuncA_Objects_DrawTerminalPlatformInFront
.IMPORT FuncA_Objects_MoveShapeRightHalfTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncC_Town_GetScreenTilePpuAddr
.IMPORT FuncC_Town_RaiseCore
.IMPORT Func_AckIrqAndLatchWindowFromParam4
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_HarmAvatar
.IMPORT Func_InitActorBadOrc
.IMPORT Func_InitActorNpcOrc
.IMPORT Func_InitActorWithState1
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxBaddieJump
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_PlaySfxMenuConfirm
.IMPORT Func_PlaySfxMenuMove
.IMPORT Func_PlaySfxSample
.IMPORT Func_PlaySfxThump
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToDeviceCenter
.IMPORT Func_SpawnExplosionAtPoint
.IMPORT MainA_Cutscene_StartEpilogue
.IMPORT MainA_Cutscene_StartNextFinaleStep
.IMPORT Main_LoadPrisonCellAndStartCutscene
.IMPORT Ppu_ChrObjFinale1
.IMPORT Ppu_ChrObjFinale2
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_ScrollGoalX_u16

;;;=========================================================================;;;

;;; The room pixel Y-positions for the top and bottom of the treeline.  These
;;; are the breaks between separate parallax scrolling bands.
kTreelineTopY    = $2e
kTreelineBottomY = $62

;;; The actor indices for the townsfolk in this room.
kAlexActorIndex   = 0
kIvanActorIndex   = 1
kSandraActorIndex = 2
kOrc1ActorIndex   = 1
kOrc2ActorIndex   = 2
kThurgActorIndex  = 3
kHobokActorIndex  = 4
kLauraActorIndex  = 5
kMartinActorIndex = 6
kAnnaActorIndex   = 7
kBorisActorIndex  = 8
kGrontaActorIndex = 9

;;; The device index for the door that leads into TownHouse4.
kTownHouse4DoorDeviceIndex = 4

;;; The room pixel X-position that the Alex actor should be at when kneeling
;;; down to pick up the metal thing he found.
kAlexPickupPositionX = $0590

;;; Initial room pixel positions for the orc actors.
kOrcInitPosY    = $0098
kGrontaInitPosX = $05d7
kOrc1InitPosX   = $05e8
kOrc2InitPosX   = $05f9
kThurgInitPosX  = $0608

;;; Room pixel positions for actors during the finale cutscenes.
kHobokFinalePosX  = $0264
kLauraFinalePosX  = $0284
kMartinFinalePosX = $0276
kThurgFinalePosX  = $02ac

;;; The velocity applied to Thurg when he gets flung by the beam blast, in
;;; subpixels per frame.
kThurgFlingVelX = -400
kThurgFlingVelY = -450

;;; The velocity applied to Hobok when he flinches from the beam blast, in
;;; subpixels per frame.
kHobokFlinchVelX = -400

;;;=========================================================================;;;

;;; The screen tile column for the leftmost BG tile of the core outer platform.
kCoreOuterStartCol = $01

;;; The initial room pixel position for the center of the top edge of the core
;;; inner platform.
kInitCoreTopCenterX = $0328
kInitCoreTopCenterY = $0110

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; Timer for making the second orc jump.
    OrcJumpTimer_u8   .byte
    ;; Timer for making Alex get knocked unconscious.
    AlexSleepTimer_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_Outdoors_sRoom
.PROC DataC_Town_Outdoors_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $500
    d_byte Flags_bRoom, eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 11
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Outdoors_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Town_Outdoors_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Town_Outdoors_TickRoom
    d_addr Draw_func_ptr, FuncC_Town_Outdoors_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/town_outdoors1.room"
    .incbin "out/rooms/town_outdoors2.room"
    .incbin "out/rooms/town_outdoors3.room"
    .assert * - :- = 96 * 15, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kFinalTerminalPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kTerminalPlatformWidthPx
    d_byte HeightPx_u8, kTerminalPlatformHeightPx
    d_word Left_i16, kInitCoreTopCenterX
    d_word Top_i16, kInitCoreTopCenterY - kTerminalPlatformHeightPx
    D_END
    .assert * - :- = kCoreInnerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kCoreInnerPlatformWidthPx
    d_byte HeightPx_u8, $10
    d_word Left_i16, kInitCoreTopCenterX - kCoreInnerPlatformWidthPx / 2
    d_word Top_i16, kInitCoreTopCenterY
    D_END
    .assert * - :- = kCoreOuterPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kCoreOuterPlatformWidthPx
    d_byte HeightPx_u8, $10
    d_word Left_i16, kInitCoreTopCenterX - kCoreOuterPlatformWidthPx / 2
    d_word Top_i16, kInitCoreTopCenterY + kTileHeightPx
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0570
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    .assert * - :- = kIvanActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $02f0
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanManStanding
    D_END
    .assert * - :- = kSandraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0350
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanWomanStanding
    D_END
    .assert * - :- = kThurgActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, kThurgFinalePosX
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcOrc::GruntStanding
    D_END
    .assert * - :- = kHobokActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, kHobokFinalePosX
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcOrc::GruntStanding
    D_END
    .assert * - :- = kLauraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, kLauraFinalePosX
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanWomanStanding
    D_END
    .assert * - :- = kMartinActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, kMartinFinalePosX
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanManStanding
    D_END
    .assert * - :- = kAnnaActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0338
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanAnna
    D_END
    .assert * - :- = kBorisActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0288
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanBorisStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eRoom::TownHouse1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 13
    d_byte Target_byte, eRoom::TownHouse2
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 24
    d_byte Target_byte, eRoom::TownHouse3
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 32
    d_byte Target_byte, eDialog::TownOutdoorsSign
    D_END
    .assert * - :- = kTownHouse4DoorDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 37
    d_byte Target_byte, eRoom::TownHouse4
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 59
    d_byte Target_byte, eRoom::TownHouse5
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 71
    d_byte Target_byte, eRoom::TownHouse6
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 46
    d_byte Target_byte, eDialog::TownOutdoorsIvan
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 47
    d_byte Target_byte, eDialog::TownOutdoorsIvan
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 52
    d_byte Target_byte, eDialog::TownOutdoorsSandra
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 53
    d_byte Target_byte, eDialog::TownOutdoorsSandra
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 86
    d_byte Target_byte, eDialog::TownOutdoorsAlex1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 87
    d_byte Target_byte, eDialog::TownOutdoorsAlex1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Town_Outdoors_EnterRoom
    ;; These actors should always face to the right, rather than facing the
    ;; player avatar.
    dec Ram_ActorState2_byte_arr + kHobokActorIndex   ; now $ff
    dec Ram_ActorState2_byte_arr + kIvanActorIndex    ; now $ff
    dec Ram_ActorState2_byte_arr + kLauraActorIndex   ; now $ff
    dec Ram_ActorState2_byte_arr + kMartinActorIndex  ; now $ff
    dec Ram_ActorState2_byte_arr + kThurgActorIndex   ; now $ff
    ;; Check if a cutscene is playing as the room is entered.  If so, it's for
    ;; the finale.
    ldx Zp_Next_eCutscene
    .assert eCutscene::None = 0, error
    bne _SetUpFinaleCutscene
    ;; Otherwise, set up for normal exploration of this room by removing the
    ;; finale-only actors.
    .assert eActor::None = 0, error
    stx Ram_ActorType_eActor_arr + kAnnaActorIndex
    stx Ram_ActorType_eActor_arr + kBorisActorIndex
    stx Ram_ActorType_eActor_arr + kHobokActorIndex
    stx Ram_ActorType_eActor_arr + kLauraActorIndex
    stx Ram_ActorType_eActor_arr + kMartinActorIndex
    stx Ram_ActorType_eActor_arr + kThurgActorIndex
    rts
_SetUpFinaleCutscene:
    ;; Remove the Alex, Ivan, and Sandra actors for all finale cutscenes.
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    sta Ram_ActorType_eActor_arr + kIvanActorIndex
    sta Ram_ActorType_eActor_arr + kSandraActorIndex
    ;; The YearsLater cutscene is handled a bit differently than the others.
    cpx #eCutscene::TownOutdoorsFinaleYearsLater
    beq _SetUpYearsLaterCutscene
_SetUpGaveRemoteOrReactivateCutscene:
    ;; Remove the Anna and Boris actors for these cutscenes.
    sta Ram_ActorType_eActor_arr + kAnnaActorIndex
    sta Ram_ActorType_eActor_arr + kBorisActorIndex
    ;; Remove the Thurg actor for anything other than the FinaleReactivate5 or
    ;; FinaleGaveRemote5 cutscenes, and remove the Hobok, Laura, and Martin
    ;; actors for anything other than the FinaleGaveRemote5 cutscene.
    cpx #eCutscene::TownOutdoorsFinaleGaveRemote5
    beq @keepAll
    cpx #eCutscene::TownOutdoorsFinaleReactivate5
    beq @keepThurg
    sta Ram_ActorType_eActor_arr + kThurgActorIndex
    @keepThurg:
    sta Ram_ActorType_eActor_arr + kHobokActorIndex
    sta Ram_ActorType_eActor_arr + kLauraActorIndex
    sta Ram_ActorType_eActor_arr + kMartinActorIndex
    @keepAll:
    ;; Change the room's CHR18 bank so that different OBJ tiles can be used for
    ;; the finale than are used normally for this room.
    lda #<.bank(Ppu_ChrObjFinale1)
    sta Zp_Current_sRoom + sRoom::Chr18Bank_u8
    rts
_SetUpYearsLaterCutscene:
    ;; Remove unneeded actors.
    sta Ram_ActorType_eActor_arr + kThurgActorIndex
    sta Ram_ActorType_eActor_arr + kHobokActorIndex
    sta Ram_ActorType_eActor_arr + kLauraActorIndex
    sta Ram_ActorType_eActor_arr + kMartinActorIndex
    ;; Turn Alex's actor into an adult NPC.
    ldya #$02f8
    sta Ram_ActorPosX_i16_0_arr + kAlexActorIndex
    sty Ram_ActorPosX_i16_1_arr + kAlexActorIndex
    ldx #kAlexActorIndex
    lda #eNpcAdult::HumanAlexStanding  ; param: eNpcAdult value
    ldy #eActor::NpcAdult  ; param: actor type
    jsr Func_InitActorWithState1
    dec Ram_ActorState2_byte_arr + kAlexActorIndex  ; now $ff
    ;; Change the room's CHR18 bank so that different OBJ tiles can be used for
    ;; the finale than are used normally for this room.
    lda #<.bank(Ppu_ChrObjFinale2)
    sta Zp_Current_sRoom + sRoom::Chr18Bank_u8
    rts
.ENDPROC

.PROC FuncC_Town_Outdoors_TickRoom
_MakeOrcJump:
    lda Zp_RoomState + sState::OrcJumpTimer_u8
    beq @done
    dec Zp_RoomState + sState::OrcJumpTimer_u8
    bne @done
    ldx #kOrc2ActorIndex
    jsr FuncC_Town_Outdoors_MakeOrcJump  ; unconditional
    @done:
_KnockOutAlex:
    lda Zp_RoomState + sState::AlexSleepTimer_u8
    beq @done
    dec Zp_RoomState + sState::AlexSleepTimer_u8
    bne @done
    lda #eNpcChild::AlexSleeping
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    jsr Func_PlaySfxThump
    @done:
_DetectAvatarDeath:
    ;; If the player avatar would die (because they were caught by the orcs;
    ;; there's no other way to die in this room), then prevent the death and
    ;; instead start the cutscene for getting caught.
    lda Zp_AvatarHarmTimer_u8
    cmp #kAvatarHarmDeath
    bne @done
    lda #0
    sta Zp_AvatarHarmTimer_u8
    jsr Func_HarmAvatar
    lda #eSample::Death  ; param: eSample to play
    jsr Func_PlaySfxSample
    lda #bMusic::UsesFlag | bMusic::FlagMask
    sta Zp_Next_sAudioCtrl + sAudioCtrl::MusicFlag_bMusic
    lda #eCutscene::TownOutdoorsGetCaught
    sta Zp_Next_eCutscene
    @done:
    rts
.ENDPROC

;;; Draw function for the TownOutdoors room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Town_Outdoors_DrawRoom
_SetUpIrq:
    ;; Fix the horizontal scrolling position for the top of the screen, so that
    ;; the stars and moon don't scroll.
    lda #0
    sta Zp_PpuScrollX_u8
    ;; Compute the IRQ latch value to set between the bottom of the treeline
    ;; and the top of the window (if any), and set that as Param4_byte.
    lda Zp_Buffered_sIrq + sIrq::Latch_u8
    sub #kTreelineBottomY
    add Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Param4_byte  ; window latch
    ;; Set up our own sIrq struct to handle parallax scrolling.
    lda #kTreelineTopY - 1
    sub Zp_RoomScrollY_u8
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_TownOutdoorsTreeTopIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    ;; Compute the PPU scroll-X for the treeline (which scrolls horizontally at
    ;; 1/4 speed) and houses (which scroll at full speed), and set those as
    ;; Param1_byte and Param2_byte, respectively.
    lda Zp_RoomScrollX_u16 + 1
    lsr a
    sta T0
    lda Zp_RoomScrollX_u16 + 0
    sta Zp_Buffered_sIrq + sIrq::Param2_byte  ; houses scroll-X
    ror a
    lsr T0
    ror a
    sta Zp_Buffered_sIrq + sIrq::Param1_byte  ; treeline scroll-X
_CorePlatforms:
    jsr FuncA_Objects_DrawCoreOuterPlatform
    jsr FuncA_Objects_DrawCoreInnerPlatform
_FinalTerminal:
    ldx #kFinalTerminalPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeRightHalfTile  ; preserves X
    lda #kTileIdObjScreen  ; param: tile ID
    ldy #kPaletteObjScreen ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    jmp FuncA_Objects_DrawTerminalPlatformInFront
.ENDPROC

;;; Make the specified orc actor jump to the left.
;;; @param X The actor index.
.PROC FuncC_Town_Outdoors_MakeOrcJump
    lda #eBadOrc::Jumping
    sta Ram_ActorState1_byte_arr, x  ; current mode
    lda #<-kOrcMaxRunSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>-kOrcMaxRunSpeed
    sta Ram_ActorVelX_i16_1_arr, x
    lda #<kOrcJumpVelocity
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kOrcJumpVelocity
    sta Ram_ActorVelY_i16_1_arr, x
    jmp Func_PlaySfxBaddieJump
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TownOutdoorsAlex1_sDialog
.PROC DataA_Dialog_TownOutdoorsAlex1_sDialog
    dlg_Text ChildAlex, DataA_Text0_TownOutdoorsAlex1_u8_arr
    dlg_Cutscene eCutscene::TownOutdoorsOrcAttack
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsAlex2_sDialog
.PROC DataA_Dialog_TownOutdoorsAlex2_sDialog
    dlg_Text ChildAlex, DataA_Text0_TownOutdoorsAlex2_Part1_u8_arr
    dlg_Call _AlexStanding
    dlg_Text ChildAlexHand, DataA_Text0_TownOutdoorsAlex2_Part2_u8_arr
    dlg_Text ChildAlexHand, DataA_Text0_TownOutdoorsAlex2_Part3_u8_arr
    dlg_Done
_AlexStanding:
    lda #eNpcChild::AlexStanding
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    rts
.ENDPROC

;;; @prereq PRGC_Town is loaded.
.EXPORT DataA_Dialog_TownOutdoorsAlex3_sDialog
.PROC DataA_Dialog_TownOutdoorsAlex3_sDialog
    .assert kTileIdBgPortraitGrontaFirst = kTileIdBgPortraitAlexFirst, error
    dlg_Text ChildAlex, DataA_Text0_TownOutdoorsAlex3_Explore1_u8_arr
    dlg_Text ChildAlex, DataA_Text0_TownOutdoorsAlex3_Explore2_u8_arr
    dlg_Call _SilenceMusic
    dlg_Call FuncA_Dialog_OutdoorsScrollOrcsIntoView
    dlg_Text OrcGronta, DataA_Text0_TownOutdoorsAlex3_HandleThis_u8_arr
    dlg_Call _TurnKidsAround
    dlg_Text ChildAlex, DataA_Text0_TownOutdoorsAlex3_WhaWhat_u8_arr
    dlg_Call _RaiseGrontaAxe
    dlg_Text OrcGrontaShout, DataA_Text0_TownOutdoorsAlex3_Attack1_u8_arr
    dlg_Call _StartAttackMusic
    dlg_Text ChildAlexShout, DataA_Text0_TownOutdoorsAlex3_Attack2_u8_arr
    dlg_Call _MakeOrcGruntsJump
    dlg_Done
_SilenceMusic:
    lda #eMusic::Silence
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    rts
_TurnKidsAround:
    ;; Make Anna turn to face the orcs.
    lda #kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    ;; Make Alex turn and look up at the orcs.
    lda #eNpcChild::AlexLooking
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    lda #0
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    rts
_RaiseGrontaAxe:
    lda #eNpcOrc::GrontaAxeRaised
    sta Ram_ActorState1_byte_arr + kGrontaActorIndex
    rts
_StartAttackMusic:
    lda #eMusic::Attack
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    lda #bMusic::UsesFlag | 0
    sta Zp_Next_sAudioCtrl + sAudioCtrl::MusicFlag_bMusic
    rts
_MakeOrcGruntsJump:
    lda #30
    sta Zp_RoomState + sState::OrcJumpTimer_u8
    lda #75
    sta Zp_RoomState + sState::AlexSleepTimer_u8
    ldx #kOrc1ActorIndex
    jmp FuncC_Town_Outdoors_MakeOrcJump
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsGronta_sDialog
.PROC DataA_Dialog_TownOutdoorsGronta_sDialog
    .assert kTileIdBgPortraitGrontaFirst = kTileIdBgPortraitOrcFirst, error
    dlg_Call FuncA_Dialog_OutdoorsScrollOrcsIntoView
    dlg_Text OrcGronta, DataA_Text0_TownOutdoorsGronta_Search1_u8_arr
    dlg_Text OrcGronta, DataA_Text0_TownOutdoorsGronta_Search2_u8_arr
    dlg_Call _MakeThurgSalute
    dlg_Text OrcMaleShout, DataA_Text0_TownOutdoorsGronta_YesChief_u8_arr
    dlg_Call _LockScrolling
    dlg_Done
_MakeThurgSalute:
    lda #eNpcOrc::GruntThrowing1
    sta Ram_ActorState1_byte_arr + kThurgActorIndex
    rts
_LockScrolling:
    lda #bScroll::LockHorz
    sta Zp_Camera_bScroll
    rts
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsIvan_sDialog
.PROC DataA_Dialog_TownOutdoorsIvan_sDialog
    dlg_Text AdultMan, DataA_Text0_TownOutdoorsIvan_Part1_u8_arr
    dlg_Call _FaceAnna
    dlg_Text AdultMan, DataA_Text0_TownOutdoorsIvan_Part2_u8_arr
    dlg_Call _FaceSandra
    dlg_Done
_FaceAnna:
    lda #0
    beq _SetFace  ; unconditional
_FaceSandra:
    lda #$ff
_SetFace:
    sta Ram_ActorState2_byte_arr + kIvanActorIndex
    rts
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsSandra_sDialog
.PROC DataA_Dialog_TownOutdoorsSandra_sDialog
    dlg_Text AdultWoman, DataA_Text0_TownOutdoorsSandra_Part1_u8_arr
    dlg_Text AdultWoman, DataA_Text0_TownOutdoorsSandra_Part2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsSign_sDialog
.PROC DataA_Dialog_TownOutdoorsSign_sDialog
    dlg_Text Sign, DataA_Text0_TownOutdoorsSign_u8_arr
    dlg_Done
.ENDPROC

;;; Sets Zp_ScrollGoalX_u16 to make Gronta (and the orcs next to her) visible.
.PROC FuncA_Dialog_OutdoorsScrollOrcsIntoView
    ldax #$0500
    stax Zp_ScrollGoalX_u16
    rts
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleGaveRemote3A_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleGaveRemote3A_sDialog
    dlg_Text OrcMaleShout, DataA_Text2_TownOutdoorsFinaleGaveRemote3A_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleGaveRemote3B_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleGaveRemote3B_sDialog
    dlg_Text AdultWoman, DataA_Text2_TownOutdoorsFinaleGaveRemote3B_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleGaveRemote5_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleGaveRemote5_sDialog
    .linecont +
    .assert kTileIdBgPortraitWomanFirst = kTileIdBgPortraitGrontaFirst, error
    dlg_Text AdultWomanShout, \
             DataA_Text2_TownOutdoorsFinaleGaveRemote5_Part1_u8_arr
    dlg_Text OrcGrontaShout, \
             DataA_Text2_TownOutdoorsFinaleGaveRemote5_Part2_u8_arr
    dlg_Done
    .linecont -
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleReactivate3_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleReactivate3_sDialog
    dlg_Text OrcMaleShout, DataA_Text2_TownOutdoorsFinaleReactivate3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleReactivate5A_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleReactivate5A_sDialog
    dlg_Text OrcMaleShout, DataA_Text2_TownOutdoorsFinaleReactivate5A_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleReactivate5B_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleReactivate5B_sDialog
    dlg_Text AdultWoman, DataA_Text2_TownOutdoorsFinaleReactivate5B_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleYearsLater1_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleYearsLater1_sDialog
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater1_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater1_Part2_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexFaceLeft
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater1_Part3_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexFaceRight
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater1_Part4_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexSad
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater1_Part5_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleYearsLater2_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleYearsLater2_sDialog
    .linecont +
    .assert kTileIdBgPortraitWomanFirst = kTileIdBgPortraitAlexFirst, error
    dlg_Text AdultWomanShout, \
             DataA_Text2_TownOutdoorsFinaleYearsLater2_Part1_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexStand
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexFaceLeft
    dlg_Text ChildAlexShout, \
             DataA_Text2_TownOutdoorsFinaleYearsLater2_Part2_u8_arr
    dlg_Done
    .linecont -
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleYearsLater3_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleYearsLater3_sDialog
    .assert kTileIdBgPortraitBorisFirst = kTileIdBgPortraitAlexFirst, error
    dlg_Text AdultBoris, DataA_Text2_TownOutdoorsFinaleYearsLater3_Part1_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexSad
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater3_Part2_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexStand
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater3_Part3_u8_arr
    dlg_Text AdultBoris, DataA_Text2_TownOutdoorsFinaleYearsLater3_Part4_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleYearsLater4_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleYearsLater4_sDialog
    .linecont +
    .assert kTileIdBgPortraitBorisFirst = kTileIdBgPortraitAlexFirst, error
    dlg_Text AdultBoris, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part1_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeBorisGive
    dlg_Text AdultBoris, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part2_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexTake
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part3_u8_arr
    dlg_Text ChildAlexHand, \
             DataA_Text2_TownOutdoorsFinaleYearsLater4_Part4_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeBorisStand
    dlg_Text AdultBoris, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part5_u8_arr
    dlg_Text AdultBoris, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part6_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexStand
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part7_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexFaceRight
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part8_u8_arr
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part9_u8_arr
    dlg_Call FuncA_Dialog_TownOutdoors_MakeAlexFaceLeft
    dlg_Text ChildAlex, DataA_Text2_TownOutdoorsFinaleYearsLater4_Part10_u8_arr
    dlg_Done
    .linecont -
.ENDPROC

.EXPORT DataA_Dialog_TownOutdoorsFinaleYearsLater5_sDialog
.PROC DataA_Dialog_TownOutdoorsFinaleYearsLater5_sDialog
    dlg_Text ChildAlex, DataA_Text2_MaybeThisTimeWillBeDifferent_u8_arr
    dlg_Done
.ENDPROC

;;; Sets the Alex actor's flags to bObj::FlipH.
.PROC FuncA_Dialog_TownOutdoors_MakeAlexFaceLeft
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    rts
.ENDPROC

;;; Sets the Alex actor's flags to 0.
.PROC FuncA_Dialog_TownOutdoors_MakeAlexFaceRight
    lda #0
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    rts
.ENDPROC

;;; Sets the Alex actor's State1 to eNpcAdult::HumanAlexSad.
.PROC FuncA_Dialog_TownOutdoors_MakeAlexSad
    lda #eNpcAdult::HumanAlexSad
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    rts
.ENDPROC

;;; Sets the Alex actor's State1 to eNpcAdult::HumanAlexStanding.
.PROC FuncA_Dialog_TownOutdoors_MakeAlexStand
    lda #eNpcAdult::HumanAlexStanding
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    rts
.ENDPROC

;;; Sets the Alex actor's State1 to eNpcAdult::HumanAlexTaking.
.PROC FuncA_Dialog_TownOutdoors_MakeAlexTake
    lda #eNpcAdult::HumanAlexTaking
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    rts
.ENDPROC

;;; Sets the Boris actor's State1 to eNpcAdult::HumanBorisGiving.
.PROC FuncA_Dialog_TownOutdoors_MakeBorisGive
    lda #eNpcAdult::HumanBorisGiving
    sta Ram_ActorState1_byte_arr + kBorisActorIndex
    rts
.ENDPROC

;;; Sets the Boris actor's State1 to eNpcAdult::HumanBorisStanding.
.PROC FuncA_Dialog_TownOutdoors_MakeBorisStand
    lda #eNpcAdult::HumanBorisStanding
    sta Ram_ActorState1_byte_arr + kBorisActorIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_TownOutdoorsOrcAttack_sCutscene
.PROC DataA_Cutscene_TownOutdoorsOrcAttack_sCutscene
    act_CallFunc _RemoveDevicesAndTownsfolk
    act_MoveNpcAlexWalk kAlexActorIndex, kAlexPickupPositionX
    ;; Animate Alex bending down, picking something up, then turning around and
    ;; showing it to Anna.
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexKneeling
    act_WaitFrames 60
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 20
    act_SetActorFlags kAlexActorIndex, bObj::FlipH
    act_WaitFrames 20
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexHolding
    act_WaitFrames 30
    act_RunDialog eDialog::TownOutdoorsAlex2
    ;; Animate Alex and Anna looking up at the stars.
    act_ForkStart 1, _Scroll_sCutscene
    act_SetActorFlags kAlexActorIndex, bObj::FlipH
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexLooking
    act_WaitFrames 70
    act_SetAvatarFlags bObj::FlipH | kPaletteObjAvatarNormal
    act_SetAvatarPose eAvatar::Looking
    act_WaitFrames 60
    ;; TODO: Make a star twinkle in the sky.
    act_WaitFrames 120
    act_CallFunc _InitOrcs
    act_RunDialog eDialog::TownOutdoorsAlex3
    act_SetActorState1 kGrontaActorIndex, eNpcOrc::GrontaStanding
    act_ContinueExploring
_Scroll_sCutscene:
    act_WaitFrames 15
    act_ScrollSlowX $04c0
    act_ForkStop $ff
_RemoveDevicesAndTownsfolk:
    ;; Remove all devices from the room (so that the player can't start dialog
    ;; or run into a building once the orcs attack).
    ldx #kMaxDevices - 1
    lda #eDevice::None
    @loop:
    sta Ram_DeviceType_eDevice_arr, x
    dex
    bpl @loop
    ;; Remove the other townsfolk (other than Alex).
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kIvanActorIndex
    sta Ram_ActorType_eActor_arr + kSandraActorIndex
    rts
_InitOrcs:
    ldax #kGrontaInitPosX
    stx Ram_ActorPosX_i16_0_arr + kGrontaActorIndex
    sta Ram_ActorPosX_i16_1_arr + kGrontaActorIndex
    .assert >kOrc1InitPosX = >kGrontaInitPosX, error
    ldx #<kOrc1InitPosX
    stx Ram_ActorPosX_i16_0_arr + kOrc1ActorIndex
    sta Ram_ActorPosX_i16_1_arr + kOrc1ActorIndex
    .assert >kOrc2InitPosX = >kOrc1InitPosX, error
    ldx #<kOrc2InitPosX
    stx Ram_ActorPosX_i16_0_arr + kOrc2ActorIndex
    sta Ram_ActorPosX_i16_1_arr + kOrc2ActorIndex
    ldax #kOrcInitPosY
    stx Ram_ActorPosY_i16_0_arr + kGrontaActorIndex
    sta Ram_ActorPosY_i16_1_arr + kGrontaActorIndex
    stx Ram_ActorPosY_i16_0_arr + kOrc1ActorIndex
    sta Ram_ActorPosY_i16_1_arr + kOrc1ActorIndex
    stx Ram_ActorPosY_i16_0_arr + kOrc2ActorIndex
    sta Ram_ActorPosY_i16_1_arr + kOrc2ActorIndex
    ldx #kGrontaActorIndex  ; param: actor index
    lda #eNpcOrc::GrontaStanding  ; param: eNpcOrc value
    jsr Func_InitActorNpcOrc
    ldx #kOrc1ActorIndex  ; param: actor index
    lda #bObj::FlipH  ; param: actor flags
    jsr Func_InitActorBadOrc
    ldx #kOrc2ActorIndex  ; param: actor index
    lda #bObj::FlipH  ; param: actor flags
    jmp Func_InitActorBadOrc
.ENDPROC

.EXPORT DataA_Cutscene_TownOutdoorsGetCaught_sCutscene
.PROC DataA_Cutscene_TownOutdoorsGetCaught_sCutscene
    act_SetCutsceneFlags bCutscene::AvatarRagdoll
    act_WaitUntilZ _AnnaHasLanded
    act_SetCutsceneFlags 0
    act_SetAvatarState 0
    act_SetAvatarVelX 0
    act_CallFunc _SetHarmTimer
    act_SetAvatarFlags kPaletteObjAvatarNormal | bObj::FlipH
    act_SetAvatarPose eAvatar::Slumping
    act_WaitFrames 4
    act_CallFunc Func_PlaySfxThump
    act_SetAvatarPose eAvatar::Sleeping
    act_WaitFrames 30
    act_CallFunc _InitThurgAndHobok
    act_MoveNpcOrcWalk kThurgActorIndex, kOrc1InitPosX
    act_SetActorState1 kThurgActorIndex, eNpcOrc::GruntStanding
    act_MoveNpcOrcWalk kHobokActorIndex, kOrc2InitPosX
    act_SetActorState1 kHobokActorIndex, eNpcOrc::GruntStanding
    act_WaitFrames 60
    act_RunDialog eDialog::TownOutdoorsGronta
    act_JumpToMain Main_LoadPrisonCellAndStartCutscene
_AnnaHasLanded:
    lda Zp_AvatarState_bAvatar
    and #bAvatar::Airborne
    rts
_SetHarmTimer:
    lda #kAvatarHarmHealFrames - kAvatarHarmInvincibleFrames - 1
    sta Zp_AvatarHarmTimer_u8
    rts
_InitThurgAndHobok:
    ldx #kThurgActorIndex  ; param: actor index
    jsr @init
    ldx #kHobokActorIndex  ; param: actor index
    @init:
    lda #<kThurgInitPosX
    sta Ram_ActorPosX_i16_0_arr, x
    lda #>kThurgInitPosX
    sta Ram_ActorPosX_i16_1_arr, x
    lda #<kOrcInitPosY
    sta Ram_ActorPosY_i16_0_arr, x
    lda #>kOrcInitPosY
    sta Ram_ActorPosY_i16_1_arr, x
    lda #eNpcOrc::GruntStanding  ; param: eNpcOrc value
    jmp Func_InitActorNpcOrc
.ENDPROC

;;; Called from DataA_Cutscene_TownOutdoorsFinaleGaveRemote1_sCutscene to
;;; initialize the Gronta NPC actor.
.PROC FuncA_Cutscene_TownOutdoors_InitGrontaForFinale
    ldx #kGrontaActorIndex  ; param: actor index
    lda #eNpcOrc::GrontaStanding  ; param: eNpcOrc value
    jmp Func_InitActorNpcOrc
.ENDPROC

;;; @prereq PRGC_Town is loaded.
.EXPORT DataA_Cutscene_TownOutdoorsFinaleGaveRemote1_sCutscene
.PROC DataA_Cutscene_TownOutdoorsFinaleGaveRemote1_sCutscene
    act_SetActorPosX kGrontaActorIndex, $0320
    act_SetActorPosY kGrontaActorIndex, $0108
    act_CallFunc FuncA_Cutscene_TownOutdoors_InitGrontaForFinale
    act_SetActorState2 kGrontaActorIndex, $ff
    act_SetActorFlags kGrontaActorIndex, bObj::FlipH
    fall DataA_Cutscene_TownOutdoorsFinaleReactivate1_sCutscene
.ENDPROC

;;; @prereq PRGC_Town is loaded.
.EXPORT DataA_Cutscene_TownOutdoorsFinaleReactivate1_sCutscene
.PROC DataA_Cutscene_TownOutdoorsFinaleReactivate1_sCutscene
    act_WaitFrames 60
    act_ForkStart 1, _ExplodeGround_sCutscene
    act_WaitFrames 15
    act_SetAvatarPosX $0320
    act_SetAvatarPosY $0108
    act_RepeatFunc kCorePlatformSlowdown * 53, _RaiseCore
    act_RepeatFunc kCorePlatformSlowdown * 53, _RaiseCore
    act_JumpToMain MainA_Cutscene_StartNextFinaleStep
_RaiseCore:
    ldy #kCoreOuterStartCol  ; param: first screen tile column
    jmp FuncC_Town_RaiseCore
_ExplodeGround_sCutscene:
    act_CallFunc _ExplodeGround1
    act_WaitFrames 10
    act_CallFunc _ExplodeGround2
    act_WaitFrames 10
    act_CallFunc _ExplodeGround3
    act_WaitFrames 10
    act_CallFunc _ExplodeGround4
    act_WaitFrames 10
    act_CallFunc _ExplodeGround5
    act_WaitFrames 10
    act_CallFunc _ExplodeGround6
    act_WaitFrames 10
    @rumble:
    act_CallFunc _PlayRumblingSound
    act_WaitFrames 4
    act_ForkStart 1, @rumble
_ExplodeGround1:
    ldy #4  ; param: left-hand screen tile column
    lda #5  ; param: right-hand screen tile column
    bne _ExplodeGroundLeftAndRight  ; unconditional
_ExplodeGround2:
    ldy #3  ; param: left-hand screen tile column
    lda #6  ; param: right-hand screen tile column
    bne _ExplodeGroundLeftAndRight  ; unconditional
_ExplodeGround3:
    ldy #2  ; param: left-hand screen tile column
    lda #7  ; param: right-hand screen tile column
    bne _ExplodeGroundLeftAndRight  ; unconditional
_ExplodeGround4:
    ldy #1  ; param: left-hand screen tile column
    lda #8  ; param: right-hand screen tile column
    bne _ExplodeGroundLeftAndRight  ; unconditional
_ExplodeGround5:
    ldy #0  ; param: left-hand screen tile column
    lda #9  ; param: right-hand screen tile column
    bne _ExplodeGroundLeftAndRight  ; unconditional
_ExplodeGround6:
    ldy #31  ; param: left-hand screen tile column
    lda #10  ; param: right-hand screen tile column
    fall _ExplodeGroundLeftAndRight
_ExplodeGroundLeftAndRight:
    pha     ; right-hand screen tile column
    sty T3  ; left-hand screen tile column
    jsr _ExplodeGroundAtScreenCol  ; preserves T3+
    pla     ; right-hand screen tile column
    add #1  ; param: screen tile column
    jsr _AddRocksAtScreenCol  ; preserves T3+
    lda T3  ; param: left-hand screen tile column
    jsr _ExplodeGroundAtScreenCol  ; preserves T3+
    ldx T3  ; left-hand screen tile column
    dex
    txa     ; param: screen tile column
    mod #kScreenWidthTiles
    fall _AddRocksAtScreenCol
_AddRocksAtScreenCol:
    ldx #27  ; param: first screen tile row
    jsr FuncA_Cutscene_AllocGroundColTransfer  ; preserves T3+, returns X
    lda #$10
    sta Ram_PpuTransfer_arr + 4, x
    sta Ram_PpuTransfer_arr + 6, x
    lda #$11
    sta Ram_PpuTransfer_arr + 5, x
    rts
_ExplodeGroundAtScreenCol:
    ;; Clear ground BG tiles for the column being exploded.
    pha  ; screen tile column
    ldx #25  ; param: screen tile row
    jsr FuncA_Cutscene_AllocGroundColTransfer  ; preserves T3+, returns X and Y
    lda #' '
    @loop:
    sta Ram_PpuTransfer_arr + 4, x
    inx
    dey
    bne @loop
    ;; Spawn a pair of explosion actors centered on the column.
    pla  ; screen tile column
    mul #kTileWidthPx  ; also clears C for the ADC below
    adc #kTileWidthPx / 2
    sta Zp_PointX_i16 + 0
    lda #$03
    sta Zp_PointX_i16 + 1
    ldya #$00d0
    stya Zp_PointY_i16
    jsr Func_SpawnExplosionAtPoint
    lda #$10  ; param: offset
    jsr Func_MovePointDownByA
    jsr Func_SpawnExplosionAtPoint
    jmp Func_PlaySfxExplodeBig
_PlayRumblingSound:
    lda #60  ; param: frames
    jmp FuncA_Cutscene_PlaySfxRumbling
.ENDPROC

;;; Allocates a PPU transfer entry to draw BG tiles for one tile column of
;;; ground terrain, starting at the specified screen tile column and row in the
;;; upper nametable and extending down through the bottom tile row of the
;;; nametable, and fills the entry header.  The caller must fill in the payload
;;; of this entry.
;;; @prereq PRGC_Town is loaded.
;;; @param A The screen tile column.
;;; @param X The starting screen tile row.
;;; @return X The byte index into Ram_PpuTransfer_arr for the start of the
;;;     entry (including the entry header).
;;; @return Y The length of the transfer entry payload.
;;; @preserve T3+
.PROC FuncA_Cutscene_AllocGroundColTransfer
    stx T2  ; first screen tile row
    jsr FuncC_Town_GetScreenTilePpuAddr  ; preserves T2+, returns YA
    ldx Zp_PpuTransferLen_u8
    sta Ram_PpuTransfer_arr + 2, x
    tya  ; PPU addr (hi)
    sta Ram_PpuTransfer_arr + 1, x
    lda #kPpuCtrlFlagsVert
    sta Ram_PpuTransfer_arr + 0, x
    lda #kScreenHeightTiles
    sub T2  ; screen tile row
    sta Ram_PpuTransfer_arr + 3, x
    tay  ; transfer payload length in bytes
    add #4  ; to account for transfer entry header
    adc Zp_PpuTransferLen_u8  ; carry is already clear
    sta Zp_PpuTransferLen_u8
    rts
.ENDPROC

.EXPORT DataA_Cutscene_TownOutdoorsFinaleGaveRemote3_sCutscene
.PROC DataA_Cutscene_TownOutdoorsFinaleGaveRemote3_sCutscene
    act_WaitFrames 60
    ;; Thurg exits the house and walks forward, then calls out a greeting to
    ;; Gronta.
    act_CallFunc FuncA_Cutscene_InitThurgAtHouseDoor4
    act_WaitFrames 30
    act_MoveNpcOrcWalk kThurgActorIndex, kThurgFinalePosX
    act_SetActorState1 kThurgActorIndex, eNpcOrc::GruntStanding
    act_WaitFrames 20
    act_SetActorState1 kThurgActorIndex, eNpcOrc::GruntThrowing1
    act_RunDialog eDialog::TownOutdoorsFinaleGaveRemote3A
    act_WaitFrames 60
    ;; Hobok exits the house, and stands aside to let the humans out.
    act_CallFunc FuncA_Cutscene_InitHobokAtHouseDoor4
    act_WaitFrames 10
    act_MoveNpcOrcWalk kHobokActorIndex, $0248
    act_SetActorState1 kHobokActorIndex, eNpcOrc::GruntStanding
    act_SetActorFlags kHobokActorIndex, 0
    act_WaitFrames 20
    ;; Laura and Martin exit the house and walk forward.
    act_ForkStart 1, _LauraExitsHouse_sCutscene
    act_WaitFrames 16
    act_ForkStart 2, _MartinExitsHouse_sCutscene
    ;; Hobok moves forward to stay behind the humans.
    act_MoveNpcOrcWalk kHobokActorIndex, kHobokFinalePosX
    act_SetActorState1 kHobokActorIndex, eNpcOrc::GruntStanding
    ;; Laura speaks up, asking what's happening.
    act_WaitFrames 30
    act_RunDialog eDialog::TownOutdoorsFinaleGaveRemote3B
    act_WaitFrames 60
    act_JumpToMain MainA_Cutscene_StartNextFinaleStep
_LauraExitsHouse_sCutscene:
    act_CallFunc FuncA_Cutscene_InitLauraAtHouseDoor4
    act_MoveNpcAdultWalk kLauraActorIndex, kLauraFinalePosX
    act_SetActorState1 kLauraActorIndex, eNpcAdult::HumanWomanStanding
    act_ForkStop $ff
_MartinExitsHouse_sCutscene:
    act_CallFunc FuncA_Cutscene_InitMartinAtHouseDoor4
    act_MoveNpcAdultWalk kMartinActorIndex, kMartinFinalePosX
    act_SetActorState1 kMartinActorIndex, eNpcAdult::HumanManStanding
    act_ForkStop $ff
.ENDPROC

.EXPORT DataA_Cutscene_TownOutdoorsFinaleReactivate3_sCutscene
.PROC DataA_Cutscene_TownOutdoorsFinaleReactivate3_sCutscene
    act_WaitFrames 60
    ;; Thurg exits the house and walks forward, then demands to know what's
    ;; happening.
    act_CallFunc FuncA_Cutscene_InitThurgAtHouseDoor4
    act_WaitFrames 30
    act_MoveNpcOrcWalk kThurgActorIndex, kThurgFinalePosX
    act_SetActorState1 kThurgActorIndex, eNpcOrc::GruntStanding
    act_WaitFrames 30
    act_RunDialog eDialog::TownOutdoorsFinaleReactivate3
    act_WaitFrames 60
    act_JumpToMain MainA_Cutscene_StartNextFinaleStep
.ENDPROC

;;; Initializes the Hobok actor as an orc NPC positioned at the door in
;;; TownOutdoors that leads from TownHouse4.
.PROC FuncA_Cutscene_InitHobokAtHouseDoor4
    ldx #kHobokActorIndex  ; param: actor index
    .assert kHobokActorIndex < $80, error
    bpl FuncA_Cutscene_InitOrcAtHouseDoor4  ; unconditional
.ENDPROC

;;; Initializes the Thrug actor as an orc NPC positioned at the door in
;;; TownOutdoors that leads from TownHouse4.
.PROC FuncA_Cutscene_InitThurgAtHouseDoor4
    ldx #kThurgActorIndex  ; param: actor index
    fall FuncA_Cutscene_InitOrcAtHouseDoor4
.ENDPROC

;;; Initializes an orc NPC actor positioned at the door in TownOutdoors that
;;; leads from TownHouse4.
;;; @param X The actor index.
.PROC FuncA_Cutscene_InitOrcAtHouseDoor4
    ldy #kTownHouse4DoorDeviceIndex  ; param: device index
    jsr Func_SetPointToDeviceCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #eNpcOrc::GruntStanding  ; param: eNpcOrc value
    jmp Func_InitActorNpcOrc
.ENDPROC

;;; Initializes the Laura actor as an adult NPC positioned at the door in
;;; TownOutdoors that leads from TownHouse4.
.PROC FuncA_Cutscene_InitLauraAtHouseDoor4
    lda #eNpcAdult::HumanWomanStanding  ; param: eNpcAdult value
    ldx #kLauraActorIndex  ; param: actor index
    .assert kLauraActorIndex < $80, error
    bpl FuncA_Cutscene_InitAdultAtHouseDoor4  ; unconditional
.ENDPROC

;;; Initializes the Margin actor as an adult NPC positioned at the door in
;;; TownOutdoors that leads from TownHouse4.
.PROC FuncA_Cutscene_InitMartinAtHouseDoor4
    lda #eNpcAdult::HumanManStanding  ; param: eNpcAdult value
    ldx #kMartinActorIndex  ; param: actor index
    fall FuncA_Cutscene_InitAdultAtHouseDoor4
.ENDPROC

;;; Initializes an adult NPC actor positioned at the door in TownOutdoors that
;;; leads from TownHouse4.
;;; @param A The eNpcAdult value.
;;; @param X The actor index.
.PROC FuncA_Cutscene_InitAdultAtHouseDoor4
    pha  ; eNpcAdult value
    ldy #kTownHouse4DoorDeviceIndex  ; param: device index
    jsr Func_SetPointToDeviceCenter  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    pla  ; param: eNpcAdult value
    ldy #eActor::NpcAdult  ; param: actor type
    jmp Func_InitActorWithState1
.ENDPROC

.EXPORT DataA_Cutscene_TownOutdoorsFinaleGaveRemote5_sCutscene
.PROC DataA_Cutscene_TownOutdoorsFinaleGaveRemote5_sCutscene
    ;; Laura protests, and Gronta shouts at them to leave.
    act_WaitFrames 30
    act_RunDialog eDialog::TownOutdoorsFinaleGaveRemote5
    ;; Thurg turns around to glare at the humans.
    act_WaitFrames 15
    act_SetActorFlags kThurgActorIndex, bObj::FlipH
    act_WaitFrames 45
    ;; Hobok pushes Martin back.
    act_ForkStart 1, _MartinGetsPushed_sCutscene
    act_MoveNpcOrcWalk kHobokActorIndex, kMartinFinalePosX + 0
    act_SetActorState1 kHobokActorIndex, eNpcOrc::GruntStanding
    act_SetActorFlags kHobokActorIndex, bObj::FlipH
    act_WaitFrames 20
    ;; Hobok pushes Laura back.
    act_ForkStart 2, _LauraGetsPushed_sCutscene
    act_MoveNpcOrcWalk kHobokActorIndex, kLauraFinalePosX + 8
    act_SetActorState1 kHobokActorIndex, eNpcOrc::GruntStanding
    act_SetActorFlags kHobokActorIndex, bObj::FlipH
    act_WaitFrames 60
    ;; Martin retreats, followed by Laura, as Hobok shoos them away.
    act_ForkStart 1, _HobokShoosHumans_sCutscene
    act_ForkStart 2, _MartinLeaves_sCutscene
    act_MoveNpcAdultWalk kLauraActorIndex, $0200
    act_WaitFrames 90
    act_JumpToMain MainA_Cutscene_StartNextFinaleStep
_MartinGetsPushed_sCutscene:
    act_MoveNpcAdultWalk kMartinActorIndex, kMartinFinalePosX - 14
    act_SetActorState1 kMartinActorIndex, eNpcAdult::HumanManStanding
    act_SetActorFlags kMartinActorIndex, 0
    act_ForkStop $ff
_LauraGetsPushed_sCutscene:
    act_MoveNpcAdultWalk kLauraActorIndex, kLauraFinalePosX - 8
    act_SetActorState1 kLauraActorIndex, eNpcAdult::HumanWomanStanding
    act_SetActorFlags kLauraActorIndex, 0
    act_ForkStop $ff
_MartinLeaves_sCutscene:
    act_WaitFrames 5
    act_MoveNpcAdultWalk kMartinActorIndex, $0200
    act_ForkStop $ff
_HobokShoosHumans_sCutscene:
    act_MoveNpcOrcWalk kHobokActorIndex, kHobokFinalePosX
    act_SetActorState1 kHobokActorIndex, eNpcOrc::GruntStanding
    act_ForkStop $ff
.ENDPROC

.EXPORT DataA_Cutscene_TownOutdoorsFinaleReactivate5_sCutscene
.PROC DataA_Cutscene_TownOutdoorsFinaleReactivate5_sCutscene
    ;; Animate Thurg stepping forward and shouting defiantly.
    act_WaitFrames 30
    act_MoveNpcOrcWalk kThurgActorIndex, $02b4
    act_SetActorState1 kThurgActorIndex, eNpcOrc::GruntThrowing1
    act_RunDialog eDialog::TownOutdoorsFinaleReactivate5A
    ;; Hobok exits the house as well.
    act_WaitFrames 10
    act_CallFunc FuncA_Cutscene_InitHobokAtHouseDoor4
    act_MoveNpcOrcWalk kHobokActorIndex, $0274
    act_SetActorState1 kHobokActorIndex, eNpcOrc::GruntStanding
    act_WaitFrames 30
    ;; Play sounds for Anna operating the final terminal off-screen.
    act_CallFunc Func_PlaySfxMenuConfirm
    act_WaitFrames 10
    act_CallFunc Func_PlaySfxMenuMove
    act_WaitFrames 10
    act_CallFunc Func_PlaySfxMenuMove
    act_WaitFrames 10
    act_CallFunc Func_PlaySfxMenuConfirm
    act_WaitFrames 10
    act_CallFunc Func_PlaySfxMenuConfirm
    act_WaitFrames 30
    ;; A laser beam strikes Thurg from the sky, and he falls to the ground as
    ;; Hobok flinches and runs away.
    act_CallFunc FuncA_Cutscene_PlaySfxQuickWindup
    act_WaitFrames 32
    act_SetCutsceneFlags bCutscene::TickAllActors
    act_CallFunc _ShootBeamAtThurg
    act_WaitFrames 32
    act_CallFunc FuncA_Cutscene_PlaySfxQuickWindup
    act_WaitFrames 32
    act_CallFunc _ShootBeamNearHobok
    act_WaitFrames 170
    ;; Laura exits the house to see what's happening, then looks around.
    act_CallFunc FuncA_Cutscene_InitLauraAtHouseDoor4
    act_WaitFrames 60
    act_MoveNpcAdultWalk kLauraActorIndex, $026a
    act_SetActorState1 kLauraActorIndex, eNpcAdult::HumanWomanStanding
    act_WaitFrames 30
    act_SetActorFlags kLauraActorIndex, bObj::FlipH
    act_WaitFrames 30
    act_SetActorFlags kLauraActorIndex, 0
    act_WaitFrames 90
    act_RunDialog eDialog::TownOutdoorsFinaleReactivate5B
    act_WaitFrames 15
    ;; Martin exists the house and looks towards where Hobok ran way, then
    ;; turns back.
    act_CallFunc FuncA_Cutscene_InitMartinAtHouseDoor4
    act_WaitFrames 45
    act_MoveNpcAdultWalk kMartinActorIndex, $0238
    act_SetActorState1 kMartinActorIndex, eNpcAdult::HumanManStanding
    act_WaitFrames 60
    act_MoveNpcAdultWalk kMartinActorIndex, $0248
    act_SetActorState1 kMartinActorIndex, eNpcAdult::HumanManStanding
    act_WaitFrames 100
    act_JumpToMain MainA_Cutscene_StartNextFinaleStep
_ShootBeamAtThurg:
    ;; Make Hobok flinch and run away.
    ldx #kHobokActorIndex  ; param: actor index
    lda #bObj::FlipH  ; param: actor flags
    jsr Func_InitActorBadOrc  ; preserves X
    lda #eBadOrc::Flinching
    sta Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    lda #60
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    lda #<kHobokFlinchVelX
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kHobokFlinchVelX
    sta Ram_ActorVelX_i16_1_arr, x
    ;; Make Thurg go flying.
    ldx #kThurgActorIndex  ; param: actor index
    lda #bObj::FlipH  ; param: actor flags
    jsr Func_InitActorBadOrc  ; preserves X
    lda #eBadOrc::Collapsing
    sta Ram_ActorState1_byte_arr, x  ; current eBadOrc mode
    lda #<kThurgFlingVelX
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kThurgFlingVelX
    sta Ram_ActorVelX_i16_1_arr, x
    lda #<kThurgFlingVelY
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kThurgFlingVelY
    sta Ram_ActorVelY_i16_1_arr, x
    ;; Shoot a laser beam at Thurg.
    jsr Func_SetPointToActorCenter
    jmp _ShootBeamAtPoint
_ShootBeamNearHobok:
    ldx #kHobokActorIndex  ; param: actor index
    jsr Func_SetPointToActorCenter
    lda #7  ; param: offset
    jsr Func_MovePointRightByA
    fall _ShootBeamAtPoint
_ShootBeamAtPoint:
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @done  ; no more actor slots available
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr FuncA_Cutscene_InitActorSmokeBeam
    jsr FuncA_Cutscene_PlaySfxBeam
    @done:
    lda #6  ; param: offset
    jsr Func_MovePointDownByA
    jsr Func_SpawnExplosionAtPoint
    jmp Func_PlaySfxExplodeBig
.ENDPROC

.EXPORT DataA_Cutscene_TownOutdoorsFinaleYearsLater_sCutscene
.PROC DataA_Cutscene_TownOutdoorsFinaleYearsLater_sCutscene
    act_WaitFrames 120
    ;; Alex expresses his regrets to Anna.
    act_RunDialog eDialog::TownOutdoorsFinaleYearsLater1
    act_WaitFrames 120
    ;; Stela calls to Alex and Anna that Boris is home.
    act_RunDialog eDialog::TownOutdoorsFinaleYearsLater2
    act_WaitFrames 60
    ;; Boris walks onscreen and greets the kids.
    act_MoveNpcAdultWalk kBorisActorIndex, $02d8
    act_SetActorState1 kBorisActorIndex, eNpcAdult::HumanBorisStanding
    act_WaitFrames 60
    act_RunDialog eDialog::TownOutdoorsFinaleYearsLater3
    ;; Alex and Boris move together to hug.
    act_ForkStart 1, _AlexHug_sCutscene
    act_MoveNpcAdultWalk kBorisActorIndex, $02e8
    act_SetActorState1 kBorisActorIndex, eNpcAdult::HumanBorisGiving
    act_WaitFrames 120
    ;; Alex and Boris break apart from the hug.
    act_ForkStart 1, _AlexBackUp_sCutscene
    act_MoveNpcAdultWalk kBorisActorIndex, $02e5
    act_SetActorFlags kBorisActorIndex, 0
    act_SetActorState1 kBorisActorIndex, eNpcAdult::HumanBorisStanding
    act_WaitFrames 120
    ;; Boris shows Alex the relic from across the sea.
    act_RunDialog eDialog::TownOutdoorsFinaleYearsLater4
    ;; The screen fades to black, and Alex speaks the finale line of dialogue
    ;; before the epilogue.
    act_CallFunc FuncA_Cutscene_Finale_FadeRoomToBlack
    act_WaitFrames 30
    act_RunDialog eDialog::TownOutdoorsFinaleYearsLater5
    act_WaitFrames 30
    act_JumpToMain MainA_Cutscene_StartEpilogue
_AlexHug_sCutscene:
    act_WaitFrames 8
    act_MoveNpcAdultWalk kAlexActorIndex, $02f0
    act_SetActorState1 kAlexActorIndex, eNpcAdult::HumanAlexTaking
    act_ForkStop $ff
_AlexBackUp_sCutscene:
    act_MoveNpcAdultWalk kAlexActorIndex, $02f3
    act_SetActorState1 kAlexActorIndex, eNpcAdult::HumanAlexStanding
    act_SetActorFlags kAlexActorIndex, bObj::FlipH
    act_ForkStop $ff
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the treeline in the TownOutdoors
;;; room.  Sets the horizontal scroll for the treeline to a fraction of the
;;; room scroll, so that the treeline scrolls more slowly than the main portion
;;; of the room (thus making it look far away).
;;; @thread IRQ
.PROC Int_TownOutdoorsTreeTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda #kTreelineBottomY - kTreelineTopY - 1  ; param: latch value
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_TownOutdoorsTreeBottomIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #5  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #0 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda #kTreelineTopY  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    ;; Scroll the treeline horizontally.
    lda Zp_Active_sIrq + sIrq::Param1_byte  ; treeline scroll-X
    tax  ; new scroll-X value
    div #8
    ora #(kTreelineTopY & $38) << 2
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom of the treeline in the
;;; TownOutdoors room.  Sets the horizontal scroll back to match the room
;;; scroll, so that the bottom portion of the room scrolls normally.
;;; @thread IRQ
.PROC Int_TownOutdoorsTreeBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam4  ; preserves Y
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #5  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #0 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda #kTreelineBottomY  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    lda Zp_Active_sIrq + sIrq::Param2_byte  ; houses scroll-X
    tax  ; new scroll-X value
    div #8
    ora #(kTreelineBottomY & $38) << 2
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
