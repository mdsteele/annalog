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

.INCLUDE "actors/orc.inc"
.INCLUDE "audio.inc"
.INCLUDE "charmap.inc"
.INCLUDE "death.inc"
.INCLUDE "epilogue.inc"
.INCLUDE "fade.inc"
.INCLUDE "flag.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "rooms/boss_city.inc"
.INCLUDE "rooms/boss_crypt.inc"
.INCLUDE "rooms/boss_garden.inc"
.INCLUDE "rooms/boss_lava.inc"
.INCLUDE "rooms/boss_mine.inc"
.INCLUDE "rooms/boss_shadow.inc"
.INCLUDE "rooms/boss_temple.inc"
.INCLUDE "tileset.inc"
.INCLUDE "timer.inc"

.IMPORT DataA_Room_Building_sTileset
.IMPORT DataA_Room_Core_sTileset
.IMPORT DataA_Room_Crypt_sTileset
.IMPORT DataA_Room_Garden_sTileset
.IMPORT DataA_Room_Lava_sTileset
.IMPORT DataA_Room_Mine_sTileset
.IMPORT DataA_Room_Shadow_sTileset
.IMPORT DataA_Room_Temple_sTileset
.IMPORT DataA_Terrain_GardenUpperLeft_u8_arr
.IMPORT FuncA_Objects_DrawShapeTiles
.IMPORT FuncC_Title_ClearNametableTiles
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_DirectPpuTransfer
.IMPORT Func_DivMod
.IMPORT Func_FadeInFromBlackToNormal
.IMPORT Func_FadeOutToBlackSlowly
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_IsFlagSet
.IMPORT Func_ProcessFrame
.IMPORT Func_SetAndTransferFade
.IMPORT Func_Window_Disable
.IMPORT MainC_Title_Menu
.IMPORT Ppu_ChrBgAnimA0
.IMPORT Ppu_ChrBgAnimB0
.IMPORT Ppu_ChrBgAnimB4
.IMPORT Ppu_ChrBgBossCity
.IMPORT Ppu_ChrBgFontUpper
.IMPORT Ppu_ChrObjBoss1
.IMPORT Ppu_ChrObjBoss2
.IMPORT Ppu_ChrObjBoss3
.IMPORT Ppu_ChrObjMine
.IMPORT Ppu_ChrObjPause
.IMPORT Ppu_ChrObjShadow1
.IMPORT Sram_DeathCount_u8_arr
.IMPORT Sram_ExploreTimer_u8_arr
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_Current_sTileset
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; For this file only, remap capital letters to CHR0C instead of CHR04, so
;;; that CHR04 can be used for animated terrain without needing to use IRQs to
;;; switch CHR banks midframe.
.CHARMAP $2e, $c3  ; '.'
.CHARMAP $2f, $c7  ; '/'
.CHARMAP $41, $e0  ; 'A'
.CHARMAP $42, $e1  ; 'B'
.CHARMAP $43, $e2  ; 'C'
.CHARMAP $44, $e3  ; 'D'
.CHARMAP $45, $e4  ; 'E'
.CHARMAP $46, $e5  ; 'F'
.CHARMAP $47, $e6  ; 'G'
.CHARMAP $48, $e7  ; 'H'
.CHARMAP $49, $e8  ; 'I'
.CHARMAP $4a, $e9  ; 'J'
.CHARMAP $4b, $ea  ; 'K'
.CHARMAP $4c, $eb  ; 'L'
.CHARMAP $4d, $ec  ; 'M'
.CHARMAP $4e, $ed  ; 'N'
.CHARMAP $4f, $ee  ; 'O'
.CHARMAP $50, $ef  ; 'P'
.CHARMAP $51, $f0  ; 'Q'
.CHARMAP $52, $f1  ; 'R'
.CHARMAP $53, $f2  ; 'S'
.CHARMAP $54, $f3  ; 'T'
.CHARMAP $55, $f4  ; 'U'
.CHARMAP $56, $f5  ; 'V'
.CHARMAP $57, $f6  ; 'W'
.CHARMAP $58, $f7  ; 'X'
.CHARMAP $59, $f8  ; 'Y'
.CHARMAP $5a, $f9  ; 'Z'

;;;=========================================================================;;;

;;; The number of individual "scenes" in a given epilogue sequence.
kEpilogueNumScenes = 18

;;; The duration, in frames, of one epilogue scene.  This is equal in duration
;;; to two measures (eight beats) of the epilogue music, where each beat is 24
;;; frames long (this should match the tempo in src/music/epilogue.sng).
kEpilogueSceneFrames = 24 * 8

;;; The nametable tile rows for boss descriptions and names.
kBossDescRow = 9
kBossNameRow = 20

;;; The nametable tile row that epilogue terrain (if any) starts on.
kEpilogueTerrainStartRow = 11

;;; The PPU address for the top-left corner of the epilogue terrain.
.LINECONT +
Ppu_EpilogueTerrainStart = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kEpilogueTerrainStartRow
.LINECONT -

;;;=========================================================================;;;

;;; The tile row/col in the upper nametable for the top-left corner of boss 2's
;;; BG tiles.
kBoss2StartRow = 14
kBoss2StartCol = 11

;;; The PPU addresses for the start (left) of each row of boss 2's BG tiles.
.LINECONT +
Ppu_Boss2Row0Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss2StartRow + 0) + kBoss2StartCol
Ppu_Boss2Row1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss2StartRow + 1) + kBoss2StartCol
Ppu_Boss2Row2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss2StartRow + 2) + kBoss2StartCol
Ppu_Boss2Row3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss2StartRow + 3) + kBoss2StartCol
.LINECONT -

;;;=========================================================================;;;

;;; The tile row/col in the upper nametable for the top-left corner of boss 3's
;;; BG tiles.
kBoss3StartRow = 13
kBoss3StartCol = 14

;;; The PPU addresses for the start (left) of each row of boss 3's BG tiles.
.LINECONT +
Ppu_Boss3Row0Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss3StartRow + 0) + kBoss3StartCol
Ppu_Boss3Row1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss3StartRow + 1) + kBoss3StartCol
Ppu_Boss3Row2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss3StartRow + 2) + kBoss3StartCol
Ppu_Boss3Row3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss3StartRow + 3) + kBoss3StartCol
Ppu_Boss3EyeAttrs = Ppu_Nametable0_sName + sName::Attrs_u8_arr64 + \
    ((kBoss3StartRow + 1) / 4) * 8 + ((kBoss3StartCol + 2) / 4)
