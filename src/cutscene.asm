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

.INCLUDE "actors/child.inc"
.INCLUDE "actors/orc.inc"
.INCLUDE "audio.inc"
.INCLUDE "avatar.inc"
.INCLUDE "cpu.inc"
.INCLUDE "cutscene.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"

.IMPORT DataA_Cutscene_CityCenterBreakerCity_sCutscene
.IMPORT DataA_Cutscene_CityFlowerOrcAttack_sCutscene
.IMPORT DataA_Cutscene_CityOutskirtsLook_sCutscene
.IMPORT DataA_Cutscene_CoreBossFinaleReactivate_sCutscene
.IMPORT DataA_Cutscene_CoreBossFinaleSelfDestruct_sCutscene
.IMPORT DataA_Cutscene_CoreBossGrontaDefeated_sCutscene
.IMPORT DataA_Cutscene_CoreBossPowerUpCircuit_sCutscene
.IMPORT DataA_Cutscene_CoreBossStartBattle_sCutscene
.IMPORT DataA_Cutscene_CoreLockBreakerShadow_sCutscene
.IMPORT DataA_Cutscene_CoreSouthCorraHelping_sCutscene
.IMPORT DataA_Cutscene_FactoryEastCorraHelping_sCutscene
.IMPORT DataA_Cutscene_FactoryElevatorWaitUp_sCutscene
.IMPORT DataA_Cutscene_GardenShrineBreakerMine_sCutscene
.IMPORT DataA_Cutscene_MermaidHut1AlexPetition_sCutscene
.IMPORT DataA_Cutscene_MermaidHut1BreakerCrypt_sCutscene
.IMPORT DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
.IMPORT DataA_Cutscene_MermaidSpringFixConsole_sCutscene
.IMPORT DataA_Cutscene_MermaidVillageAlexLeave_sCutscene
.IMPORT DataA_Cutscene_PrisonCellGetThrownIn_sCutscene
.IMPORT DataA_Cutscene_PrisonUpperBreakerTemple_sCutscene
.IMPORT DataA_Cutscene_PrisonUpperFreeAlex_sCutscene
.IMPORT DataA_Cutscene_PrisonUpperFreeKids_sCutscene
.IMPORT DataA_Cutscene_PrisonUpperLoosenBrick_sCutscene
.IMPORT DataA_Cutscene_SharedFlipBreaker_sCutscene
.IMPORT DataA_Cutscene_SharedTeleportIn_sCutscene
.IMPORT DataA_Cutscene_SharedTeleportOut_sCutscene
.IMPORT DataA_Cutscene_TempleEntryWaitUp_sCutscene
.IMPORT DataA_Cutscene_TempleNaveAlexBoosting_sCutscene
.IMPORT DataA_Cutscene_TownHouse2WakeUp_sCutscene
.IMPORT DataA_Cutscene_TownHouse4BreakerLava_sCutscene
.IMPORT DataA_Cutscene_TownOutdoorsGetCaught_sCutscene
.IMPORT DataA_Cutscene_TownOutdoorsOrcAttack_sCutscene
.IMPORT FuncA_Actor_TickAllActors
.IMPORT FuncA_Actor_TickAllSmokeActors
.IMPORT FuncA_Avatar_RagdollMove
.IMPORT FuncA_Room_CallRoomTick
.IMPORT FuncM_DrawObjectsForRoomAndProcessFrame
.IMPORT FuncM_ScrollTowardsGoal
.IMPORT Func_PlaySfxSample
.IMPORT Func_ShakeRoom
.IMPORT Func_TickAllDevices
.IMPORT Main_Dialog_WithinCutscene
.IMPORT Main_Explore_Continue
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorState4_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_ScrollGoalX_u16

;;;=========================================================================;;;

;;; The fork index for the main cutscene fork.
kMainForkIndex = 0

;;;=========================================================================;;;

.ZEROPAGE

;;; Which tick functions to call during the current cutscene.
Zp_CutsceneFlags_bCutscene: .res 1

;;; The index of the current cutscene fork (from zero inclusive to kMaxForks
;;; exclusive).
Zp_ForkIndex_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Cutscene"

;;; Timers used to implement the WaitFrames action for each cutscene fork.
;;; Starts at zero, and increments each frame that the cutscene is blocked on a
;;; WaitFrames action.  When the WaitFrames completes, this is reset back to
;;; zero.
Ram_CutsceneTimer_u8_arr: .res kMaxForks

;;; A pointer to the next cutscene action to be executed for each cutscene
;;; fork.
Ram_Next_sCutscene_ptr_0_arr: .res kMaxForks
Ram_Next_sCutscene_ptr_1_arr: .res kMaxForks

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for starting a new cutscene.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
;;; @param X The eCutscene value for the cutscene to play.
.EXPORT Main_Cutscene_Start
.PROC Main_Cutscene_Start
    jsr_prga FuncA_Cutscene_Init
    .assert * = Main_Cutscene_Continue, error, "fallthrough"
