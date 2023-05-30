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
.INCLUDE "../actors/orc.inc"
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Outdoors_sTileset
.IMPORT Func_AckIrqAndLatchWindowFromParam3
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_HarmAvatar
.IMPORT Func_InitActorBadOrc
.IMPORT Func_InitActorNpcOrc
.IMPORT Func_Noop
.IMPORT Main_LoadPrisonCellAndStartCutscene
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_PpuScrollX_u8
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
kGrontaActorIndex = 3

;;; The room pixel X-position that the Alex actor should be at when kneeling
;;; down to pick up the metal thing he found.
kAlexPickupPositionX = $0590

;;; CutsceneTimer_u8 values for various phases of the cutscene.
kCutsceneTimerKneeling = 60
kCutsceneTimerStanding = 20 + kCutsceneTimerKneeling
kCutsceneTimerTurning  = 20 + kCutsceneTimerStanding
kCutsceneTimerHolding  = 30 + kCutsceneTimerTurning

;;; Initial room pixel positions for the orc actors.
kOrcInitPosY    = $0098
kGrontaInitPosX = $05d7
kOrc1InitPosX   = $05e8
kOrc2InitPosX   = $05f9

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; A timer used for animating cutscenes in this room.
    CutsceneTimer_u8 .byte
    ;; Timer for making the second orc jump.
    OrcJumpTimer_u8  .byte
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
    d_addr Tick_func_ptr, FuncC_Town_Outdoors_TickRoom
    d_addr Draw_func_ptr, FuncC_Town_Outdoors_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Outdoors_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/town_outdoors1.room"
    .incbin "out/data/town_outdoors2.room"
    .incbin "out/data/town_outdoors3.room"
    .assert * - :- = 96 * 15, error
_Platforms_sPlatform_arr:
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
    d_byte Param_byte, kTileIdAdultManFirst
    D_END
    .assert * - :- = kSandraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0350
    d_word PosY_i16, $00c8
    d_byte Param_byte, kTileIdAdultWomanFirst
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_u8, eRoom::TownHouse1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 13
    d_byte Target_u8, eRoom::TownHouse2
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 24
    d_byte Target_u8, eRoom::TownHouse3
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 32
    d_byte Target_u8, eDialog::TownOutdoorsSign
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 37
    d_byte Target_u8, eRoom::TownHouse4
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 59
    d_byte Target_u8, eRoom::TownHouse5
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 71
    d_byte Target_u8, eRoom::TownHouse6
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 46
    d_byte Target_u8, eDialog::TownOutdoorsIvan
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 47
    d_byte Target_u8, eDialog::TownOutdoorsIvan
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 52
    d_byte Target_u8, eDialog::TownOutdoorsSandra
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 53
    d_byte Target_u8, eDialog::TownOutdoorsSandra
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 86
    d_byte Target_u8, eDialog::TownOutdoorsAlex1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 87
    d_byte Target_u8, eDialog::TownOutdoorsAlex1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Town_Outdoors_TickRoom
_MakeOrcJump:
    lda Zp_RoomState + sState::OrcJumpTimer_u8
    beq @done
    dec Zp_RoomState + sState::OrcJumpTimer_u8
    bne @done
    ldx #kOrc2ActorIndex
    jmp FuncC_Town_Outdoors_MakeOrcJump  ; unconditional
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
    lda #eCutscene::TownOutdoorsGetCaught
    sta Zp_Next_eCutscene
    @done:
    rts
.ENDPROC

;;; Draw function for the TownOutdoors room.
.PROC FuncC_Town_Outdoors_DrawRoom
    ;; Fix the horizontal scrolling position for the top of the screen, so that
    ;; the stars and moon don't scroll.
    lda #0
    sta Zp_PpuScrollX_u8
    ;; Compute the IRQ latch value to set between the bottom of the treeline
    ;; and the top of the window (if any), and set that as Param3_byte.
    lda <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    sub #kTreelineBottomY
    add Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param3_byte)  ; window latch
    ;; Set up our own sIrq struct to handle parallax scrolling.
    lda #kTreelineTopY - 1
    sub Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    ldax #Int_TownOutdoorsTreeTopIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    ;; Compute the PPU scroll-X for the treeline (which scrolls horizontally at
    ;; 1/4 speed) and houses (which scroll at full speed), and set those as
    ;; Param1_byte and Param2_byte, respectively.
    lda Zp_RoomScrollX_u16 + 1
    lsr a
    sta T0
    lda Zp_RoomScrollX_u16 + 0
    sta <(Zp_Buffered_sIrq + sIrq::Param2_byte)  ; houses scroll-X
    ror a
    lsr T0
    ror a
    sta <(Zp_Buffered_sIrq + sIrq::Param1_byte)  ; treeline scroll-X
    rts
.ENDPROC

;;; Make the specified orc actor jump to the left.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
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
    rts
.ENDPROC