.LINECONT -

;;;=========================================================================;;;

;;; The tile row/col in the upper nametable for the top-left corner of boss 4's
;;; BG tiles.
kBoss4StartRow = 13
kBoss4StartCol = 12

;;; The PPU addresses for the start (left) of each row of boss 4's BG tiles.
.LINECONT +
Ppu_Boss4Row0Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss4StartRow + 0) + kBoss4StartCol
Ppu_Boss4Row1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss4StartRow + 1) + kBoss4StartCol
Ppu_Boss4Row2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss4StartRow + 2) + kBoss4StartCol
Ppu_Boss4Row3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss4StartRow + 3) + kBoss4StartCol
.LINECONT -

;;;=========================================================================;;;

;;; The tile row/col in the upper nametable for the top-left corner of boss 5's
;;; BG tiles.
kBoss5StartRow = 13
kBoss5StartCol = 15

;;; The PPU addresses for the start (left) of each row of boss 5's BG tiles.
.LINECONT +
Ppu_Boss5Row0Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss5StartRow + 0) + kBoss5StartCol
Ppu_Boss5Row1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss5StartRow + 1) + kBoss5StartCol
Ppu_Boss5Row2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss5StartRow + 2) + kBoss5StartCol
Ppu_Boss5Row3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss5StartRow + 3) + kBoss5StartCol
Ppu_Boss5ConveyorStart = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kEpilogueTerrainStartRow + 7) + 0
.LINECONT -

;;;=========================================================================;;;

;;; The tile row/col in the upper nametable for the top-left corner of boss 6's
;;; BG tiles.
kBoss6StartRow = 12
kBoss6StartCol = 12

;;; The PPU addresses for the start (left) of each row of boss 6's BG tiles.
.LINECONT +
Ppu_Boss6Row0Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss6StartRow + 0) + kBoss6StartCol
Ppu_Boss6Row1Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss6StartRow + 1) + kBoss6StartCol
Ppu_Boss6Row2Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss6StartRow + 2) + kBoss6StartCol
Ppu_Boss6Row3Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss6StartRow + 3) + kBoss6StartCol
Ppu_Boss6Row4Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss6StartRow + 4) + kBoss6StartCol
Ppu_Boss6Row5Start = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kBoss6StartRow + 5) + kBoss6StartCol
Ppu_Boss6CoreAttrs = Ppu_Nametable0_sName + sName::Attrs_u8_arr64 + \
    ((kBoss6StartRow + 2) / 4) * 8 + ((kBoss6StartCol + 3) / 4)
.LINECONT -

;;;=========================================================================;;;

;;; The tile row in the upper nametable for each of the post-game stats.
kStatsCompletionRow = 13
kStatsDeathsRow = 15
kStatsTimeRow = 17

;;; The PPU addresses for the start (left) of the BG tiles for each of the
;;; post-game stat numbers.
.LINECONT +
Ppu_StatsCompletionStart = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kStatsCompletionRow + 20
Ppu_StatsDeathsStart = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kStatsDeathsRow + 18
Ppu_StatsTimeStart = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kStatsTimeRow + 14
.LINECONT -

;;;=========================================================================;;;

;;; Particular scenes that can play within an epilogue sequence.  Some scenes
;;; only appear in one of the epilogues, while others are shared.
.ENUM eEpilogueScene
    Title
    Credit1
    Boss1
    Credit2
    Boss2
    Credit3
    Boss3
    Credit4
    Boss4
    Credit5
    Boss5
    Credit6
    Boss6
    Credit7
    Boss7
    Credit8
    Boss8
    Dedication
    NUM_VALUES
.ENDENUM

;;; Stores static information about a single epilogue scene.
.STRUCT sEpiScene
    ;; A pointer to the tileset used for this scene's terrain (if any).
    ;; @prereq PRGA_Room is loaded.
    Terrain_sTileset_ptr    .addr
    ;; A pointer to the terrain block data for this boss, which stores 1 byte
    ;; per block in row-major order, 16 blocks wide and 5 blocks high.  If the
    ;; high byte is zero, then no terrain will be drawn.
    TerrainData_ptr         .addr
    ;; An additional offset, in tiles, to the initial nametable address when
    ;; drawing the terrain (if any).  This can be used to help visually center
    ;; the terrain on screen.
    TerrainOffset_u8        .byte
    ;; An additional set of PPU transfer entries to apply when initializing the
    ;; scene, after drawing the terrain (if any).
    Transfer_sXfer_ptr      .addr
    ;; The CHR04 bank number to set when drawing this scene.
    Chr04Bank_u8            .byte
    ;; The CHR18 bank number to set when drawing this scene.
    Chr18Bank_u8            .byte
    ;; Specifies objects to draw for this scene.  If the high byte is zero,
    ;; then no objects will be drawn.  Otherwise, these shape tiles will be
    ;; drawn, starting from an initial shape position at the top center of the
    ;; epilogue scene terrain.
    Draw_sShapeTile_arr_ptr .addr
.ENDSTRUCT

;;;=========================================================================;;;

.ZEROPAGE

;;; The epilogue sequence that's currently playing.
Zp_Current_eEpilogue: .res 1

;;; The zero-based index into the current epilogue's sequence of scenes.
Zp_EpilogueSceneIndex_u8: .res 1

