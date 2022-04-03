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
.INCLUDE "oam.inc"
.INCLUDE "pause.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "window.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT Func_ClearRestOfOam
.IMPORT Func_FadeIn
.IMPORT Func_FadeOut
.IMPORT Func_ProcessFrame
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_Disable
.IMPORT Main_Explore_FadeIn
.IMPORT Ppu_ChrPause
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_Minimap_u16_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarMinimapCol_u8
.IMPORTZP Zp_AvatarMinimapRow_u8
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

;;; The BG tile ID for an unexplored tile on the minimap.
kMinimapTileIdUnexplored  = $80

;;; The OBJ tile ID for marking the current area on the minimap.
kMinimapAreaObjTileId     = $02

;;; The BG tile ID for the bottom-left tile for all upgrade symbols.  Add 1 to
;;; this to get the the bottom-right tile ID for those symbols.
kUpgradeTileIdBottomLeft  = $ac
;;; The BG tile ID for the top-left tile of the symbol for max-instruction
;;; upgrades.  Add 1 to this to get the the top-right tile ID for that symbol.
kMaxInstTileIdTopLeft     = $ae
;;; The BG tile ID for the top-left tile for the symbol of the first
;;; non-max-instruction upgrade.  Add 1 to this to get the the top-right tile
;;; ID for that symbol, then add another 1 to get the top-left tile ID for the
;;; next upgrade, and so on.
kRemainingTileIdTopLeft   = $b0

;;; The screen pixel positions for the top and left edges of the minimap rect.
kMinimapTopPx  = $28
kMinimapLeftPx = $20

;;; The OBJ palette numbers for marking the current area and blinking the
;;; current screen on the minimap.
kMinimapCurrentAreaPalette   = 0
kMinimapCurrentScreenPalette = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for when the game is paused.
;;; @prereq Rendering is disabled.
.EXPORT Main_Pause
.PROC Main_Pause
    chr08_bank #<.bank(Ppu_ChrPause)
    jsr_prga FuncA_Pause_InitAndFadeIn
_GameLoop:
    jsr_prga FuncA_Pause_DrawObjectsForMinimap
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckForUnause:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start | bJoypad::BButton | bJoypad::AButton
    beq @done
    jsr Func_FadeOut
    jmp Main_Explore_FadeIn
    @done:
_Tick:
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Pause"

;;; The tile ID grid for the minimap (stored in row-major order).
.PROC DataA_Pause_Minimap_u8_arr
:   .incbin "out/data/minimap.map"
    .assert * - :- = kMinimapWidth * kMinimapHeight, error
.ENDPROC

;;; The "Current area:" label that is drawn on the pause screen, along with
;;; some of the surrounding tiles.
.PROC DataA_Pause_CurrentAreaLabel_u8_arr
Start:
    .byte kWindowTileIdTopRight, kWindowTileIdBlank
LineStart:
    .byte kWindowTileIdBlank, kWindowTileIdVert
    .byte " Current area: "
kAreaNameStartCol = * - LineStart
kSize = * - Start
.ENDPROC

;;; The screen tile column that the area name begins on.
kAreaNameStartCol = DataA_Pause_CurrentAreaLabel_u8_arr::kAreaNameStartCol

;;; Initializes pause mode, then fades in the screen.
;;; @prereq Rendering is disabled.
.PROC FuncA_Pause_InitAndFadeIn
    ;; Reset the frame counter before drawing any objects so that the
    ;; current-position blink will be in aconsistent state as we fade in.
    lda #0
    sta Zp_FrameCounter_u8
_DrawScreen:
    jsr Func_Window_Disable
    jsr FuncA_Pause_DirectDrawBg
    jsr FuncA_Pause_DrawObjectsForMinimap
    jsr Func_ClearRestOfOam
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jmp Func_FadeIn
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
    ;; Copy the current room's AreaName_u8_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::AreaName_u8_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Draw the room's area name.
    ldy #0
    beq @start  ; unconditional
    @loop:
    sta Hw_PpuData_rw
    iny
    @start:
    lda (Zp_Tmp_ptr), y
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
    jsr _DrawBlankLine
    ldya #DataA_Pause_Minimap_u8_arr
    stya Zp_Tmp_ptr
    ldx #0
    @rowLoop:
    jsr _DrawLineBreak  ; preserves X and Zp_Tmp_ptr
    jsr FuncA_Pause_DirectDrawMinimapLine  ; preserves X, advances Zp_Tmp_ptr
    inx
    cpx #kMinimapHeight
    bne @rowLoop
    jsr _DrawBlankLine
_DrawItems:
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
_DrawBlankLine:
    jsr _DrawLineBreak
    lda #kWindowTileIdBlank
    ldy #kScreenWidthTiles - 4
    @colLoop:
    sta Hw_PpuData_rw
    dey
    bne @colLoop
    rts
.ENDPROC

