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
.INCLUDE "avatar.inc"
.INCLUDE "cpu.inc"
.INCLUDE "cutscene.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"

.IMPORT DataA_Cutscene_CoreBossPowerUpCircuit_sCutscene
.IMPORT DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
.IMPORT DataA_Cutscene_PrisonCellGetThrownIn_sCutscene
.IMPORT DataA_Cutscene_PrisonUpperBreakerTemple_sCutscene
.IMPORT DataA_Cutscene_PrisonUpperFreeAlex_sCutscene
.IMPORT DataA_Cutscene_SharedFadeBackToBreakerRoom_sCutscene
.IMPORT DataA_Cutscene_SharedTeleportIn_sCutscene
.IMPORT DataA_Cutscene_SharedTeleportOut_sCutscene
.IMPORT DataA_Cutscene_TempleNaveAlexBoosting_sCutscene
.IMPORT DataA_Cutscene_TownHouse2WakeUp_sCutscene
.IMPORT DataA_Cutscene_TownOutdoorsGetCaught_sCutscene
.IMPORT DataA_Cutscene_TownOutdoorsOrcAttack_sCutscene
.IMPORT FuncA_Actor_TickAllSmokeActors
.IMPORT FuncA_Avatar_RagdollMove
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_ClearRestOfOamAndProcessFrame
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
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointX_i16

;;;=========================================================================;;;

;;; The fork index for the main cutscene fork.
kMainForkIndex = 0

;;;=========================================================================;;;

.ZEROPAGE

;;; Which tick functions to call during the current cutscene.
Zp_CutsceneFlags_bCutscene: .res 1

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
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Cutscene_ExecuteAllForks  ; returns C and T1T0
    bcs _Finish
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jsr_prga FuncA_Actor_TickAllSmokeActors
    jsr Func_TickAllDevices
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

.SEGMENT "PRGA_Cutscene"

;;; A null cutscene that just immediately ends the current fork.
.PROC DataA_Cutscene_Null_sCutscene
    .byte eAction::ForkStop, $ff
.ENDPROC

;;; Maps from an eCutscene value to a pointer to the cutscene action sequence.
.LINECONT +
.REPEAT 2, table
    D_TABLE_LO table, DataA_Cutscene_Table_sCutscene_ptr_0_arr
    D_TABLE_HI table, DataA_Cutscene_Table_sCutscene_ptr_1_arr
    D_TABLE eCutscene
    d_entry table, None, DataA_Cutscene_Null_sCutscene
    d_entry table, CoreBossPowerUpCircuit, \
            DataA_Cutscene_CoreBossPowerUpCircuit_sCutscene
    d_entry table, MermaidHut1BreakerGarden, \
            DataA_Cutscene_MermaidHut1BreakerGarden_sCutscene
    d_entry table, PrisonCellGetThrownIn, \
            DataA_Cutscene_PrisonCellGetThrownIn_sCutscene
    d_entry table, PrisonUpperBreakerTemple, \
            DataA_Cutscene_PrisonUpperBreakerTemple_sCutscene
    d_entry table, PrisonUpperFreeAlex, \
            DataA_Cutscene_PrisonUpperFreeAlex_sCutscene
    d_entry table, SharedFadeBackToBreakerRoom, \
            DataA_Cutscene_SharedFadeBackToBreakerRoom_sCutscene
    d_entry table, SharedTeleportIn, \
            DataA_Cutscene_SharedTeleportIn_sCutscene
    d_entry table, SharedTeleportOut, \
            DataA_Cutscene_SharedTeleportOut_sCutscene
    d_entry table, TempleNaveAlexBoosting, \
            DataA_Cutscene_TempleNaveAlexBoosting_sCutscene
    d_entry table, TownHouse2WakeUp, \
            DataA_Cutscene_TownHouse2WakeUp_sCutscene
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
.PROC FuncA_Cutscene_ExecuteAllForks
    ldx #0
    @loop:
    txa  ; fork index
    pha  ; fork index
    jsr FuncA_Cutscene_ExecuteOneFork  ; returns C and T1T0
    pla  ; fork index
    bcs @return
    tax  ; fork index
    inx
    cpx #kMaxForks
    blt @loop
    clc  ; cutscene should continue
    @return:
    rts
.ENDPROC

;;; Adds T to the Next_sCutscene_ptr for the specified fork.
;;; @param X The fork index.
;;; @param Y The byte offset to add.
;;; @preserve X, T0+
.PROC FuncA_Cutscene_AdvanceFork
    tya
    add Ram_Next_sCutscene_ptr_0_arr, x
    sta Ram_Next_sCutscene_ptr_0_arr, x
    lda #0
    adc Ram_Next_sCutscene_ptr_1_arr, x
    sta Ram_Next_sCutscene_ptr_1_arr, x
    rts
.ENDPROC

