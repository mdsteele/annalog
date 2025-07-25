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
.INCLUDE "charmap.inc"
.INCLUDE "cpu.inc"
.INCLUDE "devices/flower.inc"
.INCLUDE "flag.inc"
.INCLUDE "irq.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "minimap.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "pause.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "window.inc"

.IMPORT DataA_Pause_AreaNames_u8_arr12_ptr_0_arr
.IMPORT DataA_Pause_AreaNames_u8_arr12_ptr_1_arr
.IMPORT DataA_Pause_PaperLocation_eArea_arr
.IMPORT FuncA_Pause_DirectDrawMinimap
.IMPORT FuncA_Pause_DirectDrawPaperGrid
.IMPORT FuncA_Pause_DrawMinimapObjects
.IMPORT FuncA_Pause_DrawPaperCursor
.IMPORT FuncA_Pause_InitPaperGrid
.IMPORT FuncA_Pause_MovePaperCursor
.IMPORT FuncA_Pause_MovePaperCursorNext
.IMPORT FuncA_Pause_TransferGameStats
.IMPORT FuncA_Pause_TransferHidePortrait
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_AllocObjects
.IMPORT Func_AllocOneObject
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_CountDeliveredFlowers
.IMPORT Func_FadeInFromBlackToNormal
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FillLowerAttributeTable
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_IsFlagSet
.IMPORT Func_PlaySfxWindowClose
.IMPORT Func_PlaySfxWindowOpen
.IMPORT Func_SetMusicVolumeForCurrentRoom
.IMPORT Func_Window_Disable
.IMPORT Func_Window_ScrollDown
.IMPORT Func_Window_ScrollUp
.IMPORT Int_NoopIrq
.IMPORT MainA_Pause_RereadPaper
.IMPORT Main_Explore_FadeIn
.IMPORT Ppu_ChrBgFontUpper
.IMPORT Ppu_ChrBgMinimap
.IMPORT Ppu_ChrBgPause
.IMPORT Ppu_ChrObjPause
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_ProgressFlags_arr
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PaperCursorRow_u8
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_WindowTopGoal_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The goal value for Zp_WindowTop_u8 while scrolling in the papers window.
.LINECONT +
kPapersWindowTopGoal = \
    kScreenHeightPx - ((kTileHeightPx * 24) + kWindowMarginBottomPx)
.LINECONT -
;;; How fast the papers window scrolls up/down, in pixels per frame.
kPapersWindowScrollSpeed = 11

;;; The BG tile ID for the top-left tile for the symbol of the first non-RAM
;;; upgrade.  Add 1 to this to get the the top-right tile ID for that symbol,
;;; then add another 1 to get the top-left tile ID for the next upgrade, and so
;;; on.
kTileIdBgRemainingTopLeft = $84

;;; The OBJ palette number for the cursor for opening the papers window.
kPaletteObjOpenWindowCursor = 1

;;;=========================================================================;;;

.ZEROPAGE

;;; Bit N of this is set if breaker number N (starting at 0) is activated.
.ASSERT kNumBreakerFlags <= 8, error
Zp_ActivatedBreakers_byte: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for fading in the pause screen after pausing the game in explore mode.
;;; @prereq Rendering is disabled.
.EXPORT Main_Pause_FadeIn
.PROC Main_Pause_FadeIn
    jmp_prga MainA_Pause_FadeIn
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; Mode for fading in the pause screen after pausing the game in explore mode.
;;; @prereq Rendering is disabled.
.PROC MainA_Pause_FadeIn
    lda #<.bank(Ppu_ChrBgFontUpper)
    sta Zp_Chr04Bank_u8
    main_chr08_bank Ppu_ChrBgPause
    main_chr0c_bank Ppu_ChrBgMinimap
    main_chr18_bank Ppu_ChrObjPause
    jsr FuncA_Pause_InitAndFadeIn
    fall MainA_Pause_Minimap
.ENDPROC

;;; Mode for running the pause screen while the minimap is visible.
;;; @prereq Rendering is enabled.
.PROC MainA_Pause_Minimap
_GameLoop:
    jsr FuncA_Pause_DrawObjectsAndProcessFrame
