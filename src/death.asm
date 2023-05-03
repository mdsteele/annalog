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

.INCLUDE "avatar.inc"
.INCLUDE "charmap.inc"
.INCLUDE "cpu.inc"
.INCLUDE "fade.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Objects_DrawPlayerAvatar
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeOutToBlackSlowly
.IMPORT Func_FadeToBlack
.IMPORT Func_ProcessFrame
.IMPORT Func_TransferPalettes
.IMPORT Main_Explore_SpawnInLastSafeRoom
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_PpuTransferLen_u8

;;;=========================================================================;;;

;;; How many frames the player avatar spends in each phase of its death
;;; animation.
kDeathKneelingFrames  = 45
kDeathStrainingFrames = 60
kDeathReachingFrames  = 8
kDeathStumblingFrames = 30
kDeathSlumpingFrames  = 10
kDeathSleepingFrames  = 80
.LINECONT +
kDeathTotalAvatarAnimationFrames = \
    kDeathKneelingFrames + kDeathStrainingFrames + kDeathReachingFrames + \
    kDeathStumblingFrames + kDeathSlumpingFrames + kDeathSleepingFrames
.LINECONT -

;;; How many pixels to adjust the player avatar's horizontal position by when
;;; transitioning between kneeling and sleeping modes.
kLieDownOffset = 2

;;;=========================================================================;;;

.ZEROPAGE

;;; A frame timer used for the death animation.
Zp_DeathTimer_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for when the avatar has just been killed while exploring.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.EXPORT Main_Death
.PROC Main_Death
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_FadeToBlack
_AnimateAvatar:
    lda #kDeathTotalAvatarAnimationFrames
    sta Zp_DeathTimer_u8
    lda #0
    sta Zp_AvatarHarmTimer_u8
    beq @start  ; unconditional
    @loop:
    jsr Func_ProcessFrame
    jsr_prga FuncA_Death_AnimateAvatar
    @start:
    jsr_prga FuncA_Objects_DrawPlayerAvatar
    jsr Func_ClearRestOfOam
    lda Zp_DeathTimer_u8
    bne @loop
_FadeOut:
    ldy #eFade::Normal  ; param: eFade value
    jsr Func_TransferPalettes
    jsr Func_FadeOutToBlackSlowly
_Respawn:
    ;; TODO: Show a retry/quit menu, to let player quit to the title screen.
    jmp Main_Explore_SpawnInLastSafeRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Death"

;;; Performs per-frame updates during the player avatar death animation.
.PROC FuncA_Death_AnimateAvatar
_DecrementTimer:
    dec Zp_DeathTimer_u8
    bne @done
    ;; When the timer reaches zero, set the player avatar's palette back to
    ;; normal (from kPaletteObjAvatarDeath).
    lda Zp_AvatarFlags_bObj
    and #<~bObj::PaletteMask
    ora #kPaletteObjAvatarNormal
    sta Zp_AvatarFlags_bObj
    @done:
_BlankOutBg:
    ldy Zp_DeathTimer_u8  ; param: nametable tile column index
    cpy #kScreenWidthTiles
    bge @noTransfer
    jsr FuncA_Death_TransferBlankBgTileColumn
    @noTransfer:
_SetAvatarPose:
    ;; Update the avatar pose based on the current value of the death animation
    ;; timer.
    lda Zp_DeathTimer_u8
    sec
    sbc #kDeathSleepingFrames
    beq @lieDown
    blt @sleeping
    sbc #kDeathSlumpingFrames
    blt @slumping
    sbc #kDeathStumblingFrames
    blt @kneeling
    sbc #kDeathReachingFrames
    blt @reaching
    sbc #kDeathStrainingFrames
    bge @kneeling
    ;; If the player avatar is straining, make it vibrate horizontally.
    @straining:
    div #4
    and #$01
    sta T0  ; horz vibration (0 or 1)
    lda Zp_AvatarPosX_i16 + 0
    and #$fe
    ora T0  ; horz vibration (0 or 1)
    sta Zp_AvatarPosX_i16 + 0
    lda #eAvatar::Straining
    bne @setAvatarPose  ; unconditional
    ;; If the player avatar is reaching/kneeling/slumping, just set the avatar
    ;; pose.
    @reaching:
    lda #eAvatar::Reaching
    bne @setAvatarPose  ; unconditional
    @kneeling:
    lda #eAvatar::Kneeling
    bne @setAvatarPose  ; unconditional
    @slumping:
    lda #eAvatar::Slumping
    bne @setAvatarPose  ; unconditional
    ;; If the player avatar needs to lie down, adjust its horizontal position
    ;; (to make the animation from the kneeling position more natural).
    @lieDown:
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @lieDownLeft
    @lieDownRight:
    lda #<kLieDownOffset
    ldy #0
    beq @finishLyingDown  ; unconditional
    @lieDownLeft:
    lda #<-kLieDownOffset
    ldy #$ff
    @finishLyingDown:
    add Zp_AvatarPosX_i16 + 0
    sta Zp_AvatarPosX_i16 + 0
    tya
    adc Zp_AvatarPosX_i16 + 1
    sta Zp_AvatarPosX_i16 + 1
    @sleeping:
    lda #eAvatar::Sleeping
    @setAvatarPose:
    sta Zp_AvatarPose_eAvatar
    rts
.ENDPROC

;;; Buffers a PPU transfer to blank out one tile column of terrain.
;;; @param Y The nametable tile column number to blank out.
.PROC FuncA_Death_TransferBlankBgTileColumn
    sty T0  ; nametable tile column index
    ldx Zp_PpuTransferLen_u8
_UpperNametable:
    lda #kPpuCtrlFlagsVert
    sta Ram_PpuTransfer_arr, x
    inx
    lda #>Ppu_Nametable0_sName
    sta Ram_PpuTransfer_arr, x
    inx
    .assert <Ppu_Nametable0_sName = 0, error
    tya  ; nametable tile column index
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kScreenHeightTiles
    sta Ram_PpuTransfer_arr, x
    inx
    tay  ; kScreenHeightTiles
    lda #' '
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
_LowerNametable:
    lda #kPpuCtrlFlagsVert
    sta Ram_PpuTransfer_arr, x
    inx
    lda #>Ppu_Nametable3_sName
    sta Ram_PpuTransfer_arr, x
    inx
    .assert <Ppu_Nametable3_sName = 0, error
    lda T0  ; nametable tile column index
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kTallRoomHeightTiles - kScreenHeightTiles
    sta Ram_PpuTransfer_arr, x
    inx
    tay  ; kTallRoomHeightTiles - kScreenHeightTiles
    lda #' '
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @loop
_Finish:
    stx Zp_PpuTransferLen_u8
    rts
.ENDPROC

;;;=========================================================================;;;
