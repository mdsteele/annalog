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
.INCLUDE "../tileset.inc"
.INCLUDE "crab.inc"

.IMPORT FuncA_Actor_FaceOppositeDir
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_MoveForwardOnePixel
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_GetRandomByte
.IMPORT Func_IsPointInAnySolidPlatform
.IMPORT Func_PointHitsTerrain
.IMPORT Ram_ActorState1_byte_arr
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; The OBJ palette number to use for drawing crab baddie actors.
kPaletteObjCrab = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a crab baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadCrab
.PROC FuncA_Actor_TickBadCrab
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    lda Ram_ActorState1_byte_arr, x
    beq _StartMove
    dec Ram_ActorState1_byte_arr, x
    cmp #$18
    blt _Return
    jmp FuncA_Actor_MoveForwardOnePixel  ; preserves X
_StartMove:
    ;; Check the terrain block just in front of the crab.  If it's solid, the
    ;; crab has to turn around.
    lda #kTileWidthPx + 1  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_IsPointInAnySolidPlatform  ; preserves X, returns C
    bcs @turnAround
    jsr Func_PointHitsTerrain  ; preserves X, returns C and Y
    bcs @turnAround
    ;; Check the floor just in front of the crab.  If it's not solid, the crab
    ;; has to turn around.
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    blt @turnAround
    ;; Otherwise, randomly turn around 25% of the time.
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$03
    bne @continueForward
    ;; Make the crab face the opposite direction.
    @turnAround:
    jsr FuncA_Actor_FaceOppositeDir  ; preserves X
    ;; Start a new movement cycle for the crab.
    @continueForward:
    lda #$1f
    sta Ram_ActorState1_byte_arr, x
_Return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a crab baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadCrab
.PROC FuncA_Objects_DrawActorBadCrab
    lda Ram_ActorState1_byte_arr, x
    div #$10
    and #$01
    tay
    lda _TileIds_u8_arr2, y  ; param: first tile ID
    ldy #kPaletteObjCrab  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr2:
    .byte kTileIdObjBadCrabFirst + 0
    .byte kTileIdObjBadCrabFirst + 4
.ENDPROC

;;;=========================================================================;;;
