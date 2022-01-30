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
    op ARG + 1
    .endif
.ENDMACRO

;;;=========================================================================;;;

;;; LDAX (load a 16-bit value into AX)
;;;
;;; Loads a 16-bit value, putting the low byte in X and the high byte in A.
;;;
;;; Examples:
;;;     ldax #$1234       ; immidiate mode; sets X to $34 and A to $12
;;;     ldax Zp_Foo_u16   ; zeropage mode; sets X to [Foo] and A to [Foo+1]
;;;     ldax Ram_Foo_u16  ; absolute mode; sets X to [Foo] and A to [Foo+1]
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
;;;     ldxy Zp_Foo_u16   ; zeropage mode; sets Y to [Foo] and X to [Foo+1]
;;;     ldxy Ram_Foo_u16  ; absolute mode; sets Y to [Foo] and X to [Foo+1]
.MACRO ldxy ARG
    _lo_byte ldy, ARG
    _hi_byte ldx, ARG
.ENDMACRO

;;; LDYA (load a 16-bit value into YA)
;;;
;;; Loads a 16-bit value, putting the low byte in A and the high byte in Y.
;;;
;;; Examples:
;;;     ldya #$1234       ; immidiate mode; sets A to $34 and Y to $12
;;;     ldya Zp_Foo_u16   ; zeropage mode; sets A to [Foo] and Y to [Foo+1]
;;;     ldya Ram_Foo_u16  ; absolute mode; sets A to [Foo] and Y to [Foo+1]
.MACRO ldya ARG
    _lo_byte lda, ARG
    _hi_byte ldy, ARG
.ENDMACRO

;;; STAX (store a 16-bit value from AX)
;;;
;;; Stores a 16-bit value, using X as the low byte and A as the high byte.
;;;
;;; Examples:
;;;     stax Zp_Foo_u16   ; zeropage mode; sets [Foo] to X and [Foo+1] to A
;;;     stax Ram_Foo_u16  ; absolute mode; sets [Foo] to X and [Foo+1] to A
.MACRO stax ARG
    _lo_byte stx, ARG
    _hi_byte sta, ARG
.ENDMACRO

;;; STXY (store a 16-bit value from XY)
;;;
;;; Stores a 16-bit value, using Y as the low byte and X as the high byte.
;;;
;;; Examples:
;;;     stxy Zp_Foo_u16   ; zeropage mode; sets [Foo] to Y and [Foo+1] to X
;;;     stxy Ram_Foo_u16  ; absolute mode; sets [Foo] to Y and [Foo+1] to X
.MACRO stxy ARG
    _lo_byte sty, ARG
    _hi_byte stx, ARG
.ENDMACRO

;;; STYA (store a 16-bit value from YA)
;;;
;;; Stores a 16-bit value, using A as the low byte and Y as the high byte.
;;;
;;; Examples:
;;;     stya Zp_Foo_u16   ; zeropage mode; sets [Foo] to A and [Foo+1] to Y
;;;     stya Ram_Foo_u16  ; absolute mode; sets [Foo] to A and [Foo+1] to Y
.MACRO stya ARG
    _lo_byte sta, ARG
    _hi_byte sty, ARG
.ENDMACRO

;;;=========================================================================;;;

;;; DIV (divide A by a constant power of 2)
;;; Affects flags: N Z C
;;;
;;; The argument must be a constant immediate value equal to 2, 4, 8, 16, or
;;; 32.
;;;
;;; Examples:
;;;     div #$10            ; divides A by 16
;;;     div #.sizeof(sObj)  ; divides A by .sizeof(sObj)
.MACRO div ARG
    .if !_is_immediate ARG
    .error "div only supports immediate addressing"
    .elseif !.const(_get_immediate ARG)
    .error "div argument must be a constant"
    .elseif 2 = _get_immediate ARG
    lsr a
    .elseif 4 = _get_immediate ARG
    lsr a
    lsr a
    .elseif 8 = _get_immediate ARG
    lsr a
    lsr a
    lsr a
    .elseif 16 = _get_immediate ARG
    .repeat 4
    lsr a
    .endrepeat
    .elseif 32 = _get_immediate ARG
    .repeat 5
    lsr a
    .endrepeat
    .else
    .error .sprintf("unsupported div argument: %d", _get_immediate ARG)
    .endif
.ENDMACRO

;;; MUL (multiply A by a constant power of 2)
;;; Affects flags: N Z C
;;;
;;; The argument must be a constant immediate value equal to 2, 4, 8, 16, or
;;; 32.
;;;
;;; Examples:
;;;     mul #$10            ; multiplies A by 16
;;;     mul #.sizeof(sObj)  ; multiplies A by .sizeof(sObj)
.MACRO mul ARG
    .if !_is_immediate ARG
    .error "mul only supports immediate addressing"
    .elseif !.const(_get_immediate ARG)
    .error "mul argument must be a constant"
    .elseif 2 = _get_immediate ARG
    asl a
    .elseif 4 = _get_immediate ARG
    asl a
    asl a
    .elseif 8 = _get_immediate ARG
    asl a
    asl a
    asl a
    .elseif 16 = _get_immediate ARG
    .repeat 4
    asl a
    .endrepeat
    .elseif 32 = _get_immediate ARG
    .repeat 5
    asl a
    .endrepeat
    .else
    .error .sprintf("unsupported mul argument: %d", _get_immediate ARG)
    .endif
.ENDMACRO

;;;=========================================================================;;;
