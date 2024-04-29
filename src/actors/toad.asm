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

.INCLUDE "../avatar.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "toad.inc"

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_LandOnTerrain
.IMPORT FuncA_Actor_PlaySfxToadJump
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorWithFlags
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr

;;;=========================================================================;;;

;;; The (signed, 16-bit) initial Y-velocity of a toad baddie actor when
;;; jumping, in subpixels per frame.
kToadJumpVelocity = $ffff & -850

;;; OBJ tile IDs for drawing toad baddie actors.
kTileIdObjToadGrounded = kTileIdObjBadToadFirst + 0
kTileIdObjToadAirborne = kTileIdObjBadToadFirst + 4

;;; The OBJ palette number to use for drawing toad baddie actors.
kPaletteObjToad = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a toad baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The flags to set.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorBadToad
.PROC FuncA_Room_InitActorBadToad
    jsr Func_InitActorWithFlags  ; preserves X
    jsr Func_GetRandomByte  ; preserves X
    and #$3f
    add #$20
    sta Ram_ActorState1_byte_arr, x  ; jump timer
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a toad baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadToad
.PROC FuncA_Actor_TickBadToad
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    lda Ram_ActorState2_byte_arr, x  ; 0 if grounded, 1 if airborne
    beq _IsGrounded
_IsAirborne:
    jsr FuncA_Actor_ApplyGravity  ; preserves X
    lda #0  ; param: bounding box down
    jsr FuncA_Actor_LandOnTerrain  ; preserves X, returns C
    bcc @done  ; still airborne
    ;; Mark the toad as being grounded.
    lda #0
    sta Ram_ActorState2_byte_arr, x  ; 0 if grounded, 1 if airborne
    ;; Set the jump timer.
    jsr Func_GetRandomByte  ; preserves X
    and #$3f
    add #$20
    sta Ram_ActorState1_byte_arr, x  ; jump timer
    @done:
    rts
_IsGrounded:
    ;; Decrement jump timer; jump when it's at zero.
    lda Ram_ActorState1_byte_arr, x  ; jump timer
    beq _StartJump
    dec Ram_ActorState1_byte_arr, x  ; jump timer
    rts
_StartJump:
    ;; TODO: only play sound if the toad is on screen (or nearly)
    jsr FuncA_Actor_PlaySfxToadJump  ; preserves X
    jsr FuncA_Actor_FaceTowardsAvatar  ; preserves X
    ;; Set Y-velocity.
    lda #<kToadJumpVelocity
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kToadJumpVelocity
    sta Ram_ActorVelY_i16_1_arr, x
    ;; Mark the toad as being airborne.
    lda #1
    sta Ram_ActorState2_byte_arr, x  ; 0 if grounded, 1 if airborne
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a toad baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadToad
.PROC FuncA_Objects_DrawActorBadToad
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda #5  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X
    ldy Ram_ActorState2_byte_arr, x  ; 0 if grounded, 1 if airborne
    lda _FirstTileId_u8_arr2, y  ; param: first tile ID
    .assert kPaletteObjToad = 0, error
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
_FirstTileId_u8_arr2:
    .byte kTileIdObjToadGrounded
    .byte kTileIdObjToadAirborne
.ENDPROC

;;;=========================================================================;;;
