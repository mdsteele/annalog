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

;;; The size (in bytes) of a 6502 memory address.
kSizeofAddr = 2

;;;=========================================================================;;;

;;; Constants for 6502 processor flags.
.SCOPE bProc
    Negative   = %10000000
    Overflow   = %01000000
    Break      = %00010000
    Decimal    = %00001000
    IntDisable = %00000100
    Zero       = %00000010
    Carry      = %00000001
.ENDSCOPE

;;;=========================================================================;;;

;;; Fixed addresses for interrupt/reset vectors.
Data_NmiVector_int_ptr    = $fffa  ; See https://www.nesdev.org/wiki/NMI
Data_ResetVector_main_ptr = $fffc
Data_IrqVector_int_ptr    = $fffe  ; See https://www.nesdev.org/wiki/IRQ

;;;=========================================================================;;;