;;; Use the same storage space as Zp_Current_sRoom for storing data for the
;;; current epilogue scene (since we don't need room data during the epilogue).
.ASSERT .sizeof(sEpiScene) <= .sizeof(sRoom), error
Zp_Current_sEpiScene := Zp_Current_sRoom

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for playing the epilogue.
;;; @prereq Audio is disabled.
;;; @prereq Rendering is disabled.
;;; @param X The eEpilogue value for the epilogue to play.
.EXPORT Main_Epilogue
.PROC Main_Epilogue
    jmp_prgc MainC_Title_Epilogue
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; Mode for playing the epilogue.
;;; @prereq Rendering is disabled.
;;; @param X The eEpilogue value for the epilogue to play.
.PROC MainC_Title_Epilogue
    stx Zp_Current_eEpilogue
    lda #0
    sta Zp_EpilogueSceneIndex_u8
_EnableAudio:
    lda #bAudio::Enable
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
    lda #eMusic::Epilogue
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
_SceneLoop:
    main_prga_bank DataA_Room_Garden_sTileset
    jsr FuncC_Title_LoadEpilogueScene
    main_prga_bank DataA_Terrain_GardenUpperLeft_u8_arr
    jsr FuncC_Title_InitEpilogueScene
_GameLoop:
    main_prga_bank FuncA_Objects_DrawShapeTiles
    jsr FuncC_Title_DrawEpilogueScene
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr FuncC_Title_TickEpilogueScene
    ;; Check if this epilogue scene is over yet.  Note that we subtract 1 from
    ;; kEpilogueSceneFrames here to account for the extra frame used to disable
    ;; rendering under _NextScene below.
    lda Zp_FrameCounter_u8
    cmp #kEpilogueSceneFrames - 1
    blt _GameLoop
_NextScene:
    ;; Disable rendering.
    lda #0
    sta Zp_Render_bPpuMask
    jsr Func_ProcessFrame
    ;; Advance to the next scene.
    inc Zp_EpilogueSceneIndex_u8
    lda Zp_EpilogueSceneIndex_u8
    cmp #kEpilogueNumScenes
    blt _SceneLoop
    fall MainC_Title_TheEnd
.ENDPROC

;;; Mode for the "The End" screen.
;;; @prereq Rendering is disabled.
.PROC MainC_Title_TheEnd
    ldxy #Ppu_Nametable0_sName  ; param: nametable addr
    jsr FuncC_Title_ClearNametableTiles
    ldy #$00  ; param: attribute byte
    jsr Func_FillUpperAttributeTable
    ldax #_Init_sXfer  ; param: ptr
    jsr Func_DirectPpuTransfer
_DrawTime:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    lda #>Ppu_StatsTimeStart
    sta Hw_PpuAddr_w2
    lda #<Ppu_StatsTimeStart
    sta Hw_PpuAddr_w2
    ldx #kNumTimerDigits - 1
    @loop:
    lda Sram_ExploreTimer_u8_arr, x
    add #'0'
    sta Hw_PpuData_rw
    ;; Draw an 'h' after the hours count.
    cpx #5
    bne @noH
    lda #'h'
    sta Hw_PpuData_rw
    @noH:
    ;; Draw an 'm' after the minutes count.
    cpx #3
    bne @noM
    lda #'m'
    sta Hw_PpuData_rw
    @noM:
    ;; Skip the bottom "digit", which is the subsecond frame count.
    dex
    bne @loop  ; exit loop before digit #0
_DrawPercentCompletion:
    jsr FuncC_Title_GetPercentCompletion  ; returns A (param: dividend)
    ldy #10  ; param: divisor
    jsr Func_DivMod  ; returns quotient in Y and remainder in A
    ldx #0
    cpy #10
    blt @setDigits
    ldy #0
    inx  ; now X is 1
    @setDigits:
    pha  ; percentage 1's digit
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    lda #>Ppu_StatsCompletionStart
    sta Hw_PpuAddr_w2
    lda #<Ppu_StatsCompletionStart
    sta Hw_PpuAddr_w2
    txa  ; percentage 100's digit
    add #'0'
    sta Hw_PpuData_rw
    tya  ; percentage 10's digit
    add #'0'
    sta Hw_PpuData_rw  ; percentage 10's digit
    pla  ; percentage 1's digit
    add #'0'
    sta Hw_PpuData_rw
_DrawNumDeaths:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    lda #>Ppu_StatsDeathsStart
    sta Hw_PpuAddr_w2
    lda #<Ppu_StatsDeathsStart
    sta Hw_PpuAddr_w2
    ldx #kNumDeathDigits - 1
    @loop:
    lda Sram_DeathCount_u8_arr, x
    add #'0'
    sta Hw_PpuData_rw
    dex
    bpl @loop
_FadeIn:
    main_chr0c_bank Ppu_ChrBgFontUpper
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jsr Func_Window_Disable
    jsr Func_ClearRestOfOam
    jsr Func_FadeInFromBlackToNormal
_GameLoop:
    jsr Func_ClearRestOfOamAndProcessFrame
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq _GameLoop
_FadeOut:
    jsr Func_FadeOutToBlackSlowly
    jmp MainC_Title_Menu
_Init_sXfer:
    d_xfer_text_row 8, "- ANNALOG -"
    d_xfer_text_row kStatsCompletionRow, "Completion: xxx%"
    .assert kNumDeathDigits = 3, error
    d_xfer_text_row kStatsDeathsRow, "Deaths: xxx"
    d_xfer_text_row kStatsTimeRow, "Time: HHHhMMmSSs"
    d_xfer_text_row 22, "- PRESS START -"
    d_xfer_terminator
.ENDPROC

;;; Computes the completion percentage for a completed game.
;;; @return A The completion percentage (0-100).
.PROC FuncC_Title_GetPercentCompletion
_DefeatGronta:
    ;; Defeating Gronta is worth 4% completion, while giving up the remote is
    ;; worth 3%.
    ldy #3
    lda Zp_Current_eEpilogue
    cmp #eEpilogue::OrcsAscend
    beq @setPercent
    iny
    @setPercent:
    sty T0  ; percent completion
_Flowers:
    .assert kNumFlowerFlags = 12, error
    ;; Each flower delivered earns 3% completion (36% total).
    ldx #kLastFlowerFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X and T0+, returns Z
    beq @continue
    lda T0  ; percent completion
    add #3
    sta T0  ; percent completion
    @continue:
    dex
    cpx #kFirstFlowerFlag
    bge @loop
_Papers:
    .assert kNumPaperFlags = 45, error
    ;; Each paper collected earns 1% completion (45% total).
    ldx #kLastPaperFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X and T0+, returns Z
    beq @continue
    inc T0  ; percent completion
    @continue:
    dex
    cpx #kFirstPaperFlag
    bge @loop
_Upgrades:
    .assert kNumUpgradeFlags = 15, error
    ;; Each upgrade collected earns 1% completion (15% total).
    ldx #kLastUpgradeFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X and T0+, returns Z
    beq @continue
    inc T0  ; percent completion
    @continue:
    dex
    cpx #kFirstUpgradeFlag
    bge @loop
_Finish:
    lda T0  ; percent completion
    rts
.ENDPROC

.PROC DataC_Title_Title_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 15, "ANNALOG"
    d_xfer_attr_upper $1b, 2, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Boss1_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr TerrainData_ptr, _TerrainData
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgAnimA0) + 1
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss1)
    d_addr Draw_sShapeTile_arr_ptr, _Draw_sShapeTile_arr
    D_END
