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
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
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
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_AckIrqAndLatchWindowFromParam3
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_InitActorBadOrc
.IMPORT Func_Noop
.IMPORT Main_Dialog_OpenWindow
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarMode_eAvatar
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_NextCutscene_main_ptr
.IMPORTZP Zp_NextIrq_int_ptr
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
kIvanActorIndex   = 0
kSandraActorIndex = 1
kAlexActorIndex   = 2
kOrc1ActorIndex   = 0
kOrc2ActorIndex   = 1

;;; The room pixel X-position that the Alex actor should be at when kneeling
;;; down to pick up the metal thing he found.
kAlexPickupPositionX = $0590

;;; CutsceneTimer_u8 values for various phases of the cutscene.
kCutsceneTimerKneeling = 60
kCutsceneTimerStanding = 20 + kCutsceneTimerKneeling
kCutsceneTimerTurning  = 20 + kCutsceneTimerStanding
kCutsceneTimerHolding  = 30 + kCutsceneTimerTurning

;;; Initial room pixel positions for the orc actors.
kOrcInitPosY  = $0098
kOrc1InitPosX = $05e8
kOrc2InitPosX = $05f9

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; A timer used for animating cutscenes in this room.
    CutsceneTimer_u8 .byte
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
    d_addr Tick_func_ptr, Func_Noop
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
    .assert * - :- = 96 * 16, error
_Platforms_sPlatform_arr:
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kIvanActorIndex * .sizeof(sActor), error
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
    .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0570
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcChild::AlexStanding
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

.EXPORT DataC_Town_TownOutdoorsAlex1_sDialog
.PROC DataC_Town_TownOutdoorsAlex1_sDialog
    .word ePortrait::ChildAlex
    .byte "Hi, Anna! I wanted to$"
    .byte "show you something.$"
    .byte "Look at what I found$"
    .byte "in the dirt over here!#"
    .addr _CutsceneFunc
_CutsceneFunc:
    ldya #MainC_Town_OutdoorsCutscene1
    stya Zp_NextCutscene_main_ptr
    ldya #DataC_Town_TownOutdoorsEmpty_sDialog
    rts
.ENDPROC

.PROC MainC_Town_OutdoorsCutscene1
    ;; Remove the other townsfolk (other than Alex).
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kIvanActorIndex
    sta Ram_ActorType_eActor_arr + kSandraActorIndex
_RemoveAllDevices:
    ;; Remove all devices from the room (so that the player can't start dialog
    ;; or run into a building once the orcs attack).
    ldx #kMaxDevices - 1
    lda #eDevice::None
    @loop:
    sta Ram_DeviceType_eDevice_arr, x
    dex
    bpl @loop
_GameLoop:
    ;; Draw the frame:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
    ;; Check if Alex is at his picking-up position yet.
    lda Ram_ActorPosX_i16_0_arr + kAlexActorIndex
    cmp #<kAlexPickupPositionX
    beq _InPickupPosition
_WalkToPickupPosition:
    ;; Face the player avatar towards Alex.
    lda Ram_ActorPosX_i16_0_arr + kAlexActorIndex
    cmp Zp_AvatarPosX_i16 + 0
    blt @noTurnAvatar
    lda #kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    @noTurnAvatar:
    ;; Animate Alex walking towards his picking-up position.
    inc Ram_ActorPosX_i16_0_arr + kAlexActorIndex
    lda Zp_FrameCounter_u8
    and #$08
    beq @walk2
    lda #eNpcChild::AlexWalking1
    bne @setState  ; unconditional
    @walk2:
    lda #eNpcChild::AlexWalking2
    @setState:
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    lda #$ff
    sta Ram_ActorState2_byte_arr + kAlexActorIndex
    lda #0
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    beq _GameLoop  ; unconditional
_InPickupPosition:
    ;; Animate Alex crouching down, standing back up, then facing Anna again.
    inc Zp_RoomState + sState::CutsceneTimer_u8
    lda Zp_RoomState + sState::CutsceneTimer_u8
    cmp #kCutsceneTimerKneeling
    blt @kneeling
    cmp #kCutsceneTimerStanding
    blt @standing
    cmp #kCutsceneTimerTurning
    blt @turning
    cmp #kCutsceneTimerHolding
    bge _ResumeDialog
    @holding:
    lda #eNpcChild::AlexHolding
    bne @setState  ; unconditional
    @turning:
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
    bne _GameLoop  ; unconditional
    @standing:
    lda #eNpcChild::AlexStanding
    bne @setState  ; unconditional
    @kneeling:
    lda #eNpcChild::AlexKneeling
    @setState:
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    bne _GameLoop  ; unconditional
_ResumeDialog:
    ldy #eDialog::TownOutdoorsAlex2  ; param: eDialog value
    jmp Main_Dialog_OpenWindow
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
    .addr _CutsceneFunc
