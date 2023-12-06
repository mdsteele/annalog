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

.INCLUDE "../avatar.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../macros.inc"

.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_TryPushAvatarHorz
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_AvatarSubX_u8

;;;=========================================================================;;;

;;; The first terrain type index, and number of terrain types, that represent
;;; flowing sewage.  These terrain types only appear in
;;; DataA_Room_Sewer_sTileset, and range from $20 to $2f.
kTerrainTypeSewageFlowFirst = $20
kNumSewageFlowTerrainTypes  = $10

;;; The index (starting from kTerrainTypeSewageFlowFirst) of the particular
;;; sewage terrain block that splits left and right, and thus doesn't have a
;;; single flow direction for the whole block.
kBidirectionalSewageBlockIndex = 3

;;; How fast sewage pushes the player avatar, in subpixels per frame.
kSewagePushSpeed = $40
.ASSERT kSewagePushSpeed < $80, error, "kSewagePushSpeed must be a positive i8"

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Pushes the player avatar if standing in flowing sewage terrain.  This
;;; should be called from the room tick function for any room that contains
;;; animated sewage terrain that flows along a floor.
.EXPORT FuncA_Room_SewagePushAvatar
.PROC FuncA_Room_SewagePushAvatar
    ;; If the player avatar isn't standing, do nothing.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi @done
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvs @done
    ;; Get the terrain type for the block the player avatar is standing in.
    jsr Func_SetPointToAvatarCenter
    jsr Func_PointHitsTerrain  ; returns terrain type in A
    ;; Check if the terrain type is flowing sewage; if not, do nothing.
    sub #kTerrainTypeSewageFlowFirst
    blt @done
    cmp #kNumSewageFlowTerrainTypes
    bge @done
    ;; Determine the flow direction for this sewage block.
    ldy #0
    cmp #kBidirectionalSewageBlockIndex
    bne @unidirectional
    ;; One sewage terrain type in particular is special, in that it splits left
    ;; and right in the middle of the block.  So for that one, check which half
    ;; of the block the player avatar is standing in, and set the flow rate
    ;; accordingly.
    @bidirectional:
    lda Zp_AvatarPosX_i16 + 0
    and #$0f
    cmp #$08
    bge @flowRight
    @flowLeft:
    lda #<-kSewagePushSpeed
    bne @negative  ; unconditional
    @flowRight:
    lda #<kSewagePushSpeed
    bne @nonneg  ; unconditional
    ;; For most sewage terrain types, the flow rate is either always to the
    ;; left, or always to the right, or always zero.
    @unidirectional:
    tax  ; sewage type index
    lda _FlowDelta_i8_arr, x
    beq @done  ; no flow for this terrain type
    bpl @nonneg
    @negative:
    dey  ; now Y is $ff
    @nonneg:
    ;; Push the avatar.
    add Zp_AvatarSubX_u8
    sta Zp_AvatarSubX_u8
    tya  ; push speed in subpixels/frame (hi)
    adc #0
    sta Zp_AvatarPushDelta_i8
    jmp Func_TryPushAvatarHorz
    @done:
    rts
_FlowDelta_i8_arr:
:   .byte 0, 0
    .byte 0, 0
    .byte <-kSewagePushSpeed, kSewagePushSpeed
    .byte <-kSewagePushSpeed, kSewagePushSpeed
    .byte 0, 0
    .byte <-kSewagePushSpeed, kSewagePushSpeed
    .byte <-kSewagePushSpeed, kSewagePushSpeed
    .byte 0, 0
    .assert * - :- = kNumSewageFlowTerrainTypes, error
.ENDPROC

;;;=========================================================================;;;