_TerrainData:
:   .incbin "out/epilogue/boss1.epi"
    .assert * - :- = 16 * 5, error
_Transfer_sXfer:
    d_xfer_text_row kBossDescRow, "Carnivorous Overgrowth"
    d_xfer_text_row kBossNameRow, "POLYCLOPS"
    d_xfer_terminator
_Draw_sShapeTile_arr:
    ;; Left-hand large eye:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * -4)
    d_byte DeltaY_i8, <(kTileHeightPx * 1)
    d_byte Flags_bObj, kPaletteObjBossGardenEye
    d_byte Tile_u8, kTileIdObjBossGardenEyeWhiteFirst + 4
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * 0)
    d_byte DeltaY_i8, <(kTileHeightPx * 1)
    d_byte Flags_bObj, kPaletteObjBossGardenEye
    d_byte Tile_u8, kTileIdObjBossGardenEyeWhiteFirst + 5
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * 1)
    d_byte DeltaY_i8, <(kTileHeightPx * -1)
    d_byte Flags_bObj, kPaletteObjBossGardenEye | bObj::FlipH
    d_byte Tile_u8, kTileIdObjBossGardenEyeWhiteFirst + 4
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * 0)
    d_byte DeltaY_i8, <(kTileHeightPx * 1)
    d_byte Flags_bObj, kPaletteObjBossGardenEye | bObj::FlipH
    d_byte Tile_u8, kTileIdObjBossGardenEyeWhiteFirst + 5
    D_END
    ;; Right-hand large eye:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * 5)
    d_byte DeltaY_i8, <(kTileHeightPx * 3)
    d_byte Flags_bObj, kPaletteObjBossGardenEye
    d_byte Tile_u8, kTileIdObjBossGardenEyeWhiteFirst + 10
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * 0)
    d_byte DeltaY_i8, <(kTileHeightPx * 1)
    d_byte Flags_bObj, kPaletteObjBossGardenEye
    d_byte Tile_u8, kTileIdObjBossGardenEyeWhiteFirst + 11
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * 1)
    d_byte DeltaY_i8, <(kTileHeightPx * -1)
    d_byte Flags_bObj, kPaletteObjBossGardenEye | bObj::FlipH
    d_byte Tile_u8, kTileIdObjBossGardenEyeWhiteFirst + 10
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(kTileWidthPx * 0)
    d_byte DeltaY_i8, <(kTileHeightPx * 1)
    d_byte Flags_bObj, kPaletteObjBossGardenEye | bObj::FlipH
    d_byte Tile_u8, kTileIdObjBossGardenEyeWhiteFirst + 11
    D_END
    ;; Right-hand mini eyes:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, <-$18
    d_byte Flags_bObj, kPaletteObjBossGardenEye
    d_byte Tile_u8, kTileIdObjBossGardenEyeMiniFirst + 0
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, $28
    d_byte DeltaY_i8, $10
    d_byte Flags_bObj, kPaletteObjBossGardenEye
    d_byte Tile_u8, kTileIdObjBossGardenEyeMiniFirst + 1
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-$08
    d_byte DeltaY_i8, <-$28
    d_byte Flags_bObj, kPaletteObjBossGardenEye
    d_byte Tile_u8, kTileIdObjBossGardenEyeMiniFirst + 0
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-$08
    d_byte DeltaY_i8, $10
    d_byte Flags_bObj, kPaletteObjBossGardenEye
    d_byte Tile_u8, kTileIdObjBossGardenEyeMiniFirst + 2
    D_END
    ;; Left-hand mini eye:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-$30
    d_byte DeltaY_i8, <-$08
    d_byte Flags_bObj, kPaletteObjBossGardenEye | bObj::Final
    d_byte Tile_u8, kTileIdObjBossGardenEyeMiniFirst + 3
    D_END
.ENDPROC

.PROC DataC_Title_Boss2_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr TerrainData_ptr, _TerrainData
    d_byte TerrainOffset_u8, 1
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgAnimB4) + 2
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss2)
    d_addr Draw_sShapeTile_arr_ptr, _Draw_sShapeTile_arr
    D_END
_TerrainData:
:   .incbin "out/epilogue/boss2.epi"
    .assert * - :- = 16 * 5, error
_Transfer_sXfer:
    d_xfer_text_row kBossDescRow, "Mutant Abomination"
    d_xfer_text_row kBossNameRow, "OUTBREAK"
    ;; Boss row 0:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss2Row0Start
    .assert kTileIdBgAnimOutbreakFirst = $48, error
    d_xfer_data $48, $49, $4a, $4b, $4c, $4d, $4e, $4f, $50, $51
    ;; Boss row 1:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss2Row1Start
    d_xfer_data $52, $53, $54, $55, $56, $57, $58, $59, $5a, $5b
    ;; Boss row 2:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss2Row2Start
    d_xfer_data $5c, $5d, $5e, $5f, $60, $61, $62, $63, $64, $65
    ;; Boss row 3:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss2Row3Start
    d_xfer_data $66, $67, $68, $69, $6a, $6b, $6c, $6d, $6e, $6f
    d_xfer_terminator