_CheckForOpenPapersWindow:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    bne MainA_Pause_ScrollPapersUp
_CheckForUnpause:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start | bJoypad::BButton
    beq _GameLoop
    fall MainA_Pause_FadeOut
.ENDPROC

;;; Mode for fading out the pause screen and resuming explore mode.
;;; @prereq Rendering is enabled.
.PROC MainA_Pause_FadeOut
    jsr Func_FadeOutToBlack
    jsr Func_SetMusicVolumeForCurrentRoom
    jmp Main_Explore_FadeIn
.ENDPROC

;;; Mode for scrolling up the papers window, thus making it visible.
;;; @prereq Rendering is enabled.
.PROC MainA_Pause_ScrollPapersUp
    jsr Func_PlaySfxWindowOpen
    lda #kPapersWindowTopGoal
    sta Zp_WindowTopGoal_u8
    lda #kScreenHeightPx - kPapersWindowScrollSpeed
    sta Zp_WindowTop_u8
_GameLoop:
    jsr FuncA_Pause_DrawObjectsAndProcessFrame
    lda #kPapersWindowScrollSpeed  ; param: scroll by
    jsr Func_Window_ScrollUp  ; sets C if fully scrolled in
    bcc _GameLoop
    jsr FuncA_Pause_MovePaperCursorNext
    fall MainA_Pause_Papers
.ENDPROC

;;; Mode for running the pause screen while the papers window is visible.
;;; @prereq Rendering is enabled.
.EXPORT MainA_Pause_Papers
.PROC MainA_Pause_Papers
    jsr FuncA_Pause_TransferHidePortrait
    jsr FuncA_Pause_TransferGameStats
_GameLoop:
    jsr FuncA_Pause_DrawObjectsAndProcessFrame
_CheckButtons:
    ;; Move the cursor or close the window in response to the D-pad.
    jsr FuncA_Pause_MovePaperCursor  ; sets C if cursor moved
    bcc @doneMove  ; cursor didn't move, so don't close window
    lda Zp_PaperCursorRow_u8
    bmi MainA_Pause_ScrollPapersDown  ; cursor moved up from top row
    @doneMove:
    ;; Unpause in response to the START button.
    lda #bJoypad::Start
    bit Zp_P1ButtonsPressed_bJoypad
    bne MainA_Pause_FadeOut
    ;; Close the papers window in response to the B button.
    .assert bJoypad::BButton = bProc::Overflow, error
    bvs MainA_Pause_ScrollPapersDown
    ;; Read the selected paper in response to the A button.
    .assert bJoypad::AButton = bProc::Negative, error
    bpl _GameLoop  ; A button was not pressed
    lda Zp_PaperCursorRow_u8
    bmi _GameLoop  ; no paper is selected
    jmp MainA_Pause_RereadPaper
.ENDPROC

;;; Mode for scrolling down the papers window, thus making the minimap visible.
;;; @prereq Rendering is enabled.
.PROC MainA_Pause_ScrollPapersDown
    jsr Func_PlaySfxWindowClose
    lda #$ff
    sta Zp_PaperCursorRow_u8
    ;; Restore CHR0C bank for minimap (in case it was changed by dialog mode
    ;; for reading any papers).
    main_chr0c_bank Ppu_ChrBgMinimap
_GameLoop:
    jsr FuncA_Pause_DrawObjectsAndProcessFrame
    lda #kPapersWindowScrollSpeed  ; param: scroll by
    jsr Func_Window_ScrollDown  ; sets C if fully scrolled out
    bcc _GameLoop
    bcs MainA_Pause_Minimap  ; unconditional
.ENDPROC

;;; The "current area" label that is drawn on the pause screen minimap window.
.PROC DataA_Pause_CurrentAreaLabel_u8_arr
    .byte "Current area: "
.ENDPROC

;;; The "papers found" label that is drawn on the pause screen papers window.
.PROC DataA_Pause_AreaPaperLabel_u8_arr
    .byte " Pages found in area: "
.ENDPROC

;;; Initializes pause mode, then fades in the screen.
;;; @prereq Rendering is disabled.
.PROC FuncA_Pause_InitAndFadeIn
    jsr FuncA_Pause_InitPaperGrid
    ;; Reset the frame counter before drawing any objects so that the
    ;; current-position blink will be in a consistent state as we fade in.
    ldx #0
    stx Zp_FrameCounter_u8