.ENDPROC

;;; Mode for continuing a cutscene that's already in progress.
;;; @prereq Rendering is enabled.
;;; @prereq The current cutscene is already initialized.
.EXPORT Main_Cutscene_Continue
.PROC Main_Cutscene_Continue
_GameLoop:
    jsr FuncM_DrawObjectsForRoomAndProcessFrame
    jsr_prga FuncA_Cutscene_ExecuteAllForks  ; returns C, T1T0, and Y
    bcs _Finish
    jsr FuncM_ScrollTowardsGoal
    jsr_prga FuncA_Actor_TickCutsceneActors
    jsr Func_TickAllDevices
_MaybeTickRoom:
    bit Zp_CutsceneFlags_bCutscene
    .assert bCutscene::RoomTick = bProc::Negative, error
    bpl @noRoomTick
    jsr_prga FuncA_Room_CallRoomTick
    @noRoomTick:
_MaybeAvatarRagdoll:
    bit Zp_CutsceneFlags_bCutscene
    .assert bCutscene::AvatarRagdoll = bProc::Overflow, error
    bvc @noRagdoll
    jsr_prga FuncA_Avatar_RagdollMove
    @noRagdoll:
    jmp _GameLoop
_Finish:
    jmp (T1T0)
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Ticks all actors if bCutscene::TickAllActors is set; otherwise, ticks smoke
;;; actors only.
.PROC FuncA_Actor_TickCutsceneActors
    lda Zp_CutsceneFlags_bCutscene
    and #bCutscene::TickAllActors
    jeq FuncA_Actor_TickAllSmokeActors
    jmp FuncA_Actor_TickAllActors
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; A null cutscene that just immediately ends the current fork.
.PROC DataA_Cutscene_Null_sCutscene
    act_ForkStop $ff
.ENDPROC

;;; Maps from an eCutscene value to a pointer to the cutscene action sequence.
.LINECONT +
.REPEAT 2, table
    D_TABLE_LO table, DataA_Cutscene_Table_sCutscene_ptr_0_arr
    D_TABLE_HI table, DataA_Cutscene_Table_sCutscene_ptr_1_arr
    D_TABLE .enum, eCutscene
    d_entry table, None, DataA_Cutscene_Null_sCutscene
    d_entry table, CityCenterBreakerCity, \
            DataA_Cutscene_CityCenterBreakerCity_sCutscene
    d_entry table, CityFlowerOrcAttack, \
            DataA_Cutscene_CityFlowerOrcAttack_sCutscene
    d_entry table, CityOutskirtsLook, \
            DataA_Cutscene_CityOutskirtsLook_sCutscene
    d_entry table, CoreBossFinaleReactivate, \
            DataA_Cutscene_CoreBossFinaleReactivate_sCutscene
    d_entry table, CoreBossFinaleSelfDestruct, \
            DataA_Cutscene_CoreBossFinaleSelfDestruct_sCutscene
    d_entry table, CoreBossGrontaDefeated, \
            DataA_Cutscene_CoreBossGrontaDefeated_sCutscene
    d_entry table, CoreBossPowerUpCircuit, \
            DataA_Cutscene_CoreBossPowerUpCircuit_sCutscene
    d_entry table, CoreBossStartBattle, \
            DataA_Cutscene_CoreBossStartBattle_sCutscene
    d_entry table, CoreLockBreakerShadow, \
            DataA_Cutscene_CoreLockBreakerShadow_sCutscene
    d_entry table, CoreSouthCorraHelping, \
            DataA_Cutscene_CoreSouthCorraHelping_sCutscene
    d_entry table, FactoryEastCorraHelping, \
            DataA_Cutscene_FactoryEastCorraHelping_sCutscene
    d_entry table, FactoryElevatorWaitUp, \
            DataA_Cutscene_FactoryElevatorWaitUp_sCutscene
    d_entry table, GardenShrineBreakerMine, \
            DataA_Cutscene_GardenShrineBreakerMine_sCutscene
    d_entry table, MermaidHut1AlexPetition, \
            DataA_Cutscene_MermaidHut1AlexPetition_sCutscene
    d_entry table, MermaidHut1BreakerCrypt, \
            DataA_Cutscene_MermaidHut1BreakerCrypt_sCutscene
    d_entry table, MermaidHut1BreakerGarden, \
            DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
    d_entry table, MermaidSpringFixConsole, \
            DataA_Cutscene_MermaidSpringFixConsole_sCutscene
    d_entry table, MermaidVillageAlexLeave, \
            DataA_Cutscene_MermaidVillageAlexLeave_sCutscene
    d_entry table, PrisonCellGetThrownIn, \
            DataA_Cutscene_PrisonCellGetThrownIn_sCutscene
    d_entry table, PrisonUpperBreakerTemple, \
            DataA_Cutscene_PrisonUpperBreakerTemple_sCutscene
    d_entry table, PrisonUpperFreeAlex, \
            DataA_Cutscene_PrisonUpperFreeAlex_sCutscene
    d_entry table, PrisonUpperFreeKids, \
            DataA_Cutscene_PrisonUpperFreeKids_sCutscene
    d_entry table, PrisonUpperLoosenBrick, \
            DataA_Cutscene_PrisonUpperLoosenBrick_sCutscene
    d_entry table, SharedFlipBreaker, \
            DataA_Cutscene_SharedFlipBreaker_sCutscene
    d_entry table, SharedTeleportIn, \
            DataA_Cutscene_SharedTeleportIn_sCutscene
    d_entry table, SharedTeleportOut, \
            DataA_Cutscene_SharedTeleportOut_sCutscene
    d_entry table, TempleEntryWaitUp, \
            DataA_Cutscene_TempleEntryWaitUp_sCutscene
    d_entry table, TempleNaveAlexBoosting, \
            DataA_Cutscene_TempleNaveAlexBoosting_sCutscene
    d_entry table, TownHouse2WakeUp, \
            DataA_Cutscene_TownHouse2WakeUp_sCutscene
    d_entry table, TownHouse4BreakerLava, \
            DataA_Cutscene_TownHouse4BreakerLava_sCutscene
    d_entry table, TownOutdoorsGetCaught, \
            DataA_Cutscene_TownOutdoorsGetCaught_sCutscene
    d_entry table, TownOutdoorsOrcAttack, \
            DataA_Cutscene_TownOutdoorsOrcAttack_sCutscene
    D_END
