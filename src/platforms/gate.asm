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
.INCLUDE "../sample.inc"
.INCLUDE "gate.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT FuncC_Prison_PlaySfxPrisonGate
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_MovePlatformVert
.IMPORT Func_MovePointUpByA
.IMPORT Func_PlaySfxSample
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
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
;;; from a room's Enter function.
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
    ;; Move the gate towards its shut position.
    lda #kGateShutSpeed  ; param: move speed
    jsr Func_MovePlatformTopTowardPointY  ; preserves X, returns Z
    php  ; save Z
    ;; When the gate moves, play occasional "clink" sounds.
    beq @doneSound
    jsr _PlayClinkingSound  ; preserves X
    ;; If the gate finished moving into its fully-shut position, also play a
    ;; "clang" sample.
    lda Ram_PlatformTop_i16_1_arr, x
    cmp Zp_PointY_i16 + 1
    bne @doneSound
    lda Ram_PlatformTop_i16_0_arr, x
    cmp Zp_PointY_i16 + 0
    bne @doneSound
    lda #eSample::AnvilF
    jsr Func_PlaySfxSample
    @doneSound:
    plp  ; restore Z
    rts
_Open:
    ;; Move Zp_PointY_i16 up to the gate's open position.
    lda #kGateRiseDistancePx  ; param: offset
    jsr Func_MovePointUpByA  ; preserves X
    ;; Move the gate towards its open position.
    lda #kGateOpenSpeed  ; param: move speed
    jsr Func_MovePlatformTopTowardPointY  ; preserves X, returns Z
    ;; When the gate moves, play occasional "clink" sounds.
    beq @doneSound
    php  ; save Z
    jsr _PlayClinkingSound
    plp  ; restore Z
    @doneSound:
_Return:
    rts
_PlayClinkingSound:
    lda Ram_PlatformTop_i16_0_arr, x
    and #$04
    bne _Return
    jmp FuncC_Prison_PlaySfxPrisonGate  ; preserves X
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