_InitActivatedBreakers:
    stx Zp_ActivatedBreakers_byte  ; X is still zero
    ldx #kLastBreakerFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X, clears Z if flag is set
    clc
    beq @notActivated
    sec
    @notActivated:
    rol Zp_ActivatedBreakers_byte
    dex
    cpx #kFirstBreakerFlag
    bge @loop
_ReduceMusic:
    ;; Reduce music volume while on the pause screen.
    lda #bAudio::Enable | bAudio::ReduceMusic
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
_DrawScreen:
    ldy #$00  ; param: fill byte
    jsr Func_FillUpperAttributeTable  ; preserves Y
    jsr Func_FillLowerAttributeTable
    jsr Func_Window_Disable
    jsr FuncA_Pause_DirectDrawBg
    jsr FuncA_Pause_DrawObjects
    jsr Func_ClearRestOfOam
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jmp Func_FadeInFromBlackToNormal
.ENDPROC

;;; Directly fills both PPU nametables with BG tile data for the pause screen.
;;; @prereq Rendering is disabled.
.PROC FuncA_Pause_DirectDrawBg
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
_BeginUpperNametable:
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr
    sta Hw_PpuAddr_w2  ; PPU address (hi)
    stx Hw_PpuAddr_w2  ; PPU address (lo)
    ldy #kScreenWidthTiles * 2  ; param: num blank tiles to draw
    jsr FuncA_Pause_DirectDrawBlankTiles
    jsr FuncA_Pause_DirectDrawWindowTopBorder
_DrawCurrentAreaLabel:
    jsr FuncA_Pause_DirectDrawWindowLineSide
    ldx #0
    @loop:
    lda DataA_Pause_CurrentAreaLabel_u8_arr, x
    sta Hw_PpuData_rw
    inx
    cpx #.sizeof(DataA_Pause_CurrentAreaLabel_u8_arr)
    blt @loop
_DrawCurrentAreaName:
    ;; Copy the current room's AreaName_u8_arr_ptr into T1T0.
    lda Zp_Current_sRoom + sRoom::Flags_bRoom
    and #bRoom::AreaMask
    tay  ; eArea value
    lda DataA_Pause_AreaNames_u8_arr12_ptr_0_arr, y
    sta T0
    lda DataA_Pause_AreaNames_u8_arr12_ptr_1_arr, y
    sta T1
    ;; Draw the room's area name.
    ldy #0
    @loop:
    lda (T1T0), y
    sta Hw_PpuData_rw
    iny
    cpy #12
    blt @loop
    jsr FuncA_Pause_DirectDrawWindowLineSide
_DrawMinimap:
    jsr FuncA_Pause_DirectDrawWindowBlankLine
    jsr FuncA_Pause_DirectDrawMinimap
    jsr FuncA_Pause_DirectDrawWindowBlankLine
_DrawItems:
    ldx #0
    @rowLoop:
    jsr FuncA_Pause_DirectDrawItemsLine  ; preserves X
    inx
    cpx #6
    bne @rowLoop
_FinishUpperNametable:
    jsr FuncA_Pause_DirectDrawWindowBottomBorder
    ldy #kScreenWidthTiles * 2  ; param: num blank tiles to draw
    jsr FuncA_Pause_DirectDrawBlankTiles
_BeginLowerNametable:
    ldax #Ppu_Nametable3_sName + sName::Tiles_u8_arr
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    ldy #kScreenWidthTiles  ; param: num blank tiles to draw
    jsr FuncA_Pause_DirectDrawBlankTiles
    jsr FuncA_Pause_DirectDrawWindowTopBorder
_CheckIfInTown:
    ;; If the player avatar is still in the Town area at the start of the game,
    ;; don't draw the text about papers in the area.
    lda Zp_Current_sRoom + sRoom::Flags_bRoom
    and #bRoom::AreaMask
    cmp #eArea::Town
    bne @notInTown
    @inTown:
    jsr FuncA_Pause_DirectDrawWindowBlankLine
    jmp _DrawCollectedPapers
    @notInTown:
    sta T2  ; current eArea
