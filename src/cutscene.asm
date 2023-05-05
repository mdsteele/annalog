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

.IMPORT DataA_Cutscene_CoreBossPowerUpCircuit_arr
.IMPORT DataA_Cutscene_MermaidHut1BreakerGarden_arr
.IMPORT DataA_Cutscene_PrisonCellGetThrownIn_arr
.IMPORT DataA_Cutscene_PrisonUpperBreakerTemple_arr
.IMPORT DataA_Cutscene_SharedFadeBackToBreakerRoom_arr
.IMPORT DataA_Cutscene_SharedTeleportIn_arr
.IMPORT DataA_Cutscene_SharedTeleportOut_arr
.IMPORT DataA_Cutscene_TempleNaveAlexBoosting_arr
.IMPORT DataA_Cutscene_TownHouse2WakeUp_arr
.IMPORT DataA_Cutscene_TownOutdoorsGetCaught_arr
.IMPORT DataA_Cutscene_TownOutdoorsOrcAttack_arr
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
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_PointX_i16

;;;=========================================================================;;;

.ZEROPAGE

;;; A pointer to the next cutscene action to be executed.
Zp_CutsceneAction_ptr: .res 2

;;; Which tick functions to call during the current cutscene.
Zp_CutsceneFlags_bCutscene: .res 1

;;; Timer used to implement the WaitFrames action.  Starts at zero, and
;;; increments each frame that the cutscene is blocked on a WaitFrames action.
;;; When the WaitFrames completes, this is reset back to zero.
Zp_CutsceneTimer_u8: .res 1

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
    jsr_prga FuncA_Cutscene_Execute  ; returns C and T1T0
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

;;; An empty cutscene that just immediately jumps back to explore mode.
.PROC DataA_Cutscene_Empty_arr
    .byte eAction::ContinueExploring
.ENDPROC

;;; Maps from an eCutscene value to a pointer to the cutscene action sequence.
.LINECONT +
.REPEAT 2, table
    D_TABLE_LO table, DataA_Cutscene_Table_arr_ptr_0_arr
    D_TABLE_HI table, DataA_Cutscene_Table_arr_ptr_1_arr
    D_TABLE eCutscene
    d_entry table, None, DataA_Cutscene_Empty_arr
    d_entry table, CoreBossPowerUpCircuit, \
            DataA_Cutscene_CoreBossPowerUpCircuit_arr
    d_entry table, MermaidHut1BreakerGarden, \
            DataA_Cutscene_MermaidHut1BreakerGarden_arr
    d_entry table, PrisonCellGetThrownIn, \
            DataA_Cutscene_PrisonCellGetThrownIn_arr
    d_entry table, PrisonUpperBreakerTemple, \
            DataA_Cutscene_PrisonUpperBreakerTemple_arr
    d_entry table, SharedFadeBackToBreakerRoom, \
            DataA_Cutscene_SharedFadeBackToBreakerRoom_arr
    d_entry table, SharedTeleportIn, \
            DataA_Cutscene_SharedTeleportIn_arr
    d_entry table, SharedTeleportOut, \
            DataA_Cutscene_SharedTeleportOut_arr
    d_entry table, TempleNaveAlexBoosting, \
            DataA_Cutscene_TempleNaveAlexBoosting_arr
    d_entry table, TownHouse2WakeUp, \
            DataA_Cutscene_TownHouse2WakeUp_arr
    d_entry table, TownOutdoorsGetCaught, \
            DataA_Cutscene_TownOutdoorsGetCaught_arr
    d_entry table, TownOutdoorsOrcAttack, \
            DataA_Cutscene_TownOutdoorsOrcAttack_arr
    D_END
.ENDREPEAT
.LINECONT -

;;; Initializes variables for a new cutscene.
;;; @param X The eCutscene value for the cutscene to play.
.PROC FuncA_Cutscene_Init
    lda DataA_Cutscene_Table_arr_ptr_0_arr, x
    sta Zp_CutsceneAction_ptr + 0
    lda DataA_Cutscene_Table_arr_ptr_1_arr, x
    sta Zp_CutsceneAction_ptr + 1
    lda #0
    sta Zp_CutsceneFlags_bCutscene
    sta Zp_CutsceneTimer_u8
    rts
.ENDPROC

;;; Updates Zp_CutsceneAction_ptr by adding Y.
;;; @param Y The byte offset to add to Zp_CutsceneAction_ptr.
;;; @preserve X, Y, T0+
.PROC FuncA_Cutscene_AdvanceActionPtr
    Tya
    add Zp_CutsceneAction_ptr + 0
    sta Zp_CutsceneAction_ptr + 0
    lda Zp_CutsceneAction_ptr + 1
    adc #0
    sta Zp_CutsceneAction_ptr + 1
    rts
.ENDPROC

;;; Calls FuncA_Cutscene_AdvanceActionPtr and then FuncA_Cutscene_Execute.
;;; @param Y The byte offset to add to Zp_CutsceneAction_ptr.
;;; @return C Set if the cutscene should end.
;;; @return T1T0 If C is set, this holds the address of the main to jump to.
.PROC FuncA_Cutscene_AdvanceAndExecute
    jsr FuncA_Cutscene_AdvanceActionPtr
    .assert * = FuncA_Cutscene_Execute, error, "fallthrough"
.ENDPROC

