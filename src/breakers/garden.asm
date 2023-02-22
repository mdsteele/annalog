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

.INCLUDE "../dialog.inc"
.INCLUDE "../macros.inc"

.IMPORT Main_Breaker_FadeBackToBreakerRoom
.IMPORT Main_Dialog_OpenWindow
.IMPORTZP Zp_NextCutscene_main_ptr

;;;=========================================================================;;;

.SEGMENT "PRG8"

.EXPORT Main_BreakerCutscene_Garden
.PROC Main_BreakerCutscene_Garden
    ;; TODO: wait a bit, then shake the room, then wait another beat
    ldax #Main_Breaker_FadeBackToBreakerRoom
    stax Zp_NextCutscene_main_ptr
    ;; TODO: use correct dialog index
    ldy #eDialog::MermaidHut1Guard  ; param: eDialog value
    jmp Main_Dialog_OpenWindow
.ENDPROC

;;;=========================================================================;;;