_DrawAreaPaperLabel:
    jsr FuncA_Pause_DirectDrawWindowLineSide  ; preserves T0+
    ldx #0
    stx T0  ; num papers found in area
    stx T1  ; total num papers in area
    @loop:
    lda DataA_Pause_AreaPaperLabel_u8_arr, x
    sta Hw_PpuData_rw
    inx
    cpx #.sizeof(DataA_Pause_AreaPaperLabel_u8_arr)
    blt @loop
_CountPapers:
    ldx #kNumPaperFlags - 1
    @loop:
    lda DataA_Pause_PaperLocation_eArea_arr, x
    cmp T2  ; current eArea
    bne @notInArea
    inc T1  ; total num papers in area
    txa  ; loop index
    pha  ; loop index
    add #kFirstPaperFlag
    tax  ; param: flag
    jsr Func_IsFlagSet  ; preserves T0+, sets Z if flag is not set
    beq @notCollected
    inc T0  ; num papers found in area
    @notCollected:
    pla  ; loop index
    tax  ; loop index
    @notInArea:
    dex
    .assert kNumPaperFlags <= $80, error
    bpl @loop
_DrawAreaPaperCount:
    lda T0  ; num papers found in area
    .assert '0' .mod $10 = 0, error
    ora #'0'
    sta Hw_PpuData_rw
    lda #'/'
    sta Hw_PpuData_rw
    lda T1  ; total num papers in area
    .assert '0' .mod $10 = 0, error
    ora #'0'
    sta Hw_PpuData_rw
    lda #' '
    sta Hw_PpuData_rw
    jsr FuncA_Pause_DirectDrawWindowLineSide
_DrawCollectedPapers:
    jsr FuncA_Pause_DirectDrawPaperGrid
_FinishLowerNametable:
    jsr FuncA_Pause_DirectDrawWindowBlankLine
    jsr FuncA_Pause_DirectDrawWindowTopBorder
    ldx #4
    @loop:
    jsr FuncA_Pause_DirectDrawWindowBlankLine  ; preserves X
    dex
    bne @loop
    jsr FuncA_Pause_DirectDrawWindowBottomBorder
    ldy #kScreenWidthTiles * 5  ; param: num blank tiles to draw
    fall FuncA_Pause_DirectDrawBlankTiles
.ENDPROC

;;; Draws the specified number of blank BG tiles to Hw_PpuData_rw.
;;; @prereq Rendering is disabled.
;;; @param Y The number of blank tiles to draw.
;;; @preserve X, T0+
.EXPORT FuncA_Pause_DirectDrawBlankTiles
.PROC FuncA_Pause_DirectDrawBlankTiles
    lda #' '
    @loop:
    sta Hw_PpuData_rw
    dey
    bne @loop
    rts
.ENDPROC

;;; Writes BG tile data for one line of the items section of the pause screen
;;; directly to the PPU.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @prereq Hw_PpuAddr_w2 is set to the start of the nametable row.
;;; @param X The item line number (0-5).
;;; @preserve X
.PROC FuncA_Pause_DirectDrawItemsLine
    jsr FuncA_Pause_DirectDrawWindowLineSide  ; preserves X
    stx T0  ; line number (0-5)
    lda #' '
    sta Hw_PpuData_rw
.PROC _DrawUpgrades
    ;; Calculate the eFlag value for the first upgrade on this line, and store
    ;; it in X.
    lda T0  ; line number (0-5)
    div #2
    sta T1  ; upgrade row (0-2)
    mul #4
    adc T1  ; upgrade row (0-2), carry flag is already zero
    .assert kFirstUpgradeFlag > 0, error
    adc #kFirstUpgradeFlag
    tax  ; first upgrade eFlag
    ;; Calculate the loop limit, and store it in T1.
    add #5
    sta T1  ; ending eFlag
    ;; Loop over each upgrade on this line.
    @loop:
    jsr Func_IsFlagSet  ; preserves X and T0+, sets Z if flag X is not set
    bne @drawUpgrade
    ;; The player doesn't have this upgrade yet, so draw some blank space.
    lda #' '
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    .assert ' ' = 0, error
    beq @continue  ; unconditional
    @drawUpgrade:
    ;; The player does have this upgrade.  Determine the first tile ID to draw
    ;; for this line of this upgrade.
    lda T0  ; line number (0-5)
    and #$01
    beq @top
    @bottom:
    lda #kTileIdBgUpgradeBottomFirst
    .assert kTileIdBgUpgradeBottomFirst > 0, error
    bne @draw  ; unconditional
    @top:
    txa  ; upgrade eFlag
    sub #kLastRamUpgradeFlag + 1
    blt @isRamUpgrade
    mul #2
    add #kTileIdBgRemainingTopLeft
    bcc @draw  ; unconditional
    @isRamUpgrade:
    lda #kTileIdBgUpgradeRamFirst
    @draw:
    ;; Draw the upgrade.
    sta Hw_PpuData_rw
    add #1
    sta Hw_PpuData_rw
    lda #' '
    sta Hw_PpuData_rw
    @continue:
    ;; Continue to the next upgrade on this line.
    inx  ; upgrade eFlag
    cpx T1  ; ending eFlag
    blt @loop
    ;; At this point, A is still set to ' '.
    sta Hw_PpuData_rw
