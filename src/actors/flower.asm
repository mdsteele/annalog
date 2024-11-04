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

.INCLUDE "../devices/flower.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "flower.inc"

.IMPORT DataA_Objects_FlowerShape_sShapeTile_arr
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinHorzDistance
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Objects_DrawShapeTiles
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorProjFireball
.IMPORT Func_MovePointRightByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_PlaySfxShootFire
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr

;;;=========================================================================;;;

;;; The number of VBlank frames between each animation frame of a flower
;;; baddie's transformation.
.DEFINE kBadFlowerAnimationSlowdown 8

;;; The number of VBlank frames it takes for a flower baddie to transform.
kBadFlowerTransformFrames = 4 * kBadFlowerAnimationSlowdown - 1

;;; The time between shots when a flower baddie is attacking, in frames.
.DEFINE kBadFlowerShotCooldownFrames 16

;;; How many projectiles a flower baddie shoots per attack wave.
kBadFlowerNumShots = 4

;;; The time between when a flower baddie decides to attack and when it starts
;;; shooting, in frames.
kBadFlowerWindupFrames = 30

;;; The total time for a full attack wave from a flower baddie, in frames.
.LINECONT +
kBadFlowerAttackFrames = \
    kBadFlowerShotCooldownFrames * kBadFlowerNumShots + kBadFlowerWindupFrames
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a flower baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadFlower
.PROC FuncA_Actor_TickBadFlower
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    ;; Execute mode-specific behavior.
    ldy Ram_ActorState1_byte_arr, x  ; current eBadFlower mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBadFlower
    d_entry table, Dormant,   FuncA_Actor_TickBadFlower_Dormant
    d_entry table, Growing,   FuncA_Actor_TickBadFlower_Growing
    d_entry table, Ready,     FuncA_Actor_TickBadFlower_Ready
    d_entry table, Attacking, FuncA_Actor_TickBadFlower_Attacking
    d_entry table, Shrinking, FuncA_Actor_TickBadFlower_Shrinking
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for a flower baddie actor that's in Dormant
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadFlower_Dormant
    ;; Check if the player avatar is nearby; if not, stay dormant.
    lda #$20  ; param: distance above avatar
    tay       ; param: distance below avatar
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc _Return  ; avatar is too far away vertically
    lda #$50  ; param: distance
    jsr FuncA_Actor_IsAvatarWithinHorzDistance  ; preserves X, returns C
    bcc _Return  ; avatar is too far away horizontally
_StartGrowing:
    ;; TODO: play a sound for the flower growing
    .assert eBadFlower::Growing = eBadFlower::Dormant + 1, error
    inc Ram_ActorState1_byte_arr, x  ; current eBadFlower mode
_Return:
    rts
.ENDPROC

;;; Performs per-frame updates for a flower baddie actor that's in Growing
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadFlower_Growing
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kBadFlowerTransformFrames
    bge @ready
    @grow:
    inc Ram_ActorState2_byte_arr, x  ; mode timer
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    div #kBadFlowerAnimationSlowdown
    sta Ram_ActorState3_byte_arr, x  ; animation pose
    rts
    @ready:
    .assert eBadFlower::Ready = eBadFlower::Growing + 1, error
    inc Ram_ActorState1_byte_arr, x  ; current eBadFlower mode
    lda #1
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    rts
.ENDPROC

;;; Performs per-frame updates for a flower baddie actor that's in Ready mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadFlower_Ready
_CoolDown:
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    bne _Return
_ChangeModes:
    ;; Check if the player avatar is nearby; if so, attack, otherwise shrink.
    lda #$3c  ; param: distance above avatar
    tay       ; param: distance below avatar
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc _StartShrinking  ; avatar is too far away vertically
_StartAttacking:
    lda #eBadFlower::Attacking
    sta Ram_ActorState1_byte_arr, x  ; current eBadFlower mode
    lda #kBadFlowerAttackFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    rts
_StartShrinking:
    ;; TODO: play a sound for the flower shrinking
    lda #eBadFlower::Shrinking
    sta Ram_ActorState1_byte_arr, x  ; current eBadFlower mode
    lda #kBadFlowerTransformFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
_Return:
    rts
.ENDPROC

;;; Performs per-frame updates for a flower baddie actor that's in Attacking
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadFlower_Attacking
    lda #4
    sta Ram_ActorState3_byte_arr, x  ; animation pose
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    bne _ContinueAttacking
_FinishAttacking:
    .assert eBadFlower::Ready = eBadFlower::Attacking - 1, error
    dec Ram_ActorState1_byte_arr, x  ; current eBadFlower mode
    lda #60
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    lda #3
    sta Ram_ActorState3_byte_arr, x  ; animation pose
    rts
