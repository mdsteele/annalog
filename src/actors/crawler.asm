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
.INCLUDE "../tileset.inc"
.INCLUDE "crawler.inc"

.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarAboveOrBelow
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_MoveForwardOnePixel
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetTerrainColumnPtrForPointX
.IMPORT Func_InitActorProjEmber
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_PlaySfxShootFire
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; The minimum time between embers for hothead baddie actors.
kHotheadEmberCooldownFrames = 32

;;; The initial downward speed of a dropped ember, in pixels per frame.
kHotheadEmberInitSpeed = 1

;;; The OBJ palette number used for beetle/hothead baddie actors.
kPaletteObjCrawler = 1

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
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
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
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a horizontally-crawling hothead baddie
;;; actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadHotheadHorz
.PROC FuncA_Actor_TickBadHotheadHorz
    jsr FuncA_Actor_HotheadCooldown  ; preserves X
    ;; Don't drop embers when right-side up.
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bpl @done
    jsr FuncA_Actor_MaybeDropEmber  ; preserves X
    @done:
_Crawl:
    jsr FuncA_Actor_CrawlHorz  ; preserves X, sets C if baddie must turn
    bcc @noTurn
    lda #eActor::BadHotheadVert
    sta Ram_ActorType_eActor_arr, x
    @noTurn:
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a vertically-crawling hothead baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadHotheadVert
.PROC FuncA_Actor_TickBadHotheadVert
    jsr FuncA_Actor_HotheadCooldown  ; preserves X
    jsr FuncA_Actor_MaybeDropEmber  ; preserves X
    jsr FuncA_Actor_CrawlVert  ; preserves X, sets C if baddie must turn
    bcc @noTurn
    lda #eActor::BadHotheadHorz
    sta Ram_ActorType_eActor_arr, x
    @noTurn:
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
.ENDPROC

;;; Decrements a hothead baddie's ember cooldown, if it is nonzero.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_HotheadCooldown
    lda Ram_ActorState2_byte_arr, x  ; ember cooldown
    beq @done
    dec Ram_ActorState2_byte_arr, x  ; ember cooldown
    @done:
    rts
.ENDPROC

;;; Checks if the hothead baddie should drop an ember projectile, and does so
;;; if it should.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_MaybeDropEmber
    ;; Don't drop an ember unless the cooldown is zero.
    lda Ram_ActorState2_byte_arr, x  ; ember cooldown
    bne @done
    ;; Don't drop an ember if the player avatar isn't horizontally nearby.
    lda #15  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc @done
    ;; Don't drop an ember if the player avatar is above the hothead.
    jsr FuncA_Actor_IsAvatarAboveOrBelow  ; preserves X, returns N
    bmi @done
    ;; Set the starting position for the ember.
    jsr Func_SetPointToActorCenter  ; preserves X
    jsr _AdjustPoint
    ;; Drop an ember.
    stx T0  ; hothead actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @noEmber
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    jsr Func_InitActorProjEmber  ; preserves X and T0+
    lda #kHotheadEmberInitSpeed
    sta Ram_ActorVelY_i16_1_arr, x
    ldx T0  ; hothead actor index
    lda #kHotheadEmberCooldownFrames
    sta Ram_ActorState2_byte_arr, x  ; ember cooldown
    jmp Func_PlaySfxShootFire  ; preserves X
    @noEmber:
    ldx T0  ; hothead actor index
    @done:
    rts
_AdjustPoint:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::BadHotheadVert
    bne @adjustSlightlyDown
    lda #8  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne @adjustRight
    @adjustLeft:
    lda #4
    jmp Func_MovePointLeftByA  ; preserves X
    @adjustRight:
    lda #4
    jmp Func_MovePointRightByA  ; preserves X
    @adjustSlightlyDown:
    lda #1  ; param: offset
    jmp Func_MovePointDownByA  ; preserves X
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
    jsr FuncA_Actor_MoveForwardOnePixel  ; preserves X
