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

.INCLUDE "../charmap.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"

.IMPORT FuncA_Actor_TickAllActors
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_ShakeRoom
.IMPORT Main_Breaker_FadeBackToBreakerRoom
.IMPORT Main_Dialog_OpenWindow
.IMPORTZP Zp_NextCutscene_main_ptr

;;;=========================================================================;;;

.SEGMENT "PRG8"

.EXPORT Main_BreakerCutscene_Garden
.PROC Main_BreakerCutscene_Garden
    lda #120
_GameLoop:
    pha
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Actor_TickAllActors
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    pla
    tax
    dex
    cpx #60
    bne @noShake
    ;; TODO: play a sound
    lda #30  ; param: num shake frames
    jsr Func_ShakeRoom  ; preserves X
    @noShake:
    txa
    bne _GameLoop
_StartDialog:
    ;; TODO: wait a bit more after dialog before fading back
    ldax #Main_Breaker_FadeBackToBreakerRoom
    stax Zp_NextCutscene_main_ptr
    ldy #eDialog::MermaidHut1Cutscene  ; param: eDialog value
    jmp Main_Dialog_OpenWindow
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_MermaidHut1Cutscene_sDialog
.PROC DataA_Dialog_MermaidHut1Cutscene_sDialog
    .word ePortrait::MermaidQueen
    .byte "What the...What did$"
    .byte "that human just do!?#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
