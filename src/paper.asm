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

.INCLUDE "charmap.inc"
.INCLUDE "dialog.inc"
.INCLUDE "flag.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "pause.inc"
.INCLUDE "portrait.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT DataA_Text2_PaperJerome01_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome01_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome02_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome02_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome03_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome03_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome04_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome04_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome05_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome05_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome05_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome06_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome06_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome06_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome07_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome07_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome08_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome08_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome08_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome09_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome09_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome09_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome10_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome11_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome11_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome12_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome12_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome13_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome13_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome14_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome14_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome15_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome15_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome16_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome16_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome17_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome17_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome18_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome18_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome19_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome19_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome20_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome21_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome21_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome22_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome22_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome23_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome23_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome24_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome24_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome27_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome27_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome27_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome28_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome28_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome29_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome29_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome30_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome30_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome30_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome31_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome31_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome32_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome32_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome32_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome33_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome33_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome33_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome34_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome34_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome35_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome35_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome35_Page3_u8_arr
.IMPORT DataA_Text2_PaperJerome36_Page1_u8_arr
.IMPORT DataA_Text2_PaperJerome36_Page2_u8_arr
.IMPORT DataA_Text2_PaperJerome36_Page3_u8_arr
.IMPORT DataA_Text2_PaperManual1_Page1_u8_arr
.IMPORT DataA_Text2_PaperManual1_Page2_u8_arr
.IMPORT DataA_Text2_PaperManual2_Page1_u8_arr
.IMPORT DataA_Text2_PaperManual2_Page2_u8_arr
.IMPORT DataA_Text2_PaperManual3_Page1_u8_arr
.IMPORT DataA_Text2_PaperManual3_Page2_u8_arr
.IMPORT DataA_Text2_PaperManual4_Page1_u8_arr
.IMPORT DataA_Text2_PaperManual4_Page2_u8_arr
.IMPORT DataA_Text2_PaperManual5_Page1_u8_arr
.IMPORT DataA_Text2_PaperManual5_Page2_u8_arr
.IMPORT DataA_Text2_PaperManual5_Page3_u8_arr
.IMPORT DataA_Text2_PaperManual6_Page1_u8_arr
.IMPORT DataA_Text2_PaperManual6_Page2_u8_arr
.IMPORT DataA_Text2_PaperManual8_Page1_u8_arr
.IMPORT DataA_Text2_PaperManual8_Page2_u8_arr
.IMPORT DataA_Text2_PaperManual9_Page1_u8_arr
.IMPORT DataA_Text2_PaperManual9_Page2_u8_arr
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Pause_DirectDrawWindowBlankLine
.IMPORT FuncA_Pause_DirectDrawWindowLineSide
.IMPORT Func_AllocObjects
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_IsFlagSet
.IMPORT Func_SetFlag
.IMPORT Func_UnsignedMult
.IMPORT Main_Dialog_OnPauseScreen
.IMPORT Main_Dialog_WhileExploring
.IMPORT Ppu_WindowTopLeft
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The PPU address in the lower nametable for the top-left tile of the dialog
;;; portrait.
Ppu_PortraitTopLeft := Ppu_WindowTopLeft + kScreenWidthTiles * 1 + 2

;;; The number of columns and rows in the grid of collected papers on the pause
;;; screen.
.DEFINE kPaperGridCols 9
.DEFINE kPaperGridRows 5
.ASSERT kPaperGridCols * kPaperGridRows = kNumPaperFlags, error

;;; The BG tile IDs used for drawing collected papers.
kTileIdBgPaperTopLeft      = $bc
kTileIdBgPaperBottomLeft   = $bd
kTileIdBgPaperTopRight     = $be
kTileIdBgPaperBottomRight  = $bf

