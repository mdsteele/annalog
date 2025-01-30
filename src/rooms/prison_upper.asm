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
.INCLUDE "../actors/toddler.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/dialog.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/gate.inc"
.INCLUDE "../platforms/stepstone.inc"
.INCLUDE "../portrait.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"
.INCLUDE "../scroll.inc"

.IMPORT DataA_Room_Prison_sTileset
.IMPORT DataA_Text0_PrisonUpperAlexCell_GetDoorOpen_u8_arr
.IMPORT DataA_Text0_PrisonUpperAlexCell_Intro_u8_arr
.IMPORT DataA_Text0_PrisonUpperAlexFree_Part1_u8_arr
.IMPORT DataA_Text0_PrisonUpperAlexFree_Part2_u8_arr
.IMPORT DataA_Text0_PrisonUpperAlexLast_Part1_u8_arr
.IMPORT DataA_Text0_PrisonUpperAlexLast_Part2_u8_arr
.IMPORT DataA_Text0_PrisonUpperAlexLast_Part3_u8_arr
.IMPORT DataA_Text0_PrisonUpperAlexLast_Part4_u8_arr
.IMPORT DataA_Text0_PrisonUpperBreakerTemple1_Part1_u8_arr
.IMPORT DataA_Text0_PrisonUpperBreakerTemple1_Part2_u8_arr
.IMPORT DataA_Text0_PrisonUpperBreakerTemple2_u8_arr
.IMPORT DataA_Text0_PrisonUpperBruno_Adults_u8_arr
.IMPORT DataA_Text0_PrisonUpperBruno_ClimbUp_u8_arr
.IMPORT DataA_Text0_PrisonUpperMarie_GoTalkToAlex_u8_arr
.IMPORT DataA_Text0_PrisonUpperMarie_LooseBrick_u8_arr
.IMPORT DataA_Text0_PrisonUpperMarie_StandCareful_u8_arr
.IMPORT DataA_Text0_PrisonUpperNora_u8_arr
.IMPORT Data_Empty_sDialog
.IMPORT FuncA_Cutscene_PlaySfxClick
.IMPORT FuncA_Objects_DrawStepstonePlatform
.IMPORT FuncC_Prison_DrawGatePlatform
.IMPORT FuncC_Prison_OpenGateAndFlipLever
.IMPORT FuncC_Prison_TickGatePlatform
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_PlaySfxMetallicDing
.IMPORT Func_SetFlag
.IMPORT Func_SetOrClearFlag
.IMPORT Main_Breaker_FadeBackToBreakerRoom
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_Nearby_bDevice
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_ScrollGoalX_u16

;;;=========================================================================;;;

;;; Actor indices for specific NPCs in this room.
kAlexActorIndex  = 0
kNoraActorIndex  = 1
kNinaActorIndex  = 2
kBrunoActorIndex = 3
kMarieActorIndex = 4
kOrc1ActorIndex  = 5
kOrc2ActorIndex  = 6

;;; Device indices for various talk devices in this room.
kAlexCellDeviceIndex      = 0
kAlexFreeRightDeviceIndex = 1
kAlexFreeLeftDeviceIndex  = 2
kFirstNonTalkDeviceIndex  = 9

;;; The platform index for the stepstone that appears after talking to Alex.
kStepstonePlatformIndex = 1

;;; The platform index for the prison gate in this room.
kGatePlatformIndex = 0

;;; The room block row for the top of the gate when it's shut.
kGateBlockRow = 10

;;; The room pixel X-position that the Alex actor should walk to after the
;;; prison gate is opened.
kAlexFreePositionX = $0090
;;; The room pixel X-position that NPC actors can walk to during the
;;; PrisonUpperFreedKids cutscene to be offscreen.
kFreeKidsOffscreenPositionX = $0128

