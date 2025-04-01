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

.INCLUDE "audio.inc"
.INCLUDE "avatar.inc"
.INCLUDE "charmap.inc"
.INCLUDE "cpu.inc"
.INCLUDE "death.inc"
.INCLUDE "fade.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Objects_DrawPlayerAvatar
.IMPORT FuncM_DrawObjectsForRoom
.IMPORT Func_AllocObjects
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeOutToBlackSlowly
.IMPORT Func_FadeToBlack
.IMPORT Func_PlaySfxThump
.IMPORT Func_ProcessFrame
.IMPORT Func_SetAndTransferFade
.IMPORT Main_Explore_SpawnInLastSafeRoom
.IMPORT Ppu_ChrObjPause
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_DeathCount_u8_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; How many frames the player avatar spends in each phase of its death
;;; animation.
kDeathStumblingFrames = 55
kDeathSlumpingFrames  = 10
kDeathSleepingFrames  = 100
.LINECONT +
kDeathTotalAvatarAnimationFrames = \
    kDeathStumblingFrames + kDeathSlumpingFrames + kDeathSleepingFrames
.LINECONT -

;;; The Zp_DeathTimer_u8 value at which the death counter digits start rolling.
kRollStartTime = 65

;;; How many pixels to adjust the player avatar's horizontal position by when
;;; transitioning between kneeling and sleeping modes.
kLieDownOffset = 2

;;; The width of the death counter, in pixels.
kDeathCountWidthPx = kTileWidthPx * kNumDeathDigits
;;; The minimum margin, in pixels, between the edge of the screen and the edge
;;; of the death counter.
kDeathCountMarginPx = $10

;;; The OBJ tile ID for the solid black squares used to hide rolling death
;;; counter digits.
kTileIdObjOpaqueBlack = $06

;;;=========================================================================;;;

.ZEROPAGE

;;; A frame timer used for the death animation.
Zp_DeathTimer_u8: .res 1

