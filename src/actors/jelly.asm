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
.INCLUDE "../program.inc"
.INCLUDE "jelly.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_MovePointTowardVelXDir
.IMPORT FuncA_Actor_MovePointTowardVelYDir
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Actor_ZeroVelY
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorSubX_u8_arr
.IMPORT Ram_ActorSubY_u8_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64

;;;=========================================================================;;;

;;; How fast a jelly baddie moves, in subpixels per frame.
kBadJellySpeed = $0190

;;; How many pixels in front of its center a jelly baddie actor checks for
;;; solid terrain to see if it needs to turn.
kBadJellyTurnDistance = 8

;;; How many VBlank frames between jelly baddie animation frames.
.DEFINE kBadJellyAnimSlowdown 8

;;; The OBJ palette number to use for drawing jelly baddie actors.
kPaletteObjJelly = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a jelly baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadJelly
.PROC FuncA_Actor_TickBadJelly
    inc Ram_ActorState2_byte_arr, x  ; animation counter
    ;; Set the point in the direction the jelly is moving in.
    jsr Func_SetPointToActorCenter  ; preserves X
    lda Ram_ActorVelX_i16_1_arr, x
    .assert kBadJellySpeed >= $100, error
    beq @noVelX
    lda #kBadJellyTurnDistance  ; param: offset
    jsr FuncA_Actor_MovePointTowardVelXDir  ; preserves X
    @noVelX:
    lda Ram_ActorVelY_i16_1_arr, x
    .assert kBadJellySpeed >= $100, error
    beq @noVelY
    lda #kBadJellyTurnDistance  ; param: offset
    jsr FuncA_Actor_MovePointTowardVelYDir  ; preserves X
    @noVelY:
    ;; Check if there is solid terrain in front of the jelly.
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc _ContinueForward
_Turn:
    ;; Align the jelly to the grid.
    lda #0
    sta Ram_ActorSubX_u8_arr, x
    sta Ram_ActorSubY_u8_arr, x
    lda Ram_ActorPosX_i16_0_arr, x
    .assert kBlockWidthPx = $10, error
    and #$f0
    ora #$08
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_ActorPosY_i16_0_arr, x
    .assert kBlockHeightPx = $10, error
    and #$f0
    ora #$08
    sta Ram_ActorPosY_i16_0_arr, x
    ;; Update the jelly's direction.
    lda Ram_ActorState1_byte_arr, x  ; bBadJelly value
    and #bBadJelly::DirMask
    tay  ; old eDir value
    lda Ram_ActorState1_byte_arr, x  ; bBadJelly value
    .assert bBadJelly::TurnCcw = bProc::Negative, error
    bmi @turnCcw
    @turnCw:
    .assert (eDir::Up + 1) .mod 4 = eDir::Right, error
    .assert (eDir::Right + 1) .mod 4 = eDir::Down, error
    .assert (eDir::Down + 1) .mod 4 = eDir::Left, error
    .assert (eDir::Left + 1) .mod 4 = eDir::Up, error
    iny
    bne @setDir  ; unconditional
    @turnCcw:
    dey
    @setDir:
    tya
    .assert eDir::NUM_VALUES = 4, error
    and #$03
    sta T0  ; new eDir value
    lda Ram_ActorState1_byte_arr, x  ; bBadJelly value
    and #<~bBadJelly::DirMask
    ora T0  ; new eDir value
    sta Ram_ActorState1_byte_arr, x  ; bBadJelly value
_ContinueForward:
    jsr _SetVelocity  ; preserves X
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_SetVelocity:
    jsr FuncA_Actor_ZeroVelX  ; preserves X
    jsr FuncA_Actor_ZeroVelY  ; preserves X
    lda Ram_ActorState1_byte_arr, x  ; bBadJelly value
    and #bBadJelly::DirMask
    .assert eDir::Up = 0, error
    beq @up
    cmp #eDir::Left
    beq @left
    cmp #eDir::Down
    beq @down
    @right:
    lda #<kBadJellySpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>kBadJellySpeed
    sta Ram_ActorVelX_i16_1_arr, x
    rts
    @up:
    lda #<-kBadJellySpeed
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>-kBadJellySpeed
    sta Ram_ActorVelY_i16_1_arr, x
    rts
    @left:
    lda #<-kBadJellySpeed
    sta Ram_ActorVelX_i16_0_arr, x
    lda #>-kBadJellySpeed
    sta Ram_ActorVelX_i16_1_arr, x
    rts
    @down:
    lda #<kBadJellySpeed
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kBadJellySpeed
    sta Ram_ActorVelY_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a jelly baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadJelly
.PROC FuncA_Objects_DrawActorBadJelly
    lda Ram_ActorState2_byte_arr, x  ; animation counter
    div #kBadJellyAnimSlowdown
    and #$03
    tay
    lda _TileId_arr4, y
    pha
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda #kPaletteObjJelly  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    pla
    bcs @done
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kPaletteObjJelly | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kPaletteObjJelly | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjJelly | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
_TileId_arr4:
    .byte kTileIdObjJellyFirst + 0
    .byte kTileIdObjJellyFirst + 1
    .byte kTileIdObjJellyFirst + 2
    .byte kTileIdObjJellyFirst + 1
.ENDPROC

;;;=========================================================================;;;
