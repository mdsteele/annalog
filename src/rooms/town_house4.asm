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
.INCLUDE "../actors/orc.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../portrait.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_House_sTileset
.IMPORT DataA_Text0_TownHouse4BreakerLava1_Part1_u8_arr
.IMPORT DataA_Text0_TownHouse4BreakerLava1_Part2_u8_arr
.IMPORT DataA_Text0_TownHouse4BreakerLava1_Part3_u8_arr
.IMPORT DataA_Text0_TownHouse4BreakerLava1_Part4_u8_arr
.IMPORT DataA_Text0_TownHouse4BreakerLava2_Part1_u8_arr
.IMPORT DataA_Text0_TownHouse4BreakerLava2_Part2_u8_arr
.IMPORT DataA_Text0_TownHouse4BreakerLava3_u8_arr
.IMPORT DataA_Text0_TownHouse4Laura_Waiting1_u8_arr
.IMPORT DataA_Text0_TownHouse4Laura_Waiting2_u8_arr
.IMPORT DataA_Text0_TownHouse4Martin_u8_arr
.IMPORT Data_Empty_sPlatform_arr
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_PlaySfxThump
.IMPORT Main_Breaker_FadeBackToBreakerRoom
.IMPORT Ppu_ChrObjTown
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORTZP Zp_Next_eCutscene

;;;=========================================================================;;;

;;; Actor indices for specific NPCs in this room.
kLauraActorIndex  = 0
kMartinActorIndex = 1
kThurgActorIndex  = 2
kHobokActorIndex  = 3

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_House4_sRoom
.PROC DataC_Town_House4_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, bRoom::ReduceMusic | eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 13
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_House_sTileset
    d_addr Platforms_sPlatform_arr_ptr, Data_Empty_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncC_Town_House4_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/town_house4.room"
    .assert * - :- = 16 * 15, error
_Actors_sActor_arr:
:   .assert * - :- = kLauraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $0050
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanWoman
    D_END
    .assert * - :- = kMartinActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcAdult
    d_word PosX_i16, $00b0
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcAdult::HumanMan
    D_END
    .assert * - :- = kThurgActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $0076
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcOrc::GruntStanding
    D_END
    .assert * - :- = kHobokActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcOrc
    d_word PosX_i16, $00a0
    d_word PosY_i16, $00c8
    d_byte Param_byte, eNpcOrc::GruntStanding
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_byte, eDialog::TownHouse4Laura
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eDialog::TownHouse4Laura
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 8
    d_byte Target_byte, eRoom::TownOutdoors
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eDialog::TownHouse4Martin
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eDialog::TownHouse4Martin
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Town_House4_EnterRoom
    ;; If the lava breaker cutscene is playing, initialize it.  Otherwise,
    ;; remove the orc NPCs (which only appear in the cutscene).
    lda Zp_Next_eCutscene
    cmp #eCutscene::TownHouse4BreakerLava
    bne @noCutscene
    @initCutscene:
    lda #$ff
    sta Ram_ActorState2_byte_arr + kLauraActorIndex
    sta Ram_ActorState2_byte_arr + kMartinActorIndex
    sta Ram_ActorState2_byte_arr + kThurgActorIndex
    sta Ram_ActorState2_byte_arr + kHobokActorIndex
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr + kMartinActorIndex
    sta Ram_ActorFlags_bObj_arr + kThurgActorIndex
    sta Ram_ActorFlags_bObj_arr + kHobokActorIndex
    lda #$c0
    sta Ram_ActorPosX_i16_0_arr + kMartinActorIndex
    rts
    @noCutscene:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kThurgActorIndex
    sta Ram_ActorType_eActor_arr + kHobokActorIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_TownHouse4BreakerLava_sCutscene
