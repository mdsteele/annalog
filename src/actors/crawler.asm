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

.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../terrain.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_Terrain_GetColumnPtrForTileIndex
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; First-tile-ID values that can be passed to FuncA_Objects_Draw2x2Actor for
;;; various actor animation frames.
kCrawlerFirstTileId1 = $9c
kCrawlerFirstTileId2 = $a0
kCrawlerFirstTileId3 = $a4

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a crawler enemy actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickCrawler
.PROC FuncA_Actor_TickCrawler
    lda Ram_ActorState_byte_arr, x
    beq _StartMove
    dec Ram_ActorState_byte_arr, x
    cmp #$18
    blt _DetectCollision
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne _MoveLeft
_MoveRight:
    lda Ram_ActorPosX_i16_0_arr, x
    add #1
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_MoveLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    sub #1
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosX_i16_1_arr, x
_DetectCollision:
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_StartMove:
    ;; Compute the room tile column index for the center of the crawler,
    ;; storing it in Y.
    lda Ram_ActorPosX_i16_1_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_0_arr, x
    .repeat 3
    lsr Zp_Tmp1_byte
    ror a
    .endrepeat
    tay
    ;; If the crawler is facing right, increment Y (so as to check the tile
    ;; column to the right of the crawler); if the crawler is facing left,
    ;; decrement Y (so as to check the tile column to the left of the crawler).
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @facingLeft
    @facingRight:
    iny
    bne @doneFacing  ; unconditional
    @facingLeft:
    dey
    dey
    @doneFacing:
    ;; Get the terrain for the tile column we're checking.
    stx Zp_Tmp1_byte
    tya  ; param: room tile column index
    jsr Func_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte
    ;; Compute the room block row index for the center of the crawler, storing
    ;; it in Y.
    lda Ram_ActorPosY_i16_1_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_0_arr, x
    .repeat 4
    lsr Zp_Tmp1_byte
    ror a
    .endrepeat
    tay
    ;; Check the terrain block just in front of the crawler.  If it's solid,
    ;; the crawler has to turn around.
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    bge @turnAround
    ;; Check the floor just in front of the crawler.  If it's not solid, the
    ;; crawler has to turn around.
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    bge @continueForward
    ;; Make the crawler face the opposite direction.
    @turnAround:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    ;; Start a new movement cycle for the crawler.
    @continueForward:
    lda #$1f
    sta Ram_ActorState_byte_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a crawler enemy actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawCrawlerActor
.PROC FuncA_Objects_DrawCrawlerActor
    lda Ram_ActorState_byte_arr, x
    and #$08
    bne @frame2
    lda Ram_ActorState_byte_arr, x
    and #$10
    bne @frame3
    @frame1:
    lda #kCrawlerFirstTileId1
    bne @draw  ; unconditional
    @frame2:
    lda #kCrawlerFirstTileId2
    bne @draw  ; unconditional
    @frame3:
    lda #kCrawlerFirstTileId3
    @draw:
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