;;; The OBJ tile ID for drawing the papers window cursor.
kTileIdObjPaperCursor = kTileIdObjPauseFirst + $0c
;;; The OBJ palette number for the papers window cursor.
kPaletteObjPaperCursor = 1

;;;=========================================================================;;;

.ZEROPAGE

;;; The current row and column for the papers window cursor.  When the cursor
;;; is inactive, the row should be set to $ff.
.EXPORTZP Zp_PaperCursorRow_u8
Zp_PaperCursorRow_u8: .res 1
Zp_PaperCursorCol_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Pause"

;;; A bit array indicating which papers have been collected.  The array
;;; contains one u8 for each column of the paper grid; if the paper at row R
;;; and column C has been collected, then the Rth bit of the Cth u8 in this
;;; array will be set.
.ASSERT kPaperGridRows <= 8, error
Ram_CollectedPapers_u8_arr: .res kPaperGridCols

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for collecting a paper.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active paper device.
;;; @param X The paper device index.
.EXPORT Main_Paper_UseDevice
.PROC Main_Paper_UseDevice
    jmp_prga MainA_Pause_UsePaperDevice
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; Mode for collecting a paper.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active paper device.
;;; @param X The paper device index.
.PROC MainA_Pause_UsePaperDevice
    lda Ram_DeviceTarget_byte_arr, x
    pha  ; eFlag::Paper* value
    tax  ; param: flag
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs @doneSfx
    ;; TODO: play a sound for collecting a new paper
    @doneSfx:
    pla  ; eFlag::Paper* value
    sub #kFirstPaperFlag
    tax
    ldy DataA_Pause_PaperDialogs_eDialog_arr, x  ; param: eDialog value
    jmp Main_Dialog_WhileExploring
.ENDPROC

;;; PPU transfer entries for showing the dialog portrait.
.PROC DataA_Pause_ShowPortraitTransfer_arr
    .repeat 4, row
    .scope
    .byte kPpuCtrlFlagsHorz      ; control flags
    .dbyt Ppu_PortraitTopLeft + kScreenWidthTiles * row  ; destination address
    .byte @dataEnd - @dataStart  ; transfer length
    @dataStart:
    .repeat 4, col
    .byte kTileIdBgPortraitPaperFirst + col * 4 + row
    .endrepeat
    @dataEnd:
    .endscope
    .endrepeat
.ENDPROC

;;; PPU transfer entries for hiding the dialog portrait.
.PROC DataA_Pause_HidePortraitTransfer_arr
    .repeat 4, row
    .scope
    .byte kPpuCtrlFlagsHorz      ; control flags
    .dbyt Ppu_PortraitTopLeft + kScreenWidthTiles * row  ; destination address
    .byte @dataEnd - @dataStart  ; transfer length
    @dataStart:
    .byte 0, 0, 0, 0
    @dataEnd:
    .endscope
    .endrepeat
.ENDPROC

;;; Buffers a PPU transfer to hide the dialog portrait.
.EXPORT FuncA_Pause_TransferHidePortrait
.PROC FuncA_Pause_TransferHidePortrait
    ldax #DataA_Pause_HidePortraitTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Pause_HidePortraitTransfer_arr)  ; param: data size
    jmp Func_BufferPpuTransfer
.ENDPROC

;;; Mode for reading a paper from the pause screen.
;;; @prereq Rendering is enabled.
.EXPORT MainA_Pause_RereadPaper
.PROC MainA_Pause_RereadPaper
    ;; Buffer a PPU transfer to show the dialog portrait.
    ldax #DataA_Pause_ShowPortraitTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Pause_ShowPortraitTransfer_arr)  ; param: data size
    jsr Func_BufferPpuTransfer
    ;; Calculate the eDialog value and start dialog mode.
    lda Zp_PaperCursorRow_u8  ; param: multiplicand
    ldy #kPaperGridCols  ; param: multiplier
    jsr Func_UnsignedMult  ; returns YA
    add Zp_PaperCursorCol_u8
    tax
    ldy DataA_Pause_PaperDialogs_eDialog_arr, x  ; param: eDialog
    jmp Main_Dialog_OnPauseScreen
