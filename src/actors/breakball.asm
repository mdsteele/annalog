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
.INCLUDE "breakball.inc"

.IMPORT FuncA_Actor_GetRoomBlockRow
.IMPORT FuncA_Actor_GetRoomTileColumn
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetTerrainColumnPtrForTileIndex
.IMPORT Func_InitActorDefault
.IMPORT Func_InitActorProjFlamewave
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The OBJ palette number used for breakball projectile actors.
kPaletteObjBreakball = 1

;;; How many VBlank frames between breakball animation frames.
.DEFINE kProjBreakballAnimSlowdown 4

;;; How fast the breakball moves horizontally/vertically, in subpixels/frame.
kProjBreakballSpeed = $c0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a breakball projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A Zero if the breakball should move right, or bObj::FlipH for left.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorProjBreakball
.PROC FuncA_Room_InitActorProjBreakball
    sta Zp_Tmp1_byte  ; horz flag
    ldy #eActor::ProjBreakball  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X and Zp_Tmp*
_InitVelY:
    lda #kProjBreakballSpeed
    ldy #0
    sta Ram_ActorVelY_i16_0_arr, x
    tya
    sta Ram_ActorVelY_i16_1_arr, x
_InitVelX:
    bit Zp_Tmp1_byte  ; horz flag
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @left
    @right:
    lda #kProjBreakballSpeed
    bne @setXVel  ; unconditional
    @left:
    dey  ; now Y is $ff
    lda #<-kProjBreakballSpeed
    @setXVel:
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a breakball projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjBreakball
.PROC FuncA_Actor_TickProjBreakball
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    jsr FuncA_Actor_ProjBreakball_HorzBounce  ; preserves X
    jsr FuncA_Actor_ProjBreakball_HitFloor  ; preserves X
    ;; TODO: bounce off platform sides?
    ;; TODO: bounce off platform floor
    rts
.ENDPROC

;;; If the breakball is hitting the side of a terrain wall, bounce it
;;; horizontally.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_ProjBreakball_HorzBounce
    lda Ram_ActorVelX_i16_1_arr, x
    bpl _CheckRightSide
_CheckLeftSide:
    lda Ram_ActorPosX_i16_0_arr, x
    sub #kProjBreakballRadius
    tay
    lda Ram_ActorPosX_i16_1_arr, x
    sbc #0
    jmp _BounceHorzIfTerrainCollision
_CheckRightSide:
    lda Ram_ActorPosX_i16_0_arr, x
    add #kProjBreakballRadius
    tay
    lda Ram_ActorPosX_i16_1_arr, x
    adc #0
_BounceHorzIfTerrainCollision:
    ;; Get the room tile column for the side of the breakball that we're
    ;; checking, storing it in A.
    sta Zp_Tmp1_byte
    tya
    .assert kTileWidthPx = (1 << 3), error
    .repeat 3
    lsr Zp_Tmp1_byte
    ror a
    .endrepeat
    ;; Get the terrain for that tile column.
    stx Zp_Tmp1_byte  ; actor index
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte  ; actor index
    ;; Check the terrain block, and set C if the terrain is solid.
    jsr FuncA_Actor_GetRoomBlockRow  ; preserves X, returns Y
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    ;; If the terrain is solid, bounce the breakball horizontally.
    bcc @noBounce
    lda #0
    sub Ram_ActorVelX_i16_0_arr, x
    sta Ram_ActorVelX_i16_0_arr, x
    lda #0
    sbc Ram_ActorVelX_i16_1_arr, x
    sta Ram_ActorVelX_i16_1_arr, x
    @noBounce:
    rts
.ENDPROC

;;; If the breakball is hitting the top of a terrain floor, explode it into
;;; flame waves.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_ProjBreakball_HitFloor
    lda Ram_ActorVelY_i16_1_arr, x
    bmi _Return
    ;; Get the terrain for the actor's tile column.
    jsr FuncA_Actor_GetRoomTileColumn  ; preserves X, returns A
    stx Zp_Tmp1_byte  ; actor index
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte  ; actor index
    ;; Get the room pixel Y-position of the bottom of the breakball, storing
    ;; the low byte in Y and the high byte in A.
    lda Ram_ActorPosY_i16_0_arr, x
    add #kProjBreakballRadius
    tay
    lda Ram_ActorPosY_i16_1_arr, x
    adc #0
    ;; Get the room block row for the bottom of the breakball, storing it in Y.
    sta Zp_Tmp1_byte
    tya
    .assert kBlockHeightPx = (1 << 4), error
    .repeat 4
    lsr Zp_Tmp1_byte
    ror a
    .endrepeat
    tay
    ;; Check the terrain block, and set C if the terrain is solid.
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType
    ;; If the terrain is solid, explode the breakball.
    bcc _Return
_Explode:
    lda Ram_ActorPosY_i16_0_arr, x
    and #$f0
    ora #$08
    sta Ram_ActorPosY_i16_0_arr, x
    txa  ; breakball actor index
    pha  ; breakball actor index
    tay  ; breakball actor index
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @doneFirstFlamewave
    lda Ram_ActorPosX_i16_0_arr, y
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosX_i16_1_arr, y
    sta Ram_ActorPosX_i16_1_arr, x
    lda Ram_ActorPosY_i16_0_arr, y
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_ActorPosY_i16_1_arr, y
    sta Ram_ActorPosY_i16_1_arr, x
    lda #0  ; param: direction (0 = right)
    jsr Func_InitActorProjFlamewave
    @doneFirstFlamewave:
    pla  ; breakball actor index
    tax  ; param: actor index
    lda #bObj::FlipH  ; param: direction (FlipH = left)
    jmp Func_InitActorProjFlamewave  ; preserves X
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a breakball projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjBreakball
.PROC FuncA_Objects_DrawActorProjBreakball
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda #kPaletteObjBreakball  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda Zp_FrameCounter_u8
    div #kProjBreakballAnimSlowdown
    and #$01
    add #kTileIdObjBreakballFirst
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kPaletteObjBreakball | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kPaletteObjBreakball | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjBreakball | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