;;; The room pixel X-position that the Marie actor should stand in while still
;;; imprisoned.
kMarieCellPositionX = $0190
;;; The room pixel X-position that the Marie actor should be at when jumping to
;;; loosen the brick.
kMarieJumpPositionX = $0199

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the lever in this room.
    GateLever_u8 .byte
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
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Prison_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncC_Prison_Upper_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Prison_Upper_TickRoom
    d_addr Draw_func_ptr, FuncC_Prison_Upper_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/prison_upper.room"
    .assert * - :- = 33 * 15, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kGatePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kGatePlatformWidthPx
    d_byte HeightPx_u8, kGatePlatformHeightPx
    d_word Left_i16, $0063
    d_word Top_i16, kGateBlockRow * kBlockHeightPx
    D_END
    ;; Stepping stone on right side of eastern cell:
    .assert * - :- = kStepstonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, kStepstonePlatformWidthPx
    d_byte HeightPx_u8, kStepstonePlatformHeightPx
    d_word Left_i16, $01a1
    d_word Top_i16,  $0093
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
    .assert * - :- = kNoraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0110
    d_word PosY_i16, $0078
    d_byte Param_byte, bNpcChild::Pri | eNpcChild::NoraStanding
    D_END
    .assert * - :- = kNinaActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcToddler
    d_word PosX_i16, $0128
    d_word PosY_i16, $0078
    d_byte Param_byte, bNpcToddler::Pri | 17
    D_END
    .assert * - :- = kBrunoActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $0160
    d_word PosY_i16, $00b8
    d_byte Param_byte, bNpcChild::Pri | eNpcChild::BrunoStanding
    D_END
    .assert * - :- = kMarieActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, kMarieCellPositionX
    d_word PosY_i16, $00b8
    d_byte Param_byte, bNpcChild::Pri | eNpcChild::MarieStanding
    D_END
    .assert * - :- = kOrc1ActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $0136
    d_word PosY_i16, $00b8
    d_byte Param_byte, eNpcOrc::GruntStanding
    D_END
    .assert * - :- = kOrc2ActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $01e8
    d_word PosY_i16, $00b0
    d_byte Param_byte, eNpcOrc::GruntStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kAlexCellDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eDialog::PrisonUpperAlexCell
    D_END
    .assert * - :- = kAlexFreeRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; becomes TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eDialog::PrisonUpperAlexFree
    D_END
    .assert * - :- = kAlexFreeLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder  ; becomes TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eDialog::PrisonUpperAlexFree
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 16
    d_byte Target_byte, eDialog::PrisonUpperNora
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 17
    d_byte Target_byte, eDialog::PrisonUpperNora
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 21
    d_byte Target_byte, eDialog::PrisonUpperBruno
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 22
    d_byte Target_byte, eDialog::PrisonUpperBruno
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 24
    d_byte Target_byte, eDialog::PrisonUpperMarie
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 25
    d_byte Target_byte, eDialog::PrisonUpperMarie
    D_END
    .assert * - :- = kFirstNonTalkDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 4
    d_byte Target_byte, sState::GateLever_u8
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::PrisonCrossroad
    d_byte SpawnBlock_u8, 10
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Prison_Upper_EnterRoom
_Gate:
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperGateOpen
    beq @shut
    ldy #sState::GateLever_u8  ; param: lever target
    ldx #kGatePlatformIndex  ; param: gate platform index
    jsr FuncC_Prison_OpenGateAndFlipLever
    @shut:
_CheckForBreakerCutscene:
    ;; If the temple breaker cutscene is playing, initialize it (and skip the
    ;; checking of progress flags below).  Otherwise, remove the orc NPCs
    ;; (which only appear in the cutscene).
    lda Zp_Next_eCutscene
    cmp #eCutscene::PrisonUpperBreakerTemple
    bne @noCutscene
    @initCutscene:
    lda #$ff
    sta Ram_ActorState2_byte_arr + kOrc1ActorIndex
    sta Ram_ActorState2_byte_arr + kNoraActorIndex
    sta Ram_ActorState2_byte_arr + kBrunoActorIndex
    sta Ram_ActorState2_byte_arr + kMarieActorIndex
    lda #bObj::Pri | bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kBrunoActorIndex
    rts
    @noCutscene:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kOrc1ActorIndex
    sta Ram_ActorType_eActor_arr + kOrc2ActorIndex