;;; Calls FuncA_Cutscene_AdvanceFork and then FuncA_Cutscene_ExecuteOneFork.
;;; @param X The fork index.
;;; @param Y The byte offset to add.
;;; @return C Set if the cutscene should end.
;;; @return T1T0 If C is set, this holds the address of the main to jump to.
.PROC FuncA_Cutscene_AdvanceForkAndExecute
    jsr FuncA_Cutscene_AdvanceFork
    .assert * = FuncA_Cutscene_ExecuteOneFork, error, "fallthrough"
.ENDPROC

;;; Executes actions for the current frame on the specified cutscene fork.
;;; @param X The fork index.
;;; @return C Set if the cutscene should end.
;;; @return T1T0 If C is set, this holds the address of the main to jump to.
.PROC FuncA_Cutscene_ExecuteOneFork
    stx T2  ; current fork index
    lda Ram_Next_sCutscene_ptr_0_arr, x
    sta T0
    lda Ram_Next_sCutscene_ptr_1_arr, x
    sta T1
    ldy #0
    lda (T1T0), y
    tax  ; eAction value
    iny
    lda _JumpTable_ptr_0_arr, x
    sta T4
    lda _JumpTable_ptr_1_arr, x
    sta T5
    jmp (T5T4)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eAction
    d_entry table, ContinueExploring, _ContinueExploring
    d_entry table, JumpToMain,        _JumpToMain
    d_entry table, ForkStart,         _ForkStart
    d_entry table, ForkStop,          _ForkStop
    d_entry table, CallFunc,          _CallFunc
    d_entry table, SetActorFlags,     _SetActorFlags
    d_entry table, SetActorPosX,      _SetActorPosX
    d_entry table, SetActorPosY,      _SetActorPosY
    d_entry table, SetActorState1,    _SetActorState1
    d_entry table, SetActorState2,    _SetActorState2
    d_entry table, SetAvatarFlags,    _SetAvatarFlags
    d_entry table, SetAvatarPosX,     _SetAvatarPosX
    d_entry table, SetAvatarPosY,     _SetAvatarPosY
    d_entry table, SetAvatarPose,     _SetAvatarPose
    d_entry table, SetAvatarState,    _SetAvatarState
    d_entry table, SetAvatarVelX,     _SetAvatarVelX
    d_entry table, SetAvatarVelY,     _SetAvatarVelY
    d_entry table, SetCutsceneFlags,  _SetCutsceneFlags
    d_entry table, ShakeRoom,         _ShakeRoom
    d_entry table, RunDialog,         _RunDialog
    d_entry table, WaitFrames,        _WaitFrames
    d_entry table, WaitUntilC,        _WaitUntilC
    d_entry table, WaitUntilZ,        _WaitUntilZ
    d_entry table, WalkAlex,          _WalkAlex
    d_entry table, WalkNpcOrc,        _WalkNpcOrc
    D_END
.ENDREPEAT
_AdvanceAndExecuteForkT2:
    ldx T2  ; param: current fork index
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_ContinueExploring:
    ldax #Main_Explore_Continue
    stax T1T0
    sec  ; exit cutscene mode
    rts
_JumpToMain:
    lda (T1T0), y
    tax
    iny
    lda (T1T0), y
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
    cpx T2  ; current fork index
    bne @startOtherFork
    jmp FuncA_Cutscene_ExecuteOneFork
    @startOtherFork:
    iny
    jmp _AdvanceAndExecuteForkT2
_ForkStop:
    lda (T1T0), y
    tax  ; fork index to end
    .assert kMainForkIndex = 0, error
    beq _ContinueExploring
    bmi @endCurrentFork
    cpx T2  ; current fork index
    beq @endCurrentFork
    @endOtherFork:
    iny
    lda #<DataA_Cutscene_Null_sCutscene
    sta Ram_Next_sCutscene_ptr_0_arr, x
    lda #>DataA_Cutscene_Null_sCutscene
    sta Ram_Next_sCutscene_ptr_1_arr, x
    jmp _AdvanceAndExecuteForkT2
    @endCurrentFork:
    lda T2  ; current fork index
    .assert kMainForkIndex = 0, error
    beq _ContinueExploring
    clc  ; cutscene should continue
    rts
_CallFunc:
    lda T2  ; current fork index
    pha  ; current fork index
    jsr _CallFuncArg
    pla  ; current fork index
    tax  ; param: current fork index
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_SetActorFlags:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorFlags_bObj_arr, x
    iny
    jmp _AdvanceAndExecuteForkT2
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
    jmp _AdvanceAndExecuteForkT2
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
    jmp _AdvanceAndExecuteForkT2
_SetActorState1:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorState1_byte_arr, x
    iny
    jmp _AdvanceAndExecuteForkT2
_SetActorState2:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Ram_ActorState2_byte_arr, x
    iny
    jmp _AdvanceAndExecuteForkT2
_SetAvatarFlags:
    lda (T1T0), y
    sta Zp_AvatarFlags_bObj
    iny
    jmp _AdvanceAndExecuteForkT2
_SetAvatarPosX:
    lda (T1T0), y
    sta Zp_AvatarPosX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_AvatarPosX_i16 + 1
    iny
    jmp _AdvanceAndExecuteForkT2
