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
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The OBJ palette number used for breakfire projectile actors.
kPaletteObjBreakfire = 1

;;; How many VBlank frames between breakfire animation frames.
.DEFINE kProjBreakfireAnimSlowdown 2

;;; How fast a breakfire moves horizontally, in subpixels/frame.
kProjBreakfireSpeed = $01c0

;;; How many times a breakfire can bounce off a wall without expiring.
kProjBreakfireMaxBounces = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a breakfire projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A Zero if the breakfire should move right, or bObj::FlipH for left.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorProjBreakfire
.PROC Func_InitActorProjBreakfire
    sta T0  ; horz flag
    ldy #eActor::ProjBreakfire  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X and T0+
_InitVelX:
    bit T0  ; horz flag
    .assert bObj::FlipH = bProc::Overflow, error
    bvs _Left
_Right:
    lda #<kProjBreakfireSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kProjBreakfireSpeed
    sta Ram_ActorVelX_i16_1_arr, x
    rts
_Left:
    lda #<-kProjBreakfireSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>-kProjBreakfireSpeed
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a breakfire projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjBreakfire
.PROC FuncA_Actor_TickProjBreakfire
    ;; If the breakfire somehow goes for too long without hitting a wall,
    ;; expire it.
    inc Ram_ActorState1_byte_arr, x  ; expiration timer
    beq _Expire
_CheckIfHitsWall:
    ;; Check if the breakfire has hit a wall.  If not, we're done.
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcc _Finish
    ;; Check if the breakfire has already bounced the maximum number of times;
    ;; if so, expire it.
    lda Ram_ActorState2_byte_arr, x  ; num bounces so far
    cmp #kProjBreakfireMaxBounces
    bge _Expire
    ;; Otherwise, increment the bounce count, then bounce off the wall.
    inc Ram_ActorState2_byte_arr, x  ; num bounces so far
    lda #0
    sta Ram_ActorState1_byte_arr, x  ; expiration timer
    jsr FuncA_Actor_NegateVelX  ; preserves X
_Finish:
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_Expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
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
    sta T0  ; num tiles
    lda #kTileIdObjBreakfireFirst + 4
    sta T1  ; first tile ID
    bne _Loop  ; unconditional
_Tall:
    lda #3
    sta T0  ; num tiles
    lda #kTileIdObjBreakfireFirst + 2
    sta T1  ; first tile ID
_Loop:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X and T0+, returns C and Y
    bcs @continue
    lda T1  ; tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjBreakfire
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    dec T1  ; tile ID
    dec T0  ; num tiles
    bne _Loop
    rts
.ENDPROC

;;;=========================================================================;;;