_Draw_sShapeTile_arr:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-kTileWidthPx
    d_byte DeltaY_i8, $10
    d_byte Flags_bObj, kPaletteObjOutbreakBrain
    d_byte Tile_u8, kTileIdObjOutbreakBrainFirst + 1
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjOutbreakBrain | bObj::FlipH
    d_byte Tile_u8, kTileIdObjOutbreakBrainFirst + 1
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-$2c
    d_byte DeltaY_i8, 8
    d_byte Flags_bObj, kPaletteObjOutbreakClaw | bObj::FlipH
    d_byte Tile_u8, kTileIdObjOutbreakClaw
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, kTileHeightPx * 3
    d_byte Flags_bObj, kPaletteObjOutbreakClaw | bObj::FlipHV
    d_byte Tile_u8, kTileIdObjOutbreakClaw
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, $2c + $24
    d_byte DeltaY_i8, <(kTileHeightPx * -3)
    d_byte Flags_bObj, kPaletteObjOutbreakClaw
    d_byte Tile_u8, kTileIdObjOutbreakClaw
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, <(kTileHeightPx * 3)
    d_byte Flags_bObj, kPaletteObjOutbreakClaw | bObj::FlipV
    d_byte Tile_u8, kTileIdObjOutbreakClaw
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <(-$24 - 4)
    d_byte DeltaY_i8, 6
    d_byte Flags_bObj, kPaletteObjOutbreakEye
    d_byte Tile_u8, kTileIdObjOutbreakEyeFirst + 3
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-$10
    d_byte DeltaY_i8, <-6
    d_byte Flags_bObj, kPaletteObjOutbreakEye
    d_byte Tile_u8, kTileIdObjOutbreakEyeFirst + 2
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, $20
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjOutbreakEye | bObj::Final
    d_byte Tile_u8, kTileIdObjOutbreakEyeFirst + 1
    D_END
.ENDPROC

.PROC DataC_Title_Boss3_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Crypt_sTileset
    d_addr TerrainData_ptr, _TerrainData
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgAnimB0) + 1
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss1)
    d_addr Draw_sShapeTile_arr_ptr, _Draw_sShapeTile_arr
    D_END
_TerrainData:
:   .incbin "out/epilogue/boss3.epi"
    .assert * - :- = 16 * 5, error
_Transfer_sXfer:
    d_xfer_text_row kBossDescRow, "Cryptic Fiend"
    d_xfer_text_row kBossNameRow, "DOOMGAZE"
    ;; Boss row 0:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss3Row0Start
    .assert kTileIdBgAnimBossCryptFirst = $48, error
    d_xfer_data $48, $49, $4a, $4b, $4c, $4d
    ;; Boss row 1:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss3Row1Start
    .assert kTileIdBgBossCryptEyeWhiteFirst = $a4, error
    d_xfer_data $4e, $4f, $a8, $aa, $50, $51
    ;; Boss row 2:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss3Row2Start
    .assert kTileIdBgBossCryptEyeWhiteFirst = $a4, error
    d_xfer_data $58, $59, $a9, $ab, $5a, $5b
    ;; Boss row 3:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss3Row3Start
    d_xfer_data $52, $53, $54, $55, $56, $57
    ;; Nametable attributes to color eyeball red:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss3EyeAttrs
    d_xfer_data $10
    d_xfer_terminator
_Draw_sShapeTile_arr:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 4
    d_byte DeltaY_i8, 28
    d_byte Flags_bObj, kPaletteObjBossCryptPupil | bObj::Final
    d_byte Tile_u8, kTileIdObjBossCryptPupilFirst + 0
    D_END
.ENDPROC

.PROC DataC_Title_Boss4_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Lava_sTileset
    d_addr TerrainData_ptr, _TerrainData
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgAnimB0) + 3
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss2)
    d_addr Draw_sShapeTile_arr_ptr, _Draw_sShapeTile_arr
    D_END
_TerrainData:
:   .incbin "out/epilogue/boss4.epi"
    .assert * - :- = 16 * 5, error
_Transfer_sXfer:
    d_xfer_text_row kBossDescRow, "Lavaborn Spider"
    d_xfer_text_row kBossNameRow, "PYROFUGE"
    ;; Boss row 0:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss4Row0Start
    .assert kTileIdBgAnimBossLavaFirst = $68, error
    .assert kTileIdBgTerrainBossLavaFirst = $a8, error
    d_xfer_data $68, $6c, $70, $a8, $a9, $74, $78, $7c
    ;; Boss row 1:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss4Row1Start
    d_xfer_data $69, $6d, $71, $aa, $ab, $75, $79, $7d
    ;; Boss row 2:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss4Row2Start
    d_xfer_data $6a, $6e, $72, $ac, $ad, $76, $7a, $7e
    ;; Boss row 3:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss4Row3Start
    d_xfer_data $6b, $6f, $73, $ae, $af, $77, $7b, $7f
    d_xfer_terminator
_Draw_sShapeTile_arr:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-kTileWidthPx
    d_byte DeltaY_i8, kTileHeightPx
    d_byte Flags_bObj, kPaletteObjBossLava
    d_byte Tile_u8, kTileIdObjBossLavaJawsFirst + 4
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjBossLava | bObj::FlipH
    d_byte Tile_u8, kTileIdObjBossLavaJawsFirst + 4
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-kTileWidthPx
    d_byte DeltaY_i8, kTileHeightPx * 5
    d_byte Flags_bObj, kPaletteObjBossLava
    d_byte Tile_u8, kTileIdObjBossLavaJawsFirst + 5
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, kTileWidthPx
    d_byte DeltaY_i8, 0
    d_byte Flags_bObj, kPaletteObjBossLava | bObj::FlipH | bObj::Final
    d_byte Tile_u8, kTileIdObjBossLavaJawsFirst + 5
    D_END
.ENDPROC

.PROC DataC_Title_Boss5_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr TerrainData_ptr, _TerrainData
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgAnimB4) + 2
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Draw_sShapeTile_arr_ptr, _Draw_sShapeTile_arr
    D_END
_TerrainData:
:   .incbin "out/epilogue/boss5.epi"
    .assert * - :- = 16 * 5, error
_Transfer_sXfer:
    d_xfer_text_row kBossDescRow, "Gargantuan Annelid"
    d_xfer_text_row kBossNameRow, "SALTWYRM"
    ;; Boss row 0:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss5Row0Start
    .assert kTileIdBgAnimWyrmFirst = $70, error
    d_xfer_data $70, $74, $78, $7c
    ;; Boss row 1:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss5Row1Start
    d_xfer_data $71, $75, $79, $7d
    ;; Boss row 2:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss5Row2Start
    d_xfer_data $72, $76, $7a, $7e
    ;; Boss row 3:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss5Row3Start
    d_xfer_data $73, $77, $7b, $7f
    ;; Conveyor:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss5ConveyorStart
    .assert kTileIdBgTerrainConveyorFirst = $b8, error
    d_xfer_data $b9, $b9, $b9, $b9, $b9, $bd
    d_xfer_terminator
