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
.INCLUDE "../ppu.inc"
.INCLUDE "flamestrike.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorWithFlags
.IMPORT Func_MovePointDownByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; How long it takes for a flamestrike to descend by one step, in frames.
kFlamestrikeDescendFrames = 6

;;; How long a flamestrike pauses after descending and before sweeping
;;; outwards, in frames.
kFlamestrikePauseFrames = 100

;;; The maximum height of a fully-descended flamestrike, in tiles.
kFlamestrikeMaxHeightTiles = 6

;;; The OBJ palette number used for flamestrike projectile actors.
kPaletteObjFlamestrike = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a flamestrike projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A Zero if the flame should sweep right, or bObj::FlipH for left.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Room_InitActorProjFlamestrike
.PROC FuncA_Room_InitActorProjFlamestrike
    ldy #eActor::ProjFlamestrike  ; param: actor type
    jmp Func_InitActorWithFlags  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a flamestrike projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjFlamestrike
.PROC FuncA_Actor_TickProjFlamestrike
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_CheckMode:
    lda Ram_ActorState1_byte_arr, x  ; eProjFlamestrike mode
    .assert eProjFlamestrike::Descending = 0, error
    beq _Descending
    cmp #eProjFlamestrike::Paused
    beq _Paused
_Sweeping:
    ;; Remove the projectile when it hits a side wall.
    jsr Func_SetPointToActorCenter  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _Remove
    ;; Set speed based on the timer.
    inc Ram_ActorState3_byte_arr, x  ; timer
    lda #0
    sta T0  ; speed (hi)
    lda Ram_ActorState3_byte_arr, x  ; timer
    .repeat 4
    asl a   ; param: speed (lo)
    rol T0  ; speed (hi)
    .endrepeat
    ldy T0  ; param: speed (hi)
    jmp FuncA_Actor_SetVelXForward  ; preserves X
_Remove:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
_Paused:
    dec Ram_ActorState3_byte_arr, x  ; timer
    bne @done
    lda #eProjFlamestrike::Sweeping
    sta Ram_ActorState1_byte_arr, x  ; eProjFlamestrike mode
    @done:
    rts
_Descending:
    lda Ram_ActorState3_byte_arr, x  ; timer
    beq _Lengthen
    dec Ram_ActorState3_byte_arr, x  ; timer
    rts
_Lengthen:
    ;; TODO: play a sound
    ;; Set a cooldown before we expand again.
    lda #kFlamestrikeDescendFrames
    sta Ram_ActorState3_byte_arr, x  ; timer
    ;; Move the flamestrike down by one tile.
    jsr Func_SetPointToActorCenter  ; preserves X
    lda #kTileHeightPx
    jsr Func_MovePointDownByA  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    ;; Increase the visual height of the flamestrike.
    inc Ram_ActorState2_byte_arr, x  ; visual height in tiles
    lda Ram_ActorState2_byte_arr, x  ; visual height in tiles
    cmp #kFlamestrikeMaxHeightTiles
    blt @done
    ;; The flamestrike is now at full length, so switch to pause mode.
    lda #eProjFlamestrike::Paused
    sta Ram_ActorState1_byte_arr, x  ; eProjFlamestrike mode
    lda #kFlamestrikePauseFrames
    sta Ram_ActorState3_byte_arr, x  ; timer
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a flamestrike projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjFlamestrike
.PROC FuncA_Objects_DrawActorProjFlamestrike
    ;; Only draw the flamestrike on alternating frames, with parity equal to
    ;; the actor's bObj::FlipH flag.  That way, when there's both a left- and
    ;; right-sweeping flamestrike on screen, only one will draw in a given
    ;; frame, thus saving on objects in the boss room.
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipH = (1 << 6), error  ; the FlipH flag is in bit 6
    asl a  ; now the FlipH bit is in bit 7
    asl a  ; now the FlipH bit is in the carry flag
    rol a  ; now the FlipH bit is in bit 0
    eor Zp_FrameCounter_u8
    and #1
    beq @done
    ;; Set the shape position to the bottom-left of the flamestrike.
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and T0+
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X and T0+
    jsr FuncA_Objects_MoveShapeUpHalfTile  ; preserves X and T0+
    ;; Determine the number of objects to draw.  If zero, we're done.
    lda Ram_ActorState2_byte_arr, x  ; visual height in tiles
    beq @done  ; we don't need to draw anything
    stx T3  ; actor index
    tax  ; num objects to draw
    ;; Determine the tile ID to use.
    lda Zp_FrameCounter_u8
    div #2
    and #1
    .assert kTileIdObjFlamestrikeFirst .mod 2 = 0, error
    ora #kTileIdObjFlamestrikeFirst
    sta T2  ; tile ID
    ;; Draw a column of flame objects.
    @loop:
    ldy #kPaletteObjFlamestrike  ; param: object flags
    lda T2  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    dex
    bne @loop
    ;; Restore the actor index.
    ldx T3  ; actor index
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