_CheckProgressFlags:
    ;; If the kids have already been freed, remove them (and also place the
    ;; stepstone).
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedKids
    bne _RemoveKids
    ;; Otherwise, if Alex has already been freed, move Alex (and also place the
    ;; stepstone).
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedAlex
    bne _MoveAlex
    lda #$ff
    sta Ram_ActorState2_byte_arr + kAlexActorIndex
    ;; Otherwise, if Marie has already loosened the brick, place the stepstone.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperLoosenedBrick
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
    bmi _PlaceStepstone  ; unconditional
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
_PlaceStepstone:
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kStepstonePlatformIndex
    rts
.ENDPROC

.PROC FuncC_Prison_Upper_TickRoom
_Gate:
    ;; Update the flag from the lever.
    ldx #eFlag::PrisonUpperGateOpen  ; param: flag
    lda Zp_RoomState + sState::GateLever_u8  ; param: zero for clear
    jsr Func_SetOrClearFlag
    ;; Move the gate based on the lever.
    ldy Zp_RoomState + sState::GateLever_u8  ; param: zero for shut
    jsr FuncC_Prison_Upper_TickGate
_FreeAlex:
    ;; If Alex has already been freed, we're done.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperFreedAlex
    bne @done
    ;; Otherwise, if the gate has been opened, mark Alex as freed and start a
    ;; cutscene.
    flag_bit Sram_ProgressFlags_arr, eFlag::PrisonUpperGateOpen
    beq @done
    ldx #eFlag::PrisonUpperFreedAlex
    jsr Func_SetFlag
    lda #eCutscene::PrisonUpperFreeAlex
    sta Zp_Next_eCutscene
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for the gate in this room.
;;; @param Y Zero if the gate should shut, nonzero if it should open.
;;; @return Z Cleared if the platform moved, set if it didn't.
.PROC FuncC_Prison_Upper_TickGate
    ldx #kGatePlatformIndex  ; param: gate platform index
    lda #kGateBlockRow  ; param: block row
    jmp FuncC_Prison_TickGatePlatform  ; returns Z
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

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_PrisonUpperBreakerTemple_sCutscene
.PROC DataA_Cutscene_PrisonUpperBreakerTemple_sCutscene
    act_WaitFrames 60
    ;; Shake the room, and make the kids and the guard orc look around in
    ;; confusion.
    act_CallFunc Func_PlaySfxExplodeBig
    act_ShakeRoom 30
    act_WaitFrames 20
    act_SetActorFlags kBrunoActorIndex, bObj::Pri
    act_SetActorFlags kNoraActorIndex, bObj::Pri | bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kMarieActorIndex, bObj::Pri | bObj::FlipH
    act_SetActorFlags kOrc1ActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kBrunoActorIndex, bObj::Pri | bObj::FlipH
    act_SetActorFlags kNoraActorIndex, bObj::Pri
    act_WaitFrames 10
    act_SetActorFlags kMarieActorIndex, bObj::Pri
    act_SetActorFlags kOrc1ActorIndex, 0
    act_WaitFrames 90
    act_SetActorFlags kBrunoActorIndex, bObj::Pri
    ;; Make a second orc run into the room and deliver a message to the first.
    act_MoveNpcOrcWalk kOrc2ActorIndex, $01b6
    act_SetActorState1 kOrc2ActorIndex, eNpcOrc::GruntThrowing1
    act_RunDialog eDialog::PrisonUpperBreakerTemple1
    ;; Make the two orcs exit the room.
    act_ForkStart 1, _Orc2Exit_sCutscene
    act_MoveNpcOrcWalk kOrc1ActorIndex, $01ac
    act_SetActorPosY kOrc1ActorIndex, $00b0
    act_MoveNpcOrcWalk kOrc1ActorIndex, $01e8
    act_WaitFrames 60
    ;; Make Bruno call out after the guards.
    act_MoveNpcBrunoWalk kBrunoActorIndex, $0179
    act_SetActorState1 kBrunoActorIndex, eNpcChild::BrunoStanding
    act_RunDialog eDialog::PrisonUpperBreakerTemple2
    act_WaitFrames 60
    act_JumpToMain Main_Breaker_FadeBackToBreakerRoom