;;; Writes BG tile data for one line of the pause screen minimap (not including
;;; the borders) directly to the PPU.
;;; @param Zp_Tmp_ptr The start of the minimap tile data row.
;;; @param X The minimap row (0-15).
;;; @return Zp_Tmp_ptr The start of the next minimap tile data row.
;;; @preserve X
.PROC FuncA_Pause_DirectDrawMinimapLine
    ;; Draw left margin.
    lda #kWindowTileIdBlank
    sta Hw_PpuData_rw
    sta Hw_PpuData_rw
    ;; Determine the bitmask we should use for this minimap row, and store it
    ;; in Zp_Tmp1_byte.
    txa
    and #$07
    tay
    lda Data_PowersOfTwo_u8_arr8, y
    sta Zp_Tmp1_byte  ; mask
    ;; Save X in Zp_Tmp2_byte so we can use X for something else and later
    ;; restore it.
    stx Zp_Tmp2_byte  ; minimap row
    ;; We'll use Y as the byte index into the minimap tile data (starting from
    ;; Zp_Tmp_ptr).
    ldy #0
    ;; We'll use X as the byte index into Sram_Minimap_u16_arr.  If we're in
    ;; the first eight rows, we'll be checking our bitmask against the low
    ;; eight bits of each u16; otherwise, we'll be checking against the high
    ;; eight bits.
    txa
    ldx #0
    cmp #8
    blt @colLoop
    inx
    ;; For each tile in this minimap row, check if the player has explored
    ;; that screen.  If so, draw that minimap tile; otherwise, draw a blank
    ;; tile.
    @colLoop:
    lda Sram_Minimap_u16_arr, x
    and Zp_Tmp1_byte  ; mask
    bne @explored
    lda #kMinimapTileIdUnexplored
    .assert kMinimapTileIdUnexplored > 0, error
    bne @draw  ; unconditional
    @explored:
    lda (Zp_Tmp_ptr), y
    @draw:
    sta Hw_PpuData_rw
    inx
    inx
    iny
    cpy #kMinimapWidth
    blt @colLoop
    ;; Advance Zp_Tmp_ptr.
    tya
    add Zp_Tmp_ptr + 0
    sta Zp_Tmp_ptr + 0
    lda #0
    adc Zp_Tmp_ptr + 1
    sta Zp_Tmp_ptr + 1
    ;; Restore X (since this function needs to preserve it).
    ldx Zp_Tmp2_byte  ; minimap row
    ;; Draw right margin.
    lda #kWindowTileIdBlank
    sta Hw_PpuData_rw
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
    lda _ConduitTiles, x
    ldy #kWindowTileIdBlank
    sty Hw_PpuData_rw
    sty Hw_PpuData_rw
    sty Hw_PpuData_rw
    .repeat 8
    sta Hw_PpuData_rw
    .endrepeat
    sty Hw_PpuData_rw
    sty Hw_PpuData_rw
    sty Hw_PpuData_rw
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
_ConduitTiles:
    .byte "-=- M "
.ENDPROC

;;; Allocates and populates OAM slots for objects that should be drawn on the
;;; pause screen minimap.
.PROC FuncA_Pause_DrawObjectsForMinimap
    ;; Copy the current room's AreaCells_u8_arr2_arr_ptr into Zp_Tmp_ptr.
    ldy #sRoomExt::AreaCells_u8_arr2_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta Zp_Tmp_ptr + 1
    ;; Draw an object for each explored minimap cell in the array.
    ldy #0
    beq @continue  ; unconditional
    @loop:
    ;; At this point, A holds the most recently read minimap row.  Store it in
    ;; Zp_Tmp1_byte for later.
    iny
    sta Zp_Tmp1_byte  ; minimap row
    ;; Determine the bitmask we should use for this minimap row, and store it
    ;; in Zp_Tmp3_byte.
    and #$07
    tax
    lda Data_PowersOfTwo_u8_arr8, x
    sta Zp_Tmp3_byte  ; mask
    ;; Read the minimap col and store it in Zp_Tmp2_byte for later.
    lda (Zp_Tmp_ptr), y
    iny
    sta Zp_Tmp2_byte  ; minimap col
    ;; We'll use X as the byte index into Sram_Minimap_u16_arr.  If we're in
    ;; the first eight rows, we'll be checking our bitmask against the low
    ;; eight bits of each u16; otherwise, we'll be checking against the high
    ;; eight bits.
    mul #2
    tax
    lda Zp_Tmp1_byte  ; minimap row
    cmp #$08
    blt @loByte
    inx
    @loByte:
    ;; Check if this minimap cell has been explored.  If not, don't draw an
    ;; object for this cell.
    lda Sram_Minimap_u16_arr, x
    and Zp_Tmp3_byte  ; mask
    beq @continue
    ;; If this minimap cell is the avatar's current position, blink its color.
    lda Zp_Tmp1_byte  ; minimap row
    cmp Zp_AvatarMinimapRow_u8
    bne @noBlink
    lda Zp_Tmp2_byte  ; minimap col
    cmp Zp_AvatarMinimapCol_u8
    bne @noBlink
    lda Zp_FrameCounter_u8
    and #$10
    beq @noBlink
    @blink:
    lda #bObj::Pri | kMinimapCurrentScreenPalette
    bne @setFlags  ; unconditional
    @noBlink:
    lda #bObj::Pri | kMinimapCurrentAreaPalette
    @setFlags:
    ;; Draw an object for this minimap cell.
    ldx Zp_OamOffset_u8
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, x
    lda Zp_Tmp1_byte  ; minimap row
    mul #kTileHeightPx
    adc #kMinimapTopPx - 1
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, x
    lda Zp_Tmp2_byte  ; minimap col
    mul #kTileWidthPx
    adc #kMinimapLeftPx
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, x
    lda #kMinimapAreaObjTileId
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, x
    .repeat .sizeof(sObj)
    inx
    .endrepeat
    stx Zp_OamOffset_u8
    ;; Read the minimap row (or $ff terminator) for the next iteration.
    @continue:
    lda (Zp_Tmp_ptr), y
    bpl @loop
    rts
.ENDPROC

;;;=========================================================================;;;
