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

.INCLUDE "actor.inc"
.INCLUDE "avatar.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "terrain.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT Func_HarmAvatar
.IMPORT Func_Noop
.IMPORT Func_Terrain_GetColumnPtrForTileIndex
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_ScrollXHi_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; First-tile-ID values that can be passed to FuncA_Objects_Draw2x2Actor for
;;; various actor animation frames.
kCrawlerFirstTileId1 = $94
kCrawlerFirstTileId2 = $98
kCrawlerFirstTileId3 = $9c

;;;=========================================================================;;;

Func_Actor_TickNone = Func_Noop
FuncA_Objects_DrawNoneActor = Func_Noop

.LINECONT +
.DEFINE ActorTickFuncs \
    Func_Actor_TickNone, \
    Func_Actor_TickCrawler
.LINECONT -

.LINECONT +
.DEFINE ActorDrawFuncs \
    FuncA_Objects_DrawNoneActor, \
    FuncA_Objects_DrawCrawlerActor
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "RAM_Actor"

;;; The type for each actor in the room (or eActor::None for an empty slot).
.EXPORT Ram_ActorType_eActor_arr
Ram_ActorType_eActor_arr: .res kMaxActors

;;; The current X/Y positions of each actor in the room, in room-space pixels.
.EXPORT Ram_ActorPosX_i16_0_arr, Ram_ActorPosX_i16_1_arr
Ram_ActorPosX_i16_0_arr: .res kMaxActors
Ram_ActorPosX_i16_1_arr: .res kMaxActors
.EXPORT Ram_ActorPosY_i16_0_arr, Ram_ActorPosY_i16_1_arr
Ram_ActorPosY_i16_0_arr: .res kMaxActors
Ram_ActorPosY_i16_1_arr: .res kMaxActors

;;; Type-specific state data for each actor in the room.
.EXPORT Ram_ActorState_byte_arr
Ram_ActorState_byte_arr: .res kMaxActors

;;; The object flags to apply for each actor in the room.  In particular, if
;;; bObj::FlipH is set, then the actor will face left instead of right.
.EXPORT Ram_ActorFlags_bObj_arr
Ram_ActorFlags_bObj_arr: .res kMaxActors

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; How far an actor's bounding box extends in each direction from the actor's
;;; position, indexed by eActor value.
.PROC Data_ActorBoundingBoxUp_u8_arr
    D_ENUM eActor
    d_byte None,    0
    d_byte Crawler, 0
    D_END
.ENDPROC
.PROC Data_ActorBoundingBoxDown_u8_arr
    D_ENUM eActor
    d_byte None,    0
    d_byte Crawler, 8
    D_END
.ENDPROC
.PROC Data_ActorBoundingBoxLeft_u8_arr
    D_ENUM eActor
    d_byte None,    0
    d_byte Crawler, 7
    D_END
.ENDPROC
.PROC Data_ActorBoundingBoxRight_u8_arr
    D_ENUM eActor
    d_byte None,    0
    d_byte Crawler, 7
    D_END
.ENDPROC

;;; Performs per-frame updates for each actor in the room.
.EXPORT Func_TickAllActors
.PROC Func_TickAllActors
    ldx #kMaxActors - 1
    @loop:
    jsr Func_TickOneActor  ; preserves X
    dex
    bpl @loop
    rts
.ENDPROC

;;; Performs per-frame updates for one actor.
;;; @param X The actor index.
;;; @preserve X
.PROC Func_TickOneActor
    lda Ram_ActorType_eActor_arr, x
    tay
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_0_arr: .lobytes ActorTickFuncs
_JumpTable_ptr_1_arr: .hibytes ActorTickFuncs
.ENDPROC

;;; Performs per-frame updates for a crawler actor.
;;; @param X The actor index.
;;; @preserve X
.PROC Func_Actor_TickCrawler
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
    jmp Func_Actor_HarmAvatarIfCollision  ; preserves X
_MoveLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    sub #1
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosX_i16_1_arr, x
_DetectCollision:
    jmp Func_Actor_HarmAvatarIfCollision  ; preserves X
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

;;; Checks if the actor is colliding with the player avatar; if so, harms the
;;; avatar.
;;; @param X The actor index.
;;; @preserve X
.PROC Func_Actor_HarmAvatarIfCollision
    ldy Ram_ActorType_eActor_arr, x
    ;; Check right side.
    lda Data_ActorBoundingBoxRight_u8_arr, y
    add #kAvatarBoundingBoxLeft
    adc Ram_ActorPosX_i16_0_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    cmp Zp_AvatarPosX_i16 + 1
    blt _NoHit
    bne @hitRight
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosX_i16 + 0
    ble _NoHit
    @hitRight:
    ;; Check left side.
    lda Data_ActorBoundingBoxLeft_u8_arr, y
    add #kAvatarBoundingBoxRight
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_0_arr, x
    sub Zp_Tmp1_byte
    sta Zp_Tmp1_byte
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    cmp Zp_AvatarPosX_i16 + 1
    blt @hitLeft
    bne _NoHit
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosX_i16 + 0
    bge _NoHit
    @hitLeft:
    ;; Check top side.
    lda Data_ActorBoundingBoxUp_u8_arr, y
    add #kAvatarBoundingBoxDown
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_0_arr, x
    sub Zp_Tmp1_byte
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_1_arr, x
    sbc #0
    cmp Zp_AvatarPosY_i16 + 1
    blt @hitTop
    bne _NoHit
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosY_i16 + 0
    bge _NoHit
    @hitTop:
    ;; Check bottom side.
    lda Data_ActorBoundingBoxDown_u8_arr, y
    add #kAvatarBoundingBoxUp
    adc Ram_ActorPosY_i16_0_arr, x
    sta Zp_Tmp1_byte
    lda Ram_ActorPosY_i16_1_arr, x
    adc #0
    cmp Zp_AvatarPosY_i16 + 1
    blt _NoHit
    bne @hitBottom
    lda Zp_Tmp1_byte
    cmp Zp_AvatarPosY_i16 + 0
    ble _NoHit
    @hitBottom:
_Hit:
    jmp Func_HarmAvatar  ; preserves X
_NoHit:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for all actors in the room.
.EXPORT FuncA_Objects_DrawAllActors
.PROC FuncA_Objects_DrawAllActors
    ldx #kMaxActors - 1
    @loop:
    jsr FuncA_Objects_DrawOneActor  ; preserves X
    dex
    bpl @loop
    rts
.ENDPROC

;;; Allocates and populates OAM slots (if any) for one actor.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_DrawOneActor
    lda Ram_ActorType_eActor_arr, x
    tay
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_0_arr: .lobytes ActorDrawFuncs
_JumpTable_ptr_1_arr: .hibytes ActorDrawFuncs
.ENDPROC

;;; Allocates and populates OAM slots for a crawler actor.
;;; @param X The actor index.
;;; @preserve X
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

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the three subsequent tile IDs.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_Draw2x2Actor
    pha  ; first tile ID
    ;; Calculate screen-space Y-position.
    lda Ram_ActorPosY_i16_0_arr, x
    sub Zp_PpuScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Ram_ActorPosY_i16_1_arr, x
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate screen-space X-position.
    lda Ram_ActorPosX_i16_0_arr, x
    sub Zp_PpuScrollX_u8
    sta Zp_ShapePosX_i16 + 0
    lda Ram_ActorPosX_i16_1_arr, x
    sbc Zp_ScrollXHi_u8
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate objects.
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    pla  ; first tile ID
    bcs _Done
    sta Zp_Tmp1_byte  ; first tile ID
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    and #bObj::FlipH
    bne _FacingLeft
_FacingRight:
    lda Zp_Tmp1_byte  ; first tile ID
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
_Done:
    rts
_FacingLeft:
    lda Zp_Tmp1_byte  ; first tile ID
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    rts
.ENDPROC

;;;=========================================================================;;;
