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

.INCLUDE "audio.inc"
.INCLUDE "charmap.inc"
.INCLUDE "epilogue.inc"
.INCLUDE "fade.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "ppu.inc"

.IMPORT FuncC_Title_ClearNametableTiles
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_DirectPpuTransfer
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_Noop
.IMPORT Func_ProcessFrame
.IMPORT Func_SetAndTransferFade
.IMPORT Func_Window_Disable
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Ppu_ChrBgFontUpper
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

;;; The number of individual "scenes" in a given epilogue sequence.
kEpilogueNumScenes = 18

;;; The duration, in frames, of one epilogue scene.  This is equal in duration
;;; to two measures (eight beats) of the epilogue music, where each beat is 24
;;; frames long (this should match the tempo in src/music/epilogue.sng).
kEpilogueSceneFrames = 24 * 8

;;;=========================================================================;;;

;;; Particular scenes that can play within an epilogue sequence.  Some scenes
;;; only appear in one of the epilogues, while others are shared.
.ENUM eEpilogueScene
    Title
    AGameBy
    CreditDesign
    CreditMusic
    CreditAsstArtDir
    CreditBetaTesting
    CreditTbd
    CreditPublishing
    CreditSpecialThanks
    CreditDedication
    Placeholder  ; TODO: replace this with real cutscenes
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.ZEROPAGE

;;; The epilogue sequence that's currently playing.
Zp_Current_eEpilogue: .res 1

;;; The zero-based index into the current epilogue's sequence of scenes.
Zp_EpilogueSceneIndex_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for playing the epilogue.
;;; @prereq Audio is disabled.
;;; @prereq Rendering is disabled.
;;; @param X The eEpilogue value for the epilogue to play.
.EXPORT Main_Epilogue
.PROC Main_Epilogue
    jmp_prgc MainC_Title_Epilogue
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; Mode for playing the epilogue.
;;; @prereq Rendering is disabled.
;;; @param X The eEpilogue value for the epilogue to play.
.PROC MainC_Title_Epilogue
    stx Zp_Current_eEpilogue
    lda #0
    sta Zp_EpilogueSceneIndex_u8
_EnableAudio:
    lda #bAudio::Enable
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
    lda #eMusic::Epilogue
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
_SceneLoop:
    jsr FuncC_Title_InitEpilogueScene
_GameLoop:
    jsr FuncC_Title_DrawEpilogueScene
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr FuncC_Title_TickEpilogueScene
    ;; Check if this epilogue scene is over yet.  Note that we subtract 1 from
    ;; kEpilogueSceneFrames here to account for the extra frame used to disable
    ;; rendering under _NextScene below.
    lda Zp_FrameCounter_u8
    cmp #kEpilogueSceneFrames - 1
    blt _GameLoop
_NextScene:
    ;; Disable rendering.
    lda #0
    sta Zp_Render_bPpuMask
    jsr Func_ProcessFrame
    ;; Advance to the next scene.
    inc Zp_EpilogueSceneIndex_u8
    lda Zp_EpilogueSceneIndex_u8
    cmp #kEpilogueNumScenes
    blt _SceneLoop
    fall MainC_Title_TheEnd
.ENDPROC

;;; Mode for the "The End" screen.
;;; @prereq Rendering is disabled.
.PROC MainC_Title_TheEnd
    ;; TODO: init TheEnd mode
_GameLoop:
    jsr Func_ClearRestOfOamAndProcessFrame
    ;; TODO: check buttons, go to title screen on press
    jmp _GameLoop
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::Placeholder.
;;; TODO: Remove this.
.PROC DataC_Title_EpiloguePlaceholder_sXfer_arr
    d_xfer_text_row 16, "TODO: cutscene"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::Title.
.PROC DataC_Title_EpilogueTitle_sXfer_arr
    d_xfer_text_row 15, "ANNALOG"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::AGameBy.
.PROC DataC_Title_EpilogueAGameBy_sXfer_arr
    d_xfer_text_row 15, "a game by mdsteele"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::CreditDesign.
.PROC DataC_Title_EpilogueDesign_sXfer_arr
    d_xfer_text_row 14, "DESIGN/PROGRAMMING"
    d_xfer_text_row 16, "Matthew Steele"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::CreditMusic.
.PROC DataC_Title_EpilogueMusic_sXfer_arr
    d_xfer_text_row 14, "MUSIC"
    d_xfer_text_row 16, "Jon Moran"
    d_xfer_text_row 17, "Matthew Steele"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::CreditAsstArtDir.
.PROC DataC_Title_EpilogueAsstArt_sXfer_arr
    d_xfer_text_row 14, "ASST. ART DIRECTOR"
    d_xfer_text_row 16, "Stephanie Steele"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::CreditBetaTesting.