.ENDPROC
.PROC _DrawCircuits
    lda T0  ; line number (0-5)
    mul #8
    tax
    ldy #8
    @loop:
    lda _CircuitBreakers_byte_arr8_arr6, x
    beq @drawTile
    and Zp_ActivatedBreakers_byte
    beq @drawA
    @drawTile:
    lda _CircuitTiles_u8_arr8_arr6, x
    @drawA:
    sta Hw_PpuData_rw
    inx
    dey
    bne @loop
    lda #' '
    sta Hw_PpuData_rw
.ENDPROC
    ldx T0  ; restore X register (line number)
    jmp FuncA_Pause_DirectDrawWindowLineSide  ; preserves X
_CircuitTiles_u8_arr8_arr6:
    .byte "1", $a0, " ", $b0, $b6, " ", $a1, "6"
    .byte " ", $a2, $a8, $b1, $b7, $a8, $a3, " "
    .byte " ", $a4, $a8, $b2, $b8, $a8, $a5, " "
    .byte "2", $a6, $a4, $b3, $b9, $a5, $a7, "5"
    .byte " ", "3", $a6, $b4, $ba, $a7, "4", " "
    .byte " ", " ", " ", $b5, $bb, " ", " ", " "
_CircuitBreakers_byte_arr8_arr6:
    .byte $01, $00, $00, $00, $00, $00, $00, $20
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $02, $00, $00, $00, $00, $00, $00, $10
    .byte $00, $04, $00, $00, $00, $00, $08, $00
    .byte $00, $00, $00, $40, $40, $00, $00, $00
.ENDPROC

;;; Draws a blank line within a pause screen window directly to the PPU.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @prereq Hw_PpuAddr_w2 is set to the start of the nametable row.
;;; @preserve X, T0+
.EXPORT FuncA_Pause_DirectDrawWindowBlankLine
.PROC FuncA_Pause_DirectDrawWindowBlankLine
    jsr FuncA_Pause_DirectDrawWindowLineSide  ; preserves X and T0+
    ldy #kScreenWidthTiles - 6  ; param: num blank tiles to draw
    jsr FuncA_Pause_DirectDrawBlankTiles  ; preserves X and T0+
    fall FuncA_Pause_DirectDrawWindowLineSide  ; preserves X and T0+
.ENDPROC

;;; Draws the left or right side of one pause window line, including margins;
;;; that is, a blank tile, a vertical border tile, and another blank tile.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @preserve X, T0+
.EXPORT FuncA_Pause_DirectDrawWindowLineSide
.PROC FuncA_Pause_DirectDrawWindowLineSide
    lda #' '
    sta Hw_PpuData_rw
    ldy #kTileIdBgWindowVert
    sty Hw_PpuData_rw
    sta Hw_PpuData_rw
    rts
.ENDPROC

;;; Draws one row of nametable tiles, consiting of the top border of a pause
;;; screen window.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @prereq Hw_PpuAddr_w2 is set to the start of the nametable row.
;;; @preserve T0+
.EXPORT FuncA_Pause_DirectDrawWindowTopBorder
.PROC FuncA_Pause_DirectDrawWindowTopBorder
    ldy #' '
    sty Hw_PpuData_rw
    lda #kTileIdBgWindowTopLeft
    sta Hw_PpuData_rw
    lda #kTileIdBgWindowHorz
    ldx #kScreenWidthTiles - 4
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    lda #kTileIdBgWindowTopRight
    sta Hw_PpuData_rw
    sty Hw_PpuData_rw
    rts