_Draw_sShapeTile_arr:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-1
    d_byte DeltaY_i8, $18
    d_byte Flags_bObj, kPaletteObjBossMineEye | bObj::Pri
    d_byte Tile_u8, kTileIdObjBossMineEyeFirst + 0
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjBossMineEye | bObj::Pri
    d_byte Tile_u8, kTileIdObjBossMineEyeFirst + 1
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, $08
    d_byte DeltaY_i8, <-$08
    d_byte Flags_bObj, kPaletteObjBossMineEye | bObj::Pri
    d_byte Tile_u8, kTileIdObjBossMineEyeFirst + 2
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjBossMineEye | bObj::Pri | bObj::Final
    d_byte Tile_u8, kTileIdObjBossMineEyeFirst + 3
    D_END
.ENDPROC

.PROC DataC_Title_Boss6_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Building_sTileset
    d_addr TerrainData_ptr, _TerrainData
    d_byte TerrainOffset_u8, 1
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgBossCity)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss2)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_TerrainData:
:   .incbin "out/epilogue/boss6.epi"
    .assert * - :- = 16 * 5, error
_Transfer_sXfer:
    d_xfer_text_row kBossDescRow, "Antigravity Bivalve"
    d_xfer_text_row kBossNameRow, "BOMBSHELL"
    ;; Boss row 0:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss6Row0Start + 1
    .assert kTileIdBgBossCityFirst = $40, error
    d_xfer_data $5c, $5d, $5e, $5f, $60, $61
    ;; Boss row 1:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss6Row1Start
    d_xfer_data $62, $63, $40, $41, $42, $43, $64, $65
    ;; Boss row 2:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss6Row2Start + 1
    d_xfer_data $50, $51, $52, $53, $54, $55
    ;; Boss row 3:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss6Row3Start + 1
    d_xfer_data $56, $57, $58, $59, $5a, $5b
    ;; Boss row 4:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss6Row4Start
    d_xfer_data $66, $67, $44, $45, $46, $47, $68, $69
    ;; Boss row 5:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss6Row5Start + 1
    d_xfer_data $6a, $6b, $6c, $6d, $6e, $6f
    ;; Attributes:
    d_xfer_header kPpuCtrlFlagsHorz, Ppu_Boss6CoreAttrs
    d_xfer_data $50, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Boss7_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr TerrainData_ptr, _TerrainData
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgAnimA0) + 1
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjShadow1)
    d_addr Draw_sShapeTile_arr_ptr, _Draw_sShapeTile_arr
    D_END
_TerrainData:
:   .incbin "out/epilogue/boss7.epi"
    .assert * - :- = 16 * 5, error
_Transfer_sXfer:
    d_xfer_text_row kBossDescRow, "Forgotten Phantom"
    d_xfer_text_row kBossNameRow, "ALDA EGO"
    d_xfer_terminator
_Draw_sShapeTile_arr:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-$0c
    d_byte DeltaY_i8, $18
    d_byte Flags_bObj, kPaletteObjFinalGhostNormal
    d_byte Tile_u8, kTileIdObjAnnaGhostFirst + 0
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjFinalGhostNormal
    d_byte Tile_u8, kTileIdObjAnnaGhostFirst + 1
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, $08
    d_byte DeltaY_i8, <-$08
    d_byte Flags_bObj, kPaletteObjFinalGhostNormal
    d_byte Tile_u8, kTileIdObjAnnaGhostFirst + 2
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjFinalGhostNormal | bObj::Final
    d_byte Tile_u8, kTileIdObjAnnaGhostFirst + 3
    D_END
.ENDPROC

.PROC DataC_Title_Boss8_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, _TerrainData
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgAnimA0) + 1
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss3)
    d_addr Draw_sShapeTile_arr_ptr, _Draw_sShapeTile_arr
    D_END
_TerrainData:
:   .incbin "out/epilogue/boss8.epi"
    .assert * - :- = 16 * 5, error
_Transfer_sXfer:
    d_xfer_text_row kBossDescRow, "Defiant Warlord"
    d_xfer_text_row kBossNameRow, "CHIEF GRONTA"
    d_xfer_terminator
_Draw_sShapeTile_arr:
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-$08
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjGrontaHead
    d_byte Tile_u8, kTileIdObjOrcGrontaStandingFirst + $04
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjGrontaHead
    d_byte Tile_u8, kTileIdObjOrcGrontaStandingFirst + $05
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, $08
    d_byte DeltaY_i8, <-$08
    d_byte Flags_bObj, kPaletteObjGrontaHead
    d_byte Tile_u8, kTileIdObjOrcGrontaStandingFirst + $06
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjGrontaHead
    d_byte Tile_u8, kTileIdObjOrcGrontaStandingFirst + $07
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, <-$08
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjOrc
    d_byte Tile_u8, kTileIdObjOrcGrontaStandingFirst + $0c
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjOrc
    d_byte Tile_u8, kTileIdObjOrcGrontaStandingFirst + $0d
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, $08
    d_byte DeltaY_i8, <-$08
    d_byte Flags_bObj, kPaletteObjOrc
    d_byte Tile_u8, kTileIdObjOrcGrontaStandingFirst + $0e
    D_END
    D_STRUCT sShapeTile
    d_byte DeltaX_i8, 0
    d_byte DeltaY_i8, $08
    d_byte Flags_bObj, kPaletteObjOrc | bObj::Final
    d_byte Tile_u8, kTileIdObjOrcGrontaStandingFirst + $0f
    D_END
.ENDPROC

