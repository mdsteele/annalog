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
.INCLUDE "../tileset.inc"
.INCLUDE "goo.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarToLeftOrRight
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Actor_IsPointToLeftOrRight
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_InitActorWithFlags
.IMPORT Func_IsActorWithinHorzDistanceOfPoint
.IMPORT Func_PointHitsTerrain
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORTZP Zp_PointX_i16

;;;=========================================================================;;;

;;; The number of VBlank frames required for a goo baddie to complete a full
;;; movement cycle.
.DEFINE kGooMoveCycleFrames 32

;;; How far a (red) goo baddie can move per move cycle, in subpixels.
kGooMoveCycleSubpixels = $0200

;;; How many pixels in front of its center a (red) goo baddie actor checks for
;;; solid terrain to see if it needs to stop.
kGooStopDistance = 9

;;; How close, in pixels, a (red) goo baddie wants to be to its home base.
kGooHomeDistance = 4

;;; The OBJ palette numbers to use for drawing goo baddie actors.
kPaletteObjGooGreen = 2
kPaletteObjGooRed = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a red goo baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The flags to set.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorBadGooRed
.PROC FuncA_Room_InitActorBadGooRed
    ldy #eActor::BadGooRed  ; param: actor type
    jsr Func_InitActorWithFlags  ; preserves X
    lda Ram_ActorPosX_i16_0_arr, x
    sta Ram_ActorState2_byte_arr, x  ; home base block column
    lda Ram_ActorPosX_i16_1_arr, x
    .assert kBlockWidthPx = 1 << 4, error
    .repeat 4
    lsr a
    ror Ram_ActorState2_byte_arr, x  ; home base block column
    .endrepeat
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a green goo baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGooGreen
.PROC FuncA_Actor_TickBadGooGreen
    inc Ram_ActorState1_byte_arr, x  ; animation timer
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a red goo baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGooRed
.PROC FuncA_Actor_TickBadGooRed
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    ;; Set velocity only at the start of each movement cycle.
    lda Ram_ActorState1_byte_arr, x  ; animation timer
    inc Ram_ActorState1_byte_arr, x  ; animation timer
    mod #kGooMoveCycleFrames
    beq _ChooseDirection
    .assert kGooMoveCycleFrames .mod 2 = 0, error
    cmp #kGooMoveCycleFrames / 2
    bne _Return
_SetVelocity:
    lda Ram_ActorState3_byte_arr, x  ; "should move" bool
    bpl @stop
    ;; Move forward.
    @forward:
    .assert kGooMoveCycleFrames .mod 2 = 0, error
    ldya #kGooMoveCycleSubpixels / (kGooMoveCycleFrames / 2)  ; param: speed
    jsr FuncA_Actor_SetVelXForward  ; preserves X
    rts
    ;; Stop.
    @stop:
    jsr FuncA_Actor_ZeroVelX  ; preserves X
_Return:
    rts
_ChooseDirection:
    lda #0
    sta Ram_ActorState3_byte_arr, x  ; "should move" bool (now false)
    jsr FuncA_Actor_ZeroVelX  ; preserves X
    lda #8  ; param: distance above avatar
    ldy #8  ; param: distance below avatar
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc _MaybeGoHome
_ChaseAvatar:
    jsr FuncA_Actor_IsAvatarToLeftOrRight  ; preserves X, returns N
    jsr FuncA_Actor_BadGooFaceN  ; preserves X
    ;; Only move if the goo isn't blocked in front.
    lda #kGooStopDistance  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs @done
    dec Ram_ActorState3_byte_arr, x  ; "should move" bool (now true)
    @done:
    rts
_MaybeGoHome:
    ;; Set Zp_PointX_i16 to the center of the goo baddie's home base block.
    lda Ram_ActorState2_byte_arr, x  ; home base block column
    sec     ; Shift in a 1 bit at the bottom of the first multiply-by-2, so
    rol a   ; that Zp_PointX_i16 will end up at the midpoint of the block.
    sta Zp_PointX_i16 + 0
    lda #0  ; Init upper byte to zero, and shift in the carry from the lower
    rol a   ; byte.
    .assert kBlockWidthPx = 16, error
    .repeat 3  ; Now multiply by 8.
    asl Zp_PointX_i16 + 0
    rol a
    .endrepeat
    sta Zp_PointX_i16 + 1
    ;; Only change direction and move if the goo isn't near its home base.
    lda #kGooHomeDistance  ; param: distance
    jsr Func_IsActorWithinHorzDistanceOfPoint  ; preserves X, returns C
    bcc _DoGoHome
    rts
_DoGoHome:
    dec Ram_ActorState3_byte_arr, x  ; "should move" bool (now true)
    jsr FuncA_Actor_IsPointToLeftOrRight  ; preserves X, returns N
    fall FuncA_Actor_BadGooFaceN  ; preserves X
.ENDPROC

;;; Sets a goo baddie actor to face the specified direction.
;;; @param N Set if the goo should face left, cleared to face right.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_BadGooFaceN
    bpl @faceRight
    @faceLeft:
    lda #bObj::FlipHV
    bne @setFlags  ; unconditional
    @faceRight:
    lda #0
    @setFlags:
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a red goo baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGooRed
.PROC FuncA_Objects_DrawActorBadGooRed
    ldy #kPaletteObjGooRed  ; param: OBJ palette number
    .assert kPaletteObjGooRed < $80, error
    bpl FuncA_Objects_DrawActorBadGoo  ; unconditional
.ENDPROC

;;; Draws a green goo baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGooGreen
.PROC FuncA_Objects_DrawActorBadGooGreen
    ldy #kPaletteObjGooGreen  ; param: OBJ palette number
    fall FuncA_Objects_DrawActorBadGoo
.ENDPROC

;;; Draws a goo baddie actor.
;;; @param X The actor index.
;;; @param Y The OBJ palette number to use.
;;; @preserve X
.PROC FuncA_Objects_DrawActorBadGoo
    sty T0  ; OBJ palette number
    lda Ram_ActorState1_byte_arr, x  ; animation timer
    .assert kGooMoveCycleFrames .mod 8 = 0, error
    add #(kGooMoveCycleFrames / 8) - 2
    div #kGooMoveCycleFrames / 8
    mod #8
    tay
    lda _TileIds_u8_arr8, y  ; param: first tile ID
    ldy T0  ; param: OBJ palette number
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr8:
:   .byte kTileIdObjBadGooFirst + $00
    .byte kTileIdObjBadGooFirst + $04
    .byte kTileIdObjBadGooFirst + $08
    .byte kTileIdObjBadGooFirst + $08
    .byte kTileIdObjBadGooFirst + $08
    .byte kTileIdObjBadGooFirst + $04
    .byte kTileIdObjBadGooFirst + $04
    .byte kTileIdObjBadGooFirst + $00
    .assert * - :- = 8, error
.ENDPROC

;;;=========================================================================;;;