.ENDPROC

;;; Maps from eFlag::Paper* values to eDialog::Paper* values.
;;; TODO: Once all papers exist, we can remove this and just use arithmetic.
.PROC DataA_Pause_PaperDialogs_eDialog_arr
    D_ARRAY kNumPaperFlags, kFirstPaperFlag
    d_byte eFlag::PaperJerome01, eDialog::PaperJerome01
    d_byte eFlag::PaperJerome02, eDialog::PaperJerome02
    d_byte eFlag::PaperJerome03, eDialog::PaperJerome03
    d_byte eFlag::PaperJerome04, eDialog::PaperJerome04
    d_byte eFlag::PaperJerome05, eDialog::PaperJerome05
    d_byte eFlag::PaperJerome06, eDialog::PaperJerome06
    d_byte eFlag::PaperJerome07, eDialog::PaperJerome07
    d_byte eFlag::PaperJerome08, eDialog::PaperJerome08
    d_byte eFlag::PaperJerome09, eDialog::PaperJerome09
    d_byte eFlag::PaperJerome10, eDialog::PaperJerome10
    d_byte eFlag::PaperJerome11, eDialog::PaperJerome11
    d_byte eFlag::PaperJerome12, eDialog::PaperJerome12
    d_byte eFlag::PaperJerome13, eDialog::PaperJerome13
    d_byte eFlag::PaperJerome14, eDialog::PaperJerome14
    d_byte eFlag::PaperJerome15, eDialog::PaperJerome15
    d_byte eFlag::PaperJerome16, eDialog::PaperJerome16
    d_byte eFlag::PaperJerome17, eDialog::PaperJerome17
    d_byte eFlag::PaperJerome18, eDialog::PaperJerome18
    d_byte eFlag::PaperJerome19, eDialog::PaperJerome19
    d_byte eFlag::PaperJerome20, eDialog::PaperJerome20
    d_byte eFlag::PaperJerome21, eDialog::PaperJerome21
    d_byte eFlag::PaperJerome22, eDialog::PaperJerome22
    d_byte eFlag::PaperJerome23, eDialog::PaperJerome23
    d_byte eFlag::PaperJerome24, eDialog::PaperJerome24
    d_byte eFlag::PaperJerome25, 0  ; TODO
    d_byte eFlag::PaperJerome26, 0  ; TODO
    d_byte eFlag::PaperJerome27, eDialog::PaperJerome27
    d_byte eFlag::PaperJerome28, eDialog::PaperJerome28
    d_byte eFlag::PaperJerome29, eDialog::PaperJerome29
    d_byte eFlag::PaperJerome30, eDialog::PaperJerome30
    d_byte eFlag::PaperJerome31, eDialog::PaperJerome31
    d_byte eFlag::PaperJerome32, eDialog::PaperJerome32
    d_byte eFlag::PaperJerome33, eDialog::PaperJerome33
    d_byte eFlag::PaperJerome34, eDialog::PaperJerome34
    d_byte eFlag::PaperJerome35, eDialog::PaperJerome35
    d_byte eFlag::PaperJerome36, eDialog::PaperJerome36
    d_byte eFlag::PaperManual1, eDialog::PaperManual1
    d_byte eFlag::PaperManual2, eDialog::PaperManual2
    d_byte eFlag::PaperManual3, eDialog::PaperManual3
    d_byte eFlag::PaperManual4, eDialog::PaperManual4
    d_byte eFlag::PaperManual5, eDialog::PaperManual5
    d_byte eFlag::PaperManual6, eDialog::PaperManual6
    d_byte eFlag::PaperManual7, 0  ; TODO
    d_byte eFlag::PaperManual8, eDialog::PaperManual8
    d_byte eFlag::PaperManual9, eDialog::PaperManual9
    D_END
.ENDPROC