.EXPORT DataC_Town_TownOutdoorsAlex1_sDialog
.PROC DataC_Town_TownOutdoorsAlex1_sDialog
    .word ePortrait::ChildAlex
    .byte "Hi, Anna! I wanted to$"
    .byte "show you something.$"
    .byte "Look at what I found$"
    .byte "in the dirt over here!#"
    .addr _CutsceneFunc
_CutsceneFunc:
    lda #eCutscene::TownOutdoorsOrcAttack
    sta Zp_Next_eCutscene
    ldya #DataC_Town_TownOutdoorsEmpty_sDialog
    rts
.ENDPROC

.EXPORT DataC_Town_TownOutdoorsAlex2_sDialog
.PROC DataC_Town_TownOutdoorsAlex2_sDialog
    .word ePortrait::ChildAlex
    .byte "It's some weird metal$"
    .byte "thing. But nothing$"
    .byte "like the iron or steel$"
    .byte "Smith Dominic uses.#"
    .word ePortrait::ChildAlex
    .byte "No idea what it is. It$"
    .byte "almost looks like part$"
    .byte "of a machine, but it$"
    .byte "seems so...advanced.#"
    .addr _StandingFunc
_StandingFunc:
    lda #eNpcChild::AlexStanding
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    ldya #_IWonder_sDialog
    rts
_IWonder_sDialog:
    .word ePortrait::ChildAlex
    .byte "I wonder where a thing$"
    .byte "like this could have$"
    .byte "come from...#"
    .word ePortrait::Done
.ENDPROC

.EXPORT DataC_Town_TownOutdoorsAlex3_sDialog
.PROC DataC_Town_TownOutdoorsAlex3_sDialog
    .word ePortrait::ChildAlex
    .byte "Do you ever wish we$"
    .byte "could just leave this$"
    .byte "town and go exploring?$"
    .byte "You and me?#"
    .word ePortrait::ChildAlex
    .byte "Mom always says it's$"
    .byte "too dangerous, but I$"
    .byte "bet we could handle$"
    .byte "anything out there...#"
    .addr _ScrollFunc
_ScrollFunc:
    ;; Scroll the orcs into view.
    ldax #$0500
    stax Zp_ScrollGoalX_u16
    ldya #_HandleThis_sDialog
    rts
_HandleThis_sDialog:
    .word ePortrait::OrcGronta
    .byte "Handle THIS, human.#"
    .addr _TurnAroundFunc
_TurnAroundFunc:
    ;; Make Anna turn to face the orcs.
    lda #kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    ;; Make Alex turn and look up at the orcs.
    lda #eNpcChild::AlexLooking
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    lda #0
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    ldya #_WhaWhat_sDialog
    rts
_WhaWhat_sDialog:
    .word ePortrait::ChildAlex
    .byte "Wha- what?#"
    .addr _AttackFunc
_AttackFunc:
    lda #eNpcOrc::GrontaArmsRaised
    sta Ram_ActorState1_byte_arr + kGrontaActorIndex
    ldya #_Attack_sDialog
    rts
_Attack_sDialog:
    .word ePortrait::OrcGrontaShout
    .byte "Orcs, attaaaaaack!#"
    .word ePortrait::ChildAlexShout
    .byte "Anna, run!#"
    .addr _OrcJumpFunc
_OrcJumpFunc:
    ldx #kOrc1ActorIndex
    jsr FuncC_Town_Outdoors_MakeOrcJump
    lda #30
    sta Zp_RoomState + sState::OrcJumpTimer_u8
    ldya #DataC_Town_TownOutdoorsEmpty_sDialog
    rts
.ENDPROC

.EXPORT DataC_Town_TownOutdoorsGronta_sDialog
.PROC DataC_Town_TownOutdoorsGronta_sDialog
    .word ePortrait::OrcGronta
    .byte "Lieutenent Thurg! Have$"
    .byte "the grunts round up$"
    .byte "the townsfolk, and$"
    .byte "lock these kids up.#"
    .word ePortrait::OrcGronta
    .byte "Then we can begin our$"
    .byte "search.#"
    .word ePortrait::OrcMale
    .byte "Yes, Chief Gronta!#"
    .word ePortrait::Done
.ENDPROC

.EXPORT DataC_Town_TownOutdoorsIvan_sDialog
.PROC DataC_Town_TownOutdoorsIvan_sDialog
    .word ePortrait::AdultMan
    .byte "The harvest isn't$"
    .byte "looking good, Sandra.$"
    .byte "This might be a tough$"
    .byte "winter for all of us.#"
    .word ePortrait::AdultMan
    .byte "Oh, sorry Anna, I$"
    .byte "didn't see you there.#"
    .word ePortrait::Done
.ENDPROC

.EXPORT DataC_Town_TownOutdoorsSandra_sDialog
.PROC DataC_Town_TownOutdoorsSandra_sDialog
    .word ePortrait::AdultWoman
    .byte "Looking for Alex? He$"
    .byte "popped by the house$"
    .byte "earlier to see Bruno$"
    .byte "and Marie.#"
    .word ePortrait::AdultWoman
    .byte "One of them might know$"
    .byte "where he went.#"
    .word ePortrait::Done