;;; Stores the number of digits that should roll during the death counter
;;; increment animation.  Usually this is 1 (if only the one's place changes),
;;; but can be more if rolling from e.g. 009 -> 010 or 099 -> 100.  If the
;;; death counter is already at its maximum value, then none of the digits will
;;; change, so this will be 0.
Zp_NumRollingDeathDigits_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for when the avatar has just been killed while exploring.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is already initialized.
.EXPORT Main_Death
.PROC Main_Death
    jsr FuncM_DrawObjectsForRoom
    jsr_prga FuncA_Cutscene_InitDeathAndFadeToBlack
_AnimateAvatar:
    jmp @start
    @loop:
    jsr Func_ProcessFrame
    jsr_prga FuncA_Cutscene_AnimateAvatarDeath
    @start:
    jsr_prga FuncA_Objects_DrawPlayerAvatar
    jsr Func_ClearRestOfOam
    lda Zp_DeathTimer_u8
    bne @loop
_FadeOut:
    ldy #eFade::Normal  ; param: eFade value
    jsr Func_SetAndTransferFade
    jsr Func_FadeOutToBlackSlowly
_Respawn:
    ;; TODO: Show a retry/quit menu, to let player quit to the title screen.
    jmp Main_Explore_SpawnInLastSafeRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Initializes death mode.
;;; @prereq Rendering is enabled.
.PROC FuncA_Cutscene_InitDeathAndFadeToBlack
    ;; Reduce music volume during death animation.
    lda #bAudio::Enable | bAudio::ReduceMusic
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
_CountNinesInDeathCounter:
    ldy #0
    @loop:
    lda Sram_DeathCount_u8_arr, y
    cmp #9
    bne @break
    iny
    cpy #kNumDeathDigits
    blt @loop
    @break:
_IncrementDeathCounter:
    ;; If the counter is already at all 9's (the max), don't increment.
    cpy #kNumDeathDigits
    bge @done
    sty T0  ; num consecutive 9's
    ldx #0
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Roll the 9's (if any) back to 0.
    txa  ; set A to zero
    beq @start  ; unconditional
    @loop:
    sta Sram_DeathCount_u8_arr, x
    inx
    @start:
    cpx T0  ; num consecutive 9's
    blt @loop
    ;; Increment the first non-nine digit.
    @incrementDigit:
    inc Sram_DeathCount_u8_arr, x
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    @done:
_InitNumRollingDeathDigits:
    ;; Store the number of digits that changed.  This is 1 + the number of
    ;; consecutive 9's, except that if the counter is all 9's (the max), then
    ;; it doesn't increment, so the number of digits changed should be zero.
    iny
    tya  ; num consecutive 9's, plus 1
    .assert kNumDeathDigits + 1 = 4, error
    mod #4
    sta Zp_NumRollingDeathDigits_u8
_InitTimers:
    lda #kDeathTotalAvatarAnimationFrames
    sta Zp_DeathTimer_u8
    lda #0
    sta Zp_AvatarHarmTimer_u8
_FadeOut:
    jsr Func_ClearRestOfOam
    jsr Func_FadeToBlack
    main_chr18_bank Ppu_ChrObjPause
    rts
.ENDPROC

;;; Performs per-frame updates during the player avatar death animation.
.PROC FuncA_Cutscene_AnimateAvatarDeath
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipV
    sta Zp_AvatarFlags_bObj
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
    jsr FuncA_Cutscene_TransferBlankBgTileColumn
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
    ;; If the player avatar is kneeling, make it vibrate horizontally.
    @kneeling:
    div #4
    and #$01
    sta T0  ; horz vibration (0 or 1)
    lda Zp_AvatarPosX_i16 + 0
    and #$fe
    ora T0  ; horz vibration (0 or 1)
    sta Zp_AvatarPosX_i16 + 0
    lda #eAvatar::Kneeling
    bne @setAvatarPose  ; unconditional
    ;; If the player avatar is slumping, just set the avatar pose.
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
    jsr Func_PlaySfxThump
    @sleeping:
    lda #eAvatar::Sleeping
    @setAvatarPose:
    sta Zp_AvatarPose_eAvatar
_DrawDeathCounter:
    lda Zp_DeathTimer_u8
    cmp #kDeathSleepingFrames
    blt FuncA_Cutscene_DrawDeathCounter
    rts
.ENDPROC

;;; Draws the decimal counter showing how many times the player avatar has
;;; died.
.PROC FuncA_Cutscene_DrawDeathCounter
_SetPosX:
    ;; Calculate the screen X-position the death counter digits.  This will
    ;; normally be centered on the player avatar's X-position, but if the
    ;; avatar dies near or past the edge of the screen, we may need to clamp
    ;; the counter position so it stays fully visible.
    lda Zp_AvatarPosX_i16 + 0
    sub Zp_RoomScrollX_u16 + 0
    sta T0  ; X-position center
    lda Zp_AvatarPosX_i16 + 1
    sbc Zp_RoomScrollX_u16 + 1
    bmi @clampLeft
    bne @clampRight
    lda T0  ; X-position center
    cmp #kDeathCountMarginPx + kDeathCountWidthPx / 2
    blt @clampLeft
    cmp #kScreenWidthPx - kDeathCountMarginPx - kDeathCountWidthPx / 2
    blt @noClamp
    @clampRight:
    lda #kScreenWidthPx - kDeathCountMarginPx - kDeathCountWidthPx
    bne @setLeftPos  ; unconditional
    @clampLeft:
    lda #kDeathCountMarginPx
    .assert kDeathCountMarginPx > 0, error
    bne @setLeftPos  ; unconditional
    @noClamp:
    sub #kDeathCountWidthPx / 2
    @setLeftPos:
    sta T0  ; X-position left
_SetBasePosY:
    ;; Calculate the screen Y-position of the top of the visible row of digits.
    ;; This will normally be just above the player avatar, but place it just
    ;; below instead if the avatar is near the top of the screen.
    lda Zp_AvatarPosY_i16 + 0
    sub Zp_RoomScrollY_u8
    cmp #kScreenHeightPx / 4
    blt @placeBelowAvatar
    @placeAboveAvatar:
    sub #kTileHeightPx * 2
    bne @setYPos  ; unconditional
    @placeBelowAvatar:
    add #kTileHeightPx * 2
    @setYPos:
    sta T1  ; base Y-position
_SetRollingPosY:
    ;; Calculate the screen Y-position of the top of the rolling digits.  This
    ;; starts out as offset from the base Y-position (so that the previous
    ;; digit(s) are shown), but animates to match the base Y-position:
    ;;   rollPosY = basePosY + min(max(0, timer - rollEndTime), kTileHeightPx)
    lda Zp_DeathTimer_u8
    sub #kRollStartTime - kTileHeightPx
    blt @rollZero
    cmp #kTileHeightPx
    blt @setRoll
    @rollMax:
    lda #kTileHeightPx
    bne @setRoll  ; unconditional
    @rollZero:
    lda #0
    @setRoll:
    add T1  ; base Y-position
    sta T2  ; rolling Y-position
_DrawDigits:
    ;; Each digit of the counter needs 4 objects: the new digit, the previous
    ;; digit to roll from, and two "curtain" objects above and below to cover
    ;; up the rolling digits.
    lda #kNumDeathDigits * 4  ; param: num objects
    jsr Func_AllocObjects  ; preserves T0+ returns Y
    ldx #kNumDeathDigits - 1  ; digit index (starting with highest place)
    @loop:
    ;; Set objects' X-position.
    lda T0  ; X-position
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta T0  ; X-position
    ;; Set curtains' Y-positions.
    lda T1  ; base Y-position
    sub #kTileHeightPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    add #kTileHeightPx * 2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    ;; Set digits' Y-positions.
    cpx Zp_NumRollingDeathDigits_u8
    blt @rolling
    @notRolling:
    lda T1  ; base Y-position
    bne @setYPos  ; unconditional
    @rolling:
    lda T2  ; rolling Y-position
    @setYPos:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    sub #kTileHeightPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    ;; Set objects' flags.
    lda Zp_AvatarFlags_bObj
    and #bObj::PaletteMask
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    ;; Set curtains' tile ID.
    lda #kTileIdObjOpaqueBlack
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    ;; Set digits' tile IDs.
    lda Sram_DeathCount_u8_arr, x
    .assert '0' .mod $10 = 0, error
    ora #$80 | '0'
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sub #1
    cmp #$80 | '0'
    bge @noWrap
    lda #$80 | '9'
    @noWrap:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    ;; Continue to the next-lower digit.
    tya
    add #.sizeof(sObj) * 4
    tay
    dex
    bpl @loop
    rts
.ENDPROC

;;; Buffers a PPU transfer to blank out one tile column of terrain.
;;; @param Y The nametable tile column number to blank out.
.EXPORT FuncA_Cutscene_TransferBlankBgTileColumn
.PROC FuncA_Cutscene_TransferBlankBgTileColumn
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