.ENDREPEAT
.LINECONT -

;;; Initializes variables for a new cutscene.
;;; @param X The eCutscene value for the cutscene to play.
.PROC FuncA_Cutscene_Init
    lda #eCutscene::None
    sta Zp_Next_eCutscene
_InitSecondaryForks:
    ldy #kMaxForks - 1
    @loop:
    lda #0
    sta Ram_CutsceneTimer_u8_arr, y
    lda #<DataA_Cutscene_Null_sCutscene
    sta Ram_Next_sCutscene_ptr_0_arr, y
    lda #>DataA_Cutscene_Null_sCutscene
    sta Ram_Next_sCutscene_ptr_1_arr, y
    dey
    bne @loop
_InitMainFork:
    ;; At this point, Y is zero.
    sty Zp_CutsceneFlags_bCutscene
    .assert kMainForkIndex = 0, error
    sty Ram_CutsceneTimer_u8_arr + kMainForkIndex
    lda DataA_Cutscene_Table_sCutscene_ptr_0_arr, x
    sta Ram_Next_sCutscene_ptr_0_arr + kMainForkIndex
    lda DataA_Cutscene_Table_sCutscene_ptr_1_arr, x
    sta Ram_Next_sCutscene_ptr_1_arr + kMainForkIndex
    rts
.ENDPROC

;;; Executes actions for the current frame on all cutscene forks.
;;; @return C Set if the cutscene should end.
;;; @return T1T0 If C is set, this holds the address of the main to jump to.
;;; @return Y A parameter for the main to jump to, if any.
.PROC FuncA_Cutscene_ExecuteAllForks
    ldx #0
    @loop:
    stx Zp_ForkIndex_u8
    jsr FuncA_Cutscene_ExecuteOneFork  ; returns C, T1T0, and Y
    bcs @return  ; cutscene should end
    ldx Zp_ForkIndex_u8
    inx
    cpx #kMaxForks
    blt @loop
    clc  ; cutscene should continue
    @return:
    rts
.ENDPROC

;;; Adds Y to the Next_sCutscene_ptr for the current cutscene fork.
;;; @prereq Zp_ForkIndex_u8 is initialized.
;;; @param Y The byte offset to add.
;;; @preserve T0+
.PROC FuncA_Cutscene_AdvanceFork
    ldx Zp_ForkIndex_u8
    tya  ; byte offset
    add Ram_Next_sCutscene_ptr_0_arr, x
    sta Ram_Next_sCutscene_ptr_0_arr, x
    lda #0
    adc Ram_Next_sCutscene_ptr_1_arr, x
    sta Ram_Next_sCutscene_ptr_1_arr, x
    rts
.ENDPROC