.ENDPROC

.EXPORT DataC_Town_TownOutdoorsSign_sDialog
.PROC DataC_Town_TownOutdoorsSign_sDialog
    .word ePortrait::Sign
    .byte "$"
    .byte " Bartik Town Hall#"
    .assert * = DataC_Town_TownOutdoorsEmpty_sDialog, error, "fallthrough"
.ENDPROC

.PROC DataC_Town_TownOutdoorsEmpty_sDialog
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_TownOutdoorsOrcAttack_sCutscene
.PROC DataA_Cutscene_TownOutdoorsOrcAttack_sCutscene
    .byte eAction::CallFunc
    .addr _RemoveDevicesAndTownsfolk
    .byte eAction::WalkAlex, kAlexActorIndex
    .word kAlexPickupPositionX
    ;; Animate Alex bending down, picking something up, then turning around and
    ;; showing it to Anna.
    .byte eAction::SetActorState1, kAlexActorIndex, eNpcChild::AlexKneeling
    .byte eAction::WaitFrames, 60
    .byte eAction::SetActorState1, kAlexActorIndex, eNpcChild::AlexStanding
    .byte eAction::WaitFrames, 20
    .byte eAction::SetActorFlags, kAlexActorIndex, bObj::FlipH
    .byte eAction::WaitFrames, 20
    .byte eAction::SetActorState1, kAlexActorIndex, eNpcChild::AlexHolding
    .byte eAction::WaitFrames, 30
    .byte eAction::RunDialog, eDialog::TownOutdoorsAlex2
    ;; Animate Alex and Anna looking up at the stars.
    .byte eAction::CallFunc
    .addr _SetScrollGoal
    .byte eAction::SetActorFlags, kAlexActorIndex, bObj::FlipH
    .byte eAction::SetActorState1, kAlexActorIndex, eNpcChild::AlexLooking
    .byte eAction::WaitFrames, 60
    .byte eAction::SetAvatarFlags, bObj::FlipH | kPaletteObjAvatarNormal
    .byte eAction::SetAvatarPose, eAvatar::Looking
    .byte eAction::WaitFrames, 60
    ;; TODO: Make a star twinkle in the sky.
    .byte eAction::WaitFrames, 120
    .byte eAction::CallFunc
    .addr _InitOrcs
    .byte eAction::RunDialog, eDialog::TownOutdoorsAlex3
    .byte eAction::SetActorState1, kGrontaActorIndex, eNpcOrc::GrontaStanding
    .byte eAction::ContinueExploring
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
_SetScrollGoal:
    ;; TODO: scroll slowly instead
    ldax #$04c0
    stax Zp_ScrollGoalX_u16
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
    jsr Func_InitActorBadOrc
    rts
.ENDPROC

.EXPORT DataA_Cutscene_TownOutdoorsGetCaught_sCutscene
.PROC DataA_Cutscene_TownOutdoorsGetCaught_sCutscene
    .byte eAction::SetCutsceneFlags, bCutscene::AvatarRagdoll
    .byte eAction::WaitUntilZ
    .addr _AnnaHasLanded
    .byte eAction::SetCutsceneFlags, 0
    .byte eAction::SetAvatarState, 0
    .byte eAction::SetAvatarVelX
    .word 0
    .byte eAction::CallFunc
    .addr _SetHarmTimer
    .byte eAction::SetAvatarFlags, kPaletteObjAvatarNormal | bObj::FlipH
    .byte eAction::SetAvatarPose, eAvatar::Slumping
    .byte eAction::WaitFrames, 4
    .byte eAction::SetAvatarPose, eAvatar::Sleeping
    .byte eAction::WaitFrames, 120
    ;; TODO: make Chief Gronta walk onscreen
    .byte eAction::RunDialog, eDialog::TownOutdoorsGronta
    .byte eAction::JumpToMain
    .addr Main_LoadPrisonCellAndStartCutscene
_AnnaHasLanded:
    lda Zp_AvatarState_bAvatar
    and #bAvatar::Airborne
    rts
_SetHarmTimer:
    lda #kAvatarHarmHealFrames - kAvatarHarmInvincibileFrames - 1
    sta Zp_AvatarHarmTimer_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the treeline in the TownOutdoors
;;; room.  Sets the horizontal scroll for the treeline to a fraction of the
;;; room scroll, so that the treeline scrolls more slowly than the main portion
;;; of the room (thus making it look far away).
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
    lda <(Zp_Active_sIrq + sIrq::Param1_byte)  ; treeline scroll-X
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
.PROC Int_TownOutdoorsTreeBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam3  ; preserves Y
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
    lda <(Zp_Active_sIrq + sIrq::Param2_byte)  ; houses scroll-X
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
