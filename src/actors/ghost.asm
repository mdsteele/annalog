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
.INCLUDE "../ppu.inc"
.INCLUDE "ghost.inc"
.INCLUDE "orc.inc"
.INCLUDE "townsfolk.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Objects_BobActorShapePosUpAndDown
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_Draw2x3TownsfolkShape
.IMPORT FuncA_Objects_MoveShapeHorz
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_MoveShapeVert
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_Cosine
.IMPORT Func_InitActorWithState1
.IMPORT Func_Noop
.IMPORT Func_SignedMult
.IMPORT Func_Sine
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Turns an NPC mermaid ghost or orc ghost into a ghost baddie, and then makes
;;; it disappear.
;;; @param X The actor index.
;;; @param Y The new actor type for the ghost (BadGhostMermaid or BadGhostOrc).
.EXPORT FuncA_Room_MakeNpcGhostDisappear
.PROC FuncA_Room_MakeNpcGhostDisappear
    lda #eBadGhost::Disappearing  ; param: eBadGhost value
    jsr Func_InitActorWithState1  ; preserves X
    ;; TODO: Make the ghost baddie face the player avatar.
    ;; TODO: Play a sound
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for an orc ghost baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGhostMermaid
.PROC FuncA_Actor_TickBadGhostMermaid
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBadGhost
    d_entry table, Absent,       Func_Noop
    d_entry table, Idle,         Func_Noop
    d_entry table, Disappearing, FuncA_Actor_TickBadGhost_Disappearing
    d_entry table, Reappearing,  FuncA_Actor_TickBadGhost_Reappearing
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for an orc ghost baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGhostOrc
.PROC FuncA_Actor_TickBadGhostOrc
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBadGhost
    d_entry table, Absent,       Func_Noop
    d_entry table, Idle,         Func_Noop
    d_entry table, Disappearing, FuncA_Actor_TickBadGhost_Disappearing
    d_entry table, Reappearing,  FuncA_Actor_TickBadGhost_Reappearing
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; Disappearing mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_Disappearing
    ;; Increment timer until it reaches its end value.
    inc Ram_ActorState2_byte_arr, x  ; mode timer
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kBadGhostAppearFrames
    blt @done
    ;; When the timer finishes, make the ghost absent (and clear its timer).
    lda #eBadGhost::Absent
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    .assert eBadGhost::Absent = 0, error
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for a mermaid/orc ghost baddie actor that's in
;;; Disappearing mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGhost_Reappearing
    ;; Increment timer until it reaches zero.
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    ;; When the timer finishes, make the ghost idle.  Its timer will already be
    ;; clear.
    lda #eBadGhost::Idle
    sta Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a mermaid ghost baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGhostMermaid
.PROC FuncA_Objects_DrawActorBadGhostMermaid
    jsr FuncA_Objects_SetShapePosToBadGhostCenter  ; preserves X; returns Y, Z
    beq FuncA_Objects_DrawActorBadGhostAbsent  ; preserves X
    lda _FirstTileId_u8_arr, y  ; param: first tile ID
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jmp FuncA_Objects_Draw2x3TownsfolkShape  ; preserves X
_FirstTileId_u8_arr:
    D_ARRAY .enum, eBadGhost
    d_byte Absent,       kTileIdMermaidGhostFirst + 0
    d_byte Idle,         kTileIdMermaidGhostFirst + 0
    d_byte Disappearing, kTileIdMermaidGhostFirst + 0
    d_byte Reappearing,  kTileIdMermaidGhostFirst + 0
    D_END
.ENDPROC

;;; Draws a ghost baddie actor that's absent (invisible).  In other words, this
;;; is a no-op.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Objects_DrawActorBadGhostAbsent
    rts
.ENDPROC

;;; Draws an orc ghost baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGhostOrc
.PROC FuncA_Objects_DrawActorBadGhostOrc
    jsr FuncA_Objects_SetShapePosToBadGhostCenter  ; preserves X; returns Y, Z
    beq FuncA_Objects_DrawActorBadGhostAbsent  ; preserves X
    ;; Draw feet:
    lda _FirstTileId_u8_arr, y  ; param: first tile ID
    jsr _DrawPart  ; preserves X
    ;; Draw head:
    lda #kBlockHeightPx
    jsr FuncA_Objects_MoveShapeUpByA  ; preserves X and T0+
    lda #kTileIdObjOrcGhostFirst + 0  ; param: first tile ID
_DrawPart:
    ldy Ram_ActorFlags_bObj_arr, x  ; param: object flags
    jmp FuncA_Objects_Draw2x2Shape  ; preserves X
_FirstTileId_u8_arr:
    D_ARRAY .enum, eBadGhost
    d_byte Absent,       kTileIdObjOrcGhostFirst + 4
    d_byte Idle,         kTileIdObjOrcGhostFirst + 4
    d_byte Disappearing, kTileIdObjOrcGhostFirst + 4
    d_byte Reappearing,  kTileIdObjOrcGhostFirst + 4
    D_END
.ENDPROC

;;; Sets the shape position for a ghost baddie actor, taking its current mode
;;; into account (and also returning that mode, for convenience).
;;; @param X The actor index.
;;; @return Y The actor's current eBadGhost mode.
;;; @return Z Set if the ghost is in Absent mode, and thus should not be drawn.
;;; @preserve X
.PROC FuncA_Objects_SetShapePosToBadGhostCenter
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    jsr FuncA_Objects_BobActorShapePosUpAndDown  ; preserves X
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    .assert eBadGhost::Absent = 0, error
    beq @done  ; Z is set: ghost is absent
    cpy #eBadGhost::Disappearing
    beq @displace
    cpy #eBadGhost::Reappearing
    bne @done  ; Z is clear: ghost is not absent
    @displace:
    ;; Horizontal displacement:
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    mul #2
    sta T2  ; displacement radius
    mul #8
    bit Data_PowersOfTwo_u8_arr8 + 4
    beq @setAngle
    eor #$80
    @setAngle:
    pha  ; param: displacement angle
    jsr Func_Cosine  ; preserves X, T0+; returns A (param: signed multiplicand)
    ldy T2  ; displacement radius (param: unsigned multiplier)
    jsr Func_SignedMult  ; preserves X and T2+; returns YA
    tya  ; param: signed offset
    jsr FuncA_Objects_MoveShapeHorz  ; preserves X and T0+
    ;; Vertical displacement:
    pla  ; angle
    jsr Func_Sine  ; preserves X, T0+; returns A (param: signed multiplicand)
    ldy T2  ; displacement radius (param: unsigned multiplier)
    jsr Func_SignedMult  ; preserves X, returns YA
    tya  ; param: signed offset
    jsr FuncA_Objects_MoveShapeVert  ; preserves X
    ;; Set up Y and Z return values again:
    ldy Ram_ActorState1_byte_arr, x  ; current eBadGhost mode
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