;;; Maps from eFlag::Paper* values to the eArea where each paper is located.
.EXPORT DataA_Pause_PaperLocation_eArea_arr
.PROC DataA_Pause_PaperLocation_eArea_arr
    D_ARRAY kNumPaperFlags, kFirstPaperFlag
    d_byte eFlag::PaperJerome01, eArea::Shadow   ; room: ShadowEntry
    d_byte eFlag::PaperJerome02, eArea::Shadow   ; room: ShadowHall
    d_byte eFlag::PaperJerome03, eArea::Sewer    ; room: SewerPipe
    d_byte eFlag::PaperJerome04, eArea::Shadow   ; room: ShadowHeart
    d_byte eFlag::PaperJerome05, eArea::Sewer    ; room: SewerWest
    d_byte eFlag::PaperJerome06, eArea::Shadow   ; room: ShadowOffice
    d_byte eFlag::PaperJerome07, eArea::Factory  ; room: FactoryBridge
    d_byte eFlag::PaperJerome08, eArea::Crypt    ; room: CryptCenter
    d_byte eFlag::PaperJerome09, eArea::Mine     ; room: MineNorth
    d_byte eFlag::PaperJerome10, eArea::Lava     ; room: LavaWest
    d_byte eFlag::PaperJerome11, eArea::Crypt    ; room: CryptSpiral
    d_byte eFlag::PaperJerome12, eArea::Garden   ; room: GardenHallway
    d_byte eFlag::PaperJerome13, eArea::Garden   ; room: GardenLanding
    d_byte eFlag::PaperJerome14, eArea::Garden   ; room: GardenFlower
    d_byte eFlag::PaperJerome15, eArea::Prison   ; room: PrisonLower
    d_byte eFlag::PaperJerome16, eArea::City     ; room: CityBuilding6
    d_byte eFlag::PaperJerome17, eArea::City     ; room: CityBuilding4
    d_byte eFlag::PaperJerome18, eArea::Factory  ; room: FactoryWest
    d_byte eFlag::PaperJerome19, eArea::Sewer    ; room: SewerBasin
    d_byte eFlag::PaperJerome20, eArea::Shadow   ; room: ShadowDescent
    d_byte eFlag::PaperJerome21, eArea::Crypt    ; room: CryptEscape
    d_byte eFlag::PaperJerome22, eArea::Sewer    ; room: SewerFlower
    d_byte eFlag::PaperJerome23, eArea::Core     ; room: CoreLock
    d_byte eFlag::PaperJerome24, eArea::City     ; room: CityBuilding1
    d_byte eFlag::PaperJerome25, $ff  ; TODO
    d_byte eFlag::PaperJerome26, $ff  ; TODO
    d_byte eFlag::PaperJerome27, eArea::Lava     ; room: LavaTunnel
    d_byte eFlag::PaperJerome28, eArea::Temple   ; room: TempleChevet
    d_byte eFlag::PaperJerome29, eArea::Mermaid  ; room: MermaidElevator
    d_byte eFlag::PaperJerome30, eArea::City     ; room: CityBuilding5
    d_byte eFlag::PaperJerome31, eArea::Core     ; room: CoreFlower
    d_byte eFlag::PaperJerome32, eArea::Shadow   ; room: ShadowDepths
    d_byte eFlag::PaperJerome33, eArea::City     ; room: CityDrain
    d_byte eFlag::PaperJerome34, eArea::Temple   ; room: TemplePit
    d_byte eFlag::PaperJerome35, eArea::City     ; room: CityDump
    d_byte eFlag::PaperJerome36, eArea::Prison   ; room: PrisonCell
    d_byte eFlag::PaperManual1,  eArea::Temple   ; room: TempleFoyer
    d_byte eFlag::PaperManual2,  eArea::Prison   ; room: PrisonEscape
    d_byte eFlag::PaperManual3,  eArea::Garden   ; room: GardenCrossroad
    d_byte eFlag::PaperManual4,  eArea::Lava     ; room: LavaStation
    d_byte eFlag::PaperManual5,  eArea::Factory  ; room: FactoryUpper
    d_byte eFlag::PaperManual6,  eArea::Garden   ; room: GardenShaft
    d_byte eFlag::PaperManual7,  $ff  ; TODO
    d_byte eFlag::PaperManual8,  eArea::City     ; room: CityBuilding3
    d_byte eFlag::PaperManual9,  eArea::Temple   ; room: TempleApse
    D_END
