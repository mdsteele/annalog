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

.INCLUDE "avatar.inc"
.INCLUDE "macros.inc"
.INCLUDE "platform.inc"
.INCLUDE "ppu.inc"

.IMPORTZP Zp_AvatarCollided_bool
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_ScrollXHi_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

.ZEROPAGE

;;; The index of the platform that the player avatar is currently riding, or
;;; $ff for none.
Zp_AvatarPlatformIndex_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Platform"

;;; For each platform, true ($ff) if the platform exists, false ($00)
;;; otherwise.
.EXPORT Ram_PlatformExists_bool_arr
Ram_PlatformExists_bool_arr: .res kMaxPlatforms

;;; The room pixel Y-position of the top edge of each platform.
.EXPORT Ram_PlatformTop_i16_0_arr, Ram_PlatformTop_i16_1_arr
Ram_PlatformTop_i16_0_arr: .res kMaxPlatforms
Ram_PlatformTop_i16_1_arr: .res kMaxPlatforms

;;; The room pixel Y-position of the bottom edge of each platform.
.EXPORT Ram_PlatformBottom_i16_0_arr, Ram_PlatformBottom_i16_1_arr
Ram_PlatformBottom_i16_0_arr: .res kMaxPlatforms
Ram_PlatformBottom_i16_1_arr: .res kMaxPlatforms

;;; The room pixel X-position of the left edge of each platform.
.EXPORT Ram_PlatformLeft_i16_0_arr, Ram_PlatformLeft_i16_1_arr
Ram_PlatformLeft_i16_0_arr: .res kMaxPlatforms
Ram_PlatformLeft_i16_1_arr: .res kMaxPlatforms

;;; The room pixel X-position of the right edge of each platform.
.EXPORT Ram_PlatformRight_i16_0_arr, Ram_PlatformRight_i16_1_arr
Ram_PlatformRight_i16_0_arr: .res kMaxPlatforms
Ram_PlatformRight_i16_1_arr: .res kMaxPlatforms

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Removes all platforms.
.EXPORT Func_ClearPlatforms
.PROC Func_ClearPlatforms
    lda #$ff
    sta Zp_AvatarPlatformIndex_u8
    lda #0
    ldx #kMaxPlatforms - 1
    @loop:
    sta Ram_PlatformExists_bool_arr, x
    dex
    .assert kMaxPlatforms <= $80, error
    bpl @loop
    rts
.ENDPROC

;;; Moves the specified platform right or left by the specified delta.  If the
;;; player avatar is standing on the platform, it will be moved along with it.
;;; @param A How many pixels to move the platform by (signed).
;;; @param X The platform index.
;;; @preserve X
.EXPORT Func_MovePlatformHorz
.PROC Func_MovePlatformHorz
    ;; Sign-extend the move delta to 16 bits.
    ldy #0
    and #$ff
    bpl @nonnegative
    dey  ; now Y is $ff
    @nonnegative:
    sta Zp_Tmp1_byte  ; move delta (lo)
    sty Zp_Tmp2_byte  ; move delta (hi)
    ;; Move the platform's left edge.
    lda Ram_PlatformLeft_i16_0_arr, x
    add Zp_Tmp1_byte  ; move delta (lo)
    sta Ram_PlatformLeft_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, x
    adc Zp_Tmp2_byte  ; move delta (hi)
    sta Ram_PlatformLeft_i16_1_arr, x
    ;; Move the platform's right edge.
    lda Ram_PlatformRight_i16_0_arr, x
    add Zp_Tmp1_byte  ; move delta (lo)
    sta Ram_PlatformRight_i16_0_arr, x
    lda Ram_PlatformRight_i16_1_arr, x
    adc Zp_Tmp2_byte  ; move delta (hi)
    sta Ram_PlatformRight_i16_1_arr, x
    ;; If the player avatar is riding the platform, move the avatar as well.
    cpx Zp_AvatarPlatformIndex_u8
    bne @notRiding
    lda Zp_AvatarPosX_i16 + 0
    add Zp_Tmp1_byte  ; move delta (lo)
    sta Zp_AvatarPosX_i16 + 0
    lda Zp_AvatarPosX_i16 + 1
    adc Zp_Tmp2_byte  ; move delta (hi)
    sta Zp_AvatarPosX_i16 + 1
    @notRiding:
    ;; TODO: Check if the avatar has been crushed.
    rts
