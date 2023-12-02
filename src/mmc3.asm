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

.INCLUDE "mmc3.inc"

;;;=========================================================================;;;

.ZEROPAGE

;;; Stores the most recent kSelect* value that the main thread wants stored in
;;; Hw_Mmc3BankSelect_wo.  The main thread must write to this variable before
;;; writing to Hw_Mmc3BankSelect_wo, and the IRQ thread must copy this variable
;;; back to Hw_Mmc3BankSelect_wo after completing a bank switch; this ensures
;;; that even if an IRQ fires in the middle of a main thread bank switch, it
;;; will not disrupt it.
Zp_MainSelect_bMmc3Bank: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGE_Reset"

;;; Switches PRGA banks to the given bank number.  This is called by the
;;; main_prga macro in mmc3.inc.  Putting these few loads and stores in a
;;; function rather than inline in the macro saves seven bytes per PRGA bank
;;; switch; because there are so many PRGA bank switches within PRG8 code, this
;;; adds up to a significant space savings.  (PRGC and CHR bank switches are
;;; less common, so we don't bother for those.)
;;;
;;; This function must be in PRGE rather than PRG8, so that it can be used in
;;; Main_Reset to initialize the MMC3 (PRG8 can't be used until the MMC3 has
;;; been initialized).
;;;
;;; @param A The PRGA bank number to switch to.
;;; @preserve X, Y, T0+
.PROC FuncM_SwitchPrgaBank
    pha  ; PRGA bank number
    _main_bank_select kSelectPrga
    pla  ; PRGA bank number
    sta Hw_Mmc3BankData_wo
    rts
.ENDPROC

;;;=========================================================================;;;