;;; Calls FuncA_Cutscene_AdvanceFork and then FuncA_Cutscene_ExecuteOneFork.
;;; @prereq Zp_ForkIndex_u8 is initialized.
;;; @param Y The byte offset to add.
;;; @return C Set if the cutscene should end.
;;; @return T1T0 If C is set, this holds the address of the main to jump to.
;;; @return Y A parameter for the main to jump to, if any.
.PROC FuncA_Cutscene_AdvanceForkAndExecute
    jsr FuncA_Cutscene_AdvanceFork
    .assert * = FuncA_Cutscene_ExecuteOneFork, error, "fallthrough"
.ENDPROC

;;; Executes actions for the current frame on the current cutscene fork.
;;; @prereq Zp_ForkIndex_u8 is initialized.
;;; @return C Set if the cutscene should end.
;;; @return T1T0 If C is set, this holds the address of the main to jump to.
;;; @return Y A parameter for the main to jump to, if any.
.PROC FuncA_Cutscene_ExecuteOneFork
    ldx Zp_ForkIndex_u8
    lda Ram_Next_sCutscene_ptr_0_arr, x
    sta T0
    lda Ram_Next_sCutscene_ptr_1_arr, x
    sta T1
    ldy #0
    lda (T1T0), y
    tax  ; eAction value
    iny
    lda _JumpTable_ptr_0_arr, x
    sta T2
    lda _JumpTable_ptr_1_arr, x
    sta T3
    jmp (T3T2)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eAction
    d_entry table, BranchIfC,         _BranchIfC
    d_entry table, BranchIfZ,         _BranchIfZ
    d_entry table, CallFunc,          _CallFunc
    d_entry table, ContinueExploring, _ContinueExploring
    d_entry table, ForkStart,         _ForkStart
    d_entry table, ForkStop,          _ForkStop
    d_entry table, JumpToMain,        _JumpToMain
    d_entry table, PlayMusic,         _PlayMusic
    d_entry table, PlaySfxSample,     _PlaySfxSample
    d_entry table, RepeatFunc,        _RepeatFunc
    d_entry table, RunDialog,         _RunDialog
    d_entry table, ScrollSlowX,       _ScrollSlowX
    d_entry table, SetActorFlags,     _SetActorFlags
    d_entry table, SetActorPosX,      _SetActorPosX
    d_entry table, SetActorPosY,      _SetActorPosY
    d_entry table, SetActorState1,    _SetActorState1
    d_entry table, SetActorState2,    _SetActorState2
    d_entry table, SetActorState3,    _SetActorState3
    d_entry table, SetActorState4,    _SetActorState4
    d_entry table, SetActorVelX,      _SetActorVelX
    d_entry table, SetActorVelY,      _SetActorVelY
    d_entry table, SetAvatarFlags,    _SetAvatarFlags
    d_entry table, SetAvatarPosX,     _SetAvatarPosX
    d_entry table, SetAvatarPosY,     _SetAvatarPosY
    d_entry table, SetAvatarPose,     _SetAvatarPose
    d_entry table, SetAvatarState,    _SetAvatarState
    d_entry table, SetAvatarVelX,     _SetAvatarVelX
    d_entry table, SetAvatarVelY,     _SetAvatarVelY
    d_entry table, SetCutsceneFlags,  _SetCutsceneFlags
    d_entry table, SetDeviceAnim,     _SetDeviceAnim
    d_entry table, SetScrollFlags,    _SetScrollFlags
    d_entry table, ShakeRoom,         _ShakeRoom
    d_entry table, SwimNpcAlex,       _SwimNpcAlex
    d_entry table, WaitFrames,        _WaitFrames
    d_entry table, WaitUntilC,        _WaitUntilC
    d_entry table, WaitUntilZ,        _WaitUntilZ
    d_entry table, WalkAvatar,        _WalkAvatar
    d_entry table, WalkNpcAlex,       _WalkNpcAlex
    d_entry table, WalkNpcBruno,      _WalkNpcBruno
    d_entry table, WalkNpcGronta,     _WalkNpcGronta
    d_entry table, WalkNpcMarie,      _WalkNpcMarie
    d_entry table, WalkNpcNora,       _WalkNpcNora
    d_entry table, WalkNpcOrc,        _WalkNpcOrc
    d_entry table, WalkNpcToddler,    _WalkNpcToddler
    D_END
.ENDREPEAT
_BranchIfC:
    jsr _CallFuncArg  ; returns C
    bcs _Branch
    bcc _NoBranch  ; unconditional
_BranchIfZ:
    jsr _CallFuncArg  ; returns Z
    beq _Branch
_NoBranch:
    ldy #5  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_Branch:
    ldx Zp_ForkIndex_u8
    lda Ram_Next_sCutscene_ptr_0_arr, x
    sta T0
    lda Ram_Next_sCutscene_ptr_1_arr, x
    sta T1
    ldy #3
    lda (T1T0), y
    sta Ram_Next_sCutscene_ptr_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_Next_sCutscene_ptr_1_arr, x
    jmp FuncA_Cutscene_ExecuteOneFork
