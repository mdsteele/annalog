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

.INCLUDE "../macros.inc"

.IMPORT Func_IsFlagSet
.IMPORT Ppu_ChrBgAnimStatic
.IMPORTZP Zp_Chr04Bank_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Disables the default BG circuit animation unless the specified breaker has
;;; been activated.
;;; @param X The eFlag value for the breaker.
.EXPORT FuncA_Objects_AnimateCircuitIfBreakerActive
.PROC FuncA_Objects_AnimateCircuitIfBreakerActive
    jsr Func_IsFlagSet  ; returns Z
    bne @done
    lda #<.bank(Ppu_ChrBgAnimStatic)
    sta Zp_Chr04Bank_u8
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