_CheckForTurn:
    ;; Check the baddie's X-position mod kBlockWidthPx.
    lda Ram_ActorPosX_i16_0_arr, x
    .assert kBlockWidthPx = $10, error
    and #$0f
    beq _CheckForOuterCorner
    cmp #$08
    beq _CheckForInnerCorner
    bne _NoTurn  ; unconditional
_CheckForInnerCorner:
    ;; If we were going to support crawling around inner corners, this is where
    ;; we'd do it.  But it turns out that's not needed anywhere in the game.
    jmp _NoTurn
_CheckForOuterCorner:
    ;; Get the terrain column in front of the baddie.  Note that at this point,
    ;; the baddie's X-position is zero mod kBlockWidthPx.
    lda #kTileWidthPx  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_GetTerrainColumnPtrForPointX  ; preserves X
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
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    blt _TurnAtOuterCorner
_NoTurn:
    clc
    rts
_TurnAtOuterCorner:
    ;; Adjust the baddie's vertical position.
    lda Ram_ActorFlags_bObj_arr, x
    sta T0  ; actor flags
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
    bit T0  ; actor flags
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
    ;; Check the baddie's Y-position mod kBlockHeightPx.
    lda Ram_ActorPosY_i16_0_arr, x
    .assert kBlockHeightPx = $10, error
    and #$0f
    beq _CheckForOuterCorner
    cmp #$08
    beq _CheckForInnerCorner
    bne _NoTurn  ; unconditional
_CheckForInnerCorner:
    ;; If we were going to support crawling around inner corners, this is where
    ;; we'd do it.  But it turns out that's not needed anywhere in the game.
    jmp _NoTurn
_CheckForOuterCorner:
    ;; Get the terrain column for the wall the baddie is crawling on.
    lda #<-kBlockWidthPx  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_GetTerrainColumnPtrForPointX  ; preserves X
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
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    blt _TurnAtOuterCorner
_NoTurn:
    clc
    rts
_TurnAtOuterCorner:
    ;; Adjust the baddie's vertical position.
    lda Ram_ActorFlags_bObj_arr, x
    sta T0  ; actor flags
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
    bit T0  ; actor flags
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
    lda T0  ; actor flags
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
    lda #kTileIdObjBadBeetleHorzFirst  ; param: first tile ID
    jmp FuncA_Objects_DrawActorBadCrawlerShape  ; preserves X
.ENDPROC

;;; Draws a vertically-crawling beetle baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadBeetleVert
.PROC FuncA_Objects_DrawActorBadBeetleVert
    lda #kTileIdObjBadBeetleVertFirst  ; param: first tile ID
    jmp FuncA_Objects_DrawActorBadCrawlerShape  ; preserves X
.ENDPROC

;;; Draws a horizontally-crawling hothead baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadHotheadHorz
.PROC FuncA_Objects_DrawActorBadHotheadHorz
    lda #kTileIdObjBadHotheadHorzFirst  ; param: first tile ID
    jsr FuncA_Objects_DrawActorBadCrawlerShape  ; preserves X, returns C and Y
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
    lda #kTileIdObjBadHotheadVertFirst  ; param: first tile ID
    jsr FuncA_Objects_DrawActorBadCrawlerShape  ; preserves X, returns C and Y
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

;;; Helper function for drawing beetle/hothead baddie actors.
;;; @param A The first tile ID to use.
;;; @param X The actor index.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.PROC FuncA_Objects_DrawActorBadCrawlerShape
    sta T0  ; first tile ID
    lda Zp_FrameCounter_u8
    and #$08
    lsr a
    .assert kTileIdObjBadBeetleHorzFirst .mod $08 = 0, error
    .assert kTileIdObjBadBeetleVertFirst .mod $08 = 0, error
    .assert kTileIdObjBadHotheadHorzFirst .mod $08 = 0, error
    .assert kTileIdObjBadHotheadVertFirst .mod $08 = 0, error
    ora T0  ; first tile ID
    ldy #kPaletteObjCrawler  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X, returns C and Y
.ENDPROC

;;;=========================================================================;;;