.PROC DataC_Title_Credit1_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 14, "DESIGN/PROGRAMMING"
    d_xfer_text_row 16, "Matthew Steele"
    d_xfer_attr_upper $19, 6, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Credit2_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 14, "MUSIC"
    d_xfer_text_row 16, "Jon Moran"
    d_xfer_text_row 17, "Matthew Steele"
    d_xfer_attr_upper $1b, 2, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Credit3_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 14, "ASST. ART DIRECTOR"
    d_xfer_text_row 16, "Stephanie Steele"
    d_xfer_attr_upper $19, 6, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Credit4_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 14, "BETA FEEDBACK"
    d_xfer_text_row 16, "Christopher DuBois"
    d_xfer_text_row 17, "David Couzelis"
    d_xfer_text_row 18, "Eric Chang"
    d_xfer_text_row 19, "Gus Prevas"
    d_xfer_attr_upper $1a, 4, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Credit5_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 14, "BETA FEEDBACK"
    d_xfer_text_row 16, "Jon Moran"
    d_xfer_text_row 17, "verylowsodium"
    d_xfer_text_row 18, "walkingeye"
    d_xfer_attr_upper $1a, 4, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Credit6_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 14, "MANUAL DESIGN"
    d_xfer_text_row 16, "TODO"
    d_xfer_attr_upper $1a, 4, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Credit7_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 14, "PUBLISHING"
    d_xfer_text_row 16, "TODO"
    d_xfer_attr_upper $1a, 4, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Credit8_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 14, "SPECIAL THANKS"
    d_xfer_text_row 16, "Holly and Emily"
    d_xfer_text_row 17, "NesDev.org"
    d_xfer_attr_upper $1a, 4, $50
    d_xfer_terminator
.ENDPROC

.PROC DataC_Title_Dedication_sEpiScene
    D_STRUCT sEpiScene
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr TerrainData_ptr, 0
    d_byte TerrainOffset_u8, 0
    d_addr Transfer_sXfer_ptr, _Transfer_sXfer
    d_byte Chr04Bank_u8, <.bank(Ppu_ChrBgFontUpper)
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjPause)
    d_addr Draw_sShapeTile_arr_ptr, 0
    D_END
_Transfer_sXfer:
    d_xfer_text_row 15, "FOR GREAT JUSTIN"
    d_xfer_terminator
.ENDPROC

;;; Loads the current epilogue scene and tileset into Zp_Current_sEpiScene and
;;; Zp_Current_sTileset.
;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Title_LoadEpilogueScene
    jsr FuncC_Title_GetEpilogueScene  ; returns Y
    ldx _SceneTable_sEpiScene_ptr_0_arr, y
    lda _SceneTable_sEpiScene_ptr_1_arr, y
    stax T1T0  ; sEpiScene ptr
_CopyEpiBoss:
    ldy #.sizeof(sEpiScene) - 1
    @loop:
    lda (T1T0), y
    sta Zp_Current_sEpiScene, y
    dey
    .assert .sizeof(sEpiScene) <= $80, error
    bpl @loop
_CopyTileset:
    ;; Copy the sTileset struct into Zp_Current_sTileset.
    ldy #.sizeof(sTileset) - 1
    @loop:
    lda (Zp_Current_sEpiScene + sEpiScene::Terrain_sTileset_ptr), y
    sta Zp_Current_sTileset, y
    dey
    .assert .sizeof(sTileset) <= $80, error
    bpl @loop
    rts
.REPEAT 2, table
    D_TABLE_LO table, _SceneTable_sEpiScene_ptr_0_arr
    D_TABLE_HI table, _SceneTable_sEpiScene_ptr_1_arr
    D_TABLE .enum, eEpilogueScene
    d_entry table, Title,      DataC_Title_Title_sEpiScene
    d_entry table, Credit1,    DataC_Title_Credit1_sEpiScene
    d_entry table, Boss1,      DataC_Title_Boss1_sEpiScene
    d_entry table, Credit2,    DataC_Title_Credit2_sEpiScene
    d_entry table, Boss2,      DataC_Title_Boss2_sEpiScene
    d_entry table, Credit3,    DataC_Title_Credit3_sEpiScene
    d_entry table, Boss3,      DataC_Title_Boss3_sEpiScene
    d_entry table, Credit4,    DataC_Title_Credit4_sEpiScene
    d_entry table, Boss4,      DataC_Title_Boss4_sEpiScene
    d_entry table, Credit5,    DataC_Title_Credit5_sEpiScene
    d_entry table, Boss5,      DataC_Title_Boss5_sEpiScene
    d_entry table, Credit6,    DataC_Title_Credit6_sEpiScene
    d_entry table, Boss6,      DataC_Title_Boss6_sEpiScene
    d_entry table, Credit7,    DataC_Title_Credit7_sEpiScene
    d_entry table, Boss7,      DataC_Title_Boss7_sEpiScene
    d_entry table, Credit8,    DataC_Title_Credit8_sEpiScene
    d_entry table, Boss8,      DataC_Title_Boss8_sEpiScene
    d_entry table, Dedication, DataC_Title_Dedication_sEpiScene
    D_END
.ENDREPEAT
.ENDPROC

;;; Initializes the current epilogue scene, in particular setting up the
;;; background tiles before the screen fades in.
;;; @prereq PRGA_Terrain is loaded.
;;; @prereq Rendering is disabled.
;;; @prereq Zp_Current_eEpilogue and Zp_EpilogueSceneIndex_u8 are initialized.
.PROC FuncC_Title_InitEpilogueScene
    main_chr0c_bank Ppu_ChrBgFontUpper
    main_chr08 Zp_Current_sTileset + sTileset::Chr08Bank_u8
    main_chr18 Zp_Current_sEpiScene + sEpiScene::Chr18Bank_u8
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    sta Zp_FrameCounter_u8
    jsr Func_Window_Disable
_ClearUpperNametable:
    ldxy #Ppu_Nametable0_sName  ; param: nametable addr
    jsr FuncC_Title_ClearNametableTiles
    ldy #$00  ; param: attribute byte
    jsr Func_FillUpperAttributeTable
