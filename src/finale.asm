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
.INCLUDE "devices/console.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Cutscene_TransferBlankBgTileColumn
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
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

;;; Various steps of the three finales.  Each step represents a particular
;;; cutscene in a particular room.
.ENUM eFinale
    GaveRemote1Outdoors
    Reactivate1Outdoors  ; ground splits open, Anna emerges riding the core
    Reactivate2Sky       ; Anna rides the core into the sky
    Reactivate3Outdoors  ; Thurg comes out of the town hall and sees the core
    Reactivate4Sky       ; Jerome's recorded message begins to play
    Reactivate5Outdoors  ; Thurg and the other orc protest, but get laser-ed
    Reactivate6Sky       ; Jerome's recorded message concludes
    YearsLater1Outdoors
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.ZEROPAGE

;;; The current step of the finale.
Zp_Current_eFinale: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Fades out the screen, increments Zp_Current_eFinale, and begins the next
;;; finale step, starting the next cutscene after loading and entering its
;;; room.
;;; @prereq Zp_Current_eFinale is initialized.
;;; @prereq Rendering is enabled.
.EXPORT Main_Finale_StartNextStep
.PROC Main_Finale_StartNextStep
    jsr Func_FadeOutToBlack
    ldy Zp_Current_eFinale
    iny  ; param: finale step to start
    fall Main_Finale_SetAndStartStep
.ENDPROC

;;; Sets Zp_Current_eFinale to the specified step and begins that finale step,
;;; starting its cutscene after loading and entering its room.
;;; @prereq Rendering is disabled.
;;; @param Y The eFinale value for the finale step to run.
.PROC Main_Finale_SetAndStartStep
    sty Zp_Current_eFinale
    jsr_prga FuncA_Cutscene_GetFinaleCutsceneRoomAndMusic  ; returns X and Y
    jsr FuncM_SwitchPrgcAndLoadRoomWithMusic
    jmp_prga MainA_Cutscene_EnterFinaleCutsceneRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

;;; Mode for transitioning to the cutscene that plays in TownOutdoors after
;;; giving the B-Remote to Gronta.
;;; @prereq Rendering is enabled.
.EXPORT MainA_Cutscene_FinaleGaveRemote
.PROC MainA_Cutscene_FinaleGaveRemote
    jsr Func_FadeOutToBlackSlowly
    ldy #eFinale::GaveRemote1Outdoors  ; param: finale step to run
    jmp Main_Finale_SetAndStartStep
.ENDPROC

;;; Mode for transitioning to the cutscene that plays in TownOutdoors after
;;; reactivating the complex.
;;; @prereq Rendering is enabled.
.EXPORT MainA_Cutscene_FinaleReactivate
.PROC MainA_Cutscene_FinaleReactivate
    jsr Func_FadeOutToBlackSlowly
    ldy #eFinale::Reactivate1Outdoors  ; param: finale step to run
    jmp Main_Finale_SetAndStartStep
.ENDPROC

;;; Sets Zp_Next_eCutscene for the specified finale step, and returns the room
;;; that the cutscene takes place in and the music to play in that room.
;;; @param Y The eFinale value for the finale step.
;;; @return X The eRoom value for the cutscene room.
;;; @return Y The eMusic value for the music to play in the cutscene room.
.PROC FuncA_Cutscene_GetFinaleCutsceneRoomAndMusic
    ;; Set up the cutscene.
    lda _Finale_eCutscene_arr, y
    sta Zp_Next_eCutscene
    ;; Return the eRoom value for the room the cutscene takes place in.
    ldx _Finale_eRoom_arr, y
    ldy #eMusic::Silence
    rts
_Finale_eCutscene_arr:
    D_ARRAY .enum, eFinale
    d_byte GaveRemote1Outdoors, eCutscene::TownOutdoorsGaveRemote
    d_byte Reactivate1Outdoors, eCutscene::TownOutdoorsFinaleReactivate1
    d_byte Reactivate2Sky,      eCutscene::TownSkyFinaleReactivate2
    d_byte Reactivate3Outdoors, eCutscene::TownOutdoorsFinaleReactivate3
    d_byte Reactivate4Sky,      eCutscene::TownSkyFinaleReactivate4
    d_byte Reactivate5Outdoors, eCutscene::TownOutdoorsFinaleReactivate5
    d_byte Reactivate6Sky,      eCutscene::TownSkyFinaleReactivate6
    d_byte YearsLater1Outdoors, eCutscene::TownOutdoorsYearsLater
    D_END
_Finale_eRoom_arr:
    D_ARRAY .enum, eFinale
    d_byte GaveRemote1Outdoors, eRoom::TownOutdoors
    d_byte Reactivate1Outdoors, eRoom::TownOutdoors
    d_byte Reactivate2Sky,      eRoom::TownSky
    d_byte Reactivate3Outdoors, eRoom::TownOutdoors
    d_byte Reactivate4Sky,      eRoom::TownSky
    d_byte Reactivate5Outdoors, eRoom::TownOutdoors
    d_byte Reactivate6Sky,      eRoom::TownSky
    d_byte YearsLater1Outdoors, eRoom::TownOutdoors
    D_END
.ENDPROC

