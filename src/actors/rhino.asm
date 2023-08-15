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
.INCLUDE "rhino.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Actor_IsFacingAvatar
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Objects_Draw1x2Shape
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_PointHitsTerrain
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; How fast a rhino actor walks (when not charging) or runs (when charging),
;;; in subpixels per frame.
kRhinoWalkSpeed   = $0050
kRhinoChargeSpeed = $0235

;;; How many pixels in front of its center a rhino actor checks for solid
;;; terrain to see if it needs to turn around.
kRhinoTerrainDistance = 13

;;; How many pixels in front of its center a rhino actor checks for the player
;;; avatar to see if it should start charging.
kRhinoChargeDistance = $40

;;; How many pixels behind its center a rhino actor checks for the player
;;; avatar to see if it should turn around and start charging.
kRhinoSneakDistance = $28

;;; The maximum number of pixels above/below its center the player avatar can
;;; be in order for the rhino to notice it.
kRhinoVertProximity = 12

;;; How many frames to wait when the rhino is in Angered mode before switching
;;; to Charging mode, depending on whether the player avatar is in front of the
;;; rhino or behind it.
kRhinoAngeredFrontFrames = 5
kRhinoAngeredBehindFrames = 12

;;; How many frames to wait when the rhino is in Recovering mode before
;;; switching back to Walking mode.
kRhinoRecoveryFrames = 60

;;; Tile IDs for drawing rhino baddie actors.
kTileIdObjRhinoHeadFirst = kTileIdObjRhinoFirst + 12

;;; The OBJ palette number to use for drawing rhino baddie actors.
kPaletteObjRhino = 0

;;;=========================================================================;;;

;;; Possible values for a rhino baddie actor's State1 byte.
.ENUM eBadRhino
    Walking     ; walking forward slowly
    Angered     ; player avatar spotted; pausing before charging
    Charging    ; running forward quickly
    Recovering  ; pausing before turning around and resuming walking
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a rhino baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadRhino
.PROC FuncA_Actor_TickBadRhino
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    ldy Ram_ActorState1_byte_arr, x  ; eBadRhino mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eBadRhino
    d_entry table, Walking,    FuncA_Actor_TickBadRhino_Walking
    d_entry table, Angered,    FuncA_Actor_TickBadRhino_Angered
    d_entry table, Charging,   FuncA_Actor_TickBadRhino_Charging
    d_entry table, Recovering, FuncA_Actor_TickBadRhino_Recovering
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for a rhino baddie actor that's in Walking mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRhino_Walking
    ;; Check if the terrain forces the rhino to turn around.
    jsr FuncA_Actor_MustRhinoTurn  ; preserves X, returns C
    bcc @noTerrainTurn
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    @noTerrainTurn:
    ;; Check if the player avatar is nearby.
    ldy #kRhinoVertProximity  ; param: distance below avatar
    tya  ; param: distance above avatar
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc _SetVelocity  ; player avatar is too far away vertically
    jsr FuncA_Actor_IsFacingAvatar  ; preserves X, returns C
    bcc _NotFacingAvatar  ; rhino is not facing the player avatar
_FacingAvatar:
    lda #kRhinoChargeDistance  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc _SetVelocity  ; player avatar is too far away
    lda #kRhinoAngeredFrontFrames
    .assert kRhinoAngeredFrontFrames > 0, error
    bne _BecomeAngered  ; unconditional
_NotFacingAvatar:
    lda #kRhinoSneakDistance  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc _SetVelocity
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH
    sta Ram_ActorFlags_bObj_arr, x
    lda #kRhinoAngeredBehindFrames
_BecomeAngered:
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    lda #eBadRhino::Angered
    sta Ram_ActorState1_byte_arr, x  ; eBadRhino mode
    ;; TODO: play a sound
    jmp FuncA_Actor_ZeroVelX  ; preserves X
_SetVelocity:
    inc Ram_ActorState3_byte_arr, x  ; animation counter
    ldya #kRhinoWalkSpeed  ; param: speed
    jmp FuncA_Actor_SetVelXForward  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a rhino baddie actor that's in Charging
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRhino_Charging
    jsr FuncA_Actor_MustRhinoTurn  ; preserves X, returns C
    bcc _ContinueForward
_Stop:
    lda #kRhinoRecoveryFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    lda #eBadRhino::Recovering
    sta Ram_ActorState1_byte_arr, x  ; eBadRhino mode
    jmp FuncA_Actor_ZeroVelX  ; preserves X
_ContinueForward:
    inc Ram_ActorState3_byte_arr, x  ; animation counter
    inc Ram_ActorState3_byte_arr, x  ; animation counter
    ldya #kRhinoChargeSpeed  ; param: speed
    jmp FuncA_Actor_SetVelXForward  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a rhino baddie actor that's in Angered mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRhino_Angered
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    lda #eBadRhino::Charging
    sta Ram_ActorState1_byte_arr, x  ; eBadRhino mode
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for a rhino baddie actor that's in Recovering
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRhino_Recovering
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    lda #eBadRhino::Walking
    sta Ram_ActorState1_byte_arr, x  ; eBadRhino mode
    @done:
    rts
.ENDPROC

;;; Checks terrain to determine if the rhino baddie actor needs to turn around
;;; before moving forward any farther.
;;; @param X The actor index.
;;; @return C Set if the rhino should turn around.
;;; @preserve X
.PROC FuncA_Actor_MustRhinoTurn
    ;; Check the terrain block just in front of the rhino.  If it's solid, the
    ;; rhino has to turn around.
    lda #kRhinoTerrainDistance  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C and Y
    bcs _Return
    ;; Check the floor just in front of the rhino.  If it's not solid, the
    ;; rhino has to turn around.
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge _NoTurn
    sec
_Return:
    rts
_NoTurn:
    clc
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a rhino baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadRhino
.PROC FuncA_Objects_DrawActorBadRhino
    lda Ram_ActorState3_byte_arr, x  ; animation counter
    div #16
    and #$03
    sta T2  ; animation frame
_DrawBody:
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X and T0+
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    sta T3  ; FlipH flag
    beq @facingRight
    @facingLeft:
    lda #kTileWidthPx / 2
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X and T0+
    jmp @drawBody
    @facingRight:
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X and T0+
    @drawBody:
    ldy T2  ; animation frame
    lda _TileIdObjRhinoBodyFirst_u8_arr, y  ; param: first tile ID
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    .assert kPaletteObjRhino = 0, error
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X and T2+
_DrawHead:
    lda T3  ; FlipH flag
    beq @facingRight
    @facingLeft:
    lda #kTileWidthPx * 2
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X and T0+
    jmp @drawHead
    @facingRight:
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and T0+
    @drawHead:
    lda T2  ; animation frame
    and #$01
    mul #2
    .assert kTileIdObjRhinoHeadFirst .mod 4 = 0, error
    ora #kTileIdObjRhinoHeadFirst | 0  ; param: first tile ID
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jmp FuncA_Objects_Draw1x2Shape  ; preserves X
_TileIdObjRhinoBodyFirst_u8_arr:
    .byte kTileIdObjRhinoFirst + 0
    .byte kTileIdObjRhinoFirst + 4
    .byte kTileIdObjRhinoFirst + 8
    .byte kTileIdObjRhinoFirst + 4
.ENDPROC

;;;=========================================================================;;;