.ENDPROC

;;; Draws one row of nametable tiles, consiting of the bottom border of a pause
;;; screen window.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @prereq Hw_PpuAddr_w2 is set to the start of the nametable row.
;;; @preserve T0+
.EXPORT FuncA_Pause_DirectDrawWindowBottomBorder
.PROC FuncA_Pause_DirectDrawWindowBottomBorder
    ldy #' '
    sty Hw_PpuData_rw
    lda #kTileIdBgWindowBottomLeft
    sta Hw_PpuData_rw
    lda #kTileIdBgWindowHorz
    ldx #kScreenWidthTiles - 4
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    lda #kTileIdBgWindowBottomRight
    sta Hw_PpuData_rw
    sty Hw_PpuData_rw
    rts
.ENDPROC

;;; Draws all objects that should be drawn on the pause screen, then calls
;;; Func_ClearRestOfOamAndProcessFrame.
.PROC FuncA_Pause_DrawObjectsAndProcessFrame
    jsr FuncA_Pause_DrawObjects
    jmp Func_ClearRestOfOamAndProcessFrame
.ENDPROC

;;; Draws all objects that should be drawn on the pause screen.
.PROC FuncA_Pause_DrawObjects
    jsr FuncA_Pause_SetUpIrq
    jsr FuncA_Pause_DrawMinimapObjects
    jsr FuncA_Pause_DrawCircuitObjects
    jsr FuncA_Pause_DrawFlowerCount
    jsr FuncA_Pause_DrawOpenWindowCursor
    jmp FuncA_Pause_DrawPaperCursor
.ENDPROC

;;; Populates Ram_Buffered_sIrq appropriately for the pause screen.
.PROC FuncA_Pause_SetUpIrq
    ldy Zp_WindowTop_u8
    cpy #kScreenHeightPx
    bge _Disable
_Enable:
    dey
    sty Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_PausePapersTopIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    rts
_Disable:
    lda #$ff
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_NoopIrq
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    rts
.ENDPROC

;;; Draws objects to animate circuits for any activated breakers.
.PROC FuncA_Pause_DrawCircuitObjects
    lda Zp_FrameCounter_u8
    div #4
    and #$03
    sta T2  ; anim offset (0-3)
    ldx #14
    @loop:
    lda _CircuitBreakerMask_byte_arr, x
    and Zp_ActivatedBreakers_byte
    beq @continue
    lda _CircuitPosY_u8_arr, x  ; param: Y-position
    jsr FuncA_Pause_AllocBaseObject  ; preserves X and T0+, returns C and Y
    bcs @continue
    lda _CircuitPosX_u8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda _CircuitFlags_bObj_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda T2  ; anim offset (0-3)
    ora _CircuitFirstTile_u8_arr, x  ; param: tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @continue:
    dex
    bpl @loop
    rts
_CircuitBreakerMask_byte_arr:
    .byte $01, $01, $01, $20, $20, $20
    .byte $02, $02,           $10, $10
    .byte      $04, $04, $08, $08
    .byte              $40
_CircuitPosX_u8_arr:
    .byte $a8, $b0, $b8, $c0, $c8, $d0
    .byte $a8, $b0,           $c8, $d0
    .byte      $b0, $b8, $c0, $c8
    .byte              $bc
_CircuitPosY_u8_arr:
    .byte $ad, $ad, $ad, $ad, $ad, $ad
    .byte $bb, $bb,           $bb, $bb
    .byte      $c3, $c3, $c3, $c3
    .byte              $ca
_CircuitFirstTile_u8_arr:
    .assert kTileIdObjPauseFirst = $b0, error
    .byte $b0, $b4, $b4, $b4, $b4, $b0
    .byte $b0, $b4,           $b4, $b0
    .byte      $b0, $b4, $b4, $b0
    .byte              $b8
_CircuitFlags_bObj_arr:
    .byte 0, 0, bObj::Pri, bObj::Pri | bObj::FlipH, bObj::FlipH, bObj::FlipH
    .byte bObj::FlipV, bObj::FlipV, bObj::FlipHV, bObj::FlipHV
    .byte bObj::FlipV, bObj::Pri | bObj::FlipV
    .byte bObj::Pri | bObj::FlipHV, bObj::FlipHV
    .byte 0
