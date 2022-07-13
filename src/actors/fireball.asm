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
.INCLUDE "../macros.inc"

.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorState_byte_arr
.IMPORT Ram_ActorSubX_u8_arr
.IMPORT Ram_ActorSubY_u8_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr

;;;=========================================================================;;;

;;; The first tile ID for the fireball actor animation.
kFireballFirstTileId = $9a

;;; The OBJ palette number used for fireball actors.
kFireballPalette = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Initializes the specified actor as a fireball.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A The angle to fire at, measured in increments of tau/64.
;;; @param X The actor index.
;;; @preserve X
.EXPORT Func_InitFireballActor
.PROC Func_InitFireballActor
    and #$3f
    tay
    lda #0
    sta Ram_ActorVelX_i16_1_arr, x
    sta Ram_ActorVelY_i16_1_arr, x
_InitVelX:
    lda _VelX_u8_arr64, y
    bpl @nonneg
    dec Ram_ActorVelX_i16_1_arr, x  ; now $ff
    @nonneg:
    .repeat 3
    asl a
    rol Ram_ActorVelX_i16_1_arr, x
    .endrepeat
    sta Ram_ActorVelX_i16_0_arr, x
_InitVelY:
    lda _VelY_u8_arr64, y
    bpl @nonneg
    dec Ram_ActorVelY_i16_1_arr, x  ; now $ff
    @nonneg:
    .repeat 3
    asl a
    rol Ram_ActorVelY_i16_1_arr, x
    .endrepeat
    sta Ram_ActorVelY_i16_0_arr, x
_InitOtherVariables:
    lda #eActor::Fireball
    sta Ram_ActorType_eActor_arr, x
    lda #0
    sta Ram_ActorSubX_u8_arr, x
    sta Ram_ActorSubY_u8_arr, x
    sta Ram_ActorState_byte_arr, x
    .assert kFireballPalette <> 0, error
    lda #kFireballPalette
    sta Ram_ActorFlags_bObj_arr, x
    rts
_VelX_u8_arr64:
    ;; [0xff & int(round(96 * cos(x * pi / 32))) for x in range(64)]
    .byte $60, $60, $5e, $5c, $59, $55, $50, $4a
    .byte $44, $3d, $35, $2d, $25, $1c, $13, $09
    .byte $00, $f7, $ed, $e4, $db, $d3, $cb, $c3
    .byte $bc, $b6, $b0, $ab, $a7, $a4, $a2, $a0
    .byte $a0, $a0, $a2, $a4, $a7, $ab, $b0, $b6
    .byte $bc, $c3, $cb, $d3, $db, $e4, $ed, $f7
    .byte $00, $09, $13, $1c, $25, $2d, $35, $3d
    .byte $44, $4a, $50, $55, $59, $5c, $5e, $60
_VelY_u8_arr64:
    ;; [0xff & int(round(96 * sin(x * pi / 32))) for x in range(64)]
    .byte $00, $09, $13, $1c, $25, $2d, $35, $3d
    .byte $44, $4a, $50, $55, $59, $5c, $5e, $60
    .byte $60, $60, $5e, $5c, $59, $55, $50, $4a
    .byte $44, $3d, $35, $2d, $25, $1c, $13, $09
    .byte $00, $f7, $ed, $e4, $db, $d3, $cb, $c3
    .byte $bc, $b6, $b0, $ab, $a7, $a4, $a2, $a0
    .byte $a0, $a0, $a2, $a4, $a7, $ab, $b0, $b6
    .byte $bc, $c3, $cb, $d3, $db, $e4, $ed, $f7
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a fireball actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickFireball
.PROC FuncA_Actor_TickFireball
    inc Ram_ActorState_byte_arr, x
    beq @expire
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcc @done
    @expire:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a fireball actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawFireballActor
.PROC FuncA_Objects_DrawFireballActor
    lda Ram_ActorState_byte_arr, x
    div #2
    and #$01
    add #kFireballFirstTileId
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
