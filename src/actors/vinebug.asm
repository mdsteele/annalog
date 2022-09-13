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

.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_GetRoomTileColumn
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_GetRandomByte
.IMPORT Func_GetTerrainColumnPtrForTileIndex
.IMPORT Func_InitActorDefault
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes a vinebug baddie actor.
;;; @prereq The actor's unadjusted pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitActorBadVinebug
.PROC Func_InitActorBadVinebug
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
    inc Ram_ActorState_byte_arr, x
    ;; Get the terrain for the vinebug's tile column.
    jsr FuncA_Actor_GetRoomTileColumn  ; preserves X, returns A
    stx Zp_Tmp1_byte
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte
    ;; Get the vinebug's room block row.
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    ;; TODO: If the player avatar is below the vinebug, then drop quickly.
    ;; Determine if we're currently crawling up or down.
    lda Ram_ActorVelY_i16_1_arr, x
    bpl _CurrentlyCrawlingDown
_CurrentlyCrawlingUp:
    ;; Check the terrain block just above the vinebug.  If it's solid, the
    ;; vinebug has to turn around.
    dey
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    bge _StartCrawlingDown
    blt _StartCrawlingUp  ; unconditional
_CurrentlyCrawlingDown:
    ;; Check the terrain block just below the vinebug.  If it's empty (no vine)
    ;; or solid, the vinebug has to turn around.
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    beq _StartCrawlingUp
    cmp #kFirstSolidTerrainType
    bge _StartCrawlingUp
_StartCrawlingDown:
    ;; If the vinebug is currently moving up, then immediately set velocity to
    ;; down.  Otherwise, only change velocity once every 16 frames.
    lda Ram_ActorVelY_i16_1_arr, x
    bmi @setVelocity
    lda Ram_ActorState_byte_arr, x
    and #$0f
    bne _Finish
    ;; Set velocity randomly between 0-127 subpixels downward per frame.
    @setVelocity:
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$7f
    sta Ram_ActorVelY_i16_0_arr, x
    lda #0
    sta Ram_ActorVelY_i16_1_arr, x
    beq _Finish  ; unconditional
_StartCrawlingUp:
    ;; If the vinebug is currently moving down, then immediately set velocity
    ;; to up.  Otherwise, only change velocity once every 16 frames.
    lda Ram_ActorVelY_i16_1_arr, x
    bpl @setVelocity
    lda Ram_ActorState_byte_arr, x
    and #$0f
    bne _Finish
    ;; Set velocity randomly between 1-128 subpixels upward per frame.
    @setVelocity:
    jsr Func_GetRandomByte  ; preserves X, returns A
    ora #$80
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
    lda Ram_ActorState_byte_arr, x
    div #8
    and #$01
    tay
    lda _TileIds_u8_arr2, y  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr2:
    .byte kTileIdVinebugFirst1, kTileIdVinebugFirst2
.ENDPROC

;;;=========================================================================;;;