.PROC DataC_Title_EpilogueTesting_sXfer_arr
    d_xfer_text_row 14, "BETA TESTING"
    d_xfer_text_row 16, "Christopher DuBois"
    d_xfer_text_row 17, "David Couzelis"
    d_xfer_text_row 18, "Eric Chang"
    d_xfer_text_row 19, "Jon Moran"
    d_xfer_text_row 20, "Mitch Foley"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::CreditTbd.
.PROC DataC_Title_EpilogueTbd_sXfer_arr
    d_xfer_text_row 14, "<TBD>"
    d_xfer_text_row 16, "<TBD>"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::CreditPublishing.
.PROC DataC_Title_EpiloguePublishing_sXfer_arr
    d_xfer_text_row 14, "PUBLISHING"
    d_xfer_text_row 16, "<TBD>"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::CreditSpecialThanks.
.PROC DataC_Title_EpilogueThanks_sXfer_arr
    d_xfer_text_row 14, "SPECIAL THANKS"
    d_xfer_text_row 16, "Holly and Emily"
    d_xfer_text_row 17, "NesDev.org"
    d_xfer_terminator
.ENDPROC

;;; PPU transfer entries for eEpilogueScene::CreditDedication.
.PROC DataC_Title_EpilogueDedication_sXfer_arr
    d_xfer_text_row 15, "FOR GREAT JUSTIN"
    d_xfer_terminator
.ENDPROC

;;; Initializes the current epilogue scene, in particular setting up the
;;; background tiles before the screen fades in.
;;; @prereq Rendering is disabled.
;;; @prereq Zp_Current_eEpilogue and Zp_EpilogueSceneIndex_u8 are initialized.
.PROC FuncC_Title_InitEpilogueScene
    lda #<.bank(Ppu_ChrBgFontUpper)
    sta Zp_Chr04Bank_u8
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    sta Zp_FrameCounter_u8
    jsr Func_Window_Disable
_ClearUpperNametable:
    ldxy #Ppu_Nametable0_sName  ; param: nametable addr
    jsr FuncC_Title_ClearNametableTiles
    ldy #$00  ; param: attribute byte
    jsr Func_FillUpperAttributeTable
_SceneSpecificInit:
    jsr FuncC_Title_GetEpilogueScene  ; returns X
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eEpilogueScene
    d_entry table, Title,               _Title
    d_entry table, AGameBy,             _AGameBy
    d_entry table, CreditDesign,        _CreditDesign
    d_entry table, CreditMusic,         _CreditMusic
    d_entry table, CreditAsstArtDir,    _CreditAsstArtDir
    d_entry table, CreditBetaTesting,   _CreditBetaTesting
    d_entry table, CreditTbd,           _CreditTbd
    d_entry table, CreditPublishing,    _CreditPublishing
    d_entry table, CreditSpecialThanks, _CreditSpecialThanks
    d_entry table, CreditDedication,    _CreditDedication
    d_entry table, Placeholder,         _Placeholder
    D_END
.ENDREPEAT
_Placeholder:
    ldax #DataC_Title_EpiloguePlaceholder_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_Title:
    ldax #DataC_Title_EpilogueTitle_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_AGameBy:
    ldax #DataC_Title_EpilogueAGameBy_sXfer_arr  ; param: data pointer
    jmp Func_DirectPpuTransfer
_CreditDesign:
    ldax #DataC_Title_EpilogueDesign_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_CreditMusic:
    ldax #DataC_Title_EpilogueMusic_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_CreditAsstArtDir:
    ldax #DataC_Title_EpilogueAsstArt_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_CreditBetaTesting:
    ldax #DataC_Title_EpilogueTesting_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_CreditTbd:
    ldax #DataC_Title_EpilogueTbd_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_CreditPublishing:
    ldax #DataC_Title_EpiloguePublishing_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_CreditSpecialThanks:
    ldax #DataC_Title_EpilogueThanks_sXfer_arr  ; param: data pointer
    jmp _DrawCredits
_CreditDedication:
    ldax #DataC_Title_EpilogueDedication_sXfer_arr  ; param: data pointer
    jmp Func_DirectPpuTransfer
_DrawCredits:
    jsr Func_DirectPpuTransfer
    ldx #$06  ; param: num bytes to write
    ldy #$50  ; param: attribute value
    lda #$19  ; param: initial byte offset
    jmp Func_WriteToUpperAttributeTable
.ENDPROC

