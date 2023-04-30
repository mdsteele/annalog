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
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"
.INCLUDE "gate.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; How far gate platforms rise up when opened, in pixels.
kGateRiseDistancePx = $1d

;;; How fast gate platforms move when being open/shut, in pixels per frame.
kGateOpenSpeed = 1
kGateShutSpeed = 3

;;; OBJ tile IDs for drawing prison gate platforms.
kTileIdObjGateLeft  = kTileIdObjGateFirst + 0
kTileIdObjGateRight = kTileIdObjGateFirst + 1
kTileIdObjGateLock  = kTileIdObjGateFirst + 2

;;; The OBJ palette number to use for drawing prison gate platforms.
kPaletteObjGate = 0

;;; The bObj value to use for objects for prison gate platforms.
kGateObjFlags = kPaletteObjGate | bObj::Pri

;;;=========================================================================;;;

.SEGMENT "PRGC_Prison"

;;; Moves a gate platform from its fully shut position to its fully open
;;; position, and sets the specified lever's value to 1.  This should be called
;;; from a room's Init or Enter function.
;;; @param X The gate platform index.
;;; @param Y The byte offset into Zp_RoomState for the gate's lever target.
.EXPORT FuncC_Prison_OpenGateAndFlipLever
.PROC FuncC_Prison_OpenGateAndFlipLever
    ;; Flip the lever.
    lda #1
    sta Zp_RoomState, y
    ;; Open the gate.
    lda #<-kGateRiseDistancePx  ; param: move delta (signed)
    jmp Func_MovePlatformVert
.ENDPROC

;;; Performs per-frame updates for a gate platform.
;;; @param A The room block row for the top of the gate when it's shut.
;;; @param X The gate platform index.
;;; @param Y Zero if the gate should shut, nonzero if it should open.
;;; @return Z Cleared if the platform moved, set if it didn't.
.EXPORT FuncC_Prison_TickGatePlatform
.PROC FuncC_Prison_TickGatePlatform
    ;; Store the top of the gate's shut position in Zp_PointY_i16.
    .assert kBlockHeightPx = (1 << 4), error
    .assert kTallRoomHeightBlocks << 4 < $200, error
    .repeat 4
    asl a
    .endrepeat
    sta Zp_PointY_i16 + 0
    lda #0
    rol a
    sta Zp_PointY_i16 + 1
    ;; Check if the gate should open or shut.
    tya
    bne _Open
_Shut:
    lda #kGateShutSpeed  ; param: move speed
    jmp Func_MovePlatformTopTowardPointY  ; returns Z
_Open:
    lda Zp_PointY_i16 + 0
    sub #kGateRiseDistancePx
    sta Zp_PointY_i16 + 0
    lda Zp_PointY_i16 + 1
    sbc #0
    sta Zp_PointY_i16 + 1
    lda #kGateOpenSpeed  ; param: move speed
    jmp Func_MovePlatformTopTowardPointY  ; returns Z
.ENDPROC

;;; Draws a prison gate.
;;; @prereq PRGA_Objects is loaded.
;;; @param X The gate platform index.
.EXPORT FuncC_Prison_DrawGatePlatform
.PROC FuncC_Prison_DrawGatePlatform
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
_LeftSide:
    ldx #3
    bne @begin  ; unconditional
    @loop:
    jsr FuncA_Objects_MoveShapeDownOneTile
    @begin:
    ldy #kGateObjFlags  ; param: object flags
    lda #kTileIdObjGateLeft  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    dex
    bpl @loop
_RightSide:
    jsr FuncA_Objects_MoveShapeRightOneTile
    ldx #3
    bne @begin  ; unconditional
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile
    @begin:
    ldy #kGateObjFlags  ; param: object flags
    lda _RightTileIds_u8_arr, x  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    dex
    bpl @loop
    rts
_RightTileIds_u8_arr:
    .byte kTileIdObjGateRight, kTileIdObjGateRight
    .byte kTileIdObjGateLock, kTileIdObjGateRight
.ENDPROC

;;;=========================================================================;;;