.ENDPROC

;;; Initializes the paper grid and cursor for the pause screen.
.EXPORT FuncA_Pause_InitPaperGrid
.PROC FuncA_Pause_InitPaperGrid
    ldx #$ff
    stx Zp_PaperCursorRow_u8
_ClearCollectedPapers:
    ldx #kPaperGridCols - 1
    lda #0
    @loop:
    sta Ram_CollectedPapers_u8_arr, x
    dex
    bpl @loop
_InitCollectedPapers:
    ldy #0
    sty T0  ; paper grid col
    iny  ; now Y is $01
    sty T1  ; bitmask
    ldx #kFirstPaperFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X and T0+, clears Z if flag is set
    beq @advanceCol
    ldy T0  ; paper grid col
    lda Ram_CollectedPapers_u8_arr, y
    ora T1  ; bitmask
    sta Ram_CollectedPapers_u8_arr, y
    @advanceCol:
    ldy T0  ; paper grid col
    iny
    cpy #kPaperGridCols
    blt @setCol
    asl T1  ; bitmask
    ldy #0
    @setCol:
    sty T0  ; paper grid col
    inx
    cpx #kLastPaperFlag + 1
    blt @loop
    rts
.ENDPROC

;;; Writes BG tile data for the pause screen papers grid directly to the PPU.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @prereq Hw_PpuAddr_w2 is set to the start of a nametable row.
.EXPORT FuncA_Pause_DirectDrawPaperGrid
.PROC FuncA_Pause_DirectDrawPaperGrid
    ldx #0
    @rowLoop:
    jsr FuncA_Pause_DirectDrawWindowBlankLine  ; preserves X
    ldy #kTileIdBgPaperTopLeft  ; param: paper left tile ID
    jsr FuncA_Pause_DirectDrawPaperLine  ; preserves X
    ldy #kTileIdBgPaperBottomLeft  ; param: paper left tile ID
    jsr FuncA_Pause_DirectDrawPaperLine  ; preserves X
    inx
    cpx #kPaperGridRows
    bne @rowLoop
    rts
.ENDPROC

;;; Writes BG tile data for one line of the papers section of the pause screen
;;; directly to the PPU.
;;; @prereq Rendering is disabled.
;;; @prereq Hw_PpuCtrl_wo is set to horizontal mode.
;;; @prereq Hw_PpuAddr_w2 is set to the start of the nametable row.
;;; @param X The paper grid row number (0-4).
;;; @param Y The BG tile ID for the left side of each paper.
;;; @preserve X
.PROC FuncA_Pause_DirectDrawPaperLine
    stx T0  ; paper grid row
    sty T1  ; left tile ID
    lda Data_PowersOfTwo_u8_arr8, x
    sta T2  ; bitmask
    jsr FuncA_Pause_DirectDrawWindowLineSide  ; preserves T0+
    ldx #0  ; paper grid col
    beq @start  ; unconditional
    @loop:
    lda #' '
    sta Hw_PpuData_rw
    @start:
    lda Ram_CollectedPapers_u8_arr, x
    and T2  ; bitmask
    beq @paperNotCollected
    @paperIsCollected:
    lda T1  ; left tile ID
    sta Hw_PpuData_rw
    .assert kTileIdBgPaperTopLeft | 2 = kTileIdBgPaperTopRight, error
    .assert kTileIdBgPaperBottomLeft | 2 = kTileIdBgPaperBottomRight, error
    ora #$02
    sta Hw_PpuData_rw
    bne @continue  ; unconditional
    @paperNotCollected:
    lda #' '
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    @continue:
    inx
    cpx #kPaperGridCols
    blt @loop
    ldx T0  ; paper grid row
    jmp FuncA_Pause_DirectDrawWindowLineSide  ; preserves X and T0+