_CallFunc:
    jsr _CallFuncArg
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_ContinueExploring:
    ldax #Main_Explore_Continue
    stax T1T0
    sec  ; exit cutscene mode
    rts
_ForkStart:
    lda (T1T0), y
    tax  ; fork index to start
    iny
    lda (T1T0), y
    sta Ram_Next_sCutscene_ptr_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_Next_sCutscene_ptr_1_arr, x
    cpx Zp_ForkIndex_u8
    jeq FuncA_Cutscene_ExecuteOneFork
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_ForkStop:
    lda (T1T0), y
    tax  ; fork index to end
    .assert kMainForkIndex = 0, error
    beq _ContinueExploring
    bmi @endCurrentFork
    cpx Zp_ForkIndex_u8
    beq @endCurrentFork
    @endOtherFork:
    iny
    lda #<DataA_Cutscene_Null_sCutscene
    sta Ram_Next_sCutscene_ptr_0_arr, x
    lda #>DataA_Cutscene_Null_sCutscene
    sta Ram_Next_sCutscene_ptr_1_arr, x
    jmp FuncA_Cutscene_AdvanceForkAndExecute
    @endCurrentFork:
    lda Zp_ForkIndex_u8
    .assert kMainForkIndex = 0, error
    beq _ContinueExploring
    clc  ; cutscene should continue
    rts
_JumpToMain:
    lda (T1T0), y
    tax
    iny
    lda (T1T0), y
    stax T1T0
    sec  ; exit cutscene mode
    rts
_PlayMusic:
    lda (T1T0), y
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_PlaySfxSample:
    lda (T1T0), y  ; param: eSample to play
    jsr Func_PlaySfxSample  ; preserves Y
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_RepeatFunc:
    ldx Zp_ForkIndex_u8
    lda (T1T0), y
    cmp Ram_CutsceneTimer_u8_arr, x
    bne @stillWaiting
    lda #0
    sta Ram_CutsceneTimer_u8_arr, x
    ldy #4  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
    @stillWaiting:
    iny
    lda Ram_CutsceneTimer_u8_arr, x
    inc Ram_CutsceneTimer_u8_arr, x
    tax  ; param: old timer value
    jsr _CallFuncArg
    clc  ; cutscene should continue
    rts
_RunDialog:
    lda (T1T0), y
    pha  ; eDialog value
    iny
    jsr FuncA_Cutscene_AdvanceFork
    pla  ; eDialog value
    tay  ; param: eDialog value
    ldax #Main_Dialog_WithinCutscene
    stax T1T0
    sec  ; exit cutscene mode
    rts
_ScrollSlowX:
    lda (T1T0), y
    sta Zp_PointX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_PointX_i16 + 1
    jsr FuncA_Cutscene_MoveScrollGoalTowardPointX  ; returns C
    bcs @reachedGoal
    rts  ; otherwise, C is clear to indicate that the cutscene should continue
    @reachedGoal:
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorFlags:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorFlags_bObj_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorPosX:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorPosX_i16_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_ActorPosX_i16_1_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorPosY:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorPosY_i16_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_ActorPosY_i16_1_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorState1:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorState1_byte_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorState2:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorState2_byte_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorState3:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorState3_byte_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorState4:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorState4_byte_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorVelX:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorVelX_i16_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_ActorVelX_i16_1_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorVelY:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorVelY_i16_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_ActorVelY_i16_1_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetAvatarFlags:
    lda (T1T0), y
    sta Zp_AvatarFlags_bObj
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetAvatarPosX:
    lda (T1T0), y
    sta Zp_AvatarPosX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_AvatarPosX_i16 + 1
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetAvatarPosY:
    lda (T1T0), y
    sta Zp_AvatarPosY_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_AvatarPosY_i16 + 1
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetAvatarPose:
    lda (T1T0), y
    sta Zp_AvatarPose_eAvatar
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetAvatarState:
    lda (T1T0), y
    sta Zp_AvatarState_bAvatar
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetAvatarVelX:
    lda (T1T0), y
    sta Zp_AvatarVelX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_AvatarVelX_i16 + 1
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetAvatarVelY:
    lda (T1T0), y
    sta Zp_AvatarVelY_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_AvatarVelY_i16 + 1
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetDeviceAnim:
    lda (T1T0), y
    tax  ; device index
    iny
    lda (T1T0), y
    sta Ram_DeviceAnim_u8_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetCutsceneFlags:
    lda (T1T0), y
    sta Zp_CutsceneFlags_bCutscene
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetScrollFlags:
    lda (T1T0), y
    sta Zp_Camera_bScroll
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_ShakeRoom:
    lda (T1T0), y  ; param: num shake frames
    jsr Func_ShakeRoom  ; preserves Y
    iny
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_WaitFrames:
    ldx Zp_ForkIndex_u8
    lda (T1T0), y
    cmp Ram_CutsceneTimer_u8_arr, x
    bne @stillWaiting
    iny
    lda #0
    sta Ram_CutsceneTimer_u8_arr, x
    jmp FuncA_Cutscene_AdvanceForkAndExecute
    @stillWaiting:
    inc Ram_CutsceneTimer_u8_arr, x
    clc  ; cutscene should continue
    rts
