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
.INCLUDE "fish.inc"

.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_GetRoomTileColumn
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_Terrain_GetColumnPtrForTileIndex
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; How fast the fish swims, in subpixels per frame.
kFishSpeed = $0130

;;; First-tile-ID values that can be passed to FuncA_Objects_Draw2x2Actor for
;;; various actor animation frames.
kFishFirstTileId1 = kTileIdFishFirst + 0
kFishFirstTileId2 = kTileIdFishFirst + 4
kFishFirstTileId3 = kTileIdFishFirst + 8

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a fish baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadFish
.PROC FuncA_Actor_TickBadFish
    ;; Compute the room tile column index for the center of the fish, storing
    ;; it in Y.
    jsr FuncA_Actor_GetRoomTileColumn  ; preserves X, returns A
    tay
    ;; If the fish is facing right, add 2 to the tile column (so as to check
    ;; the block column to the right of the fish); if the fish is facing left,
    ;; subtract 2 (so as to check the block column to the left of the fish).
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @facingLeft
    @facingRight:
    iny
    iny
    bne @doneFacing  ; unconditional
    @facingLeft:
    dey
    dey
    @doneFacing:
    ;; Get the terrain for the tile column we're checking.
    stx Zp_Tmp1_byte  ; actor index
    tya  ; param: room tile column index
    jsr Func_Terrain_GetColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte  ; actor index
    ;; Check the terrain block just in front of the fish.  If it's solid,
    ;; the fish has to turn around.
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    blt @continueForward
    ;; Make the fish face the opposite direction.
    @turnAround:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    @continueForward:
_SetVelocity:
    ;; TODO: Move fast if player avatar is ahead, move slower otherwise.
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @facingLeft
    @facingRight:
    lda #<kFishSpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kFishSpeed
    sta Ram_ActorVelX_i16_1_arr, x
    bpl @done  ; unconditional
    @facingLeft:
    lda #<($ffff & -kFishSpeed)
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>($ffff & -kFishSpeed)
    sta Ram_ActorVelX_i16_1_arr, x
    @done:
    inc Ram_ActorState_byte_arr, x
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a fish baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadFish
.PROC FuncA_Objects_DrawActorBadFish
    lda Ram_ActorState_byte_arr, x
    div #8
    and #$03
    tay
    lda _TileIds_u8_arr4, y  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr4:
    .byte kFishFirstTileId1, kFishFirstTileId2
    .byte kFishFirstTileId3, kFishFirstTileId2
.ENDPROC

;;;=========================================================================;;;
