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

.INCLUDE "../actor.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../terrain.inc"
.INCLUDE "bird.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_NegateVelX
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_DivMod
.IMPORT Func_InitActorWithState1
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarVelY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; How fast the bird flies, in subpixels per frame.
kBirdSpeed = $03f0

;;; How many pixels in front of its center a bird actor checks for solid
;;; terrain to see if it needs to land.
kBirdLandDistance = 8

;;; How many frames a bird baddie actor must wait after landing before it can
;;; fly again.
kBirdCooldown = kAvatarHarmInvincibileFrames

;;; The OBJ palette number to use for drawing bird baddie actors.
kPaletteObjBird = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a bird baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The bBadBird param.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorBadBird
.PROC FuncA_Room_InitActorBadBird
    pha  ; bBadBird bits
    and #bBadBird::DistMask  ; param: state byte
    ldy #eActor::BadBird  ; param: actor type
    jsr Func_InitActorWithState1  ; preserves X
    pla  ; bBadBird bits
    .assert bBadBird::FlipH = bProc::Negative, error
    bpl @done
    lda #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a bird baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadBird
.PROC FuncA_Actor_TickBadBird
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    ;; Check if the bird is moving or not.
    .assert kBirdSpeed >= $100, error  ; we only need to check the high byte
    lda Ram_ActorVelX_i16_1_arr, x
    beq _NotMoving
_Moving:
    inc Ram_ActorState2_byte_arr, x  ; flying animation counter
    ;; Set the point to a position in front of the bird.
    jsr Func_SetPointToActorCenter  ; preserves X
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @facingLeft
    @facingRight:
    lda #kBirdLandDistance  ; param: offset
    jsr Func_MovePointRightByA  ; preserves X
    jmp @checkTerrain
    @facingLeft:
    lda #kBirdLandDistance  ; param: offset
    jsr Func_MovePointLeftByA  ; preserves X
    @checkTerrain:
    ;; Check the terrain in front of the bird.  If it's solid, then land.
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc _Done
_LandOnWall:
    ;; Stop moving.
    lda #0
    sta Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    ;; Make the bird face the opposite direction.
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    ;; Adjust position to be on the wall.
    lda Ram_ActorPosX_i16_0_arr, x
    and #$f0
    ora #$08
    sta Ram_ActorPosX_i16_0_arr, x
    ;; Set cooldown.
    lda #kBirdCooldown
    sta Ram_ActorState2_byte_arr, x  ; cooldown
_Done:
    rts
_NotMoving:
    ;; Check cooldown; don't move again until it reaches zero.
    lda Ram_ActorState2_byte_arr, x  ; cooldown
    beq @cooldownIsZero
    dec Ram_ActorState2_byte_arr, x  ; cooldown
    rts
    @cooldownIsZero:
_GetHorzDist:
    ;; Calculate how far in front of the bird the player avatar is, storing
    ;; that distance in Zp_Tmp1_byte.  If it's farther than this bird's limit,
    ;; or the player avatar is behind the bird, we're done.
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @facingLeft
    @facingRight:
    lda Zp_AvatarPosX_i16 + 0
    sub Ram_ActorPosX_i16_0_arr, x
    sta Zp_Tmp1_byte  ; horz distance to avatar
    lda Zp_AvatarPosX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    bne _Done  ; avatar is either too far away or behind bird
    beq @checkDist  ; unconditional
    @facingLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    sub Zp_AvatarPosX_i16 + 0
    sta Zp_Tmp1_byte  ; horz distance to avatar
    lda Ram_ActorPosX_i16_1_arr, x
    sbc Zp_AvatarPosX_i16 + 1
    bne _Done  ; avatar is either too far away horizontally or behind bird
    @checkDist:
    lda Ram_ActorState1_byte_arr, x  ; max look-ahead
    cmp Zp_Tmp1_byte  ; horz distance to avatar
    blt _Done  ; avatar is too far away horizontally
    ;; Calculate approximately how many frames it would take the bird to reach
    ;; the player avatar horizontally, storing that time in Zp_Tmp1_byte.
    lda Zp_Tmp1_byte  ; param: dividend (horz distance to avatar)
    ldy #>kBirdSpeed  ; param: divisor
    jsr Func_DivMod  ; preserves X, returns quotient in Y
    sty Zp_Tmp1_byte  ; num frames horz
_GetVertDist:
    lda Ram_ActorPosY_i16_0_arr, x
    sub Zp_AvatarPosY_i16 + 0
    sta Zp_Tmp2_byte  ; vert delta to avatar (signed)
    lda Ram_ActorPosY_i16_1_arr, x
    sbc Zp_AvatarPosY_i16 + 1
    beq _AvatarIsAbove
    cmp #$ff
    bne _Done  ; avatar is too far away vertically
_AvatarIsBelow:
    ;; Negate the vertical distance byte to get an unsigned value.  This is
    ;; off-by-one, but it's close enough; if we incremented, then -256 would
    ;; wrap around to zero.
    lda Zp_Tmp2_byte  ; vert delta to avatar (-256 to -1)
    eor #$ff
    sta Zp_Tmp2_byte  ; approximate vert distance to avatar (0 to 255)
    ;; If the player avatar's Y-velocity is nonnegative (i.e. zero or moving
    ;; downward), we're done.
    lda Zp_AvatarVelY_i16 + 1
    bpl _Done
    eor #$ff
    tay
    iny  ; param: divisor (vert speed)
    bne _GetVertFrames  ; unconditional
_AvatarIsAbove:
    ;; If the player avatar's Y-velocity is < 1 pixel/frame (including
    ;; negative, i.e. moving upward), we're done.
    ldy Zp_AvatarVelY_i16 + 1  ; param: divisor (vert speed)
    bmi _Done
    beq _Done
_GetVertFrames:
    ;; Calculate approximately how many frames until the player avatar is at
    ;; the same height as the bird.
    lda Zp_Tmp1_byte  ; num frames horz
    pha  ; num frames horz
    lda Zp_Tmp2_byte  ; param: dividend (vert distance, unsigned)
    jsr Func_DivMod  ; preserves X, returns quotient in Y
    sty Zp_Tmp2_byte  ; num frames vert
    pla  ; num frames horz
    ;; If it would take longer for the player avatar to reach the bird
    ;; vertically than it would take the bird to reach the avatar horizontally,
    ;; then the avatar is still too far away, and the bird shouldn't fly yet.
    cmp Zp_Tmp2_byte  ; num frames vert
    blt _Done  ; avatar is too far away
_StartFlying:
    ;; Set X-velocity for flying.
    lda #<kBirdSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kBirdSpeed
    sta Ram_ActorVelX_i16_1_arr, x
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @facingRight
    @facingLeft:
    jsr FuncA_Actor_NegateVelX  ; preserves X
    @facingRight:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a bird baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadBird
.PROC FuncA_Objects_DrawActorBadBird
    ldy Ram_ActorVelX_i16_1_arr, x
    beq @draw  ; bird is not moving, so just use animation frame zero
    lda Ram_ActorState2_byte_arr, x  ; flying animation counter
    div #2
    and #$01
    tay
    @draw:
    lda _TileIds_u8_arr2, y  ; param: first tile ID
    ldy #kPaletteObjBird  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr2:
    .byte kTileIdObjBirdFirst + 0
    .byte kTileIdObjBirdFirst + 4
.ENDPROC

;;;=========================================================================;;;