_WaitUntilC:
    jsr _CallFuncArg  ; returns C
    bcs _DoneWaitingUntil
    rts  ; carry is already clear (cutscene should continue)
_WaitUntilZ:
    jsr _CallFuncArg  ; returns Z
    beq _DoneWaitingUntil
    clc  ; cutscene should continue
    rts
_DoneWaitingUntil:
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_WalkAvatar:
    lda (T1T0), y
    sta Zp_PointX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_PointX_i16 + 1
    jsr FuncA_Cutscene_MoveAvatarTowardPointX  ; returns Z and N
    beq @reachedGoal
    jsr FuncA_Cutscene_AnimateAvatarWalking
    clc  ; cutscene should continue
    rts
    @reachedGoal:
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_MoveNpcReachedGoal:
    ldy #4  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SwimNpcAlex:
    jsr _StartMoveNpc  ; returns X, Z, and N
    beq _MoveNpcReachedGoal
    jsr FuncA_Cutscene_AnimateNpcAlexSwimming  ; preserves X
    jsr FuncA_Cutscene_FaceAvatarTowardsActor
    clc  ; cutscene should continue
    rts
_WalkNpcAlex:
    jsr _StartMoveNpc  ; returns X, Z, and N
    beq _MoveNpcReachedGoal
    jsr FuncA_Cutscene_AnimateNpcAlexWalking  ; preserves X
    jsr FuncA_Cutscene_FaceAvatarTowardsActor
    clc  ; cutscene should continue
    rts
_WalkNpcBruno:
    jsr _StartMoveNpc  ; returns X, Z, and N
    beq _MoveNpcReachedGoal
    jsr FuncA_Cutscene_AnimateNpcBrunoWalking  ; preserves X
    jsr FuncA_Cutscene_FaceAvatarTowardsActor
    clc  ; cutscene should continue
    rts
_WalkNpcGronta:
    jsr _StartMoveNpc  ; returns X, Z, and N
    beq _MoveNpcReachedGoal
    jsr FuncA_Cutscene_AnimateNpcGrontaWalking
    clc  ; cutscene should continue
    rts
_WalkNpcMarie:
    jsr _StartMoveNpc  ; returns X, Z, and N
    beq _MoveNpcReachedGoal
    jsr FuncA_Cutscene_AnimateNpcMarieWalking  ; preserves X
    jsr FuncA_Cutscene_FaceAvatarTowardsActor
    clc  ; cutscene should continue
    rts
_WalkNpcNora:
    jsr _StartMoveNpc  ; returns X, Z, and N
    beq _MoveNpcReachedGoal
    jsr FuncA_Cutscene_AnimateNpcNoraWalking
    clc  ; cutscene should continue
    rts
_WalkNpcOrc:
    jsr _StartMoveNpc  ; returns X, Z, and N
    beq _MoveNpcReachedGoal
    jsr FuncA_Cutscene_AnimateNpcOrcWalking
    clc  ; cutscene should continue
    rts
_WalkNpcToddler:
    jsr _StartMoveNpc  ; returns X, Z, and N
    beq _MoveNpcReachedGoal
    jsr FuncA_Cutscene_AnimateNpcToddlerWalking
    clc  ; cutscene should continue
    rts
_StartMoveNpc:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Zp_PointX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_PointX_i16 + 1
    jmp FuncA_Cutscene_MoveActorTowardPointX  ; preserves X, returns Z and N
_CallFuncArg:
    lda (T1T0), y
    sta T2
    iny
    lda (T1T0), y
    sta T3
    jmp (T3T2)
.ENDPROC

;;; Moves Zp_ScrollGoalX_u16 one pixel left or right towards Zp_PointX_i16.
;;; @return C Set if the goal point has been reached.
.PROC FuncA_Cutscene_MoveScrollGoalTowardPointX
    lda Zp_PointX_i16 + 0
    sub Zp_ScrollGoalX_u16 + 0
    sta T0  ; delta (lo)
    lda Zp_PointX_i16 + 1
    sbc Zp_ScrollGoalX_u16 + 1
    bmi _MoveLeft
    bne _MoveRight
    lda T0  ; delta (lo)
    bne _MoveRight
    sec  ; goal point has been reached
    rts