_ContinueAttacking:
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kBadFlowerShotCooldownFrames * kBadFlowerNumShots + 1
    bge _Return  ; still winding up
    mod #kBadFlowerShotCooldownFrames
    bne _Return  ; still cooling down
_ShootFireball:
    jsr Func_SetPointToActorCenter  ; preserves X
    lda #22
    jsr Func_MovePointRightByA  ; preserves X
    lda #7
    jsr Func_MovePointUpByA  ; preserves X
    stx T3  ; flower actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @done
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    jsr Func_GetRandomByte  ; preserves X and T0+, returns A
    mod #16
    sub #8  ; param: aim angle
    jsr Func_InitActorProjFireball  ; preserves X and T3+
    jsr Func_PlaySfxShootFire  ; preserves T0+
    @done:
    ldx T3
_Return:
    rts
.ENDPROC

;;; Performs per-frame updates for a flower baddie actor that's in Shrinking
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadFlower_Shrinking
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    beq @becomeDormant
    div #kBadFlowerAnimationSlowdown
    bpl @setAnimationPose  ; unconditional
    @becomeDormant:
    ;; At this point, A is zero.
    .assert eBadFlower::Dormant = 0, error
    sta Ram_ActorState1_byte_arr, x  ; current eBadFlower mode
    @setAnimationPose:
    sta Ram_ActorState3_byte_arr, x  ; animation pose
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC DataA_Objects_BadFlowerShape1_sShapeTile_arr
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 1
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 0
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, <-8
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 2
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 1
    d_byte DeltaY_i8, <-4
    d_byte Flags_bObj, kPaletteObjFlowerTop | bObj::Final
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 19
    D_END
.ENDPROC

.PROC DataA_Objects_BadFlowerShape2_sShapeTile_arr
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 5
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 4
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 16
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 6
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-8
    d_byte DeltaY_i8, <-8
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 7
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 3
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-8
    d_byte DeltaY_i8, <-8
    d_byte Flags_bObj, kPaletteObjFlowerTop
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 20
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerTop | bObj::Final
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 21
    D_END
.ENDPROC

.PROC DataA_Objects_BadFlowerShape3_sShapeTile_arr
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 9
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 8
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 16
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 10
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-8
    d_byte DeltaY_i8, <-8
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 12
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 13
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 14
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-16
    d_byte DeltaY_i8, <-8
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 11
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerTop
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 22
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerTop | bObj::Final
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 23
    D_END
.ENDPROC

.PROC DataA_Objects_BadFlowerShape4_sShapeTile_arr
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 9
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 8
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 16
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 10
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-8
    d_byte DeltaY_i8, <-8
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 16
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 17
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 18
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-16
    d_byte DeltaY_i8, <-8
    d_byte Flags_bObj, kPaletteObjFlowerBottom
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 15
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerTop
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 24
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 8
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjFlowerTop | bObj::Final
    d_byte Tile_u8, kTileIdObjBadFlowerFirst + 25
    D_END
.ENDPROC

;;; Draws a flower baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadFlower
.PROC FuncA_Objects_DrawActorBadFlower
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    ldy Ram_ActorState3_byte_arr, x  ; animation pose
    lda _Shapes_sShapeTile_arr_ptr_0_arr, y
    pha  ; sShapeTile arr ptr (lo)
    lda _Shapes_sShapeTile_arr_ptr_1_arr, y
    tay  ; sShapeTile arr ptr (hi)
    pla  ; sShapeTile arr ptr (lo)
    jmp FuncA_Objects_DrawShapeTiles  ; preserves X
.REPEAT 2, table
    D_TABLE_LO table, _Shapes_sShapeTile_arr_ptr_0_arr
    D_TABLE_HI table, _Shapes_sShapeTile_arr_ptr_1_arr
    D_TABLE 5
    d_entry table, 0, DataA_Objects_FlowerShape_sShapeTile_arr
    d_entry table, 1, DataA_Objects_BadFlowerShape1_sShapeTile_arr
    d_entry table, 2, DataA_Objects_BadFlowerShape2_sShapeTile_arr
    d_entry table, 3, DataA_Objects_BadFlowerShape3_sShapeTile_arr
    d_entry table, 4, DataA_Objects_BadFlowerShape4_sShapeTile_arr
    D_END
.ENDREPEAT
.ENDPROC

;;;=========================================================================;;;
