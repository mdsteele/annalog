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
.INCLUDE "grub.inc"

.IMPORT FuncA_Actor_FaceOppositeDir
.IMPORT FuncA_Actor_FaceTowardsAvatar
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsAvatarWithinVertDistances
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Objects_Draw2x2Actor
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorProjFireball
.IMPORT Func_IsPointInAnySolidPlatform
.IMPORT Func_PlaySfxShootFire
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetActorCenterToPoint
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr

;;;=========================================================================;;;

;;; How long it takes a fire grub to rise up (or lower again), in frames.
.DEFINE kGrubFireRiseFrames 16

;;; How many fireballs a fire grub should shoot per attack cycle.
kGrubFireAttackCount = 4

;;; The cooldown between fireballs from a fire grub, in frames.
.DEFINE kGrubFireCooldownFrames 16

;;; The total duration of a fire grub's attack cycle, in frames.
.LINECONT +
kGrubFireAttackFrames = \
    kGrubFireRiseFrames * 2 + kGrubFireCooldownFrames * kGrubFireAttackCount
.LINECONT -

;;; The OBJ palette number to use for drawing grub baddie actors.
kPaletteObjGrub = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a fire grub baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGrubFire
.PROC FuncA_Actor_TickBadGrubFire
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    lda Ram_ActorState2_byte_arr, x  ; attack timer
    beq _CrawlOrAttack
_ContinueAttacking:
    dec Ram_ActorState2_byte_arr, x  ; attack timer
    beq FuncA_Actor_TickBadGrub_Crawl  ; preserves X
    lda Ram_ActorState2_byte_arr, x  ; attack timer
    sub #kGrubFireRiseFrames
    blt @done  ; the grub is now lowering
    cmp #kGrubFireCooldownFrames * kGrubFireAttackCount
    bge @done  ; the grub is still raising
    mod #kGrubFireCooldownFrames
    cmp #kGrubFireCooldownFrames - 1
    bne @done  ; cooling down between projectiles
    ;; Set the fireball position just in front of the grub actor.
    lda #8  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    ;; Set the fireball aim angle based on which way the grub is facing.
    jsr Func_GetRandomByte  ; preserves X, returns A
    mod #$10
    rsub #0
    sta T0  ; aim angle
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    beq @shoot
    lda #$80
    sub T0  ; aim angle
    sta T0  ; aim angle
    @shoot:
    ;; Shoot the fireball.
    stx T3  ; grub actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @restoreX
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    lda T0  ; param: aim angle ($00 for right, or $80 for left)
    jsr Func_InitActorProjFireball  ; preserves T3+
    jsr Func_PlaySfxShootFire  ; preserves T0+
    @restoreX:
    ldx T3  ; grub actor index
    @done:
    rts
_CrawlOrAttack:
    ;; If the grub is still in the middle of a crawl cycle, continue it.
    lda Ram_ActorState1_byte_arr, x  ; crawl timer
    bne FuncA_Actor_TickBadGrub_Crawl  ; preserves X
    ;; If the player avatar isn't nearby vertically, start a new crawl cycle.
    lda #8  ; param: distance above avatar
    ldy #8  ; param: distance below avatar
    jsr FuncA_Actor_IsAvatarWithinVertDistances  ; preserves X, returns C
    bcc FuncA_Actor_TickBadGrub_Crawl  ; preserves X
    ;; Start an attack cycle.
    lda #kGrubFireAttackFrames
    sta Ram_ActorState2_byte_arr, x  ; attack timer
    jmp FuncA_Actor_FaceTowardsAvatar  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a grub baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadGrub
.PROC FuncA_Actor_TickBadGrub
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    fall FuncA_Actor_TickBadGrub_Crawl  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a grub baddie actor that's crawling.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadGrub_Crawl
    lda Ram_ActorState1_byte_arr, x  ; crawl timer
    beq _StartMove
    dec Ram_ActorState1_byte_arr, x  ; crawl timer
    cmp #$18
    blt _Return
    lda Ram_ActorFlags_bObj_arr, x
    and #bObj::FlipH
    bne _MoveLeft
_MoveRight:
    inc Ram_ActorPosX_i16_0_arr, x
    bne @noCarry
    inc Ram_ActorPosX_i16_1_arr, x
    @noCarry:
    rts
_MoveLeft:
    lda Ram_ActorPosX_i16_0_arr, x
    bne @noBorrow
    dec Ram_ActorPosX_i16_1_arr, x
    @noBorrow:
    dec Ram_ActorPosX_i16_0_arr, x
_Return:
    rts
_StartMove:
    ;; Check the terrain block just in front of the grub.  If it's solid, the
    ;; grub has to turn around.
    lda #kTileWidthPx + 1  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_IsPointInAnySolidPlatform  ; preserves X, returns C
    bcs @turnAround
    jsr Func_PointHitsTerrain  ; preserves X, returns C and Y
    bcs @turnAround
    ;; Check the floor just in front of the grub.  If it's not solid, the grub
    ;; has to turn around.
    iny
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp Zp_Current_sTileset + sTileset::FirstSolidTerrainType_u8
    bge @continueForward
    ;; Make the grub face the opposite direction.
    @turnAround:
    jsr FuncA_Actor_FaceOppositeDir  ; preserves X
    ;; Start a new movement cycle for the grub.
    @continueForward:
    lda #$1f
    sta Ram_ActorState1_byte_arr, x  ; crawl timer
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a fire grub baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGrubFire
.PROC FuncA_Objects_DrawActorBadGrubFire
    lda Ram_ActorState2_byte_arr, x  ; attack timer
    beq FuncA_Objects_DrawActorBadGrub  ; preserves X
    sub #kGrubFireRiseFrames
    blt @lowering
    sub #kGrubFireAttackFrames - kGrubFireRiseFrames * 2
    bge @raising
    @fullyRaised:
    ldy #0
    beq @draw  ; unconditional
    @lowering:
    eor #$ff
    @raising:
    div #kGrubFireRiseFrames / 4
    tay
    @draw:
    lda _TileIds_u8_arr4, y  ; param: first tile ID
    ldy #kPaletteObjGrub  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr4:
    .byte kTileIdObjBadGrubFireFirst + $04
    .byte kTileIdObjBadGrubFireFirst + $00
    .byte kTileIdObjBadGrubFireFirst + $00
    .byte kTileIdObjBadGrubFirst + $04
    .byte kTileIdObjBadGrubFirst + $04
.ENDPROC

;;; Draws a grub baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadGrub
.PROC FuncA_Objects_DrawActorBadGrub
    lda Ram_ActorState1_byte_arr, x  ; crawl timer
    div #8
    and #$03
    tay
    lda _TileIds_u8_arr4, y  ; param: first tile ID
    ldy #kPaletteObjGrub  ; param: palette
    jmp FuncA_Objects_Draw2x2Actor  ; preserves X
_TileIds_u8_arr4:
    .byte kTileIdObjBadGrubFirst + $00
    .byte kTileIdObjBadGrubFirst + $04
    .byte kTileIdObjBadGrubFirst + $08
    .byte kTileIdObjBadGrubFirst + $04
.ENDPROC

;;;=========================================================================;;;
