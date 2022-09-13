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
.INCLUDE "spider.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_PositionActorShape
.IMPORT Func_GetRandomByte
.IMPORT Func_Terrain_GetColumnPtrForTileIndex
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

kTileIdSpiderLegs1 = kTileIdSpiderFirst + 0
kTileIdSpiderHead1 = kTileIdSpiderFirst + 1
kTileIdSpiderLegs2 = kTileIdSpiderFirst + 2
kTileIdSpiderHead2 = kTileIdSpiderFirst + 3

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a spider baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadSpider
.PROC FuncA_Actor_TickBadSpider
    lda Ram_ActorState_byte_arr, x
    beq _StartMove
    dec Ram_ActorState_byte_arr, x
    cmp #$08
    blt _DetectCollision
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne _MoveLeft
_MoveRight:
    inc Ram_ActorPosX_i16_0_arr, x
    bne @noCarry
    inc Ram_ActorPosX_i16_1_arr, x
    @noCarry:
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_MoveLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    bne @noBorrow
    dec Ram_ActorPosX_i16_1_arr, x
    @noBorrow:
    dec Ram_ActorPosX_i16_0_arr, x
_DetectCollision:
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_StartMove:
    ;; Compute the room tile column index for the center of the spider, storing
    ;; it in Y.
    lda Ram_ActorPosX_i16_1_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_0_arr, x
    .repeat 3
    lsr Zp_Tmp1_byte
    ror a
    .endrepeat
    tay
    ;; If the spider is facing right, increment Y (so as to check the tile
    ;; column to the right of the spider); if the spider is facing left,
    ;; decrement Y (so as to check the tile column to the left of the spider).
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
    ;; Compute the room block row index for the center of the spider, storing
    ;; it in Y.
    lda Ram_ActorPosY_i16_1_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_0_arr, x
    .repeat 4
    lsr Zp_Tmp1_byte
    ror a
    .endrepeat
    tay
    ;; Check the terrain block just in front of the spider.  If it's solid,
    ;; the spider has to turn around.
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    bge @turnAround
    ;; Check the ceiling just in front of the spider.  If it's not solid, the
    ;; spider has to turn around.
    dey
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    blt @turnAround
    ;; Otherwise, randomly turn around 25% of the time.
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$03
    bne @continueForward
    ;; TODO: Otherwise, sometimes drop down on a thread.
    ;; Make the spider face the opposite direction.
    @turnAround:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    ;; Start a new movement cycle for the spider.
    @continueForward:
    lda #$0f
    sta Ram_ActorState_byte_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a spider baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadSpider
.PROC FuncA_Objects_DrawActorBadSpider
    jsr FuncA_Objects_PositionActorShape  ; preserves X
    lda Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda Ram_ActorState_byte_arr, x
    add #$04
    and #$08
    bne @frame2
    @frame1:
    lda #kTileIdSpiderLegs1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdSpiderHead1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    bne @setFlags  ; unconditional
    @frame2:
    lda #kTileIdSpiderLegs2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdSpiderHead2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @setFlags:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
