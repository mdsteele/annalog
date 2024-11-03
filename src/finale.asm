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
.INCLUDE "cutscene.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Death_TransferBlankBgTileColumn
.IMPORT FuncM_SwitchPrgcAndLoadRoomWithMusic
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeInFromBlackToNormal
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FadeOutToBlackSlowly
.IMPORT Func_ProcessFrame
.IMPORT Func_WaitXFrames
.IMPORT Main_Explore_EnterRoom
.IMPORT Ppu_ChrBgFontUpper
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for transitioning to the cutscene that plays in TownOutdoors after
;;; giving the B-Remote to Gronta.
;;; @prereq Rendering is enabled.
.EXPORT Main_Finale_GaveRemote
.PROC Main_Finale_GaveRemote
    jsr Func_FadeOutToBlackSlowly
    ldx #eRoom::TownOutdoors  ; param: room to load
    ldy #eMusic::Silence  ; param: music to play
    jsr FuncM_SwitchPrgcAndLoadRoomWithMusic
    jmp_prga MainA_Death_EnterFinaleGaveRemoteCutsceneRoom
.ENDPROC

;;; Mode for displaying the "years later" text as part of the self-destruct
;;; finale, before switching to the "years later" cutscene.
;;; @prereq Rendering is enabled.
;;; @prereq The current fade level is eFade::White.
.EXPORT Main_Finale_YearsLater
.PROC Main_Finale_YearsLater
    jsr_prga FuncA_Death_FinaleYearsLater  ; returns X and Y (params)
    jsr FuncM_SwitchPrgcAndLoadRoomWithMusic
    jmp_prga MainA_Death_EnterFinaleYearsLaterCutsceneRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Death"

;;; The PPU transfer entry for drawing the self-destruct finale "years later"
;;; text.
.PROC DataA_Death_YearsLaterTextTransfer_arr
    .linecont +
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
          kScreenWidthTiles * 14 + (kScreenWidthTiles - 20) / 2
    .byte 20
:   .byte "Seven years later..."
    .assert * - :- = 20, error
    .linecont -
.ENDPROC

;;; Displays the "years later" text, then fades out the screen.
;;; @prereq Rendering is enabled.
;;; @prereq The current fade level is eFade::White.
;;; @return X The eRoom value for the cutscene room.
;;; @return Y The eMusic value for the music to play in the cutscene room.
.PROC FuncA_Death_FinaleYearsLater
_BlankOutBg:
    ldy #kScreenWidthTiles - 1
    @loop:
    tya  ; loop counter
    pha  ; loop counter
    jsr FuncA_Death_TransferBlankBgTileColumn
    jsr Func_ProcessFrame
    pla  ; loop counter
    tay  ; loop counter
    dey
    .assert kScreenWidthTiles <= $80, error
    bpl @loop
_FadeOutFromWhite:
    jsr Func_ClearRestOfOam
    jsr Func_FadeOutToBlack
_DrawText:
    lda #<.bank(Ppu_ChrBgFontUpper)
    sta Zp_Chr04Bank_u8
    ldax #DataA_Death_YearsLaterTextTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Death_YearsLaterTextTransfer_arr)  ; param: data length
    jsr Func_BufferPpuTransfer
    ldx #45  ; param: num frames
    jsr Func_WaitXFrames
_FadeInText:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jsr Func_FadeInFromBlackToNormal
_FadeOutText:
    ldx #150  ; param: num frames
    jsr Func_WaitXFrames
    jsr Func_FadeOutToBlack
_ReturnRoomAndMusic:
    ;; Return the cutscene room and music to load.
    ldx #eRoom::TownOutdoors
    ldy #eMusic::Silence
    rts
.ENDPROC

;;; Sets up the avatar, room scrolling, and next cutscene for the "years later"
;;; cutscene, then jumps to Main_Explore_EnterRoom.
;;; @prereq Rendering is disabled.
;;; @prereq Static room data is loaded.
.PROC MainA_Death_EnterFinaleYearsLaterCutsceneRoom
    ;; Hide the player avatar.
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    ;; Position the (hidden) player avatar so as to make the room scroll
    ;; position be what we want.  (We don't want to do this by locking
    ;; scrolling, because we want e.g. the vertical scroll to be able to shift
    ;; while the dialog window is open.)
    ldax #$0560
    stax Zp_AvatarPosX_i16
    ldax #$00c8
    stax Zp_AvatarPosY_i16
    ;; Enter the room and start the cutscene.
    lda #eCutscene::TownOutdoorsYearsLater
    sta Zp_Next_eCutscene
    jmp Main_Explore_EnterRoom
.ENDPROC

;;; Sets up the avatar, room scrolling, and next cutscene for the "gave remote"
;;; cutscene, then jumps to Main_Explore_EnterRoom.
;;; @prereq Rendering is disabled.
;;; @prereq Static room data is loaded.
.PROC MainA_Death_EnterFinaleGaveRemoteCutsceneRoom
    ;; Hide the player avatar.
    lda #eAvatar::Hidden
    sta Zp_AvatarPose_eAvatar
    ;; Position the (hidden) player avatar so as to make the room scroll
    ;; position be what we want.  (We don't want to do this by locking
    ;; scrolling, because we want e.g. the vertical scroll to be able to shift
    ;; while the dialog window is open.)
    ldax #$02c4
    stax Zp_AvatarPosX_i16
    ldax #$00c8
    stax Zp_AvatarPosY_i16
    ;; Enter the room and start the cutscene.
    lda #eCutscene::TownOutdoorsGaveRemote
    sta Zp_Next_eCutscene
    jmp Main_Explore_EnterRoom
.ENDPROC

;;;=========================================================================;;;
