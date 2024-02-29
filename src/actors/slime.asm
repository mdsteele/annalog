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
.INCLUDE "slime.inc"
.INCLUDE "spike.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarAboveOrBelow
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw2x1Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpHalfTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjSpike
.IMPORT Func_MovePointDownByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; How many frames after dropping a spike before a slime can drop another.
kSlimeSpikeCooldownFrames = 90

;;; How close the player avatar must be horizontally to the slime in order for
;;; the slime to drop a spike, in pixels.
kSlimeSpikeHorzProximity = 30

;;; How far the spike protrudes from the bottom of the slime, in pixels.
kSlimeSpikeVertProtrusion = 3

;;; The initial downward speed of a dropped spike, in pixels per frame.
kSlimeSpikeInitSpeed = 1

;;; The OBJ palette number to use for drawing slime baddie actors.
kPaletteObjBadSlime = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a slime baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadSlime
.PROC FuncA_Actor_TickBadSlime
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    inc Ram_ActorState2_byte_arr, x  ; animation timer
_Move:
    ;; Check the terrain block just in front of the slime.  If it's solid, the
    ;; slime has to turn around.
    lda #kTileWidthPx  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C and Y
    bcs @turnAround
    ;; Check the ceiling just in front of the slime.  If it's not solid, the
    ;; slime has to turn around.
    dey
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge @continueForward
    ;; Make the slime face the opposite direction.
    @turnAround:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    ;; Set the slime's velocity.
    @continueForward:
    lda Ram_ActorState2_byte_arr, x  ; animation timer
    and #$1f
    cmp #9
    blt @slow
    cmp #25
    bge @slow
    @fast:
    lda #$68  ; param: speed (lo)
    bne @setVel  ; unconditional
    @slow:
    lda #$10  ; param: speed (lo)
    @setVel:
    ldy #$00  ; param: speed (hi)
    jsr FuncA_Actor_SetVelXForward  ; preserves X
_CoolDown:
    lda Ram_ActorState1_byte_arr, x  ; spike cooldown
    beq _MaybeDropSpike
    dec Ram_ActorState1_byte_arr, x  ; spike cooldown
_Return:
    rts
_MaybeDropSpike:
    ;; Don't drop a spike if the player avatar isn't horizontally nearby.
    lda #kSlimeSpikeHorzProximity  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc _Return
    ;; Don't drop a spike if the player avatar is above the slime.
    jsr FuncA_Actor_IsAvatarAboveOrBelow  ; preserves X, returns N
    bmi _Return
_DropSpike:
    ;; Set the starting position for the spike.
    jsr Func_SetPointToActorCenter  ; preserves X
    lda #kSlimeSpikeVertProtrusion  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    ;; Drop the spike.
    stx T0  ; slime actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @noSpike
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    jsr Func_InitActorProjSpike  ; preserves X and T0+
    lda #kSlimeSpikeInitSpeed
    sta Ram_ActorVelY_i16_1_arr, x
    ldx T0  ; slime actor index
    lda #kSlimeSpikeCooldownFrames
    sta Ram_ActorState1_byte_arr, x  ; spike cooldown
    @noSpike:
    ldx T0  ; slime actor index
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a slime baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadSlime
.PROC FuncA_Objects_DrawActorBadSlime
_Slime:
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_MoveShapeUpHalfTile  ; preserves X
    lda Ram_ActorState2_byte_arr, x  ; animation timer
    div #8
    and #$03
    tay
    lda _TileIds_u8_arr4, y  ; param: first tile ID
    ldy #kPaletteObjBadSlime  ; param: object flags
    jsr FuncA_Objects_Draw2x1Shape  ; preserves X
_Spike:
    lda Ram_ActorState1_byte_arr, x  ; spike cooldown
    div #2
    rsub #kSlimeSpikeVertProtrusion
    blt @done
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X
    lda #kTileIdObjSpike
    ldy #kPaletteObjSpike  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
    @done:
    rts
_TileIds_u8_arr4:
    .byte kTileIdObjBadSlimeFirst + $00
    .byte kTileIdObjBadSlimeFirst + $02
    .byte kTileIdObjBadSlimeFirst + $04
    .byte kTileIdObjBadSlimeFirst + $02
.ENDPROC

;;;=========================================================================;;;