.PROC DataA_Cutscene_TownHouse4BreakerLava_sCutscene
    act_WaitFrames 30
    act_MoveNpcOrcWalk kThurgActorIndex, $0060
    act_SetActorState1 kThurgActorIndex, eNpcOrc::GruntStanding
    act_RunDialog eDialog::TownHouse4BreakerLava1
    act_SetActorState1 kThurgActorIndex, eNpcOrc::GruntThrowing1
    act_CallFunc Func_PlaySfxThump
    act_RepeatFunc 9, _LauraKnockback
    ;; TODO: make Martin react
    act_RunDialog eDialog::TownHouse4BreakerLava2
    act_WaitFrames 60
    act_CallFunc Func_PlaySfxExplodeBig
    act_ShakeRoom 30
    act_WaitFrames 60
    act_SetActorFlags kThurgActorIndex, 0
    act_WaitFrames 10
    act_SetActorFlags kHobokActorIndex, 0
    act_WaitFrames 10
    act_SetActorFlags kThurgActorIndex, bObj::FlipH
    act_WaitFrames 10
    act_SetActorFlags kHobokActorIndex, bObj::FlipH
    act_WaitFrames 70
    act_SetActorFlags kThurgActorIndex, 0
    act_WaitFrames 30
    act_MoveNpcOrcWalk kThurgActorIndex, $0070
    act_SetActorState1 kThurgActorIndex, eNpcOrc::GruntStanding
    act_WaitFrames 30
    act_RunDialog eDialog::TownHouse4BreakerLava3
    act_MoveNpcOrcWalk kThurgActorIndex, $0088
    act_CallFunc _RemoveThurg
    act_WaitFrames 30
    act_MoveNpcOrcWalk kHobokActorIndex, $0050
    act_SetActorState1 kHobokActorIndex, eNpcOrc::GruntStanding
    act_WaitFrames 60
    act_JumpToMain Main_Breaker_FadeBackToBreakerRoom
_LauraKnockback:
    lda Ram_ActorPosX_i16_0_arr + kLauraActorIndex
    sub #3
    sta Ram_ActorPosX_i16_0_arr + kLauraActorIndex
    rts
_RemoveThurg:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kThurgActorIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TownHouse4Laura_sDialog
.PROC DataA_Dialog_TownHouse4Laura_sDialog
    dlg_Text AdultWoman, DataA_Text0_TownHouse4Laura_Waiting1_u8_arr
    dlg_Text AdultWoman, DataA_Text0_TownHouse4Laura_Waiting2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownHouse4Martin_sDialog
.PROC DataA_Dialog_TownHouse4Martin_sDialog
    dlg_Text AdultMan, DataA_Text0_TownHouse4Martin_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownHouse4BreakerLava1_sDialog
.PROC DataA_Dialog_TownHouse4BreakerLava1_sDialog
    .assert kTileIdBgPortraitOrcFirst = kTileIdBgPortraitWomanFirst, error
    dlg_Text OrcMale, DataA_Text0_TownHouse4BreakerLava1_Part1_u8_arr
    dlg_Text AdultWoman, DataA_Text0_TownHouse4BreakerLava1_Part2_u8_arr
    dlg_Text OrcMale, DataA_Text0_TownHouse4BreakerLava1_Part3_u8_arr
    dlg_Text AdultWoman, DataA_Text0_TownHouse4BreakerLava1_Part4_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TownHouse4BreakerLava2_sDialog
.PROC DataA_Dialog_TownHouse4BreakerLava2_sDialog
    dlg_Text OrcMaleShout, DataA_Text0_TownHouse4BreakerLava2_Part1_u8_arr
    dlg_Call _ThurgStanding
    dlg_Text OrcMale, DataA_Text0_TownHouse4BreakerLava2_Part2_u8_arr
    dlg_Done
_ThurgStanding:
    lda #eNpcOrc::GruntStanding
    sta Ram_ActorState1_byte_arr + kThurgActorIndex
    rts
.ENDPROC

.EXPORT DataA_Dialog_TownHouse4BreakerLava3_sDialog
.PROC DataA_Dialog_TownHouse4BreakerLava3_sDialog
    dlg_Text OrcMale, DataA_Text0_TownHouse4BreakerLava3_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
