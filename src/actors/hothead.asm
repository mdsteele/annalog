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
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../terrain.inc"
.INCLUDE "hothead.inc"

.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_GetRoomTileColumn
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_GetTerrainColumnPtrForTileIndex
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The OBJ palette number used for hothead baddie actors.
kPaletteObjHothead = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a horizontally-crawling beetle baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadBeetleHorz
.PROC FuncA_Actor_TickBadBeetleHorz
    jsr FuncA_Actor_CrawlHorz  ; preserves X, sets C if baddie must turn
    bcc @noTurn
    lda #eActor::BadBeetleVert
    sta Ram_ActorType_eActor_arr, x
    @noTurn:
    jmp FuncA_Actor_HarmAvatarIfCollision
.ENDPROC

;;; Performs per-frame updates for a vertically-crawling beetle baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadBeetleVert
.PROC FuncA_Actor_TickBadBeetleVert
    jsr FuncA_Actor_CrawlVert  ; preserves X, sets C if baddie must turn
    bcc @noTurn
    lda #eActor::BadBeetleHorz
    sta Ram_ActorType_eActor_arr, x
    @noTurn:
    jmp FuncA_Actor_HarmAvatarIfCollision
.ENDPROC

;;; Performs per-frame updates for a horizontally-crawling hothead baddie
;;; actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadHotheadHorz
.PROC FuncA_Actor_TickBadHotheadHorz
    jsr FuncA_Actor_CrawlHorz  ; preserves X, sets C if baddie must turn
    bcc @noTurn
    lda #eActor::BadHotheadVert
    sta Ram_ActorType_eActor_arr, x
    @noTurn:
    ;; TODO: if upside-down, sometimes drop fireballs
    jmp FuncA_Actor_HarmAvatarIfCollision
.ENDPROC

;;; Performs per-frame updates for a vertically-crawling hothead baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadHotheadVert
.PROC FuncA_Actor_TickBadHotheadVert
    jsr FuncA_Actor_CrawlVert  ; preserves X, sets C if baddie must turn
    bcc @noTurn
    lda #eActor::BadHotheadHorz
    sta Ram_ActorType_eActor_arr, x
    @noTurn:
    jmp FuncA_Actor_HarmAvatarIfCollision
.ENDPROC

;;; Performs per-frame crawling updates for a horizontally-crawling beetle or
;;; hothead baddie.
;;; @param X The actor index.
;;; @return C Set if the baddie type should switch from horz to vert.
;;; @preserve X
.PROC FuncA_Actor_CrawlHorz
    ;; Only move every other frame.
    lda Ram_ActorState1_byte_arr, x
    eor #$80
    sta Ram_ActorState1_byte_arr, x
    bmi _NoTurn
    ;; Check if the baddie is moving right or left.
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne _MoveLeft
_MoveRight:
    inc Ram_ActorPosX_i16_0_arr, x
    bne _CheckForTurn
    inc Ram_ActorPosX_i16_1_arr, x
    jmp _CheckForTurn
_MoveLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    bne @noBorrow
    dec Ram_ActorPosX_i16_1_arr, x
    @noBorrow:
    dec Ram_ActorPosX_i16_0_arr, x
_CheckForTurn:
    lda Ram_ActorPosX_i16_0_arr, x
    and #$0f
    beq _CheckForOuterCorner
    cmp #$08
    beq _CheckForInnerCorner
    bne _NoTurn  ; unconditional
_CheckForInnerCorner:
    ;; TODO: check if we need to turn
    jmp _NoTurn
_CheckForOuterCorner:
    ;; Compute the room tile column index for the center of the baddie, storing
    ;; it in Y.
    jsr FuncA_Actor_GetRoomTileColumn  ; preserves X, returns A
    tay
    ;; Compute the room tile column just in front the baddie.   Note that at
    ;; this point, the baddie's Y-position is zero mod kBlockHeightPx.
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @facingRight
    @facingLeft:
    dey
    @facingRight:
    ;; Get the terrain for the tile column we're checking.
    stx Zp_Tmp1_byte
    tya  ; param: room tile column index
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte
    ;; Compute the room block row at the baddie's feet.
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bmi @upsideDown
    @rightSideUp:
    iny
    bne @doneAdjustBlockRow  ; unconditional
    @upsideDown:
    dey
    @doneAdjustBlockRow:
    ;; If there's still a solid floor/ceiling for the baddie to continue on,
    ;; then no need to turn.
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    blt _TurnAtOuterCorner
_NoTurn:
    clc
    rts