.ENDPROC

;;; Draws objects showing the number of collected flowers.
.PROC FuncA_Pause_DrawFlowerCount
    ;; Only display the flower count if at least one flower has been delivered,
    ;; but the BEEP opcode has not been unlocked yet.
    flag_bit Ram_ProgressFlags_arr, eFlag::UpgradeOpBeep
    bne _Return
    jsr Func_CountDeliveredFlowers  ; returns Z and A
    beq _Return
    sta T0  ; flower count
_DrawNumber:
    lda #$c9  ; param: Y-position
    jsr FuncA_Pause_AllocBaseObject  ; preserves T0+, returns C and Y
    bcs @done
    lda #$1f
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda #0
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda T0  ; flower count
    ora #$80 | '0'
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_DrawFlowerIcon:
    lda #$c9  ; param: Y-position
    jsr FuncA_Pause_AllocBaseObject  ; preserves T0+, returns C and Y
    bcs @done
    lda #$28
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda #kPaletteObjFlowerTop
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjFlowerTop
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_Return:
    rts
.ENDPROC

;;; Draws the arrow cursor for opening the papers window.
.PROC FuncA_Pause_DrawOpenWindowCursor
    ;; If the window isn't fully closed, don't draw the arrow cursor.
    lda Zp_WindowTop_u8
    cmp #kScreenHeightPx
    blt @done
    ;; Draw the arrow cursor.
    lda #2  ; param: num objects
    jsr Func_AllocObjects  ; returns Y
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    tax
    lda _YPos_u8_arr4, x
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    lda #kScreenWidthPx / 2 - kTileWidthPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    lda #kScreenWidthPx / 2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    lda #kPaletteObjOpenWindowCursor
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kTileIdObjArrowCursor
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @done:
    rts
_YPos_u8_arr4:
    .byte $d7, $d8, $d7, $d6
.ENDPROC

;;; Allocates and sets the Y-position for a single object within the pause
;;; screen base window.  If the object would be behind the window, then it
;;; isn't allocated (and C is cleared).  Otherwise, the caller should use the
;;; returned OAM byte offset in Y to set the object's X-position, flags, and
;;; tile ID.
;;; @param A The screen Y-position for the object.
;;; @return C Set if no OAM slot was allocated, cleared otherwise.
;;; @return Y The OAM byte offset for the allocated object.
;;; @preserve X, T0+
.EXPORT FuncA_Pause_AllocBaseObject
.PROC FuncA_Pause_AllocBaseObject
    cmp Zp_WindowTop_u8
    bge @notVisible
    sub #1
    pha
    jsr Func_AllocOneObject  ; preserves X and T0+, returns Y
    pla
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    clc
    rts
    @notVisible:
    sec
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top edge of the pause screen papers
;;; window.  Sets the PPU scroll so as to display the papers window, and
;;; disables drawing objects over the window's top border, so that it looks
;;; like the window is in front of any objects in the minimap window.
;;; @thread IRQ
.PROC Int_PausePapersTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Set up the
    ;; next IRQ.
    lda #kTileHeightPx - 1  ; param: latch value
    jsr Func_AckIrqAndSetLatch  ; preserves Y
    ldax #Int_PausePapersInteriorIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #7  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #$0c  ; nametable number << 2 (so $0c for nametable 3)
    sta Hw_PpuAddr_w2
    lda #kTileHeightPx  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    and #$38
    asl a
    asl a
    ;; We should now be in the second HBlank (and X is zero).
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Disable drawing objects for now.
    lda #bPpuMask::BgMain
    sta Hw_PpuMask_wo
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom edge of the pause screen papers
;;; window's top border (i.e. the top edge of the window interior).  Re-enables
;;; object rendering, so that objects can be displayed inside the window.
;;; @thread IRQ
.PROC Int_PausePapersInteriorIrq
    ;; Save the A register and update the PPU mask as quickly as possible.
    pha
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Hw_PpuMask_wo
    ;; No more IRQs for the rest of this frame.
    lda #$ff
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; Restore the A register and finish.
    pla
    jmp Int_NoopIrq
.ENDPROC

;;;=========================================================================;;;
