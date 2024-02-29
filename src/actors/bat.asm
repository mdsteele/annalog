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
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../program.inc"
.INCLUDE "bat.inc"

.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_SetPointInDirFromActor
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_PointHitsTerrain
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr

;;;=========================================================================;;;

;;; How fast a bat baddie flies when at maximum speed, in subpixels per frame.
kBadBatMaxSpeed = $0110

;;; How much a bat baddie accelerates each frame (up to its max speed), in
;;; subpixels per frame per frame.
kBadBatAcceleration = 17

;;; How many pixels from its center a bat baddie actor checks for solid terrain
;;; to see if it needs to turn around.
kBadBatTurnDistance = 16

;;; How many VBlank frames per animation frame for bat baddie actors.
.DEFINE kBadBatAnimSlowdown 8

;;; The number of animation frames in a bat baddie's animation loop.
kBadBatNumAnimationFrames = 3

;;; The OBJ palette number to use for drawing bat baddie actors.
kPaletteObjBat = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a bat baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadBat
.PROC FuncA_Actor_TickBadBat
    jsr FuncA_Actor_HarmAvatarIfCollision
_Animate:
    ;; Increment the animation counter, wrapping around as necessary.
    inc Ram_ActorState2_byte_arr, x  ; animation counter
    lda Ram_ActorState2_byte_arr, x  ; animation counter
    cmp #kBadBatNumAnimationFrames * kBadBatAnimSlowdown
    blt @done
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; animation counter
    @done:
_CheckForObstacle:
    ;; Check if there's a wall ahead of the bat.
    ldy Ram_ActorState1_byte_arr, x  ; param: current eDir
    lda #kBadBatTurnDistance  ; param: offset
    jsr FuncA_Actor_SetPointInDirFromActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc _ContinueForward
    ;; If there's a wall, reverse the bat's direction.
    lda Ram_ActorState1_byte_arr, x  ; current eDir
    .assert eDir::Up = eDir::Down ^ $02, error
    .assert eDir::Left = eDir::Right ^ $02, error
    eor #$02
    sta Ram_ActorState1_byte_arr, x  ; current eDir
_ContinueForward:
    lda Ram_ActorState1_byte_arr, x  ; current eDir
    tay  ; current eDir
    .assert eDir::Up .mod 2 = 0, error
    .assert eDir::Down .mod 2 = 0, error
    .assert eDir::Left .mod 2 = 1, error
    .assert eDir::Right .mod 2 = 1, error
    and #1
    bne _AccelHorz
_AccelVert:
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X and Y
    ;; Accelerate in the current direction.
    tya  ; current eDir
    .assert eDir::Up = 0, error
    bne _AccelDown
_AccelUp:
    lda Ram_ActorVelY_i16_0_arr, x
    sub #<kBadBatAcceleration
    sta Ram_ActorVelY_i16_0_arr, x
    lda Ram_ActorVelY_i16_1_arr, x
    sbc #>kBadBatAcceleration
    bpl @setVelYHi
    cmp #>-kBadBatMaxSpeed
    blt @clamp
    bne @setVelYHi
    ldy Ram_ActorVelY_i16_0_arr, x
    cpy #<-kBadBatMaxSpeed
    bge @setVelYHi
    @clamp:
    lda #<-kBadBatMaxSpeed
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>-kBadBatMaxSpeed
    @setVelYHi:
    sta Ram_ActorVelY_i16_1_arr, x
    rts
_AccelDown:
    lda Ram_ActorVelY_i16_0_arr, x
    add #<kBadBatAcceleration
    sta Ram_ActorVelY_i16_0_arr, x
    lda Ram_ActorVelY_i16_1_arr, x
    adc #>kBadBatAcceleration
    bmi @setVelYHi
    cmp #>kBadBatMaxSpeed
    blt @setVelYHi
    bne @clamp
    ldy Ram_ActorVelY_i16_0_arr, x
    cpy #<kBadBatMaxSpeed
    blt @setVelYHi
    @clamp:
    lda #<kBadBatMaxSpeed
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kBadBatMaxSpeed
    @setVelYHi:
    sta Ram_ActorVelY_i16_1_arr, x
    rts
_AccelHorz:
    ;; Face towards the VelX direction.
    lda Ram_ActorVelX_i16_1_arr, x
    and #$80
    .assert bObj::FlipH = $40, error
    lsr a
    sta Ram_ActorFlags_bObj_arr, x
    ;; Accelerate in the current direction.
    cpy #eDir::Right
    beq _AccelRight
_AccelLeft:
    lda Ram_ActorVelX_i16_0_arr, x
    sub #<kBadBatAcceleration
    sta Ram_ActorVelX_i16_0_arr, x
    lda Ram_ActorVelX_i16_1_arr, x
    sbc #>kBadBatAcceleration
    bpl @setVelXHi
    cmp #>-kBadBatMaxSpeed
    blt @clamp
    bne @setVelXHi
    ldy Ram_ActorVelX_i16_0_arr, x
    cpy #<-kBadBatMaxSpeed
    bge @setVelXHi
    @clamp:
    lda #<-kBadBatMaxSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>-kBadBatMaxSpeed
    @setVelXHi:
    sta Ram_ActorVelX_i16_1_arr, x
    rts
_AccelRight:
    lda Ram_ActorVelX_i16_0_arr, x
    add #<kBadBatAcceleration
    sta Ram_ActorVelX_i16_0_arr, x
    lda Ram_ActorVelX_i16_1_arr, x
    adc #>kBadBatAcceleration
    bmi @setVelXHi
    cmp #>kBadBatMaxSpeed
    blt @setVelXHi
    bne @clamp
    ldy Ram_ActorVelX_i16_0_arr, x
    cpy #<kBadBatMaxSpeed
    blt @setVelXHi
    @clamp:
    lda #<kBadBatMaxSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kBadBatMaxSpeed
    @setVelXHi:
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a bat baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadBat
.PROC FuncA_Objects_DrawActorBadBat
    lda Ram_ActorState2_byte_arr, x  ; animation counter
    .assert kBadBatAnimSlowdown .mod 4 = 0, error
    div #kBadBatAnimSlowdown
    mul #4
    adc #kTileIdObjBadBatFirst  ; param: first tile ID
    ldy #kPaletteObjBat  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