;;; Sets up the avatar and room scrolling for the current finale step's
;;; cutscene, then jumps to Main_Explore_EnterRoom.
;;; @prereq Zp_Current_eFinale is initialized.
;;; @prereq Rendering is disabled.
;;; @prereq Static room data is loaded.
.PROC MainA_Cutscene_EnterFinaleCutsceneRoom
    ;; Position the (hidden) player avatar so as to make the room scroll
    ;; position be what we want.  (We don't want to do this by locking
    ;; scrolling, because we want e.g. the vertical scroll to be able to shift
    ;; while the dialog window is open.)
    ldy Zp_Current_eFinale
    lda _AvatarPosX_i16_0_arr, y
    sta Zp_AvatarPosX_i16 + 0
    lda _AvatarPosX_i16_1_arr, y
    sta Zp_AvatarPosX_i16 + 1
    lda _AvatarPosY_i16_0_arr, y
    sta Zp_AvatarPosY_i16 + 0
    lda #0
    sta Zp_AvatarPosY_i16 + 1
    lda _AvatarFlags_bObj_arr, y
    sta Zp_AvatarFlags_bObj
    lda _AvatarPose_eAvatar_arr, y
    sta Zp_AvatarPose_eAvatar
    jmp Main_Explore_EnterRoom
_AvatarPosX_i16_0_arr:
    D_ARRAY .enum, eFinale
    d_byte GaveRemote1Outdoors, $10
    d_byte Reactivate1Outdoors, $10
    d_byte Reactivate2Sky,      $b0
    d_byte Reactivate3Outdoors, $80
    d_byte Reactivate4Sky,      $b0
    d_byte Reactivate5Outdoors, $80
    d_byte Reactivate6Sky,      $b8 + kConsoleAvatarOffset
    d_byte YearsLater1Outdoors, $18
    D_END
_AvatarPosX_i16_1_arr:
    D_ARRAY .enum, eFinale
    d_byte GaveRemote1Outdoors, $03
    d_byte Reactivate1Outdoors, $03
    d_byte Reactivate2Sky,      $00
    d_byte Reactivate3Outdoors, $02
    d_byte Reactivate4Sky,      $00
    d_byte Reactivate5Outdoors, $02
    d_byte Reactivate6Sky,      $00
    d_byte YearsLater1Outdoors, $03
    D_END
_AvatarPosY_i16_0_arr:
    D_ARRAY .enum, eFinale
    d_byte GaveRemote1Outdoors, $c8
    d_byte Reactivate1Outdoors, $c8
    d_byte Reactivate2Sky,      $ca
    d_byte Reactivate3Outdoors, $c8
    d_byte Reactivate4Sky,      $80
    d_byte Reactivate5Outdoors, $28  ; high up, to avoid actor collisions
    d_byte Reactivate6Sky,      $80
    d_byte YearsLater1Outdoors, $c8
    D_END
_AvatarPose_eAvatar_arr:
    D_ARRAY .enum, eFinale
    d_byte GaveRemote1Outdoors, eAvatar::Hidden
    d_byte Reactivate1Outdoors, eAvatar::Hidden
    d_byte Reactivate2Sky,      eAvatar::Standing
    d_byte Reactivate3Outdoors, eAvatar::Hidden
    d_byte Reactivate4Sky,      eAvatar::Standing
    d_byte Reactivate5Outdoors, eAvatar::Hidden
    d_byte Reactivate6Sky,      eAvatar::Reading
    d_byte YearsLater1Outdoors, eAvatar::Hidden
    D_END
_AvatarFlags_bObj_arr:
    D_ARRAY .enum, eFinale
    d_byte GaveRemote1Outdoors, kPaletteObjAvatarNormal | 0
    d_byte Reactivate1Outdoors, kPaletteObjAvatarNormal | bObj::FlipH
    d_byte Reactivate2Sky,      kPaletteObjAvatarNormal | bObj::FlipH
    d_byte Reactivate3Outdoors, kPaletteObjAvatarNormal | bObj::FlipH
    d_byte Reactivate4Sky,      kPaletteObjAvatarNormal | bObj::FlipH
    d_byte Reactivate5Outdoors, kPaletteObjAvatarNormal | bObj::FlipH
    d_byte Reactivate6Sky,      kPaletteObjAvatarNormal | 0
    d_byte YearsLater1Outdoors, kPaletteObjAvatarNormal | 0
    D_END
.ENDPROC

;;; The PPU transfer entry for drawing the self-destruct finale "years later"
;;; text.
.PROC DataA_Cutscene_YearsLaterTextTransfer_arr
    .linecont +
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
          kScreenWidthTiles * 14 + (kScreenWidthTiles - 20) / 2
    .byte 20
:   .byte "Seven years later..."
    .assert * - :- = 20, error
    .linecont -
.ENDPROC

;;; Mode for displaying the "years later" text as part of the self-destruct
;;; finale, before switching to the "years later" cutscene.
;;; @prereq Rendering is enabled.
;;; @prereq The current fade level is eFade::White.
.EXPORT MainA_Cutscene_FinaleYearsLater
.PROC MainA_Cutscene_FinaleYearsLater
    jsr FuncA_Cutscene_FinaleYearsLater
    ldy #eFinale::YearsLater1Outdoors  ; param: finale step to run
    jmp Main_Finale_SetAndStartStep
.ENDPROC

;;; Displays the "years later" text, then fades out the screen.
;;; @prereq Rendering is enabled.
;;; @prereq The current fade level is eFade::White.
.PROC FuncA_Cutscene_FinaleYearsLater
_BlankOutBg:
    ldy #kScreenWidthTiles - 1
    @loop:
    tya  ; loop counter
    pha  ; loop counter
    jsr FuncA_Cutscene_TransferBlankBgTileColumn
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
    ldax #DataA_Cutscene_YearsLaterTextTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Cutscene_YearsLaterTextTransfer_arr)  ; param: data len
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
    jmp Func_FadeOutToBlack
.ENDPROC

;;;=========================================================================;;;