.ENDPROC

;;; Draws objects for the paper grid cursor.
.EXPORT FuncA_Pause_DrawPaperCursor
.PROC FuncA_Pause_DrawPaperCursor
    ;; If the cursor is inactive, don't draw it.
    ldx Zp_PaperCursorRow_u8
    bmi @done
    ;; Allocate objects.
    lda #4  ; param: num objects
    jsr Func_AllocObjects  ; preserves X, returns Y
    ;; Set Y-positions.
    txa  ; paper cursor row
    mul #kTileHeightPx
    sta T0
    mul #2
    adc T0
    adc Zp_WindowTop_u8
    adc #kTileHeightPx * 3 - 1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    adc #kTileHeightPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    ;; Set X-positions.
    lda Zp_PaperCursorCol_u8
    mul #kTileWidthPx
    sta T0
    mul #2
    adc T0
    adc #kTileWidthPx * 3
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    adc #kTileWidthPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::XPos_u8, y
    ;; Set tile IDs.
    lda #kTileIdObjPaperCursor
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    ;; Set object flags.
    lda #bObj::Pri | kPaletteObjPaperCursor
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;; Moves the paper grid cursor based on the D-pad buttons.
.EXPORT FuncA_Pause_MovePaperCursor
.PROC FuncA_Pause_MovePaperCursor
_Down:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    beq @done
    jsr FuncA_Pause_MovePaperCursorDown
    @done:
_Up:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Up
    beq @done
    jsr FuncA_Pause_MovePaperCursorUp
    @done:
_Left:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Left
    beq @done
    jsr FuncA_Pause_MovePaperCursorPrev
    @done:
_Right:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Right
    beq @done
    jsr FuncA_Pause_MovePaperCursorNext
    @done:
    rts
.ENDPROC

;;; Moves the paper grid cursor up to the previous row, selecting the nearest
;;; collected paper on that row.  If there is no collected paper on the
;;; previous row, keeps going to the row before that.  If there is no collected
;;; paper on any row above the current row, deactivates the paper grid cursor.
.PROC FuncA_Pause_MovePaperCursorUp
    ldy Zp_PaperCursorRow_u8
    @loop:
    dey
    bmi @setRow
    jsr FuncA_Pause_NearestPaperOnRow  ; preserves Y, returns N and X
    bmi @loop
    stx Zp_PaperCursorCol_u8
    @setRow:
    sty Zp_PaperCursorRow_u8
    rts
.ENDPROC

;;; Moves the paper grid cursor down to the next row, selecting the nearest
;;; collected paper on that row.  If there is no collected paper on the
;;; previous row, keeps going to the next row after that.  If there is no
;;; collected paper on any row below the current row, leaves the cursor
;;; position unchanged.
.PROC FuncA_Pause_MovePaperCursorDown
    ldy Zp_PaperCursorRow_u8
    @loop:
    iny
    cpy #kPaperGridRows
    bge @return
    jsr FuncA_Pause_NearestPaperOnRow  ; preserves Y, returns N and X
    bmi @loop
    stx Zp_PaperCursorCol_u8
    sty Zp_PaperCursorRow_u8
    @return:
    rts
.ENDPROC

;;; Helper function for FuncA_Pause_MovePaperCursorUp/Down.  Finds the
;;; collected paper on the specified row (if any) that is nearest to the
;;; current cursor column.
;;; @param Y The paper grid row to consider.
;;; @return N Set if no paper on the specified row has been collected yet.
;;; @return X The paper grid column with the closest collected paper, if any.
;;; @preserve Y
.PROC FuncA_Pause_NearestPaperOnRow
    lda #$ff
    sta T0  ; best dist
    sta T1  ; best col
    ldx #kPaperGridCols - 1
    @loop:
    lda Data_PowersOfTwo_u8_arr8, y
    and Ram_CollectedPapers_u8_arr, x
    beq @continue
    txa
    sub Zp_PaperCursorCol_u8
    bge @noNegate
    eor #$ff
    adc #1  ; carry is already clear
    @noNegate:
    cmp T0  ; best dist
    bge @continue
    sta T0  ; best dist
    stx T1  ; best col
    @continue:
    dex
    bpl @loop
    ldx T1  ; best col
    rts