_MoveRight:
    ldya #1
    bpl _MoveByYA  ; unconditional
_MoveLeft:
    ldya #$ffff & -1
_MoveByYA:
    add Zp_ScrollGoalX_u16 + 0
    sta Zp_ScrollGoalX_u16 + 0
    tya
    adc Zp_ScrollGoalX_u16 + 1
    sta Zp_ScrollGoalX_u16 + 1
    clc  ; not yet reached goal
    rts
.ENDPROC

;;; Moves the player avatar one pixel left or right towards Zp_PointX_i16.
;;; @return A The pixel delta that the avatar actually moved by (signed).
;;; @return N Set if the avatar moved left, cleared otherwise.
;;; @return Z Cleared if the avatar moved, set if it was at the goal position.
.PROC FuncA_Cutscene_MoveAvatarTowardPointX
    lda Zp_PointX_i16 + 0
    sub Zp_AvatarPosX_i16 + 0
    sta T0  ; delta (lo)
    lda Zp_PointX_i16 + 1
    sbc Zp_AvatarPosX_i16 + 1
    bmi _MoveLeft
    bne _MoveRight
    lda T0  ; delta (lo)
    bne _MoveRight
    rts
_MoveRight:
    ldya #1
    bpl _MoveByYA  ; unconditional
_MoveLeft:
    ldya #$ffff & -1
_MoveByYA:
    pha  ; move delta (lo)
    add Zp_AvatarPosX_i16 + 0
    sta Zp_AvatarPosX_i16 + 0
    tya
    adc Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
    pla  ; move delta (lo)
    rts
.ENDPROC

;;; Moves the specified actor one pixel left or right towards Zp_PointX_i16.
;;; @param X The actor index.
;;; @return A The pixel delta that the actor actually moved by (signed).
;;; @return N Set if the actor moved left, cleared otherwise.
;;; @return Z Cleared if the actor moved, set if it was at the goal position.
;;; @preserve X
.PROC FuncA_Cutscene_MoveActorTowardPointX
    lda Zp_PointX_i16 + 0
    sub Ram_ActorPosX_i16_0_arr, x
    sta T0  ; delta (lo)
    lda Zp_PointX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    bmi _MoveLeft
    bne _MoveRight
    lda T0  ; delta (lo)
    bne _MoveRight
    rts
_MoveRight:
    lda #1
    ldy #0
    beq _MoveByYA  ; unconditional
_MoveLeft:
    lda #<-1
    ldy #>-1
_MoveByYA:
    pha  ; move delta (lo)
    add Ram_ActorPosX_i16_0_arr, x
    sta Ram_ActorPosX_i16_0_arr, x
    tya
    adc Ram_ActorPosX_i16_1_arr, x
    sta Ram_ActorPosX_i16_1_arr, x
    pla  ; move delta (lo)
    rts
.ENDPROC

;;; Updates the flags and pose of the player avatar for a walking animation.
;;; @param N If set, the avatar will face left; otherwise, it will face right.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateAvatarWalking
    bpl @faceRight
    @faceLeft:
    lda #kPaletteObjAvatarNormal | bObj::FlipH
    bne @setFace  ; unconditional
    @faceRight:
    lda #kPaletteObjAvatarNormal
    @setFace:
    sta Zp_AvatarFlags_bObj
    lda #0
    sta Zp_AvatarState_bAvatar
_AnimatePose:
    lda Zp_FrameCounter_u8
    and #$08
    beq @walk2
    @walk1:
    lda #eAvatar::Running1
    .assert eAvatar::Running1 > 0, error
    bne @setPose  ; unconditional
    @walk2:
    lda #eAvatar::Running2
    @setPose:
    sta Zp_AvatarPose_eAvatar
    rts
.ENDPROC

;;; Updates the flags and state of the specified Alex NPC actor for a swimming
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcAlexSwimming
    jsr FuncA_Cutscene_SetActorFlipHFromN  ; preserves X, Y and T0+
    lda #$ff
    sta Ram_ActorState2_byte_arr, x
_AnimatePose:
    lda Zp_FrameCounter_u8
    and #$10
    beq @swim2
    @swim1:
    lda #eNpcChild::AlexSwimming1
    .assert eNpcChild::AlexSwimming1 > 0, error
    bne @setState  ; unconditional
    @swim2:
    lda #eNpcChild::AlexSwimming2
    @setState:
    sta Ram_ActorState1_byte_arr, x
    rts
.ENDPROC

;;; Updates the flags and state of the specified Alex NPC actor for a walking
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcAlexWalking
    jsr FuncA_Cutscene_SetActorFlipHFromN  ; preserves X, Y and T0+
    lda #$ff
    sta Ram_ActorState2_byte_arr, x