_TurnAtOuterCorner:
    ;; Adjust the baddie's vertical position.
    lda Ram_ActorFlags_bObj_arr, x
    sta Zp_Tmp1_byte  ; actor flags
    .assert bObj::FlipV = bProc::Negative, error
    bmi @upsideDown
    @rightSideUp:
    lda Ram_ActorPosY_i16_0_arr, x
    add #kTileHeightPx
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_ActorPosY_i16_1_arr, x
    adc #0
    sta Ram_ActorPosY_i16_1_arr, x
    jmp @doneAdjustVert
    @upsideDown:
    lda Ram_ActorPosY_i16_0_arr, x
    sub #kTileHeightPx
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_ActorPosY_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosY_i16_1_arr, x
    @doneAdjustVert:
    ;; Adjust the baddie's horizontal position.
    bit Zp_Tmp1_byte  ; actor flags
    .assert bObj::FlipH = bProc::Overflow, error
    bvc @facingRight
    @facingLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    sub #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosX_i16_1_arr, x
    jmp @doneAdjustHorz
    @facingRight:
    lda Ram_ActorPosX_i16_0_arr, x
    add #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    @doneAdjustHorz:
    ;; Indicate that the baddie should switch to vertical mode.
    sec
    rts
.ENDPROC

;;; Performs per-frame crawling updates for a vertically-crawling beetle or
;;; hothead baddie.
;;; @param X The actor index.
;;; @return C Set if the baddie type should switch from horz to vert.
;;; @preserve X
.PROC FuncA_Actor_CrawlVert
    ;; Only move every other frame.
    lda Ram_ActorState1_byte_arr, x
    eor #$01
    sta Ram_ActorState1_byte_arr, x
    beq _NoTurn
    ;; Check if the baddie is moving down or up.
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bmi _MoveUp
_MoveDown:
    inc Ram_ActorPosY_i16_0_arr, x
    bne _CheckForTurn
    inc Ram_ActorPosY_i16_1_arr, x
    jmp _CheckForTurn
_MoveUp:
    lda Ram_ActorPosY_i16_0_arr, x
    bne @noBorrow
    dec Ram_ActorPosY_i16_1_arr, x
    @noBorrow:
    dec Ram_ActorPosY_i16_0_arr, x
_CheckForTurn:
    lda Ram_ActorPosY_i16_0_arr, x
    and #$0f
    beq _CheckForOuterCorner
    cmp #$08
    beq _CheckForInnerCorner
    bne _NoTurn  ; unconditional
_CheckForInnerCorner:
    ;; TODO: check if we need to turn
    jmp _NoTurn
_CheckForOuterCorner:
    ;; Compute the room tile column index for the center of the baddie, storing
    ;; it in Y.
    jsr FuncA_Actor_GetRoomTileColumn  ; preserves X, returns A
    tay
    ;; If the baddie is to the right of the vertical wall, decrement Y twice to
    ;; get a tile column for the wall it's on.  If instead the baddie is to the
    ;; left of the wall, increment Y twice.
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @facingRight
    @facingLeft:
    iny
    iny
    bne @doneFacing  ; unconditional
    @facingRight:
    dey
    dey
    @doneFacing:
    ;; Get the terrain for the tile column we're checking.
    stx Zp_Tmp1_byte
    tya  ; param: room tile column index
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte
    ;; Compute the room block row just in front (above/below) of the baddie.
    ;; Note that at this point, the baddie's Y-position is zero mod
    ;; kBlockHeightPx.
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bpl @movingDown
    @movingUp:
    dey
    @movingDown:
    ;; If there's still a solid vertical wall for the baddie to continue on,
    ;; then no need to turn.
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    blt _TurnAtOuterCorner
_NoTurn:
    clc
    rts