.ENDPROC

;;; Moves the paper grid cursor to the previous collected paper, if any.  If
;;; there is no previous collected paper, leaves the cursor position unchanged.
.PROC FuncA_Pause_MovePaperCursorPrev
    ldx Zp_PaperCursorCol_u8
    ldy Zp_PaperCursorRow_u8
    @prevCol:
    dex
    bpl @checkIfCollected
    @prevRow:
    dey
    bmi @return
    ldx #kPaperGridCols - 1
    @checkIfCollected:
    lda Data_PowersOfTwo_u8_arr8, y
    and Ram_CollectedPapers_u8_arr, x
    beq @prevCol
    @setCursor:
    stx Zp_PaperCursorCol_u8
    sty Zp_PaperCursorRow_u8
    @return:
    rts
.ENDPROC

;;; Moves the paper grid cursor to the next collected paper, if any.  If the
;;; paper grid cursor is currently inactive, sets it to the first collected
;;; paper, if any.  If there is no next collected paper, leaves the cursor
;;; position unchanged.
.EXPORT FuncA_Pause_MovePaperCursorNext
.PROC FuncA_Pause_MovePaperCursorNext
    ldx Zp_PaperCursorCol_u8
    ldy Zp_PaperCursorRow_u8
    bmi @nextRow
    @nextCol:
    inx
    cpx #kPaperGridCols
    blt @checkIfCollected
    @nextRow:
    cpy #kPaperGridRows - 1
    beq @return
    iny
    ldx #0
    @checkIfCollected:
    lda Data_PowersOfTwo_u8_arr8, y
    and Ram_CollectedPapers_u8_arr, x
    beq @nextCol
    @setCursor:
    stx Zp_PaperCursorCol_u8
    sty Zp_PaperCursorRow_u8
    @return:
    rts
.ENDPROC

;;; Determines whether or not at least one paper has been collected yet.
;;; @prereq The pause screen has been initialized.
;;; @return Z Cleared if any papers have been collected, set if none.
.EXPORT FuncA_Pause_AreAnyPapersCollected
.PROC FuncA_Pause_AreAnyPapersCollected
    ldx #kPaperGridCols - 1
    @loop:
    lda Ram_CollectedPapers_u8_arr, x
    bne @return
    dex
    bpl @loop
    inx  ; now X is zero and Z is set
    @return:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PaperJerome01_sDialog
