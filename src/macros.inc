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

.MACPACK generic
.MACPACK longbranch

;;;=========================================================================;;;

.DEFINE _is_immediate(ARG) .match(.left(1, {ARG}), #)
.DEFINE _get_immediate(ARG) .right(.tcount({ARG}) - 1, {ARG})

.MACRO _lo_byte op, ARG
    .if _is_immediate ARG
    op #<(_get_immediate ARG)
    .else
    op ARG
    .endif
.ENDMACRO

.MACRO _hi_byte op, ARG
    .if _is_immediate ARG
    op #>(_get_immediate ARG)
    .else
    op (ARG) + 1
    .endif
.ENDMACRO

;;;=========================================================================;;;

;;; LDAX (load a 16-bit value into AX)
;;;
;;; Loads a 16-bit value, putting the low byte in X and the high byte in A.
;;;
;;; Examples:
;;;     ldax #$1234       ; immidiate mode; sets X to $34 and A to $12
;;;     ldax Zp_Foo_u16   ; zeropage mode; sets [Foo] to X and [Foo+1] to A
;;;     ldax Ram_Foo_u16  ; absolute mode; sets [Foo] to X and [Foo+1] to A
.MACRO ldax ARG
    _lo_byte ldx, ARG
    _hi_byte lda, ARG
.ENDMACRO

;;; LDXY (load a 16-bit value into XY)
;;;
;;; Loads a 16-bit value, putting the low byte in Y and the high byte in X.
;;;
;;; Examples:
;;;     ldxy #$1234       ; immidiate mode; sets Y to $34 and X to $12
;;;     ldxy Zp_Foo_u16   ; zeropage mode; sets [Foo] to Y and [Foo+1] to X
;;;     ldxy Ram_Foo_u16  ; absolute mode; sets [Foo] to Y and [Foo+1] to X
.MACRO ldxy ARG
    _lo_byte ldy, ARG
    _hi_byte ldx, ARG
.ENDMACRO

;;;=========================================================================;;;
