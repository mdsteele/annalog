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
.INCLUDE "wasp.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_Cosine
.IMPORT Func_InitActorWithState1
.IMPORT Func_Sine
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The OBJ palette number to use for drawing wasp baddie actors.
kPaletteObjWasp = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a wasp baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The bBadWasp param.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorBadWasp
.PROC FuncA_Room_InitActorBadWasp
    pha  ; bBadWasp param
    and #bBadWasp::DeltaMask
    .assert bBadWasp::DeltaMask = %00001111, error
    cmp #%00001000
    blt @nonneg
    ora #%11110000
    @nonneg:
    ldy #eActor::BadWasp  ; param: actor type
    jsr Func_InitActorWithState1  ; preserves X
    pla  ; bBadWasp param
    and #bBadWasp::ThetaMask
    sta Ram_ActorState2_byte_arr, x  ; angle
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a wasp baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadWasp
.PROC FuncA_Actor_TickBadWasp
_UpdateVelX:
    lda Ram_ActorState2_byte_arr, x  ; param: angle
    jsr Func_Sine  ; preserves X, returns A
    ldy #0
    asl a  ; sets C if A was negative
    sta Ram_ActorVelX_i16_0_arr, x
    lda #0            ; actor flags
    bcc @nonneg
    lda #bObj::FlipH  ; actor flags
    dey  ; now Y is $ff
    @nonneg:
    sta Ram_ActorFlags_bObj_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
_UpdateVelY:
    lda Ram_ActorState2_byte_arr, x  ; param: angle
    jsr Func_Cosine  ; preserves X, returns A
    ldy #0
    asl a
    sta Ram_ActorVelY_i16_0_arr, x
    bcc @nonneg
    dey  ; now Y is $ff
    @nonneg:
    tya
    sta Ram_ActorVelY_i16_1_arr, x
_UpdateAngle:
    lda Ram_ActorState2_byte_arr, x  ; angle
    add Ram_ActorState1_byte_arr, x  ; delta
    sta Ram_ActorState2_byte_arr, x  ; angle
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a wasp baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadWasp
.PROC FuncA_Objects_DrawActorBadWasp
    lda Zp_FrameCounter_u8
    and #$04
    .assert kTileIdObjBadWaspFirst .mod $08 = 0, error
    ora #kTileIdObjBadWaspFirst  ; param: first tile ID
    ldy #kPaletteObjWasp  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
