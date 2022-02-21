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
.INCLUDE "flag.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "ppu.inc"
.INCLUDE "window.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeIn
.IMPORT Func_FadeOut
.IMPORT Func_ProcessFrame
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_Disable
.IMPORT Main_Explore_Unpause
.IMPORT Ppu_ChrPause
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte

;;;=========================================================================;;;

;;; The BG tile ID for the bottom-left tile for all upgrade symbols.  Add 1 to
;;; this to get the the bottom-right tile ID for those symbols.
kUpgradeTileIdBottomLeft  = $80
;;; The BG tile ID for the top-left tile of the symbol for max-instruction
;;; upgrades.  Add 1 to this to get the the top-right tile ID for that symbol.
kMaxInstTileIdTopLeft     = $82
;;; The BG tile ID for the top-left tile for the symbol of the first
;;; non-max-instruction upgrade.  Add 1 to this to get the the top-right tile
;;; ID for that symbol, then add another 1 to get the top-left tile ID for the
;;; next upgrade, and so on.
kRemainingTileIdTopLeft   = $84

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for when the game is paused.
;;; @prereq Rendering is disabled.
.EXPORT Main_Pause
.PROC Main_Pause
    chr08_bank #<.bank(Ppu_ChrPause)
    jsr Func_Window_Disable
    prga_bank #<.bank(FuncA_Pause_DirectDrawBg)
    jsr FuncA_Pause_DirectDrawBg
    jsr FuncA_Pause_DrawObjectsForMinimap
    jsr Func_ClearRestOfOam
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jsr Func_FadeIn
_GameLoop:
    prga_bank #<.bank(FuncA_Pause_DrawObjectsForMinimap)
    jsr FuncA_Pause_DrawObjectsForMinimap
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckForUnause:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start | bJoypad::BButton | bJoypad::AButton
    beq @done
    jsr Func_FadeOut
    jmp Main_Explore_Unpause
    @done:
_Tick:
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

.PROC DataA_Pause_CurrentAreaLabel_u8_arr
Start:
    .byte kWindowTileIdTopRight, kWindowTileIdBlank
LineStart:
    .byte kWindowTileIdBlank, kWindowTileIdVert
    .byte " Current area: "
kAreaNameStartCol = * - LineStart
kSize = * - Start
.ENDPROC

kAreaNameStartCol = DataA_Pause_CurrentAreaLabel_u8_arr::kAreaNameStartCol

;;; TODO: get rid of this, and use the current area data instead
.PROC DataA_Pause_CurrentAreaName_u8_arr
    .byte "Deep Crypt", $ff
.ENDPROC

;;; Directly fills PPU nametable 0 with BG tile data for the pause screen.
.PROC FuncA_Pause_DirectDrawBg
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable0_sName + sName::Tiles_u8_arr
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
_ClearTopRows:
    lda #kWindowTileIdBlank
    ldx #kScreenWidthTiles * 2 + 1
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_DrawTopBorder:
    lda #kWindowTileIdTopLeft
    sta Hw_PpuData_rw
    lda #kWindowTileIdHorz
    ldx #kScreenWidthTiles - 4
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_DrawCurrentAreaLabel:
    ldx #0
    @loop:
    lda DataA_Pause_CurrentAreaLabel_u8_arr, x
    sta Hw_PpuData_rw
    inx
    cpx #DataA_Pause_CurrentAreaLabel_u8_arr::kSize
    blt @loop
_DrawCurrentAreaName:
    ldy #0
    beq @start  ; unconditional
    @loop:
    sta Hw_PpuData_rw
    iny
    @start:
    lda DataA_Pause_CurrentAreaName_u8_arr, y
    bpl @loop
    @break:
_FinishCurrentAreaLine:
    lda #kWindowTileIdBlank
    .assert kWindowTileIdBlank = 0, error
    beq @start  ; unconditional
    @loop:
    sta Hw_PpuData_rw
    iny
    @start:
    cpy #kScreenWidthTiles - kAreaNameStartCol - 2
    blt @loop
_DrawMinimap:
    ;; TODO: actually draw minimap
    ldx #0
    @rowLoop:
    jsr _DrawLineBreak  ; preserves X
    lda #kWindowTileIdBlank
    ldy #kScreenWidthTiles - 4
    @colLoop:
    sta Hw_PpuData_rw
    dey
    bne @colLoop
    inx
    cpx #17
    bne @rowLoop
