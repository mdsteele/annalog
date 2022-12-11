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
.INCLUDE "../terrain.inc"
.INCLUDE "vinebug.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorDefault
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_AvatarPosY_i16

;;;=========================================================================;;;

;;; How many pixels above/below of its center a vinebug actor checks for
;;; terrain to see if it needs to turn around.
kVinebugLookUpDist = 10
kVinebugLookDownDist = 10

;;; The OBJ palette number to use for drawing grub baddie actors.
kPaletteObjVinebug = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a vinebug baddie actor.
;;; @prereq The actor's unadjusted pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorBadVinebug
.PROC FuncA_Room_InitActorBadVinebug
    lda Ram_ActorPosX_i16_0_arr, x
    bne @noBorrow
    dec Ram_ActorPosX_i16_1_arr, x
    @noBorrow:
    dec Ram_ActorPosX_i16_0_arr, x
    ldy #eActor::BadVinebug  ; param: actor type
    lda #0  ; param: state byte
    jmp Func_InitActorDefault
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a vinebug baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadVinebug
.PROC FuncA_Actor_TickBadVinebug
    inc Ram_ActorState2_byte_arr, x
_DropIfAvatarIsBelow:
    ;; Don't drop if the player avatar isn't horizontally nearby.
    lda #30  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, Y; returns C
    bcc @notNear
    ;; Don't drop if the player avatar is above the vinebug.
    lda Ram_ActorPosY_i16_0_arr, x
    sub Zp_AvatarPosY_i16 + 0
    lda Ram_ActorPosY_i16_1_arr, x
    sbc Zp_AvatarPosY_i16 + 1
    bge @notNear
    ;; Drop quickly.
    lda #1
    sta Ram_ActorState1_byte_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
    lda #0
    sta Ram_ActorVelY_i16_0_arr, x
    @notNear:
_CrawlUpOrDown:
    jsr Func_SetPointToActorCenter  ; preserves X
    ;; Determine if we're currently crawling up or down.
    lda Ram_ActorVelY_i16_1_arr, x
    bpl _CurrentlyCrawlingDown
_CurrentlyCrawlingUp:
    ;; Check the terrain just above the vinebug.  If it's solid, the vinebug
    ;; has to turn around.
    lda #kVinebugLookUpDist  ; param: offset
    jsr Func_MovePointUpByA  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc _ContinueCrawlingUp
_StartCrawlingDown:
    ;; Resume random velocity changes.
    lda #0
    sta Ram_ActorState1_byte_arr, x
    beq _RandomVelocityDown  ; unconditional
_CurrentlyCrawlingDown:
    ;; Check the terrain just below the vinebug.  If it's empty (no vine) or
    ;; solid, the vinebug has to turn around.
    lda #kVinebugLookDownDist  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C and A
    bcs _StartCrawlingUp  ; terrain is solid
    tay  ; terrain type
    beq _StartCrawlingUp  ; terrain is empty (no vine)
_ContinueCrawlingDown:
    ;; If the vinebug is currently crawling down fast, then set velocity.
    lda Ram_ActorState1_byte_arr, x
    bne _Finish
    ;; Otherwise, only change velocity once every 16 frames.
    lda Ram_ActorState2_byte_arr, x
    and #$0f
    beq _Finish
_RandomVelocityDown:
    ;; Set velocity randomly between 0-63 subpixels downward per frame.
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$3f
    bpl _SetVelocityDown  ; unconditional
_FastVelocityDown:
    lda #$80
_SetVelocityDown:
    sta Ram_ActorVelY_i16_0_arr, x
    lda #$00
    sta Ram_ActorVelY_i16_1_arr, x
    beq _Finish  ; unconditional
_StartCrawlingUp:
    ;; Resume random velocity changes.
    lda #0
    sta Ram_ActorState1_byte_arr, x
    beq _RandomVelocityUp  ; unconditional
_ContinueCrawlingUp:
    ;; If the vinebug is currently crawling up fast, then set velocity.
    lda Ram_ActorState1_byte_arr, x
    bne _Finish
    ;; Otherwise, only change velocity once every 16 frames.
    lda Ram_ActorState2_byte_arr, x
    and #$0f
    beq _Finish
_RandomVelocityUp:
    ;; Set velocity randomly between 1-64 subpixels upward per frame.
    jsr Func_GetRandomByte  ; preserves X, returns A
    ora #$c0
    bmi _SetVelocityUp  ; unconditional
_SetVelocityUp:
    sta Ram_ActorVelY_i16_0_arr, x
    lda #$ff
    sta Ram_ActorVelY_i16_1_arr, x
_Finish:
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a vinebug baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadVinebug
.PROC FuncA_Objects_DrawActorBadVinebug
    lda Ram_ActorState2_byte_arr, x
    div #8
    and #$01
    tay
    lda _TileIds_u8_arr2, y  ; param: first tile ID
    ldy #kPaletteObjVinebug  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr2:
    .byte kTileIdVinebugFirst1, kTileIdVinebugFirst2
.ENDPROC

;;;=========================================================================;;;