;;; Executes cutscene actions for the current frame.
;;; @return C Set if the cutscene should end.
;;; @return T1T0 If C is set, this holds the address of the main to jump to.
.PROC FuncA_Cutscene_Execute
    ldy #0
    lda (Zp_CutsceneAction_ptr), y
    iny
    tax
    lda _JumpTable_ptr_0_arr, x
    sta T0
    lda _JumpTable_ptr_1_arr, x
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eAction
    d_entry table, ContinueExploring, _ContinueExploring
    d_entry table, JumpToMain,        _JumpToMain
    d_entry table, CallFunc,          _CallFunc
    d_entry table, SetActorFlags,     _SetActorFlags
    d_entry table, SetActorPosX,      _SetActorPosX
    d_entry table, SetActorPosY,      _SetActorPosY
    d_entry table, SetActorState1,    _SetActorState1
    d_entry table, SetActorState2,    _SetActorState2
    d_entry table, SetAvatarFlags,    _SetAvatarFlags
    d_entry table, SetAvatarPose,     _SetAvatarPose
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
_ContinueExploring:
    ldax #Main_Explore_Continue
    stax T1T0
    sec  ; exit cutscene mode
    rts
_JumpToMain:
    lda (Zp_CutsceneAction_ptr), y
    sta T0
    tax
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta T1
    sec  ; exit cutscene mode
    rts
_CallFunc:
    jsr _CallFuncArg
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceAndExecute
_SetActorFlags:
    lda (Zp_CutsceneAction_ptr), y
    tax  ; actor index
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Ram_ActorFlags_bObj_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_SetActorPosX:
    lda (Zp_CutsceneAction_ptr), y
    tax  ; actor index
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Ram_ActorPosX_i16_0_arr, x
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Ram_ActorPosX_i16_1_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_SetActorPosY:
    lda (Zp_CutsceneAction_ptr), y
    tax  ; actor index
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Ram_ActorPosY_i16_0_arr, x
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Ram_ActorPosY_i16_1_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_SetActorState1:
    lda (Zp_CutsceneAction_ptr), y
    tax  ; actor index
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Ram_ActorState1_byte_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_SetActorState2:
    lda (Zp_CutsceneAction_ptr), y
    tax  ; actor index
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Ram_ActorState2_byte_arr, x
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_SetAvatarFlags:
    lda (Zp_CutsceneAction_ptr), y
    sta Zp_AvatarFlags_bObj
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_SetAvatarPose:
    lda (Zp_CutsceneAction_ptr), y
    sta Zp_AvatarPose_eAvatar
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_SetCutsceneFlags:
    lda (Zp_CutsceneAction_ptr), y
    sta Zp_CutsceneFlags_bCutscene
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_ShakeRoom:
    lda (Zp_CutsceneAction_ptr), y  ; param: num shake frames
    jsr Func_ShakeRoom  ; preserves Y
    iny
    jmp FuncA_Cutscene_AdvanceAndExecute
_RunDialog:
    lda (Zp_CutsceneAction_ptr), y
    pha  ; eDialog value
    iny
    jsr FuncA_Cutscene_AdvanceActionPtr
    pla  ; eDialog value
    tay  ; param: eDialog value
    ldax #Main_Dialog_WithinCutscene
    stax T1T0
    sec  ; exit cutscene mode
    rts
_WaitFrames:
    lda (Zp_CutsceneAction_ptr), y
    cmp Zp_CutsceneTimer_u8
    bne @stillWaiting
    iny
    lda #0
    sta Zp_CutsceneTimer_u8
    jmp FuncA_Cutscene_AdvanceAndExecute
    @stillWaiting:
    inc Zp_CutsceneTimer_u8
    clc  ; cutscene should continue
    rts
_WaitUntilC:
    jsr _CallFuncArg  ; returns C
    bcs @advance
    clc  ; cutscene should continue
    rts
    @advance:
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceAndExecute
_WaitUntilZ:
    jsr _CallFuncArg  ; returns Z
    beq @advance
    clc  ; cutscene should continue
    rts
    @advance:
    ldy #3  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceAndExecute
_WalkAlex:
    lda (Zp_CutsceneAction_ptr), y
    tax  ; actor index
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Zp_PointX_i16 + 0
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Zp_PointX_i16 + 1
    jsr FuncA_Cutscene_MoveActorTowardPointX  ; preserves X, returns Z and N
    beq @reachedGoal
    jsr FuncA_Cutscene_AnimateAlexWalking  ; preserves X
    jsr FuncA_Cutscene_FaceAvatarTowardsActor
    clc  ; cutscene should continue
    rts
    @reachedGoal:
    ldy #4  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceAndExecute
_WalkNpcOrc:
    lda (Zp_CutsceneAction_ptr), y
    tax  ; actor index
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Zp_PointX_i16 + 0
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta Zp_PointX_i16 + 1
    jsr FuncA_Cutscene_MoveActorTowardPointX  ; preserves X, returns Z and N
    beq @reachedGoal
    jsr FuncA_Cutscene_AnimateNpcOrcWalking  ; preserves X
    clc  ; cutscene should continue
    rts
    @reachedGoal:
    ldy #4  ; param: byte offset
    jmp FuncA_Cutscene_AdvanceAndExecute
_CallFuncArg:
    lda (Zp_CutsceneAction_ptr), y
    sta T0
    iny
    lda (Zp_CutsceneAction_ptr), y
    sta T1
    jmp (T1T0)
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
