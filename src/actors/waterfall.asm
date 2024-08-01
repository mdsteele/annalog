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
.INCLUDE "../platforms/water.inc"
.INCLUDE "../ppu.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeUpHalfTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorWithState1
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorState4_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; How fast a waterfall falls, in pixels per frame.
kWaterfallSpeed = 3

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a waterfall smoke.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The platform index for the water below.
;;; @param X The actor index.
;;; @preserve X, T0+
.EXPORT FuncA_Room_InitActorSmokeWaterfall
.PROC FuncA_Room_InitActorSmokeWaterfall
    ldy #eActor::SmokeWaterfall  ; param: actor type
    jmp Func_InitActorWithState1  ; preserves X and T0+
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a waterfall smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickSmokeWaterfall
.PROC FuncA_Actor_TickSmokeWaterfall
_ApplyGravity:
    lda Ram_ActorState3_byte_arr, x  ; is shut off (boolean)
    bmi @isShutOff
    @isStillPouring:
    lda Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    add #kWaterfallSpeed
    sta Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    bne @done  ; unconditional
    @isShutOff:
    lda Ram_ActorPosY_i16_0_arr, x
    add #kWaterfallSpeed
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_ActorPosY_i16_1_arr, x
    adc #0
    sta Ram_ActorPosY_i16_1_arr, x
    @done:
_RemoveIfBelowWater:
    ldy Ram_ActorState1_byte_arr, x  ; water platform index
    lda Ram_PlatformTop_i16_0_arr, y
    sub Ram_ActorPosY_i16_0_arr, x
    sta T0  ; distance to water
    lda Ram_PlatformTop_i16_1_arr, y
    sbc Ram_ActorPosY_i16_1_arr, x
    beq @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
    @done:
_ClampHeight:
    lda T0  ; distance to water
    cmp Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    beq @hasHitWater
    bge @done
    @clamp:
    sta Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    @hasHitWater:
    lda #$ff
    sta Ram_ActorState4_byte_arr, x  ; has hit water (boolean)
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a waterfall smoke actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorSmokeWaterfall
.PROC FuncA_Objects_DrawActorSmokeWaterfall
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X
    jsr FuncA_Objects_MoveShapeUpHalfTile  ; preserves X
    lda Zp_FrameCounter_u8
    sub Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    div #2
    mod #4
    sta T3  ; waterfall animation (0-3)
_DrawSplash:
    ldy Ram_ActorState1_byte_arr, x  ; water platform index
    lda Ram_PlatformTop_i16_0_arr, y
    sub Ram_ActorPosY_i16_0_arr, x
    sta T2  ; distance to water
    cmp Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    bne @done
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and T0+
    lda T3  ; waterfall animation (0-3)
    .assert kTileIdObjPlatformWaterfallFirst .mod 4 = 0, error
    ora #kTileIdObjPlatformWaterfallFirst  ; param: tile ID
    ldy #kPaletteObjWater  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    lda T2  ; distance to water
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X and T0+
    @done:
_DrawWaterfall:
    lda Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    beq @done
    div #kTileHeightPx
    sta T2  ; num tiles left to draw
    lda Ram_ActorState2_byte_arr, x  ; waterfall height in pixels
    mod #kTileHeightPx  ; param: offset
    beq @skipFirstTile
    inc T2  ; num tiles left to draw
    bne @offset  ; unconditional
    @skipFirstTile:
    lda #kTileHeightPx
    @offset:
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and T0+
    @loop:
    lda T3  ; waterfall animation (0-3)
    .assert kTileIdObjPlatformSewageFirst .mod 4 = 0, error
    ora #kTileIdObjPlatformSewageFirst  ; param: tile ID
    ldy #bObj::Pri | kPaletteObjWater  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X and T0+
    dec T2  ; num tiles left to draw
    bne @loop
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
