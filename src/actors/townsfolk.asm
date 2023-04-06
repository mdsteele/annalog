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
.INCLUDE "townsfolk.inc"

.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_InitActorWithState1
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; OBJ palette numbers to use for drawing various townsfolks NPC actors.
kPaletteObjAdult            = 0
kPaletteObjChild            = 1
kPaletteObjMermaid          = 0
kPaletteObjMermaidQueenBody = 0
kPaletteObjMermaidQueenHead = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a child NPC actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The bNpcChild param.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorNpcChild
.PROC FuncA_Room_InitActorNpcChild
    pha  ; bNpcChild bits
    and #bNpcChild::EnumMask  ; param: state byte
    ldy #eActor::NpcChild  ; param: actor type
    jsr Func_InitActorWithState1  ; preserves X
    pla  ; bNpcChild bits
    .assert bNpcChild::Pri = bProc::Negative, error
    bpl @done
    lda #bObj::Pri
    sta Ram_ActorFlags_bObj_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws an adult NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcAdult
.PROC FuncA_Objects_DrawActorNpcAdult
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_GetTownsfolkFlags  ; preserves X, returns A
    .assert kPaletteObjAdult = 0, error
    tay  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3TownsfolkShape  ; preserves X
.ENDPROC

;;; Draws a child NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcChild
.PROC FuncA_Objects_DrawActorNpcChild
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_GetTownsfolkFlags  ; preserves X, returns A
    .assert kPaletteObjChild <> 0, error
    ora #kPaletteObjChild
    tay  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; eNpcChild value
    mul #4
    ora #$80  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
.ENDPROC

;;; Draws a mermaid NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcMermaid
.PROC FuncA_Objects_DrawActorNpcMermaid
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    ;; Adjust vertical position (to make the mermaid bob in the water).
    stx T0  ; actor index
    lda Zp_FrameCounter_u8
    div #8
    add T0  ; actor index
    and #$07
    tay
    lda _VertOffset_u8_arr8, y  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    ;; Draw the actor.
    jsr FuncA_Objects_GetTownsfolkFlags  ; preserves X, returns A
    .assert kPaletteObjMermaid = 0, error
    tay  ; param: object flags
    lda Ram_ActorState1_byte_arr, x  ; param: first tile ID
    jmp FuncA_Objects_Draw2x3TownsfolkShape  ; preserves X
_VertOffset_u8_arr8:
    .byte 0, 0, 0, 1, 2, 2, 2, 1
.ENDPROC

;;; Draws a mermaid queen NPC actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorNpcMermaidQueen
.PROC FuncA_Objects_DrawActorNpcMermaidQueen
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
_TopHalf:
    jsr FuncA_Objects_GetTownsfolkFlags  ; preserves X, returns A
    .assert kPaletteObjMermaidQueenHead <> 0, error
    ora #kPaletteObjMermaidQueenHead
    tay  ; param: object flags
    lda #kTileIdMermaidQueenFirst  ; param: first tile ID
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X
_BottomHalf:
    lda #kTileHeightPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    ldy #kPaletteObjMermaidQueenBody  ; param: object flags
    lda #kTileIdMermaidQueenFirst + 4  ; param: first tile ID
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
.ENDPROC

;;; Returns the flags to use for drawing the specified townsfolk NPC actor.
;;; @param X The actor index.
;;; @return A The bObj flags (excluding palette) to use for drawing the NPC.
;;; @preserve X
.PROC FuncA_Objects_GetTownsfolkFlags
    lda Ram_ActorFlags_bObj_arr, x
    ;; If State2 is true ($ff), use ActorFlags unchanged.
    ldy Ram_ActorState2_byte_arr, x  ; "use flags" boolean
    bmi @return
    ;; Otherwise, only use the bObj::Pri bit from ActorFlags; ignore the flip
    ;; flags and make the actor face towards the avatar.
    and #bObj::Pri
    sta T0  ; bObj::Pri bit
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_ActorPosX_i16_0_arr, x
    lda Zp_AvatarPosX_i16 + 1
    sbc Ram_ActorPosX_i16_1_arr, x
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bpl @faceRight
    @faceLeft:
    lda #bObj::FlipH
    ora T0  ; bObj::Pri bit
    rts
    @faceRight:
    lda T0  ; bObj::Pri bit
    @return:
    rts
.ENDPROC

;;; Draws a 2x3-tile shape, using the given first tile ID and the five
;;; subsequent tile IDs.
;;; @prereq The shape position has been initialized.
;;; @param A The first tile ID.
;;; @param Y The object flags to use.
;;; @preserve X
.PROC FuncA_Objects_Draw2x3TownsfolkShape
    sta T2  ; first tile ID
    sty T3  ; object flags
_BottomThird:
    tya  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; preserves X and T2+, returns C and Y
    bcs @doneBottom
    lda T2  ; first tile ID
    adc #2  ; carry flag is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #3
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @doneBottom:
_TopTwoThirds:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    lda T3  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X and T2+, returns C and Y
    bcs @doneTop
    lda T2  ; first tile ID
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1  ; carry flag is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    adc #2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @doneTop:
    rts
.ENDPROC

;;;=========================================================================;;;
