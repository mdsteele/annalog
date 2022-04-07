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

.INCLUDE "flag.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Fade_In
.IMPORT FuncA_Fade_Out
.IMPORT FuncA_Upgrade_ComputeMaxInstructions
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ProcessFrame
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_Disable
.IMPORT Main_Explore_EnterFromDevice
.IMPORT Ppu_ChrTitle
.IMPORT Sram_MagicNumber_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask

;;;=========================================================================;;;

;;; The nametable tile row (of the upper nametable) that the game title starts
;;; on.
kTitleStartRow = 10

;;; The PPU address in the upper nametable for the top-left corner of the game
;;; title.
.LINECONT +
Ppu_TitleTopLeft = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * kTitleStartRow
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for displaying the title screen.
;;; @prereq Rendering is disabled.
.EXPORT Main_Title
.PROC Main_Title
    jsr_prga FuncA_Title_Init
    jsr_prga FuncA_Fade_In
_GameLoop:
    jsr Func_UpdateButtons
    ;; Check START button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    bne _StartGame
    jsr Func_ProcessFrame
    jmp _GameLoop
_StartGame:
    jsr_prga FuncA_Fade_Out
    ldy #$00  ; param: attribute byte
    jsr_prga FuncA_Title_FillUpperAttributeTable
    jsr_prga FuncA_Title_ResetSramForNewGame
    jsr_prga FuncA_Upgrade_ComputeMaxInstructions
    ldx #eRoom::TownHouse2  ; param: room number
    ldy #0  ; param: device index
    jmp Main_Explore_EnterFromDevice
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Title"

;;; The tile ID grid for the game title (stored in row-major order).
.PROC DataA_Title_Map_u8_arr
:   .incbin "out/data/title.map"
    .assert * - :- = kScreenWidthTiles * 3, error
End:
.ENDPROC

;;; Initializes title mode.
;;; @prereq Rendering is disabled.
.PROC FuncA_Title_Init
    jsr Func_Window_Disable
    chr08_bank #<.bank(Ppu_ChrTitle)
_ClearOam:
    lda #0
    sta Zp_OamOffset_u8
    jsr Func_ClearRestOfOam
_ClearUpperNametable:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #0
    ldxy #kScreenWidthTiles * kScreenHeightTiles
    @loop:
    sta Hw_PpuData_rw
    dey
    bne @loop
    dex
    bpl @loop
_DrawTitle:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_TitleTopLeft
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    ldy #DataA_Title_Map_u8_arr::End - DataA_Title_Map_u8_arr
    ldx #0
    @loop:
    lda DataA_Title_Map_u8_arr, x
    sta Hw_PpuData_rw
    inx
    dey
    bne @loop
_InitAttributeTable:
    ldy #$55  ; param: attribute byte
    jsr FuncA_Title_FillUpperAttributeTable
_SetRenderState:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    rts
.ENDPROC

;;; Fills the upper attribute table with the given byte.
;;; @param Y The attribute byte to set.
.PROC FuncA_Title_FillUpperAttributeTable
    ldax #Ppu_Nametable0_sName + sName::Attrs_u8_arr64
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    ldx #64
    @loop:
    sty Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;; Erases all of SRAM and creates a save file for a new game.
.PROC FuncA_Title_ResetSramForNewGame
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Zero all of SRAM.
    lda #0
    tax
    @loop:
    .repeat $20, index
    sta $6000 + $100 * index, x
    .endrepeat
    inx
    bne @loop
    ;; Mark the save file as present.
    lda #kSaveMagicNumber
    sta Sram_MagicNumber_u8
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    rts
.ENDPROC

;;;=========================================================================;;;