.PROC DataA_Dialog_PaperJerome01_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome01_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome01_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome02_sDialog
.PROC DataA_Dialog_PaperJerome02_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome02_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome02_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome03_sDialog
.PROC DataA_Dialog_PaperJerome03_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome03_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome03_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome04_sDialog
.PROC DataA_Dialog_PaperJerome04_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome04_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome04_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome05_sDialog
.PROC DataA_Dialog_PaperJerome05_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome05_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome05_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome05_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome06_sDialog
.PROC DataA_Dialog_PaperJerome06_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome06_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome06_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome06_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome07_sDialog
.PROC DataA_Dialog_PaperJerome07_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome07_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome07_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome08_sDialog
.PROC DataA_Dialog_PaperJerome08_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome08_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome08_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome08_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome09_sDialog
.PROC DataA_Dialog_PaperJerome09_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome09_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome09_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome09_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome10_sDialog
.PROC DataA_Dialog_PaperJerome10_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome10_Page1_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome11_sDialog
.PROC DataA_Dialog_PaperJerome11_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome11_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome11_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome12_sDialog
.PROC DataA_Dialog_PaperJerome12_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome12_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome12_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome13_sDialog
.PROC DataA_Dialog_PaperJerome13_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome13_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome13_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome14_sDialog
.PROC DataA_Dialog_PaperJerome14_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome14_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome14_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome15_sDialog
.PROC DataA_Dialog_PaperJerome15_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome15_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome15_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome16_sDialog
.PROC DataA_Dialog_PaperJerome16_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome16_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome16_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome17_sDialog
.PROC DataA_Dialog_PaperJerome17_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome17_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome17_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome18_sDialog
.PROC DataA_Dialog_PaperJerome18_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome18_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome18_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome19_sDialog
.PROC DataA_Dialog_PaperJerome19_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome19_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome19_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome20_sDialog
.PROC DataA_Dialog_PaperJerome20_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome20_Page1_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome21_sDialog
.PROC DataA_Dialog_PaperJerome21_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome21_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome21_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome22_sDialog
.PROC DataA_Dialog_PaperJerome22_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome22_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome22_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome23_sDialog
.PROC DataA_Dialog_PaperJerome23_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome23_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome23_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome24_sDialog
.PROC DataA_Dialog_PaperJerome24_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome24_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome24_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome27_sDialog
.PROC DataA_Dialog_PaperJerome27_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome27_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome27_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome27_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome28_sDialog
.PROC DataA_Dialog_PaperJerome28_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome28_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome28_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome29_sDialog
.PROC DataA_Dialog_PaperJerome29_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome29_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome29_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome30_sDialog
.PROC DataA_Dialog_PaperJerome30_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome30_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome30_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome30_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome31_sDialog
.PROC DataA_Dialog_PaperJerome31_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome31_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome31_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome32_sDialog
.PROC DataA_Dialog_PaperJerome32_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome32_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome32_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome32_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome33_sDialog
.PROC DataA_Dialog_PaperJerome33_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome33_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome33_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome33_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome34_sDialog
.PROC DataA_Dialog_PaperJerome34_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome34_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome34_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome35_sDialog
.PROC DataA_Dialog_PaperJerome35_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome35_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome35_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome35_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperJerome36_sDialog
.PROC DataA_Dialog_PaperJerome36_sDialog
    dlg_Text Paper, DataA_Text2_PaperJerome36_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome36_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperJerome36_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperManual1_sDialog
.PROC DataA_Dialog_PaperManual1_sDialog
    dlg_Text Paper, DataA_Text2_PaperManual1_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual1_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperManual2_sDialog
.PROC DataA_Dialog_PaperManual2_sDialog
    dlg_Text Paper, DataA_Text2_PaperManual2_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual2_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperManual3_sDialog
.PROC DataA_Dialog_PaperManual3_sDialog
    dlg_Text Paper, DataA_Text2_PaperManual3_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual3_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperManual4_sDialog
.PROC DataA_Dialog_PaperManual4_sDialog
    dlg_Text Paper, DataA_Text2_PaperManual4_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual4_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperManual5_sDialog
.PROC DataA_Dialog_PaperManual5_sDialog
    dlg_Text Paper, DataA_Text2_PaperManual5_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual5_Page2_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual5_Page3_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperManual6_sDialog
.PROC DataA_Dialog_PaperManual6_sDialog
    dlg_Text Paper, DataA_Text2_PaperManual6_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual6_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperManual8_sDialog
.PROC DataA_Dialog_PaperManual8_sDialog
    dlg_Text Paper, DataA_Text2_PaperManual8_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual8_Page2_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_PaperManual9_sDialog
.PROC DataA_Dialog_PaperManual9_sDialog
    dlg_Text Paper, DataA_Text2_PaperManual9_Page1_u8_arr
    dlg_Text Paper, DataA_Text2_PaperManual9_Page2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
