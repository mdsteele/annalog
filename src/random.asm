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

.INCLUDE "macros.inc"

;;;=========================================================================;;;

.ZEROPAGE

;;; Seed values for Func_GetRandomByte.
Zp_RngS_u8: .res 1
Zp_RngT_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Generates a pseudorandom byte.
;;; @return A The random byte.
;;; @return N Set if the uppermost bit of the random byte is set.
;;; @preserve X, Y, T0+
.EXPORT Func_GetRandomByte
.PROC Func_GetRandomByte
    ;; This algorithm is used by Super Mario World, and is explained in the
    ;; "Super Mario World - Random Number Generation" video by Retro Game
    ;; Mechanics Explained (https://www.youtube.com/watch?v=q15yNrJHOak).
    ;;
    ;; First, set S = 5 * S + 1.
    lda Zp_RngS_u8
    mul #4
    sec
    adc Zp_RngS_u8
    sta Zp_RngS_u8
    ;; Next, if T's 4th and 7th bits are equal, then set T = 2 * T + 1.
    ;; Otherwise, set T = 2 * T.
    asl Zp_RngT_u8  ; multiply T by 2, shifting the 7th bit into C
    lda #$20
    bit Zp_RngT_u8  ; set Z equal to the old 4th bit (now 5th)
    bcc @bit7WasClear
    @bit7WasSet:
    beq @noInc
    bne @doInc  ; unconditional
    @bit7WasClear:
    bne @noInc
    @doInc:
    inc Zp_RngT_u8
    @noInc:
    ;; Finally, return the exclusive OR of S and T.
    lda Zp_RngS_u8
    eor Zp_RngT_u8
    rts
.ENDPROC

;;;=========================================================================;;;