_CutsceneFunc:
    ldya #MainC_Town_OutdoorsCutscene2
    stya Zp_NextCutscene_main_ptr
    ldya #DataC_Town_TownOutdoorsEmpty_sDialog
    rts
.ENDPROC

.PROC MainC_Town_OutdoorsCutscene2
    lda #0
    sta Zp_RoomState + sState::CutsceneTimer_u8
    ;; TODO: scroll slowly instead
    ldax #$04c0
    stax Zp_ScrollGoalX_u16
    ;; Make Alex look up at the stars.
    lda #eNpcChild::AlexLooking
    sta Ram_ActorState1_byte_arr + kAlexActorIndex
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kAlexActorIndex
_GameLoop:
    ;; Draw the frame:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
_Tick:
    lda Zp_RoomState + sState::CutsceneTimer_u8
    ;; One second into the cutscene, make Anna look up at the stars too.
    cmp #60
    bne @doneAnnaLook
    lda #eAvatar::Looking
    sta Zp_AvatarMode_eAvatar
    lda #bObj::FlipH | kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    @doneAnnaLook:
    ;; TODO: Two seconds into the cutscene, make a star twinkle in the sky.
    ;; End the cutscene after four seconds.
    cmp #240
    beq _ResumeDialog
_UpdateScrolling:
    inc Zp_RoomState + sState::CutsceneTimer_u8
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
_ResumeDialog:
    ldax #kOrc1InitPosX
    stx Ram_ActorPosX_i16_0_arr + kOrc1ActorIndex
    sta Ram_ActorPosX_i16_1_arr + kOrc1ActorIndex
    .assert >kOrc2InitPosX = >kOrc1InitPosX, error
    ldx #<kOrc2InitPosX
    stx Ram_ActorPosX_i16_0_arr + kOrc2ActorIndex
    sta Ram_ActorPosX_i16_1_arr + kOrc2ActorIndex
    ldax #kOrcInitPosY
    stx Ram_ActorPosY_i16_0_arr + kOrc1ActorIndex
    sta Ram_ActorPosY_i16_1_arr + kOrc1ActorIndex
    stx Ram_ActorPosY_i16_0_arr + kOrc2ActorIndex
    sta Ram_ActorPosY_i16_1_arr + kOrc2ActorIndex
    ldx #kOrc1ActorIndex  ; param: actor index
    lda #bObj::FlipH  ; param: actor flags
    jsr Func_InitActorBadOrc
    ldx #kOrc2ActorIndex  ; param: actor index
    lda #bObj::FlipH  ; param: actor flags
    jsr Func_InitActorBadOrc
    ;; TODO: spawn actor for Chief Gronta
    ldy #eDialog::TownOutdoorsAlex3  ; param: eDialog value
    jmp Main_Dialog_OpenWindow
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
    .word ePortrait::OrcGrontaShout
    .byte "Orcs, attaaaaaack!#"
    .word ePortrait::ChildAlexShout
    .byte "Anna, run!#"
    ;; TODO: make orcs attack
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