;;; Performs per-frame updates for the current epilogue scene, including
;;; updating the screen fade level near the start and end of the scene.
;;; @prereq Zp_Current_eEpilogue and Zp_EpilogueSceneIndex_u8 are initialized.
.PROC FuncC_Title_TickEpilogueScene
_FadeScreen:
    lda Zp_FrameCounter_u8
    cmp #1 + 5 * 0
    beq @fadeDark
    cmp #kEpilogueSceneFrames - 5 * 1
    beq @fadeDark
    cmp #1 + 5 * 1
    beq @fadeDim
    cmp #kEpilogueSceneFrames - 5 * 2
    beq @fadeDim
    cmp #1 + 5 * 2
    bne @done
    @fadeNormal:
    ldy #eFade::Normal
    .assert eFade::Normal < $80, error
    bpl @setFade  ; unconditional
    @fadeDim:
    ldy #eFade::Dim
    .assert eFade::Dim < $80, error
    bpl @setFade  ; unconditional
    @fadeDark:
    ldy #eFade::Dark
    @setFade:
    jsr Func_SetAndTransferFade
    @done:
_SceneSpecificTick:
    jsr FuncC_Title_GetEpilogueScene  ; returns X
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eEpilogueScene
    d_entry table, Title,               Func_Noop
    d_entry table, AGameBy,             Func_Noop
    d_entry table, CreditDesign,        Func_Noop
    d_entry table, CreditMusic,         Func_Noop
    d_entry table, CreditAsstArtDir,    Func_Noop
    d_entry table, CreditBetaTesting,   Func_Noop
    d_entry table, CreditTbd,           Func_Noop
    d_entry table, CreditPublishing,    Func_Noop
    d_entry table, CreditSpecialThanks, Func_Noop
    d_entry table, CreditDedication,    Func_Noop
    d_entry table, Placeholder,         Func_Noop
    D_END
.ENDREPEAT
.ENDPROC

;;; Draws any objects needed for the current epilogue scene.
;;; @prereq Zp_Current_eEpilogue and Zp_EpilogueSceneIndex_u8 are initialized.
.PROC FuncC_Title_DrawEpilogueScene
    jsr FuncC_Title_GetEpilogueScene  ; returns X
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eEpilogueScene
    d_entry table, Title,               Func_Noop
    d_entry table, AGameBy,             Func_Noop
    d_entry table, CreditDesign,        Func_Noop
    d_entry table, CreditMusic,         Func_Noop
    d_entry table, CreditAsstArtDir,    Func_Noop
    d_entry table, CreditBetaTesting,   Func_Noop
    d_entry table, CreditTbd,           Func_Noop
    d_entry table, CreditPublishing,    Func_Noop
    d_entry table, CreditSpecialThanks, Func_Noop
    d_entry table, CreditDedication,    Func_Noop
    d_entry table, Placeholder,         Func_Noop
    D_END
.ENDREPEAT
.ENDPROC

;;; Returns the eEpilogueScene value for the current epilogue scene.
;;; @prereq Zp_Current_eEpilogue and Zp_EpilogueSceneIndex_u8 are initialized.
;;; @return Y The eEpilogueScene value for the current epilogue scene.
;;; @preserve X, T2+
.PROC FuncC_Title_GetEpilogueScene
    ldy Zp_Current_eEpilogue
    lda _Scenes_eEpilogueScene_arr_ptr_0_arr, y
    sta T0
    lda _Scenes_eEpilogueScene_arr_ptr_1_arr, y
    sta T1
    ldy Zp_EpilogueSceneIndex_u8
    lda (T1T0), y
    tay
    rts
.REPEAT 2, table
    D_TABLE_LO table, _Scenes_eEpilogueScene_arr_ptr_0_arr
    D_TABLE_HI table, _Scenes_eEpilogueScene_arr_ptr_1_arr
    D_TABLE .enum, eEpilogue
    d_entry table, AlexSearches, _AlexSearches_eEpilogueScene_arr
    d_entry table, HumansAscend, _HumansAscend_eEpilogueScene_arr
    d_entry table, OrcsAscend,   _OrcsAscend_eEpilogueScene_arr
    D_END
.ENDREPEAT
_AlexSearches_eEpilogueScene_arr:  ; TODO
_HumansAscend_eEpilogueScene_arr:  ; TODO
_OrcsAscend_eEpilogueScene_arr:
:   .byte eEpilogueScene::Title
    .byte eEpilogueScene::AGameBy
    .byte eEpilogueScene::Placeholder
    .byte eEpilogueScene::CreditDesign
    .byte eEpilogueScene::Placeholder
    .byte eEpilogueScene::CreditMusic
    .byte eEpilogueScene::Placeholder
    .byte eEpilogueScene::CreditAsstArtDir
    .byte eEpilogueScene::Placeholder
    .byte eEpilogueScene::CreditBetaTesting
    .byte eEpilogueScene::Placeholder
    .byte eEpilogueScene::CreditTbd
    .byte eEpilogueScene::Placeholder
    .byte eEpilogueScene::CreditPublishing
    .byte eEpilogueScene::Placeholder
    .byte eEpilogueScene::CreditSpecialThanks
    .byte eEpilogueScene::Placeholder
    .byte eEpilogueScene::CreditDedication
    .assert * - :- = kEpilogueNumScenes, error
.ENDPROC

;;;=========================================================================;;;