_Orc2Exit_sCutscene:
    act_SetActorState1 kOrc2ActorIndex, eNpcOrc::GruntStanding
    act_WaitFrames 20
    act_MoveNpcOrcWalk kOrc2ActorIndex, $01e8
    act_ForkStop $ff
.ENDPROC

.EXPORT DataA_Cutscene_PrisonUpperLoosenBrick_sCutscene
.PROC DataA_Cutscene_PrisonUpperLoosenBrick_sCutscene
    act_ForkStart 1, _WalkAvatar_sCutscene
    ;; Animate Marie walking over to the eastern edge of her cell.
    act_MoveNpcMarieWalk kMarieActorIndex, kMarieJumpPositionX
    act_SetActorState1 kMarieActorIndex, eNpcChild::MarieStanding
    act_WaitFrames 60
    ;; Animate Marie jumping up to push the brick.
    act_ForkStart 2, _PushBrick_sCutscene
    act_SetActorState1 kMarieActorIndex, eNpcChild::MarieWalking1
    act_SetActorVelY  kMarieActorIndex, -$308
    act_SetCutsceneFlags bCutscene::TickAllActors
    act_RepeatFunc 40, _ApplyMarieGravity
    act_SetCutsceneFlags 0
    act_SetActorState1 kMarieActorIndex, eNpcChild::MarieStanding
    act_SetActorVelY  kMarieActorIndex, 0
    act_SetActorPosY  kMarieActorIndex, $00b8
    act_WaitFrames 60
    ;; Animate Marie walking back to her starting place.
    act_MoveNpcMarieWalk kMarieActorIndex, kMarieCellPositionX
    act_SetActorState1 kMarieActorIndex, eNpcChild::MarieStanding
    act_SetActorState2 kMarieActorIndex, 0
    act_RunDialog eDialog::PrisonUpperMarie
    act_SetScrollFlags 0  ; unlock scrolling from the previous dialog
    act_ContinueExploring
_WalkAvatar_sCutscene:
    act_MoveAvatarWalk $0180 | kTalkRightAvatarOffset
    act_SetAvatarPose eAvatar::Standing
    act_SetAvatarFlags kPaletteObjAvatarNormal
    act_ForkStop $ff
_PushBrick_sCutscene:
    act_WaitFrames 20
    act_CallFunc FuncA_Cutscene_PlaySfxClick
    act_CallFunc _PlaceStepstone
    act_ForkStop $ff
_PlaceStepstone:
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kStepstonePlatformIndex
    ldx #eFlag::PrisonUpperLoosenedBrick  ; param: flag
    jmp Func_SetFlag
_ApplyMarieGravity:
    lda #kAvatarGravity
    add Ram_ActorVelY_i16_0_arr + kMarieActorIndex
    sta Ram_ActorVelY_i16_0_arr + kMarieActorIndex
    lda #0
    adc Ram_ActorVelY_i16_1_arr + kMarieActorIndex
    sta Ram_ActorVelY_i16_1_arr + kMarieActorIndex
    rts
.ENDPROC

;;; @prereq PRGC_Prison is loaded.
.EXPORT DataA_Cutscene_PrisonUpperFreeAlex_sCutscene
.PROC DataA_Cutscene_PrisonUpperFreeAlex_sCutscene
    act_SetAvatarPose eAvatar::Standing
    act_SetAvatarState 0
    act_SetAvatarVelX 0
    act_CallFunc _SetDevices
    ;; Make Alex look up at the gate as he waits for it to open.
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexLooking
    act_WaitUntilZ _OpenGate
    act_WaitFrames 15
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_WaitFrames 15
    ;; Make Alex walk out of the prison cell.
    act_MoveNpcAlexWalk kAlexActorIndex, kAlexFreePositionX
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_SetActorState2 kAlexActorIndex, $00
    act_ContinueExploring