_TurnAtOuterCorner:
    ;; Adjust the baddie's vertical position.
    lda Ram_ActorFlags_bObj_arr, x
    sta Zp_Tmp1_byte  ; actor flags
    .assert bObj::FlipV = bProc::Negative, error
    bpl @movingDown
    @movingUp:
    lda Ram_ActorPosY_i16_0_arr, x
    sub #kTileHeightPx
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_ActorPosY_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosY_i16_1_arr, x
    jmp @doneAdjustVert
    @movingDown:
    lda Ram_ActorPosY_i16_0_arr, x
    add #kTileHeightPx
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_ActorPosY_i16_1_arr, x
    adc #0
    sta Ram_ActorPosY_i16_1_arr, x
    @doneAdjustVert:
    ;; Adjust the baddie's horizontal position.
    bit Zp_Tmp1_byte  ; actor flags
    .assert bObj::FlipH = bProc::Overflow, error
    bvc @facingRight
    @facingLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    add #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    jmp @doneAdjustHorz
    @facingRight:
    lda Ram_ActorPosX_i16_0_arr, x
    sub #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosX_i16_1_arr, x
    @doneAdjustHorz:
    ;; Switch the baddie to crawling on a horizontal wall.
    lda Zp_Tmp1_byte  ; actor flags
    eor #bObj::FlipHV
    sta Ram_ActorFlags_bObj_arr, x
    sec
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a horizontally-crawling beetle baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadBeetleHorz
.PROC FuncA_Objects_DrawActorBadBeetleHorz
    lda #kTileIdObjBeetleHorzFirst  ; param: first tile ID
    jmp FuncA_Objects_DrawActorBadHotheadShape  ; preserves X
.ENDPROC

;;; Draws a vertically-crawling beetle baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadBeetleVert
.PROC FuncA_Objects_DrawActorBadBeetleVert
    lda #kTileIdObjBeetleVertFirst  ; param: first tile ID
    jmp FuncA_Objects_DrawActorBadHotheadShape  ; preserves X
.ENDPROC

;;; Draws a horizontally-crawling hothead baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadHotheadHorz
.PROC FuncA_Objects_DrawActorBadHotheadHorz
    lda #kTileIdObjHotheadHorzFirst  ; param: first tile ID
    jsr FuncA_Objects_DrawActorBadHotheadShape  ; preserves X, returns C and Y
    bcs @done
    ;; As part of the animation cycle, sometimes flip the flames horizontally.
    lda Zp_FrameCounter_u8
    and #$10
    beq @done
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    pha
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    pla
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;; Draws a vertically-crawling hothead baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadHotheadVert
.PROC FuncA_Objects_DrawActorBadHotheadVert
    lda #kTileIdObjHotheadVertFirst  ; param: first tile ID
    jsr FuncA_Objects_DrawActorBadHotheadShape  ; preserves X, returns C and Y
    bcs @done
    ;; As part of the animation cycle, sometimes flip the flames vertically.
    lda Zp_FrameCounter_u8
    and #$10
    beq @done
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    pha
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    pla
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;; Helper function for drawing hothead baddie actors.
;;; @param A The first tile ID to use.
;;; @param X The actor index.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.PROC FuncA_Objects_DrawActorBadHotheadShape
    sta Zp_Tmp1_byte  ; first tile ID
    lda Zp_FrameCounter_u8
    and #$08
    lsr a
    .assert kTileIdObjBeetleHorzFirst .mod $08 = 0, error
    .assert kTileIdObjBeetleVertFirst .mod $08 = 0, error
    .assert kTileIdObjHotheadHorzFirst .mod $08 = 0, error
    .assert kTileIdObjHotheadVertFirst .mod $08 = 0, error
    ora Zp_Tmp1_byte  ; first tile ID
    ldy #kPaletteObjHothead  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X, returns C and Y
.ENDPROC

;;;=========================================================================;;;