_SetAvatarPosY:
    lda (T1T0), y
    sta Zp_AvatarPosY_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_AvatarPosY_i16 + 1
    iny
    jmp _AdvanceAndExecuteForkT2
_SetAvatarPose:
    lda (T1T0), y
    sta Zp_AvatarPose_eAvatar
    iny
    jmp _AdvanceAndExecuteForkT2
_SetAvatarState:
    lda (T1T0), y
    sta Zp_AvatarState_bAvatar
    iny
    jmp _AdvanceAndExecuteForkT2
_SetAvatarVelX:
    lda (T1T0), y
    sta Zp_AvatarVelX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_AvatarVelX_i16 + 1
    iny
    jmp _AdvanceAndExecuteForkT2
_SetAvatarVelY:
    lda (T1T0), y
    sta Zp_AvatarVelY_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_AvatarVelY_i16 + 1
    iny
    jmp _AdvanceAndExecuteForkT2
_SetCutsceneFlags:
    lda (T1T0), y
    sta Zp_CutsceneFlags_bCutscene
    iny
    jmp _AdvanceAndExecuteForkT2
_ShakeRoom:
    lda (T1T0), y  ; param: num shake frames
    jsr Func_ShakeRoom  ; preserves Y
    iny
    jmp _AdvanceAndExecuteForkT2
_RunDialog:
    lda (T1T0), y
    pha  ; eDialog value
    iny
    ldx T2  ; param: current fork index
    jsr FuncA_Cutscene_AdvanceFork
    pla  ; eDialog value
    tay  ; param: eDialog value
    ldax #Main_Dialog_WithinCutscene
    stax T1T0
    sec  ; exit cutscene mode
    rts
_WaitFrames:
    ldx T2  ; current fork index
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
    lda T2  ; current fork index
    pha  ; current fork index
    jsr _CallFuncArg  ; returns C
    pla  ; current fork index
    bcs @advance
    rts  ; carry is already clear (cutscene should continue)
    @advance:
    tax  ; param: current fork index
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_WaitUntilZ:
    lda T2  ; current fork index
    pha  ; current fork index
    jsr _CallFuncArg  ; returns C
    beq @advance
    pla  ; current fork index
    clc  ; cutscene should continue
    rts
    @advance:
    pla  ; current fork index
    tax  ; param: current fork index
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceForkAndExecute
_WalkAlex:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Zp_PointX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_PointX_i16 + 1
    jsr FuncA_Cutscene_MoveActorTowardPointX  ; preserves X, T2+; returns Z, N
    beq @reachedGoal
    jsr FuncA_Cutscene_AnimateAlexWalking  ; preserves X
    jsr FuncA_Cutscene_FaceAvatarTowardsActor
    clc  ; cutscene should continue
    rts
    @reachedGoal:
    ldy #4  ; param: byte offset
    jmp _AdvanceAndExecuteForkT2
_WalkNpcOrc:
    lda (T1T0), y
    tax  ; actor index
    iny
    lda (T1T0), y
    sta Zp_PointX_i16 + 0
    iny
    lda (T1T0), y
    sta Zp_PointX_i16 + 1
    jsr FuncA_Cutscene_MoveActorTowardPointX  ; preserves X, T2+; returns Z, N
    beq @reachedGoal
    jsr FuncA_Cutscene_AnimateNpcOrcWalking  ; preserves X
    clc  ; cutscene should continue
    rts
    @reachedGoal:
    ldy #4  ; param: byte offset
    jmp _AdvanceAndExecuteForkT2
_CallFuncArg:
    lda (T1T0), y
    sta T2
    iny
    lda (T1T0), y
    sta T3
    jmp (T3T2)
.ENDPROC

;;; Moves the specified actor one pixel left or right towards Zp_PointX_i16.
;;; @param X The actor index.
;;; @return A The pixel delta that the actor actually moved by (signed).
;;; @return N Set if the actor moved left, cleared otherwise.
;;; @return Z Cleared if the actor moved, set if it was at the goal position.
;;; @preserve X, T2+
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

;;; Updates the flags and state of the specified Alex NPC actor for a walking
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateAlexWalking
    bpl @faceRight
    @faceLeft:
    lda #bObj::FlipH
    bne @setFace  ; unconditional
    @faceRight:
    lda #0
    @setFace:
    sta Ram_ActorFlags_bObj_arr, x
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

;;; Updates the flags and state of the specified orc NPC actor for a walking
;;; animation.
;;; @param N If set, the actor will face left; otherwise, it will face right.
;;; @param X The actor index.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AnimateNpcOrcWalking
    bpl @faceRight
    @faceLeft:
    lda #bObj::FlipH
    bne @setFace  ; unconditional
    @faceRight:
    lda #0
    @setFace:
    sta Ram_ActorFlags_bObj_arr, x
    lda #$ff
    sta Ram_ActorState2_byte_arr, x
_AnimatePose:
    lda Zp_FrameCounter_u8
    div #08
    and #$03  ; param: pose
    .assert eNpcOrc::Running1 = 0, error
    sta Ram_ActorState1_byte_arr, x
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