_SetDevices:
    lda #bDevice::NoneNearby
    sta Zp_Nearby_bDevice
    lda #eDevice::Placeholder
    sta Ram_DeviceType_eDevice_arr + kAlexCellDeviceIndex
    lda #eDevice::TalkRight
    sta Ram_DeviceType_eDevice_arr + kAlexFreeRightDeviceIndex
    lda #eDevice::TalkLeft
    sta Ram_DeviceType_eDevice_arr + kAlexFreeLeftDeviceIndex
    rts
_OpenGate:
    ldy #1  ; param: zero for shut
    jmp FuncC_Prison_Upper_TickGate  ; returns Z
.ENDPROC

.EXPORT DataA_Cutscene_PrisonUpperFreeKids_sCutscene
.PROC DataA_Cutscene_PrisonUpperFreeKids_sCutscene
    ;; Make Alex walk offscreen (meanwhile, scroll the camera into position and
    ;; have Nina move to watch what's happening).
    act_ForkStart 1, _Scroll_sCutscene
    act_ForkStart 2, _NinaWait_sCutscene
    act_MoveNpcAlexWalk kAlexActorIndex, kFreeKidsOffscreenPositionX
    ;; Have Alex pick the locks offscreen.  While he does so, Nina leads Nora
    ;; out of the cell.
    act_WaitFrames 30
    act_CallFunc Func_PlaySfxMetallicDing
    act_WaitFrames 12
    act_CallFunc Func_PlaySfxMetallicDing
    act_WaitFrames 12
    act_CallFunc FuncA_Cutscene_PlaySfxClick
    act_WaitFrames 70
    act_CallFunc Func_PlaySfxMetallicDing
    act_WaitFrames 12
    act_CallFunc Func_PlaySfxMetallicDing
    act_WaitFrames 12
    act_CallFunc Func_PlaySfxMetallicDing
    act_WaitFrames 12
    act_CallFunc FuncA_Cutscene_PlaySfxClick
    act_WaitFrames 10
    act_ForkStart 2, _NinaEscape_sCutscene
    act_WaitFrames 31
    act_MoveNpcNoraWalk kNoraActorIndex, kFreeKidsOffscreenPositionX
    act_WaitFrames 90
    ;; Make Alex walk back onscreen to report on his scouting.
    act_MoveNpcAlexWalk kAlexActorIndex, $00d8
    act_SetActorState1 kAlexActorIndex, eNpcChild::AlexStanding
    act_RunDialog eDialog::PrisonUpperAlexLast
    ;; Make Alex walk back offscreen (and lead the kids out offscreen).
    act_MoveNpcAlexWalk kAlexActorIndex, kFreeKidsOffscreenPositionX
    act_CallFunc _RemoveKids
    act_SetScrollFlags 0
    act_ContinueExploring
_Scroll_sCutscene:
    act_ScrollSlowX $0020
    act_SetScrollFlags bScroll::LockHorz
    act_ForkStop $ff
_NinaWait_sCutscene:
    act_WaitFrames 10
    act_MoveNpcNinaWalk kNinaActorIndex, $00f8
    act_ForkStop $ff
_NinaEscape_sCutscene:
    act_MoveNpcNinaWalk kNinaActorIndex, kFreeKidsOffscreenPositionX
    act_ForkStop $ff
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
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PrisonUpperBreakerTemple1_sDialog
.PROC DataA_Dialog_PrisonUpperBreakerTemple1_sDialog
    dlg_Text OrcMaleShout, DataA_Text0_PrisonUpperBreakerTemple1_Part1_u8_arr
    dlg_Text OrcMaleShout, DataA_Text0_PrisonUpperBreakerTemple1_Part2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PrisonUpperBreakerTemple2_sDialog
.PROC DataA_Dialog_PrisonUpperBreakerTemple2_sDialog
    dlg_Text ChildBrunoShout, DataA_Text0_PrisonUpperBreakerTemple2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PrisonUpperAlexCell_sDialog
.PROC DataA_Dialog_PrisonUpperAlexCell_sDialog
    dlg_Text ChildAlex, DataA_Text0_PrisonUpperAlexCell_Intro_u8_arr
    dlg_Call _SetFlag
    dlg_Text ChildAlex, DataA_Text0_PrisonUpperAlexCell_GetDoorOpen_u8_arr
    dlg_Done
_SetFlag:
    ldx #eFlag::PrisonUpperFoundAlex  ; param: flag
    jmp Func_SetFlag
.ENDPROC

.EXPORT DataA_Dialog_PrisonUpperAlexFree_sDialog
.PROC DataA_Dialog_PrisonUpperAlexFree_sDialog
    dlg_Text ChildAlex, DataA_Text0_PrisonUpperAlexFree_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text0_PrisonUpperAlexFree_Part2_u8_arr
    dlg_Call _SetFlag
    dlg_Cutscene eCutscene::PrisonUpperFreeKids
_SetFlag:
    ldx #eFlag::PrisonUpperFreedKids  ; param: flag
    jmp Func_SetFlag
.ENDPROC

.EXPORT DataA_Dialog_PrisonUpperAlexLast_sDialog
.PROC DataA_Dialog_PrisonUpperAlexLast_sDialog
    dlg_Text ChildAlex, DataA_Text0_PrisonUpperAlexLast_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text0_PrisonUpperAlexLast_Part2_u8_arr
    dlg_Text ChildAlex, DataA_Text0_PrisonUpperAlexLast_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text0_PrisonUpperAlexLast_Part4_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PrisonUpperBruno_sDialog
.PROC DataA_Dialog_PrisonUpperBruno_sDialog
    dlg_IfSet PrisonUpperFoundAlex, _ClimbUp_sDialog
_Adults_sDialog:
    dlg_Text ChildBruno, DataA_Text0_PrisonUpperBruno_Adults_u8_arr
    dlg_Done
_ClimbUp_sDialog:
    dlg_Text ChildBruno, DataA_Text0_PrisonUpperBruno_ClimbUp_u8_arr
    dlg_IfSet PrisonUpperLoosenedBrick, Data_Empty_sDialog
    dlg_Call _LookAtMarie
    .assert kTileIdBgPortraitMarieFirst = kTileIdBgPortraitBrunoFirst, error
    dlg_Goto DataA_Dialog_PrisonUpperMarie_LooseBrick_sDialog
_LookAtMarie:
    ldax #$0100
    stax Zp_ScrollGoalX_u16
    lda #kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    rts
.ENDPROC

.EXPORT DataA_Dialog_PrisonUpperMarie_sDialog
.PROC DataA_Dialog_PrisonUpperMarie_sDialog
    dlg_IfSet PrisonUpperLoosenedBrick, _StandCareful_sDialog
    .linecont +
    dlg_IfSet PrisonUpperFoundAlex, \
              DataA_Dialog_PrisonUpperMarie_LooseBrick_sDialog
    .linecont -
_GoTalkToAlex_sDialog:
    dlg_Text ChildMarie, DataA_Text0_PrisonUpperMarie_GoTalkToAlex_u8_arr
    dlg_Done
_StandCareful_sDialog:
    dlg_Text ChildMarie, DataA_Text0_PrisonUpperMarie_StandCareful_u8_arr
    dlg_Done
.ENDPROC

.PROC DataA_Dialog_PrisonUpperMarie_LooseBrick_sDialog
    dlg_Text ChildMarie, DataA_Text0_PrisonUpperMarie_LooseBrick_u8_arr
    dlg_Call _LockScrolling
    dlg_Cutscene eCutscene::PrisonUpperLoosenBrick
_LockScrolling:
    lda #bScroll::LockHorz  ; will be unlocked in the cutscene
    sta Zp_Camera_bScroll
    rts
.ENDPROC

.EXPORT DataA_Dialog_PrisonUpperNora_sDialog
.PROC DataA_Dialog_PrisonUpperNora_sDialog
    dlg_Text ChildNora, DataA_Text0_PrisonUpperNora_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