.ENDPROC

;;; Moves the specified platform up or down by the specified delta.  If the
;;; player avatar is standing on the platform, it will be moved along with it.
;;; @param A How many pixels to move the platform by (signed).
;;; @param X The platform index.
;;; @preserve X
.EXPORT Func_MovePlatformVert
.PROC Func_MovePlatformVert
    ;; Sign-extend the move delta to 16 bits.
    ldy #0
    and #$ff
    bpl @nonnegative
    dey  ; now Y is $ff
    @nonnegative:
    sta Zp_Tmp1_byte  ; move delta (lo)
    sty Zp_Tmp2_byte  ; move delta (hi)
    ;; Move the platform's top edge.
    lda Ram_PlatformTop_i16_0_arr, x
    add Zp_Tmp1_byte  ; move delta (lo)
    sta Ram_PlatformTop_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, x
    adc Zp_Tmp2_byte  ; move delta (hi)
    sta Ram_PlatformTop_i16_1_arr, x
    ;; Move the platform's bottom edge.
    lda Ram_PlatformBottom_i16_0_arr, x
    add Zp_Tmp1_byte  ; move delta (lo)
    sta Ram_PlatformBottom_i16_0_arr, x
    lda Ram_PlatformBottom_i16_1_arr, x
    adc Zp_Tmp2_byte  ; move delta (hi)
    sta Ram_PlatformBottom_i16_1_arr, x
    ;; If the player avatar is riding the platform, move the avatar as well.
    cpx Zp_AvatarPlatformIndex_u8
    bne @notRiding
    lda Zp_AvatarPosY_i16 + 0
    add Zp_Tmp1_byte  ; move delta (lo)
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    adc Zp_Tmp2_byte  ; move delta (hi)
    sta Zp_AvatarPosY_i16 + 1
    @notRiding:
    ;; TODO: Check if the avatar has been crushed.
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Checks for horizontal collisions between the player avatar and all
;;; platforms.  If any collision occurs, updates the avatar's Y-position and
;;; sets Zp_AvatarCollided_bool to true.
.EXPORT FuncA_Avatar_CollideWithAllPlatformsHorz
.PROC FuncA_Avatar_CollideWithAllPlatformsHorz
    ldx #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformExists_bool_arr, x
    bpl @continue
    jsr FuncA_Avatar_CollideWithOnePlatformHorz  ; preserves X
    @continue:
    dex
    .assert kMaxPlatforms <= $80, error
    bpl @loop
    rts
.ENDPROC

