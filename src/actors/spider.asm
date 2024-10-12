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

.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../tileset.inc"
.INCLUDE "spider.inc"

.IMPORT FuncA_Actor_FaceOppositeDir
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarAboveOrBelow
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_NegateVelY
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Actor_ZeroVelY
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_GetRandomByte
.IMPORT Func_PointHitsTerrain
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; How many frames a spider baddie actor spends moving left/right in each
;;; movement cycle.
kSpiderMoveFrames = 8

;;; How many frames the spider pauses for after moving in each movement cycle.
kSpiderPauseFrames = 8

;;; The total number of frames in a spider baddie actor's movement cycle.
kSpiderMovementCycleFrames = kSpiderMoveFrames + kSpiderPauseFrames

;;; How fast the spider moves sideways, in pixels/frame.
kSpiderMoveSpeed = 1

;;; How far a spider moves in each movement cycle, in pixels.
kSpiderStridePx = kSpiderMoveSpeed * kSpiderMoveFrames

;;; How close the player avatar must be horizontally to the spider, in pixels,
;;; in order for the spider to drop down on a thread.
kSpiderDropProximity = 24

;;; How long the spider spends dropping down on a thread and coming back up.
kSpiderDropFrames = 75

;;; How fast the spider drops on a thread, in subpixels/frame.
kSpiderDropSpeed = $01a0

;;; Tile IDs for drawing spider baddie actors.
kTileIdObjBadSpiderThread = kTileIdObjBadSpiderFirst + 6

;;; The OBJ palette number used for drawing spider baddies.
kPaletteObjSpider = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a spider baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadSpider
.PROC FuncA_Actor_TickBadSpider
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bpl _IsInMovementCycle
_IsHangingFromThread:
    lda Ram_ActorState1_byte_arr, x  ; move cycle timer
    beq _ThreadCycleFinished
    dec Ram_ActorState1_byte_arr, x  ; move cycle timer
    cmp #kSpiderDropFrames / 2 + 1
    bne _Return
    jmp FuncA_Actor_NegateVelY
_ThreadCycleFinished:
    jsr FuncA_Actor_ZeroVelY  ; preserves X
    ;; Clear the FlipV flag to indicate that the spider is no longer hanging on
    ;; a thread.
    lda Ram_ActorFlags_bObj_arr, x
    and #<~bObj::FlipV
    sta Ram_ActorFlags_bObj_arr, x
    ;; Pause before starting the next movement cycle.
    lda #kSpiderPauseFrames
    sta Ram_ActorState1_byte_arr, x  ; move cycle timer
_Return:
    rts
_IsInMovementCycle:
    ;; A spider actor's "movement cycle" consists of moving at kSpiderMoveSpeed
    ;; for kSpiderMoveFrames, and then standing still for kSpiderPauseFrames.
    lda Ram_ActorState1_byte_arr, x  ; move cycle timer
    beq _MovementCycleFinished
    dec Ram_ActorState1_byte_arr, x  ; move cycle timer
    cmp #kSpiderPauseFrames + 1
    bge @done
    @paused:
    jmp FuncA_Actor_ZeroVelX  ; preserves X
    @done:
    rts
_MovementCycleFinished:
    ;; Whenever the spider finishes a movement cycle, it can either start a new
    ;; movement cycle, or start dropping down on a thread.
    ;;
    ;; Don't drop down on a thread if the player avatar isn't horizontally
    ;; nearby.
    lda #kSpiderDropProximity  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc _StartNewMovementCycle
    ;; Don't drop down on a thread if the player avatar is above the spider.
    jsr FuncA_Actor_IsAvatarAboveOrBelow  ; preserves X, returns N
    bmi _StartNewMovementCycle
    ;; Even if the spider could drop down on a thread, only do so 50% of the
    ;; time.
    jsr Func_GetRandomByte  ; preserves X, returns N
    bmi _StartNewMovementCycle
_StartDroppingDownOnThread:
    lda #kSpiderDropFrames
    sta Ram_ActorState1_byte_arr, x  ; move cycle timer
    ;; Set velocity.
    lda #<kSpiderDropSpeed
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kSpiderDropSpeed
    sta Ram_ActorVelY_i16_1_arr, x
    ;; Set thread origin.
    lda Ram_ActorPosY_i16_0_arr, x
    sub #kTileHeightPx - 1
    sta Ram_ActorState2_byte_arr, x  ; thread origin
    ;; Set the FlipV flag to indicate that the spider is now hanging on a
    ;; thread.
    lda Ram_ActorFlags_bObj_arr, x
    ora #bObj::FlipV
    sta Ram_ActorFlags_bObj_arr, x
    rts
_StartNewMovementCycle:
    ;; Check the terrain block just in front of the spider.  If it's solid,
    ;; the spider has to turn around.
    lda #kSpiderStridePx + 1  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C and Y
    bcs @turnAround
    ;; Check the ceiling just in front of the spider.  If it's not solid, the
    ;; spider has to turn around.
    dey
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    blt @turnAround
    ;; Otherwise, randomly turn around 25% of the time.
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$03
    bne @continueForward
    ;; Make the spider face the opposite direction.
    @turnAround:
    jsr FuncA_Actor_FaceOppositeDir  ; preserves X
    @continueForward:
_SetVelocityForMove:
    ldya #kSpiderMoveSpeed * $100  ; param: speed
    jsr FuncA_Actor_SetVelXForward
    ;; Start a new movement cycle for the spider.  To do this, we decrement the
    ;; timer from its current value of zero, mod kSpiderMovementCycleFrames.
    lda #kSpiderMovementCycleFrames - 1
    sta Ram_ActorState1_byte_arr, x  ; move cycle timer
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a spider baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadSpider
.PROC FuncA_Objects_DrawActorBadSpider
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bpl _NotOnThread
_HangingFromThread:
    lda Ram_ActorPosY_i16_0_arr, x
    sub Ram_ActorState2_byte_arr, x  ; thread origin
    div #kTileHeightPx
    beq @doneThread
    sta T2  ; num thread tiles
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    ldy #kPaletteObjSpider | bObj::Pri  ; param: object flags
    lda #kTileIdObjBadSpiderThread  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    dec T2  ; num thread tiles
    bne @loop
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    @doneThread:
    lda #4
    bne _DrawSpider  ; unconditional
_NotOnThread:
    lda Ram_ActorState1_byte_arr, x  ; move cycle timer
    add #$04
    div #4
    and #$02
_DrawSpider:
    ;; At this point, A holds the spider tile ID offset (0, 2, or 4).
    .assert kTileIdObjBadSpiderFirst .mod 8 = 0, error
    ora #kTileIdObjBadSpiderFirst | 1
    sta T2  ; param: tile ID
    ldy #kPaletteObjSpider | bObj::FlipH  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    lda #7
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X and T0+
    lda T2  ; param: tile ID
    ldy #kPaletteObjSpider  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X and T0+
    dec T2  ; tile ID
    lda T2  ; param: tile ID
    ldy #kPaletteObjSpider  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
    lda #7
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X and T0+
    lda T2  ; param: tile ID
    ldy #kPaletteObjSpider | bObj::FlipH  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
.ENDPROC

;;;=========================================================================;;;
