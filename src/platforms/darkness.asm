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

.INCLUDE "../fade.inc"
.INCLUDE "../macros.inc"

.IMPORT Func_AvatarDepthIntoPlatformBottom
.IMPORT Func_AvatarDepthIntoPlatformLeft
.IMPORT Func_AvatarDepthIntoPlatformRight
.IMPORT Func_AvatarDepthIntoPlatformTop

;;;=========================================================================;;;

;;; The distance, in pixels, between fade steps as the player avatar moves
;;; deeper into a zone of darkness.
kDarknessStepPx = 6

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Determines the fade level that should be applied if the player avatar is
;;; touching a darkness zone.  If the avatar is not touching this zone, Y is
;;; returned unchanged; otherwise, returns the darker of the current fade level
;;; and that which should be applied by this zone.
;;; @param X The darkness zone platform index.
;;; @param Y The eFade value for the current fade level.
;;; @return Y The eFade value for the new fade level.
;;; @preserve X
.EXPORT FuncA_Room_GetDarknessZoneFade
.PROC FuncA_Room_GetDarknessZoneFade
    sty T3  ; current fade level
    lda #$ff
    sta T2  ; min depth
    ;; Calculate the minimum depth of the avatar into the darkness zone.
    jsr Func_AvatarDepthIntoPlatformLeft    ; preserves X, T2+; returns A
    jsr _UpdateMinDepthNeg
    jsr Func_AvatarDepthIntoPlatformRight   ; preserves X, T2+; returns A
    jsr _UpdateMinDepthPos
    jsr Func_AvatarDepthIntoPlatformTop     ; preserves X, T2+; returns A
    jsr _UpdateMinDepthNeg
    jsr Func_AvatarDepthIntoPlatformBottom  ; preserves X, T2+; returns A
    jsr _UpdateMinDepthPos
    ;; If the avatar is not in the zone, don't change the fade level.
    lda T2  ; min depth
    beq _NoChange
    ;; Otherwise, calculate a darkness level to apply.
    cmp #kDarknessStepPx * 1 + 1
    blt @dim
    cmp #kDarknessStepPx * 2 + 1
    blt @dark
    @black:
    lda #eFade::Black
    bpl @update  ; unconditional
    @dark:
    lda #eFade::Dark
    bpl @update  ; unconditional
    @dim:
    lda #eFade::Dim
    ;; If the darkness to apply is no darker than the current fade level, don't
    ;; change the fade level.
    @update:
    cmp T3  ; current fade level
    bge _NoChange
    ;; Otherwise, the new fade level is this zone's darkness level.
    tay
    rts
_NoChange:
    ldy T3  ; current fade level
    rts
_UpdateMinDepthNeg:
    eor #$ff
    add #1
_UpdateMinDepthPos:
    cmp T2  ; min depth
    bge @done
    sta T2  ; min depth
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
