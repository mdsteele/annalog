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
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "breakfire.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_NegateVelX
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorSmokeParticle
.IMPORT Func_InitActorWithState1
.IMPORT Func_MovePointDownByA
.IMPORT Func_PointHitsTerrain
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The OBJ palette number used for breakfire projectile actors.
kPaletteObjBreakfire = 1

;;; How many VBlank frames between breakfire animation frames.
.DEFINE kProjBreakfireAnimSlowdown 2

;;; How fast a breakfire moves horizontally, in subpixels/frame.
kProjBreakfireSpeed = $01c0

;;; The mimimum amount of time a breakfire should persist for before expiring,
;;; in frames.
kProjBreakfireMinLifetime = kBlockWidthPx * 12 * $100 / kProjBreakfireSpeed

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Initializes the specified actor as a breakfire projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A Zero if the breakfire should move right, or bObj::FlipH for left.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_InitActorProjBreakfire
.PROC FuncA_Actor_InitActorProjBreakfire
    sta T0  ; horz flag
    ldy #eActor::ProjBreakfire  ; param: actor type
    lda #kProjBreakfireMinLifetime  ; param: min time remaining
    jsr Func_InitActorWithState1  ; preserves X and T0+
_InitVelX:
    bit T0  ; horz flag
    .assert bObj::FlipH = bProc::Overflow, error
    bvc @right
    @left:
    ldya #$ffff & -kProjBreakfireSpeed
    bmi @finish  ; unconditional
    @right:
    ldya #kProjBreakfireSpeed
    @finish:
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;; Performs per-frame updates for a breakfire projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjBreakfire
.PROC FuncA_Actor_TickProjBreakfire
    ;; If the breakfire somehow goes for too long without bouncing, expire it.
    inc Ram_ActorState2_byte_arr, x  ; expiration timer
    beq _Expire
    ;; Decrement the time-remaining counter until it reaches zero.
    lda Ram_ActorState1_byte_arr, x  ; min time remaining
    beq @done
    dec Ram_ActorState1_byte_arr, x  ; min time remaining
    @done:
_CheckIfHitsWall:
    ;; Check if the breakfire has hit a wall; if so, bounce off the wall.
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcs _Bounce
_CheckIfNotOverFloor:
    ;; Check if the breakfire has gone beyond the edge of the floor it's on; if
    ;; so, bounce off the edge.
    lda #kTileHeightPx + 1  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _Finish
_Bounce:
    ;; If the breakfire has already lasted at least its minimum duration,
    ;; expire it.
    lda Ram_ActorState1_byte_arr, x  ; min time remaining
    beq _Expire
    ;; Otherwise, bounce off the wall.
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; expiration timer
    jsr FuncA_Actor_NegateVelX  ; preserves X
_Finish:
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_Expire:
    lda #$c0  ; param: angle ($c0 = up)
    jmp Func_InitActorSmokeParticle  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a breakfire projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjBreakfire
.PROC FuncA_Objects_DrawActorProjBreakfire
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X
    lda Zp_FrameCounter_u8
    div #kProjBreakfireAnimSlowdown
    lsr a
    bcs _Tall
_Short:
    lda #2
    sta T2  ; num tiles
    lda #kTileIdObjBreakfireFirst + 4
    sta T3  ; first tile ID
    bne _Loop  ; unconditional
_Tall:
    lda #3
    sta T2  ; num tiles
    lda #kTileIdObjBreakfireFirst + 2
    sta T3  ; first tile ID
_Loop:
    lda T3  ; param: tile ID
    ldy #kPaletteObjBreakfire  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    dec T3  ; tile ID
    dec T2  ; num tiles
    bne _Loop
    rts
.ENDPROC

;;;=========================================================================;;;
