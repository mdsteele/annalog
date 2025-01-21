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
.INCLUDE "../avatar.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"
.INCLUDE "lavaball.inc"

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsActorNearlyOnScreenHorz
.IMPORT FuncA_Actor_ZeroVelY
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorWithState1
.IMPORT Func_PlaySfxShootFire
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Current_sRoom

;;;=========================================================================;;;

;;; The OBJ palette number used for drawing lavaball baddie actors.
kPaletteObjLavaball = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes a lavaball baddie actor.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The jump height param.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorBadLavaball
.PROC FuncA_Room_InitActorBadLavaball
    ldy #eActor::BadLavaball  ; param: actor type
    jsr Func_InitActorWithState1  ; preserves X
    ;; Set a random delay until the first jump.
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$1f
    add #$08
    sta Ram_ActorState2_byte_arr, x  ; jump delay
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a lavaball baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadLavaball
.PROC FuncA_Actor_TickBadLavaball
    inc Ram_ActorState3_byte_arr, x  ; animation counter
    lda Ram_ActorState2_byte_arr, x  ; jump delay
    beq _IsJumping
    dec Ram_ActorState2_byte_arr, x  ; jump delay
    beq _StartJumping
_Return:
    rts
_StartJumping:
    lda Ram_ActorState1_byte_arr, x  ; jump speed
    eor #$ff
    sta Ram_ActorVelY_i16_1_arr, x
    jsr Func_GetRandomByte  ; preserves X
    ora #$80
    sta Ram_ActorVelY_i16_0_arr, x
    ;; Play a sound effect for the jump, but only if the lavaball is on screen
    ;; (or nearly so).
    jsr FuncA_Actor_IsActorNearlyOnScreenHorz  ; preserves X, returns C
    bcc _Return
    jmp Func_PlaySfxShootFire  ; preserves X
_IsJumping:
    ;; If the lavaball is moving upwards, then continue the jump.
    lda Ram_ActorVelY_i16_1_arr, x
    bmi _ContinueJumping
    ;; Get the lavaball's starting Y-position (which depends on whether the
    ;; room is short or tall), storing it in YA.
    bit <(Zp_Current_sRoom + sRoom::Flags_bRoom)
    .assert bRoom::Tall = bProc::Overflow, error
    bvs @tall
    @short:
    ldya #kLavaballStartYShort
    bpl @checkPosition  ; unconditional
    @tall:
    ldya #kLavaballStartYTall
    @checkPosition:
    ;; If the lavaball is below its starting position, end the jump.
    sta T0  ; starting Y-position (lo)
    cmp Ram_ActorPosY_i16_0_arr, x
    tya     ; starting Y-position (hi)
    sbc Ram_ActorPosY_i16_1_arr, x
    bmi _StopJumping
_ContinueJumping:
    jsr FuncA_Actor_ApplyGravity  ; preserves X
    jmp FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_StopJumping:
    lda T0  ; starting Y-position (lo)
    sta Ram_ActorPosY_i16_0_arr, x
    tya     ; starting Y-position (hi)
    sta Ram_ActorPosY_i16_1_arr, x
    jsr FuncA_Actor_ZeroVelY  ; preserves X
    ;; Set a random delay until the next jump.
    jsr Func_GetRandomByte  ; preserves X
    and #$1f
    ora #$20
    sta Ram_ActorState2_byte_arr, x  ; jump delay
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a lavaball baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadLavaball
.PROC FuncA_Objects_DrawActorBadLavaball
    lda Ram_ActorState2_byte_arr, x  ; jump delay
    bne @done  ; not jumping, so sitting invisible in lava
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda Ram_ActorVelY_i16_1_arr, x
    and #$80
    .assert bObj::FlipV = $80, error
    eor #bObj::FlipV | kPaletteObjLavaball  ; param: object flags
    sta T2  ; object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X and T2+, returns C and Y
    bcs @done
    ;; Tile IDs:
    lda Ram_ActorState3_byte_arr, x  ; animation counter
    and #$06
    .assert kTileIdObjBadLavaballFirst .mod $08 = 0, error
    ora #kTileIdObjBadLavaballFirst
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    adc #1  ; carry is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    ;; Flags:
    lda T2  ; object flags
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