_DrawItems:
    ;; TODO: actually draw items
    ldx #0
    @rowLoop:
    jsr _DrawLineBreak  ; preserves X
    jsr FuncA_Pause_DirectDrawItemsLine  ; preserves X
    inx
    cpx #6
    bne @rowLoop
_DrawBottomBorder:
    lda #kWindowTileIdVert
    sta Hw_PpuData_rw
    lda #kWindowTileIdBlank
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    lda #kWindowTileIdBottomLeft
    sta Hw_PpuData_rw
    lda #kWindowTileIdHorz
    ldx #kScreenWidthTiles - 4
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    lda #kWindowTileIdBottomRight
    sta Hw_PpuData_rw
_ClearBottomRows:
    lda #kWindowTileIdBlank
    ldx #kScreenWidthTiles * 2 + 1
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
_DrawLineBreak:
    lda #kWindowTileIdVert
    ldy #kWindowTileIdBlank
    sta Hw_PpuData_rw
    sty Hw_PpuData_rw
    sty Hw_PpuData_rw
    sta Hw_PpuData_rw
    rts
.ENDPROC

;;; Writes BG tile data for one line of the items section of the pause screen
;;; (not including the borders) directly to the PPU.
;;; @param X The item line number (0-5).
;;; @preserve X
.PROC FuncA_Pause_DirectDrawItemsLine
.PROC _DrawConduits
    ;; TODO: actually draw conduits
    lda #kWindowTileIdBlank
    ldy #14
    @loop:
    sta Hw_PpuData_rw
    dey
    bne @loop
.ENDPROC
.PROC _DrawUpgrades
    ;; Calculate the eFlag value for the first upgrade on this line, and store
    ;; it in Zp_Tmp1_byte.
    txa  ; line number (0-5)
    and #$fe
    asl a
    sta Zp_Tmp1_byte  ; upgrade eFlag
    ;; Loop over each upgrade on this line.
    lda #4
    sta Zp_Tmp2_byte  ; loop counter
    @loop:
    ;; Get the byte offset into Sram_ProgressFlags_arr for this eFlag, and
    ;; store it in Zp_Tmp3_byte.
    lda Zp_Tmp1_byte  ; upgrade eFlag
    div #$08
    sta Zp_Tmp3_byte  ; flags byte offset
    ;; Check if the player has this upgrade.
    lda Zp_Tmp1_byte  ; upgrade eFlag
    and #$07
    tay
    lda Data_PowersOfTwo_u8_arr8, y
    ldy Zp_Tmp3_byte  ; flags byte offset
    and Sram_ProgressFlags_arr, y
    bne @drawUpgrade
    ;; The player doesn't have this upgrade yet, so draw some blank space.
    lda #kWindowTileIdBlank
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    .assert kWindowTileIdBlank = 0, error
    beq @continue  ; unconditional
    @drawUpgrade:
    ;; The player does have this upgrade.  Determine the first tile ID to draw
    ;; for this line of this upgrade.
    txa  ; line number (0-5)
    and #$01
    beq @top
    @bottom:
    lda #kUpgradeTileIdBottomLeft
    .assert kUpgradeTileIdBottomLeft > 0, error
    bne @draw  ; unconditional
    @top:
    lda Zp_Tmp1_byte  ; upgrade eFlag
    .assert kNumMaxInstructionUpgrades = 4, error
    sub #eFlag::UpgradeMaxInstructions3 + 1
    blt @upgradeMaxInstructions
    mul #2
    add #kRemainingTileIdTopLeft
    bcc @draw  ; unconditional
    @upgradeMaxInstructions:
    lda #kMaxInstTileIdTopLeft
    @draw:
    ;; Draw the upgrade.
    sta Hw_PpuData_rw
    add #1
    sta Hw_PpuData_rw
    lda #kWindowTileIdBlank
    sta Hw_PpuData_rw
    @continue:
    ;; Continue to the next upgrade on this line.
    inc Zp_Tmp1_byte  ; upgrade eFlag
    dec Zp_Tmp2_byte  ; loop counter
    bne @loop
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
.ENDPROC
    rts
.ENDPROC

;;; Allocates and populates OAM slots for objects that should be drawn on the
;;; pause screen minimap.
.PROC FuncA_Pause_DrawObjectsForMinimap
    ;; TODO: draw objects for minimap
    rts
.ENDPROC

;;;=========================================================================;;;