;;; Checks for horizontal collisions between the player avatar and the
;;; specified platform.  If a collision occurs, updates the avatar's X-position
;;; and sets Zp_AvatarCollided_bool to true.
;;; @param X The platform index.
;;; @preserve X
.PROC FuncA_Avatar_CollideWithOnePlatformHorz
    ;; Check top edge of platform.
    lda Zp_AvatarPosY_i16 + 0
    add #kAvatarBoundingBoxDown
    sta Zp_Tmp1_byte  ; avatar Y-pos + bbox (lo)
    lda Zp_AvatarPosY_i16 + 1
    adc #0            ; avatar Y-pos + bbox (hi)
    cmp Ram_PlatformTop_i16_1_arr, x
    blt @return
    bne @topEdgeHit
    lda Zp_Tmp1_byte  ; avatar Y-pos + bbox (lo)
    cmp Ram_PlatformTop_i16_0_arr, x
    ble @return
    @topEdgeHit:
    ;; Check bottom edge of platform.
    lda Ram_PlatformBottom_i16_0_arr, x
    add #kAvatarBoundingBoxUp
    sta Zp_Tmp1_byte  ; platform bottom edge + bbox (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    adc #0            ; platform bottom edge + bbox (hi)
    cmp Zp_AvatarPosY_i16 + 1
    blt @return
    bne @bottomEdgeHit
    lda Zp_Tmp1_byte  ; platform bottom edge + bbox (lo)
    cmp Zp_AvatarPosY_i16 + 0
    ble @return
    @bottomEdgeHit:
    ;; Check if the player is moving to the left or to the right.
    lda Zp_AvatarVelX_i16 + 1
    bmi _MovingLeft
    bpl _MovingRight  ; unconditional
    @return:
    rts
_MovingRight:
    ;; Check right edge of platform.
    lda Ram_PlatformRight_i16_1_arr, x
    cmp Zp_AvatarPosX_i16 + 1
    blt _Return
    bne @rightEdgeHit
    lda Ram_PlatformRight_i16_0_arr, x
    cmp Zp_AvatarPosX_i16 + 0
    blt _Return
    @rightEdgeHit:
    ;; Check left edge of platform.
    lda Ram_PlatformLeft_i16_0_arr, x
    sub #kAvatarBoundingBoxRight
    sta Zp_Tmp1_byte  ; platform left edge - bbox (lo)
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc #0
    sta Zp_Tmp2_byte  ; platform left edge - bbox (hi)
    cmp Zp_AvatarPosX_i16 + 1
    blt @leftEdgeHit
    bne _Return
    lda Zp_Tmp1_byte  ; platform left edge - bbox (lo)
    cmp Zp_AvatarPosX_i16 + 0
    beq @leftEdgeHit
    bge _Return
    @leftEdgeHit:
    ;; We've hit the left edge of this platform, so set horizontal position to
    ;; just to the right of the platform we hit.
    lda Zp_Tmp1_byte  ; platform left edge - bbox (lo)
    sta Zp_AvatarPosX_i16 + 0
    lda Zp_Tmp2_byte  ; platform left edge - bbox (hi)
    sta Zp_AvatarPosX_i16 + 1
    jmp _Collided
_MovingLeft:
    ;; Check left edge of platform.
    lda Zp_AvatarPosX_i16 + 1
    cmp Ram_PlatformLeft_i16_1_arr, x
    blt _Return
    bne @leftEdgeHit
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_PlatformLeft_i16_0_arr, x
    blt _Return
    @leftEdgeHit:
    ;; Check right edge of platform.
    lda Ram_PlatformRight_i16_0_arr, x
    add #kAvatarBoundingBoxLeft
    sta Zp_Tmp1_byte  ; platform right edge + bbox (lo)
    lda Ram_PlatformRight_i16_1_arr, x
    adc #0
    sta Zp_Tmp2_byte  ; platform right edge + bbox (hi)
    cmp Zp_AvatarPosX_i16 + 1
    blt _Return
    bne @rightEdgeHit
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosX_i16 + 0
    blt _Return
    @rightEdgeHit:
    ;; We've hit the right edge of this platform, so set horizontal position to
    ;; just to the right of the platform we hit.
    lda Zp_Tmp1_byte  ; platform right edge + bbox (lo)
    sta Zp_AvatarPosX_i16 + 0
    lda Zp_Tmp2_byte  ; platform right edge + bbox (hi)
    sta Zp_AvatarPosX_i16 + 1
_Collided:
    lda #$ff
    sta Zp_AvatarCollided_bool
_Return:
    rts
.ENDPROC

;;; Checks for vertical collisions between the player avatar and all platforms.
;;; If any collision occurs, updates the avatar's Y-position and sets
;;; Zp_AvatarCollided_bool to true.  Also updates Zp_AvatarPlatformIndex_u8.
.EXPORT FuncA_Avatar_CollideWithAllPlatformsVert
.PROC FuncA_Avatar_CollideWithAllPlatformsVert
    lda #$ff
    sta Zp_AvatarPlatformIndex_u8
    ldx #kMaxPlatforms - 1
    @loop:
    lda Ram_PlatformExists_bool_arr, x
    bpl @continue
    jsr FuncA_Avatar_CollideWithOnePlatformVert  ; preserves X
    @continue:
    dex
    .assert kMaxPlatforms <= $80, error
    bpl @loop
    rts
.ENDPROC

;;; Checks for vertical collisions between the player avatar and the specified
;;; platform.  If a collision occurs, updates the avatar's Y-position and sets
;;; Zp_AvatarCollided_bool to true.
;;; @param X The platform index.
;;; @preserve X
.PROC FuncA_Avatar_CollideWithOnePlatformVert
    ;; Check left edge of platform.
    lda Zp_AvatarPosX_i16 + 0
    add #kAvatarBoundingBoxRight
    sta Zp_Tmp1_byte  ; avatar X-pos + bbox (lo)
    lda Zp_AvatarPosX_i16 + 1
    adc #0            ; avatar X-pos + bbox (hi)
    cmp Ram_PlatformLeft_i16_1_arr, x
    blt @return
    bne @leftEdgeHit
    lda Zp_Tmp1_byte  ; avatar Y-pos + bbox (lo)
    cmp Ram_PlatformLeft_i16_0_arr, x
    ble @return
    @leftEdgeHit:
    ;; Check right edge of platform.
    lda Ram_PlatformRight_i16_0_arr, x
    add #kAvatarBoundingBoxLeft
    sta Zp_Tmp1_byte  ; platform right edge + bbox (lo)
    lda Ram_PlatformRight_i16_1_arr, x
    adc #0            ; platform right edge + bbox (hi)
    cmp Zp_AvatarPosX_i16 + 1
    blt @return
    bne @rightEdgeHit
    lda Zp_Tmp1_byte  ; platform right edge + bbox (lo)
    cmp Zp_AvatarPosX_i16 + 0
    ble @return
    @rightEdgeHit:
    ;; Check if the player is moving up or down.
    lda Zp_AvatarVelY_i16 + 1
    bmi _MovingUp
    bpl _MovingDown  ; unconditional
    @return:
    rts
_MovingUp:
    ;; Check top edge of platform.
    lda Zp_AvatarPosY_i16 + 1
    cmp Ram_PlatformTop_i16_1_arr, x
    blt _Return
    bne @topEdgeHit
    lda Zp_AvatarPosY_i16 + 0
    cmp Ram_PlatformTop_i16_0_arr, x
    blt _Return
    @topEdgeHit:
    ;; Check bottom edge of platform.
    lda Ram_PlatformBottom_i16_0_arr, x
    add #kAvatarBoundingBoxUp
    sta Zp_Tmp1_byte  ; platform bottom edge + bbox (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    adc #0
    sta Zp_Tmp2_byte  ; platform bottom edge + bbox (hi)
    cmp Zp_AvatarPosY_i16 + 1
    blt _Return
    bne @bottomEdgeHit
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosY_i16 + 0
    blt _Return
    @bottomEdgeHit:
    ;; We've hit the bottom edge of this platform, so set vertical position to
    ;; just below the platform we hit.
    lda Zp_Tmp1_byte  ; platform bottom edge + bbox (lo)
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_Tmp2_byte  ; platform bottom edge + bbox (hi)
    sta Zp_AvatarPosY_i16 + 1
    jmp _Collided
_MovingDown:
    ;; Check bottom edge of platform.
    lda Ram_PlatformBottom_i16_1_arr, x
    cmp Zp_AvatarPosY_i16 + 1
    blt _Return
    bne @bottomEdgeHit
    lda Ram_PlatformBottom_i16_0_arr, x
    cmp Zp_AvatarPosY_i16 + 0
    blt _Return
    @bottomEdgeHit:
    ;; Check top edge of platform.
    lda Ram_PlatformTop_i16_0_arr, x
    sub #kAvatarBoundingBoxDown
    sta Zp_Tmp1_byte  ; platform top edge - bbox (lo)
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_Tmp2_byte  ; platform top edge - bbox (hi)
    cmp Zp_AvatarPosY_i16 + 1
    blt @topEdgeHit
    bne _Return
    lda Zp_Tmp1_byte  ; platform top edge - bbox (lo)
    cmp Zp_AvatarPosY_i16 + 0
    beq @topEdgeHit
    bge _Return
    @topEdgeHit:
    ;; We've hit the top edge of this platform, so set vertical position to
    ;; just above the platform we hit.
    lda Zp_Tmp1_byte  ; platform top edge - bbox (lo)
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_Tmp2_byte  ; platform top edge - bbox (hi)
    sta Zp_AvatarPosY_i16 + 1
    ;; Record that the avatar is now riding this platform.
    stx Zp_AvatarPlatformIndex_u8
_Collided:
    lda #$ff
    sta Zp_AvatarCollided_bool
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the top-left corner of the specified platform.
;;; @param X The platform index.
;;; @preserve X, Y
.EXPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.PROC FuncA_Objects_SetShapePosToPlatformTopLeft
    ;; Calculate top edge in screen space.
    lda Ram_PlatformTop_i16_0_arr, x
    sub Zp_PpuScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate left edge in screen space.
    lda Ram_PlatformLeft_i16_0_arr, x
    sub Zp_PpuScrollX_u8
    sta Zp_ShapePosX_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc Zp_ScrollXHi_u8
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;;=========================================================================;;;
