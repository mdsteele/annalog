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
.INCLUDE "../cutscene.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"

.IMPORT Main_Breaker_FadeBackToBreakerRoom

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_MermaidHut1BreakerGarden_arr
.PROC DataA_Cutscene_MermaidHut1BreakerGarden_arr
    .byte eAction::WaitFrames, 60
    .byte eAction::ShakeRoom, 30
    .byte eAction::WaitFrames, 60
    .byte eAction::RunDialog, eDialog::MermaidHut1Cutscene
    .byte eAction::JumpToMain
    .addr Main_Breaker_FadeBackToBreakerRoom
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
