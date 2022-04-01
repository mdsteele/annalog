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
.INCLUDE "ppu.inc"
.INCLUDE "terrain.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeUpOneTile
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

;;; How fast a toddler walks, in pixels per frame.
kToddlerSpeed = 1
;;; How long a toddler walks before turning around, in frames.
kToddlerTime = 100

;;;=========================================================================;;;

Func_Actor_TickNone = Func_Noop
FuncA_Objects_DrawNoneActor = Func_Noop

.LINECONT +
.DEFINE ActorTickFuncs \
    Func_Actor_TickNone, \
    Func_Actor_TickAdult, \
    Func_Actor_TickChild, \
    Func_Actor_TickCrawler, \
    Func_Actor_TickToddler
.LINECONT -

.LINECONT +
.DEFINE ActorDrawFuncs \
    FuncA_Objects_DrawNoneActor, \
    FuncA_Objects_DrawAdultActor, \
    FuncA_Objects_DrawChildActor, \
    FuncA_Objects_DrawCrawlerActor, \
    FuncA_Objects_DrawToddlerActor
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
    d_byte Adult,  13
    d_byte Child,   7
    d_byte Crawler, 0
    d_byte Toddler, 4
    D_END
.ENDPROC
.PROC Data_ActorBoundingBoxDown_u8_arr
    D_ENUM eActor
    d_byte None,    0
    d_byte Adult,   8
    d_byte Child,   8
    d_byte Crawler, 8
    d_byte Toddler, 8
    D_END
.ENDPROC
.PROC Data_ActorBoundingBoxLeft_u8_arr
    D_ENUM eActor
    d_byte None,    0
    d_byte Adult,   5
    d_byte Child,   5
    d_byte Crawler, 7
    d_byte Toddler, 3
    D_END
.ENDPROC
.PROC Data_ActorBoundingBoxRight_u8_arr
    D_ENUM eActor
    d_byte None,    0
    d_byte Adult,   5
    d_byte Child,   5
    d_byte Crawler, 7
    d_byte Toddler, 4
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

;;; Performs per-frame updates for an adult townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.PROC Func_Actor_TickAdult
    .assert * = Func_Actor_TickChild, error, "fallthrough"
.ENDPROC

;;; Performs per-frame updates for a child townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.PROC Func_Actor_TickChild
    lda Ram_ActorPosX_i16_1_arr, x
    cmp Zp_AvatarPosX_i16 + 1
    blt @faceRight
    bne @faceLeft
    lda Ram_ActorPosX_i16_0_arr, x
    cmp Zp_AvatarPosX_i16 + 0
    blt @faceRight
    @faceLeft:
    lda #bObj::FlipH
    bne @setFlags  ; unconditional
    @faceRight:
    lda #0
    @setFlags:
    sta Ram_ActorFlags_bObj_arr, x
    rts
.ENDPROC

;;; Performs per-frame updates for a crawler enemy actor.
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

;;; Performs per-frame updates for a toddler townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.PROC Func_Actor_TickToddler
    dec Ram_ActorState_byte_arr, x
    bne @move
    @turnAround:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    lda #kToddlerTime
    sta Ram_ActorState_byte_arr, x
    @move:
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @moveLeft
    @moveRight:
    lda Ram_ActorPosX_i16_0_arr, x
    add #kToddlerSpeed
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    rts
    @moveLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    sub #kToddlerSpeed
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosX_i16_1_arr, x
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

;;; Allocates and populates OAM slots for an adult townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_DrawAdultActor
    lda Ram_ActorState_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3Actor  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for a child townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_DrawChildActor
    lda Ram_ActorState_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
.ENDPROC

;;; Allocates and populates OAM slots for a crawler enemy actor.
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

;;; Allocates and populates OAM slots for a toddler townsfolk actor.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_DrawToddlerActor
    lda Ram_ActorState_byte_arr, x
    and #$08
    beq @draw
    lda #$02
    @draw:
    ora #$80
    jmp FuncA_Objects_Draw1x2Actor  ; preserves X
.ENDPROC

;;; Sets Zp_ShapePosX_i16 and Zp_ShapePosY_i16 to the screen-space position of
;;; the specified actor.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_PositionActorShape
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
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the subsequent tile ID.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_Draw1x2Actor
    pha  ; first tile ID
    jsr FuncA_Objects_PositionActorShape  ; preserves X
    ;; Adjust X-position.
    lda Zp_ShapePosX_i16 + 0
    sub #kTileWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc #0
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate lower object.
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X
    bcs @doneLower
    pla  ; first tile ID
    pha  ; first tile ID
    adc #1  ; carry bit is already clear
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @doneLower:
    ;; Allocate upper object.
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X
    pla  ; first tile ID
    bcs @doneUpper
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda Ram_ActorFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @doneUpper:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the three subsequent tile IDs.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_Draw2x2Actor
    pha  ; first tile ID
    jsr FuncA_Objects_PositionActorShape  ; preserves X
    lda Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    pla  ; first tile ID
    bcs @done
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for the specified actor, using the given
;;; first tile ID and the five subsequent tile IDs.
;;; @param A The first tile ID.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_Draw2x3Actor
    pha  ; first tile ID
    jsr FuncA_Objects_PositionActorShape  ; preserves X
_BottomThird:
    lda Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; preserves X, returns C and Y
    bcs @doneBottom
    pla  ; first tile ID
    pha  ; first tile ID
    add #2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #3
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @doneBottom:
_TopTwoThirds:
    jsr FuncA_Objects_MoveShapeUpOneTile
    lda Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    pla  ; first tile ID
    bcs @doneTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @doneTop:
    rts
.ENDPROC

;;;=========================================================================;;;
