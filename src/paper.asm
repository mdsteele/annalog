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

.INCLUDE "dialog.inc"
.INCLUDE "flag.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "room.inc"

.IMPORT Func_SetFlag
.IMPORT Main_Dialog_WhileExploring
.IMPORT Ram_DeviceTarget_byte_arr

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for collecting a paper.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active paper device.
;;; @param X The paper device index.
.EXPORT Main_Paper_UseDevice
.PROC Main_Paper_UseDevice
    jsr_prga FuncA_Paper_Init  ; returns Y (param: eDialog value)
    jmp Main_Dialog_WhileExploring
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Paper"

;;; Initializes for using a paper device.
;;; @prereq Zp_Nearby_bDevice holds an active paper device.
;;; @param X The paper device index.
;;; @return Y The eDialog value for the paper.
.PROC FuncA_Paper_Init
    lda Ram_DeviceTarget_byte_arr, x
    pha  ; eFlag::Paper* value
    tax  ; param: flag
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs @doneSfx
    ;; TODO: play a sound for collecting a new paper
    @doneSfx:
    pla  ; eFlag::Paper* value
    sub #kFirstPaperFlag
    tax
    ldy DataA_Paper_Dialogs_eDialog_arr, x
    rts
.ENDPROC

;;; Maps from eFlag::Paper* values to eDialog::Paper* values.
;;; TODO: Once all papers exist, we can remove this and just use arithmetic.
.PROC DataA_Paper_Dialogs_eDialog_arr
    D_ARRAY kNumPaperFlags, kFirstPaperFlag
    d_byte eFlag::PaperJerome01, 0  ; TODO
    d_byte eFlag::PaperJerome02, 0  ; TODO
    d_byte eFlag::PaperJerome03, 0  ; TODO
    d_byte eFlag::PaperJerome04, 0  ; TODO
    d_byte eFlag::PaperJerome05, 0  ; TODO
    d_byte eFlag::PaperJerome06, 0  ; TODO
    d_byte eFlag::PaperJerome07, 0  ; TODO
    d_byte eFlag::PaperJerome08, eDialog::PaperJerome08
    d_byte eFlag::PaperJerome09, 0  ; TODO
    d_byte eFlag::PaperJerome10, eDialog::PaperJerome10
    d_byte eFlag::PaperJerome11, eDialog::PaperJerome11
    d_byte eFlag::PaperJerome12, eDialog::PaperJerome12
    d_byte eFlag::PaperJerome13, eDialog::PaperJerome13
    d_byte eFlag::PaperJerome14, 0  ; TODO
    d_byte eFlag::PaperJerome15, 0  ; TODO
    d_byte eFlag::PaperJerome16, 0  ; TODO
    d_byte eFlag::PaperJerome17, 0  ; TODO
    d_byte eFlag::PaperJerome18, 0  ; TODO
    d_byte eFlag::PaperJerome19, 0  ; TODO
    d_byte eFlag::PaperJerome20, 0  ; TODO
    d_byte eFlag::PaperJerome21, eDialog::PaperJerome21
    d_byte eFlag::PaperJerome22, 0  ; TODO
    d_byte eFlag::PaperJerome23, 0  ; TODO
    d_byte eFlag::PaperJerome24, 0  ; TODO
    d_byte eFlag::PaperJerome25, 0  ; TODO
    d_byte eFlag::PaperJerome26, 0  ; TODO
    d_byte eFlag::PaperJerome27, 0  ; TODO
    d_byte eFlag::PaperJerome28, eDialog::PaperJerome28
    d_byte eFlag::PaperJerome29, 0  ; TODO
    d_byte eFlag::PaperJerome30, 0  ; TODO
    d_byte eFlag::PaperJerome31, 0  ; TODO
    d_byte eFlag::PaperJerome32, 0  ; TODO
    d_byte eFlag::PaperJerome33, 0  ; TODO
    d_byte eFlag::PaperJerome34, eDialog::PaperJerome34
    d_byte eFlag::PaperJerome35, eDialog::PaperJerome35
    d_byte eFlag::PaperJerome36, eDialog::PaperJerome36
    d_byte eFlag::PaperManual1, 0  ; TODO
    d_byte eFlag::PaperManual2, eDialog::PaperManual2
    d_byte eFlag::PaperManual3, eDialog::PaperManual3
    d_byte eFlag::PaperManual4, eDialog::PaperManual4
    d_byte eFlag::PaperManual5, 0  ; TODO
    d_byte eFlag::PaperManual6, 0  ; TODO
    d_byte eFlag::PaperManual7, 0  ; TODO
    d_byte eFlag::PaperManual8, 0  ; TODO
    d_byte eFlag::PaperManual9, 0  ; TODO
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; Maps from eFlag::Paper* values to the eArea where each paper is located.
.EXPORT DataA_Pause_PaperLocation_eArea_arr
.PROC DataA_Pause_PaperLocation_eArea_arr
    D_ARRAY kNumPaperFlags, kFirstPaperFlag
    d_byte eFlag::PaperJerome01, $ff  ; TODO
    d_byte eFlag::PaperJerome02, $ff  ; TODO
    d_byte eFlag::PaperJerome03, $ff  ; TODO
    d_byte eFlag::PaperJerome04, $ff  ; TODO
    d_byte eFlag::PaperJerome05, $ff  ; TODO
    d_byte eFlag::PaperJerome06, $ff  ; TODO
    d_byte eFlag::PaperJerome07, $ff  ; TODO
    d_byte eFlag::PaperJerome08, eArea::Crypt    ; room: CryptCenter
    d_byte eFlag::PaperJerome09, $ff  ; TODO
    d_byte eFlag::PaperJerome10, eArea::Lava     ; room: LavaWest
    d_byte eFlag::PaperJerome11, eArea::Crypt    ; room: CryptSpiral
    d_byte eFlag::PaperJerome12, eArea::Prison   ; room: PrisonEscape
    d_byte eFlag::PaperJerome13, eArea::Garden   ; room: GardenLanding
    d_byte eFlag::PaperJerome14, $ff  ; TODO
    d_byte eFlag::PaperJerome15, $ff  ; TODO
    d_byte eFlag::PaperJerome16, $ff  ; TODO
    d_byte eFlag::PaperJerome17, $ff  ; TODO
    d_byte eFlag::PaperJerome18, $ff  ; TODO
    d_byte eFlag::PaperJerome19, $ff  ; TODO
    d_byte eFlag::PaperJerome20, $ff  ; TODO
    d_byte eFlag::PaperJerome21, eArea::Crypt   ; room: CryptEscape
    d_byte eFlag::PaperJerome22, $ff  ; TODO
    d_byte eFlag::PaperJerome23, $ff  ; TODO
    d_byte eFlag::PaperJerome24, $ff  ; TODO
    d_byte eFlag::PaperJerome25, $ff  ; TODO
    d_byte eFlag::PaperJerome26, $ff  ; TODO
    d_byte eFlag::PaperJerome27, $ff  ; TODO
    d_byte eFlag::PaperJerome28, eArea::Temple   ; room: TempleApse
    d_byte eFlag::PaperJerome29, $ff  ; TODO
    d_byte eFlag::PaperJerome30, $ff  ; TODO
    d_byte eFlag::PaperJerome31, $ff  ; TODO
    d_byte eFlag::PaperJerome32, $ff  ; TODO
    d_byte eFlag::PaperJerome33, $ff  ; TODO
    d_byte eFlag::PaperJerome34, eArea::Temple   ; room: TemplePit
    d_byte eFlag::PaperJerome35, eArea::City     ; room: CityDump
    d_byte eFlag::PaperJerome36, eArea::Prison   ; room: PrisonCell
    d_byte eFlag::PaperManual1,  $ff  ; TODO
    d_byte eFlag::PaperManual2,  eArea::Temple   ; room: TempleFoyer
    d_byte eFlag::PaperManual3,  eArea::Lava     ; room: LavaStation
    d_byte eFlag::PaperManual4,  eArea::Garden   ; room: GardenShaft
    d_byte eFlag::PaperManual5,  $ff  ; TODO
    d_byte eFlag::PaperManual6,  $ff  ; TODO
    d_byte eFlag::PaperManual7,  $ff  ; TODO
    d_byte eFlag::PaperManual8,  $ff  ; TODO
    d_byte eFlag::PaperManual9,  $ff  ; TODO
    D_END
.ENDPROC

;;;=========================================================================;;;