_DrawTerrain:
    lda Zp_Current_sEpiScene + sEpiScene::TerrainData_ptr + 1
    beq @done  ; no terrain to draw
    ;; Set up PPU address.
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldya #Ppu_EpilogueTerrainStart
    ora Zp_Current_sEpiScene + sEpiScene::TerrainOffset_u8
    sty Hw_PpuAddr_w2  ; PPU address (hi)
    sta Hw_PpuAddr_w2  ; PPU address (lo)
    ;; Write terrain data.
    ldy #0  ; byte offset into terrain data
    @blockRowLoop:
    ldx #kScreenWidthBlocks
    @lowerTileLoop:
    lda (Zp_Current_sEpiScene + sEpiScene::TerrainData_ptr), y
    iny
    sty T0  ; byte offset into terrain data
    tay
    lda (Zp_Current_sTileset + sTileset::LowerLeft_u8_arr_ptr), y
    sta Hw_PpuData_rw
    lda (Zp_Current_sTileset + sTileset::LowerRight_u8_arr_ptr), y
    sta Hw_PpuData_rw
    ldy T0  ; byte offset into terrain data
    dex
    bne @lowerTileLoop
    ldx #kScreenWidthBlocks
    @upperTileLoop:
    lda (Zp_Current_sEpiScene + sEpiScene::TerrainData_ptr), y
    iny
    sty T0  ; byte offset into terrain data
    tay
    lda (Zp_Current_sTileset + sTileset::UpperLeft_u8_arr_ptr), y
    sta Hw_PpuData_rw
    lda (Zp_Current_sTileset + sTileset::UpperRight_u8_arr_ptr), y
    sta Hw_PpuData_rw
    ldy T0  ; byte offset into terrain data
    dex
    bne @upperTileLoop
    tya
    sub #kScreenWidthBlocks
    tay
    cpy #kScreenWidthBlocks * 4
    blt @blockRowLoop
    @done:
_DrawTransfer:
    ldax Zp_Current_sEpiScene + sEpiScene::Transfer_sXfer_ptr  ; param: ptr
    jmp Func_DirectPpuTransfer
.ENDPROC

;;; Performs per-frame updates for the current epilogue scene, including
;;; updating the screen fade level near the start and end of the scene.
;;; @prereq Zp_Current_eEpilogue and Zp_EpilogueSceneIndex_u8 are initialized.
.PROC FuncC_Title_TickEpilogueScene
_FadeScreen:
    lda Zp_FrameCounter_u8
    cmp #1 + 5 * 0
    beq @fadeDark
    cmp #kEpilogueSceneFrames - 5 * 1
    beq @fadeDark
    cmp #1 + 5 * 1
    beq @fadeDim
    cmp #kEpilogueSceneFrames - 5 * 2
    beq @fadeDim
    cmp #1 + 5 * 2
    bne @done
    @fadeNormal:
    ldy #eFade::Normal
    .assert eFade::Normal < $80, error
    bpl @setFade  ; unconditional
    @fadeDim:
    ldy #eFade::Dim
    .assert eFade::Dim < $80, error
    bpl @setFade  ; unconditional
    @fadeDark:
    ldy #eFade::Dark
    @setFade:
    jsr Func_SetAndTransferFade
    @done:
    rts
.ENDPROC

;;; Draws any objects needed for the current epilogue scene.
;;; @prereq PRGA_Objects is loaded.
;;; @prereq Zp_Current_sEpiScene is initialized.
.PROC FuncC_Title_DrawEpilogueScene
    lda Zp_Current_sEpiScene + sEpiScene::Chr04Bank_u8
    sta Zp_Chr04Bank_u8
_DrawObjects:
    ldy Zp_Current_sEpiScene + sEpiScene::Draw_sShapeTile_arr_ptr + 1  ; param
    beq @done
    lda #0
    sta Zp_ShapePosX_i16 + 1
    sta Zp_ShapePosY_i16 + 1
    lda #kScreenWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda #kTileHeightPx * kEpilogueTerrainStartRow
    sta Zp_ShapePosY_i16 + 0
    lda Zp_Current_sEpiScene + sEpiScene::Draw_sShapeTile_arr_ptr + 0  ; param
    jmp FuncA_Objects_DrawShapeTiles
    @done:
    rts
.ENDPROC

;;; Returns the eEpilogueScene value for the current epilogue scene.
;;; @prereq Zp_Current_eEpilogue and Zp_EpilogueSceneIndex_u8 are initialized.
;;; @return Y The eEpilogueScene value for the current epilogue scene.
;;; @preserve X, T2+
.PROC FuncC_Title_GetEpilogueScene
    ldy Zp_Current_eEpilogue
    lda _Scenes_eEpilogueScene_arr_ptr_0_arr, y
    sta T0
    lda _Scenes_eEpilogueScene_arr_ptr_1_arr, y
    sta T1
    ldy Zp_EpilogueSceneIndex_u8
    lda (T1T0), y
    tay
    rts
.REPEAT 2, table
    D_TABLE_LO table, _Scenes_eEpilogueScene_arr_ptr_0_arr
    D_TABLE_HI table, _Scenes_eEpilogueScene_arr_ptr_1_arr
    D_TABLE .enum, eEpilogue
    d_entry table, AlexSearches, _AlexSearches_eEpilogueScene_arr
    d_entry table, HumansAscend, _HumansAscend_eEpilogueScene_arr
    d_entry table, OrcsAscend,   _OrcsAscend_eEpilogueScene_arr
    D_END
.ENDREPEAT
_AlexSearches_eEpilogueScene_arr:  ; TODO
_HumansAscend_eEpilogueScene_arr:  ; TODO
_OrcsAscend_eEpilogueScene_arr:
:   .byte eEpilogueScene::Title
    .byte eEpilogueScene::Credit1
    .byte eEpilogueScene::Boss1
    .byte eEpilogueScene::Credit2
    .byte eEpilogueScene::Boss2
    .byte eEpilogueScene::Credit3
    .byte eEpilogueScene::Boss3
    .byte eEpilogueScene::Credit4
    .byte eEpilogueScene::Boss4
    .byte eEpilogueScene::Credit5
    .byte eEpilogueScene::Boss5
    .byte eEpilogueScene::Credit6
    .byte eEpilogueScene::Boss6
    .byte eEpilogueScene::Credit7
    .byte eEpilogueScene::Boss7
    .byte eEpilogueScene::Credit8
    .byte eEpilogueScene::Boss8
    .byte eEpilogueScene::Dedication
    .assert * - :- = kEpilogueNumScenes, error
.ENDPROC

;;;=========================================================================;;;
