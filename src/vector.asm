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

.INCLUDE "cpu.inc"

.IMPORT Int_Irq
.IMPORT Int_Nmi
.IMPORT Main_Reset

;;;=========================================================================;;;

.SEGMENT "PRGE_Vector"
    .assert * = Data_NmiVector_int_ptr, error
    .addr Int_Nmi  ; See https://www.nesdev.org/wiki/NMI
    .assert * = Data_ResetVector_main_ptr, error
    .addr Main_Reset
    .assert * = Data_IrqVector_int_ptr, error
    .addr Int_Irq  ; See https://www.nesdev.org/wiki/IRQ

;;;=========================================================================;;;
