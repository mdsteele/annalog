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

.INCLUDE "../src/macros.inc"

.IMPORT Exit_Success
.IMPORT Func_ExpectAEqualsY
.IMPORT Func_GetRandomByte

;;;=========================================================================;;;

.CODE

Data_ExpectedSequence_u8_arr:
    .byte $00, $05, $18, $93, $12, $7c, $37, $80, $a8, $5d, $71, $18, $fd, $4a
    .byte $03, $31, $33, $72, $46, $9f, $9b, $ff, $e0, $5f, $67, $f3, $5c, $f3
    .byte $7b, $36, $2a, $93, $87, $2a, $e7, $4d, $0f, $e7, $21, $4c, $91, $cf
    .byte $b5, $30, $cc, $48, $e7, $99, $82, $71, $e0, $f3, $22, $ec, $27, $b1
    .byte $9a, $e9, $89, $f8, $cc, $b8, $17, $08, $51, $e7, $9c, $db, $c3, $1f
    .byte $31, $4c, $f1, $ae, $d6, $16, $20, $30, $36, $9a, $24, $9c, $5b, $e4
    .byte $2d, $d2, $7b, $a9, $cb, $eb, $ac, $53, $7b, $f7, $e9, $d5, $cb, $72
    .byte $96, $6e, $89, $aa, $fa, $3b, $3e, $d1, $c9, $08, $7d, $ea, $62, $52
    .byte $55, $1e, $7e, $0e, $98, $d9, $8d, $24, $70, $7c, $62, $ef, $23, $a7
    .byte $e8, $36, $ec, $5d, $28, $73, $52, $7d, $b4, $06, $24, $c5, $c0, $fb
    .byte $bb, $47, $98, $86, $dc, $2c, $7a, $67, $ea, $9d, $a5, $54, $f0, $5c
    .byte $82, $ce, $81, $43, $40, $c6, $ad, $ff, $cc, $9a, $20, $38, $1e, $b2
    .byte $ec, $b5, $c1, $58, $9d, $6a, $22, $93, $17, $da, $36, $de, $f9, $db
    .byte $c9, $ed, $a2, $19, $e8, $bb, $cb, $37, $89, $b5, $aa, $90, $f2, $86
kExpectedSequenceLength = * - Data_ExpectedSequence_u8_arr

;;;=========================================================================;;;

.SEGMENT "MAIN"
    sei
    cld
    ldx #$ff
    txs
    inx  ; now X is zero
    @loop:
    sta $00, x
    inx
    bne @loop
Test:
    ldx #0
    @loop:
    txa
    pha
    jsr Func_GetRandomByte  ; preserves X
    ldy Data_ExpectedSequence_u8_arr, x
    jsr Func_ExpectAEqualsY
    pla
    tax
    inx
    cpx #kExpectedSequenceLength
    blt @loop
Success:
    jmp Exit_Success

;;;=========================================================================;;;