_AnimatePose:
    lda Zp_FrameCounter_u8
    and #$08
    beq @walk2
    @walk1:
    lda #eNpcChild::AlexWalking1
    .assert eNpcChild::AlexWalking1 > 0, error
    bne @setState  ; unconditional
    @walk2:
    lda #eNpcChild::AlexWalking2
    @setState:
    sta Ram_ActorState1_byte_arr, x
    rts
.ENDPROC

;;; Updates the flags and state of the specified Bruno NPC actor for a walking
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcBrunoWalking
    jsr FuncA_Cutscene_SetActorFlipHFromN  ; preserves X, Y and T0+
    lda #$ff
    sta Ram_ActorState2_byte_arr, x
_AnimatePose:
    lda Zp_FrameCounter_u8
    and #$08
    beq @walk2
    @walk1:
    lda #eNpcChild::BrunoWalking1
    .assert eNpcChild::BrunoWalking1 > 0, error
    bne @setState  ; unconditional
    @walk2:
    lda #eNpcChild::BrunoWalking2
    @setState:
    sta Ram_ActorState1_byte_arr, x
    rts
.ENDPROC

;;; Updates the flags and state of the specified Gronta NPC actor for a walking
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcGrontaWalking
    jsr FuncA_Cutscene_SetActorFlipHFromN  ; preserves X, Y and T0+
    lda #$ff
    sta Ram_ActorState2_byte_arr, x
_AnimatePose:
    lda Zp_FrameCounter_u8
    div #08
    and #$03
    .assert eNpcOrc::GrontaRunning1 > 0, error
    .assert eNpcOrc::GrontaRunning1 .mod 4 = 0, error
    ora #eNpcOrc::GrontaRunning1
    sta Ram_ActorState1_byte_arr, x
    rts
.ENDPROC

;;; Updates the flags and state of the specified Marie NPC actor for a walking
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcMarieWalking
    jsr FuncA_Cutscene_SetActorFlipHFromN  ; preserves X, Y and T0+
    lda #$ff
    sta Ram_ActorState2_byte_arr, x
_AnimatePose:
    lda Zp_FrameCounter_u8
    and #$08
    beq @walk2
    @walk1:
    lda #eNpcChild::MarieWalking1
    .assert eNpcChild::MarieWalking1 > 0, error
    bne @setState  ; unconditional
    @walk2:
    lda #eNpcChild::MarieWalking2
    @setState:
    sta Ram_ActorState1_byte_arr, x
    rts
.ENDPROC

;;; Updates the flags and state of the specified Nora NPC actor for a walking
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcNoraWalking
    jsr FuncA_Cutscene_SetActorFlipHFromN  ; preserves X, Y and T0+
    lda #$ff
    sta Ram_ActorState2_byte_arr, x
    rts
.ENDPROC

;;; Updates the flags and state of the specified orc NPC actor for a walking
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcOrcWalking
    jsr FuncA_Cutscene_SetActorFlipHFromN  ; preserves X, Y and T0+
    lda #$ff
    sta Ram_ActorState2_byte_arr, x
_AnimatePose:
    lda Zp_FrameCounter_u8
    div #08
    and #$03
    .assert eNpcOrc::GruntRunning1 = 0, error
    sta Ram_ActorState1_byte_arr, x
    rts
.ENDPROC

;;; Updates the flags and state of the specified toddler NPC actor for a
;;; walking animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcToddlerWalking
    jsr FuncA_Cutscene_SetActorFlipHFromN  ; preserves X, Y and T0+
_AnimatePose:
    lda Zp_FrameCounter_u8
    sta Ram_ActorState1_byte_arr, x
    rts
.ENDPROC

;;; Sets the specified actor's FlipH flag bit based on the N flag.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_SetActorFlipHFromN
    bpl @faceRight
    @faceLeft:
    lda Ram_ActorFlags_bObj_arr, x
    ora #bObj::FlipH
    bne @setFace  ; unconditional
    @faceRight:
    lda Ram_ActorFlags_bObj_arr, x
    and #<~bObj::FlipH
    @setFace:
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;; Update Zp_AvatarFlags_bObj to make player avatar face the specified actor.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_FaceAvatarTowardsActor
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_ActorPosX_i16_0_arr, x
    lda Zp_AvatarPosX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bmi @faceRight
    @faceLeft:
    lda #bObj::FlipH | kPaletteObjAvatarNormal
    bne @setFace  ; unconditional
    @faceRight:
    lda #kPaletteObjAvatarNormal
    @setFace:
    sta Zp_AvatarFlags_bObj
    rts
.ENDPROC

;;;=========================================================================;;;
