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
.INCLUDE "flag.inc"
.INCLUDE "irq.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "newgame.inc"
.INCLUDE "oam.inc"
.INCLUDE "pause.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"

.IMPORT DataC_Title_NewGameName_u8_arr8_arr
.IMPORT FuncC_Title_ResetSramForNewGame
.IMPORT Func_AckIrqAndSetLatch
.IMPORT Func_AllocObjects
.IMPORT Func_AllocOneObject
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FadeInFromBlackToNormal
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FillLowerAttributeTable
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_GetRandomByte
.IMPORT Func_PlaySfxExplodeFracture
.IMPORT Func_PlaySfxMenuCancel
.IMPORT Func_PlaySfxMenuConfirm
.IMPORT Func_PlaySfxMenuMove
.IMPORT Func_PlaySfxSecretUnlocked
.IMPORT Func_SignedDivFrac
.IMPORT Func_Sine
.IMPORT Func_Window_Disable
.IMPORT MainC_Title_Prologue
.IMPORT Main_Explore_SpawnInLastSafeRoom
.IMPORT Ppu_ChrBgFontUpper
.IMPORT Ppu_ChrBgTitle
.IMPORT Ppu_ChrObjPause
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_MagicNumber_u8
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Next_sAudioCtrl
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

;;; The higher the number, the more slowly the tile screen menu line tracks
;;; towards the currently-selected menu item.
.DEFINE kMenuLineYSlowdown 2

;;; The base screen Y-position for the topmost title screen menu item.
kTitleMenuFirstItemY = $98

;;; The stride height, in pixels, between adjacent menu items.
kTitleMenuItemStridePx = 16

;;; The gap width, in tiles, in the middle of the title menu line.
kTitleMenuLineGapTiles = 8

;;; The screen pixel Y-position for the New Game cheat code menu item.
kCheatMenuYPos = $b0

;;; The vertical offset, in pixels, from the New Game cheat code menu item at
;;; which to draw the arrows.
kCheatMenuArrowOffsetPx = 14

;;; The BG tile ID used for drawing the title screen menu line.
kTileIdBgTitleMenuLine = $a5

;;; The OBJ tile ID used for drawing the arrows for the New Game cheat code
;;; menu.
kTileIdObjCheatMenuArrows = kTileIdObjArrowCursor & $7f

;;; The OBJ palette number used for title screen menu items.
kPaletteObjTitleMenuItem = 0
;;; The OBJ palette number used for the cheat code menu arrows.
kPaletteObjCheatMenuArrows = 1

;;; The length of the confirmation message for deleting a saved game, in tiles.
.DEFINE kAreYouSureLength 26

;;; The PPU address in the upper nametable for the start of the confirmation
;;; message for deleting a saved game.
.LINECONT +
Ppu_TitleAreYouSureStart = Ppu_Nametable0_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * 20 + (kScreenWidthTiles - kAreYouSureLength) / 2
.LINECONT -

;;; Title screen menu items that can be selected.
.ENUM eTitle
    TopContinue
    TopNewGame
    TopCredits
    NewCancel
    NewDelete
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; The concatenated string data for all title screen menu items.
.PROC DataC_Title_Letters_u8_arr
.PROC Continue
    .byte "CONTINUE"
.ENDPROC
.PROC NewGame
    .byte "NEW GAME"
.ENDPROC
.PROC Credits
    .byte "CREDITS"
.ENDPROC
.PROC Cancel
    .byte "CANCEL"
.ENDPROC
.PROC Delete
    .byte "DELETE"
.ENDPROC
.ENDPROC

;;; Maps from eTitle values to byte offsets into DataC_Title_Letters_u8_arr and
;;; Ram_TitleLetterOffset_i8_arr for each menu item.
.PROC DataC_Title_MenuItemOffset_u8_arr
    .linecont +
    D_ARRAY .enum, eTitle
    d_byte TopContinue, \
           DataC_Title_Letters_u8_arr::Continue - DataC_Title_Letters_u8_arr
    d_byte TopNewGame, \
           DataC_Title_Letters_u8_arr::NewGame  - DataC_Title_Letters_u8_arr
    d_byte TopCredits, \
           DataC_Title_Letters_u8_arr::Credits  - DataC_Title_Letters_u8_arr
    d_byte NewCancel, \
           DataC_Title_Letters_u8_arr::Cancel   - DataC_Title_Letters_u8_arr
    d_byte NewDelete, \
           DataC_Title_Letters_u8_arr::Delete   - DataC_Title_Letters_u8_arr
    D_END
    .linecont -
.ENDPROC

;;; Maps from eTitle values to string lengths in bytes for each menu item.
.PROC DataC_Title_MenuItemLength_u8_arr
    D_ARRAY .enum, eTitle
    d_byte TopContinue, .sizeof(DataC_Title_Letters_u8_arr::Continue)
    d_byte TopNewGame,  .sizeof(DataC_Title_Letters_u8_arr::NewGame)
    d_byte TopCredits,  .sizeof(DataC_Title_Letters_u8_arr::Credits)
    d_byte NewCancel,   .sizeof(DataC_Title_Letters_u8_arr::Cancel)
    d_byte NewDelete,   .sizeof(DataC_Title_Letters_u8_arr::Delete)
    D_END
.ENDPROC

;;; Maps from eTitle values to the base screen Y-position for each menu item.
.PROC DataC_Title_MenuItemPosY_u8_arr
    D_ARRAY .enum, eTitle
    d_byte TopContinue, 0 * kTitleMenuItemStridePx + kTitleMenuFirstItemY
    d_byte TopNewGame,  1 * kTitleMenuItemStridePx + kTitleMenuFirstItemY
    d_byte TopCredits,  2 * kTitleMenuItemStridePx + kTitleMenuFirstItemY
    d_byte NewCancel,   2 * kTitleMenuItemStridePx + kTitleMenuFirstItemY
    d_byte NewDelete,   3 * kTitleMenuItemStridePx + kTitleMenuFirstItemY
    D_END
.ENDPROC

;;;=========================================================================;;;

.ZEROPAGE

;;; The first and last menu items currently selectable on the title screen.
Zp_First_eTitle: .res 1
Zp_Last_eTitle: .res 1

;;; The currently-selected title screen menu item.
Zp_Current_eTitle: .res 1

;;; The current Y-position for the title screen menu line.
Zp_TitleMenuLinePosY_u8: .res 1

;;; The index into DataC_Title_CheatSequence_bJoypad_arr for the next button to
;;; press for the cheat code.
Zp_CheatSequenceIndex_u8: .res 1

;;; The currently-selected item on the cheat menu.
Zp_Cheat_eNewGame: .res 1

;;;=========================================================================;;;

.SEGMENT "RAM_Title"

;;; The current vertical offset, in pixels, from the base Y-position for each
;;; letter of each title menu item.
Ram_TitleLetterOffset_i8_arr: .res .sizeof(DataC_Title_Letters_u8_arr)

;;;=========================================================================;;;

.SEGMENT "PRGC_Title"

;;; The tile ID grid for the game title (stored in row-major order).
.PROC DataC_Title_Map_u8_arr
:   .incbin "out/data/title.map"
    .assert * - :- = kScreenWidthTiles * 3, error
.ENDPROC

;;; The PPU transfer entry for displaying the confirmation message for deleting
;;; a saved game.
.PROC DataC_Title_AreYouSureTransfer_arr
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TitleAreYouSureStart  ; transfer destination
    .byte kAreYouSureLength         ; transfer length
:   .byte "DELETE EXISTING SAVE DATA?"
    .assert * - :- = kAreYouSureLength, error
.ENDPROC

;;; The PPU transfer entry for hiding the confirmation message for deleting a
;;; saved game.
.PROC DataC_Title_DoneConfirmTransfer_arr
    .byte kPpuCtrlFlagsHorz
    .dbyt Ppu_TitleAreYouSureStart  ; transfer destination
    .byte kAreYouSureLength         ; transfer length
    .res kAreYouSureLength, ' '
.ENDPROC

;;; The sequence of button presses need for the New Game cheat code.
.PROC DataC_Title_CheatSequence_bJoypad_arr
    .byte bJoypad::Down     ;   Down
    .byte bJoypad::Left     ;  lEft
    .byte bJoypad::BButton  ;   B
    .byte bJoypad::Up       ;   Up
    .byte bJoypad::Right    ; riGht
    .byte bJoypad::Right    ; riGht
    .byte bJoypad::Left     ;  lEft
    .byte bJoypad::Right    ;   Right
.ENDPROC

;;; Mode for displaying the title screen.
;;; @prereq PRGC_Title is loaded.
;;; @prereq Rendering is disabled.
.EXPORT MainC_Title_Menu
.PROC MainC_Title_Menu
    jsr FuncC_Title_InitAndFadeIn
_GameLoop:
    jsr FuncC_Title_DrawMenu
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr Func_GetRandomByte  ; tick the RNG (and discard the result)
    jsr FuncC_Title_TickMenu
_CheckForCheatInput:
    ;; Only allow the New Game cheat if there's no saved game data.
    lda Sram_MagicNumber_u8
    cmp #kSaveMagicNumber
    beq @resetCheatIndex  ; a saved game exists
    ;; If a button was pressed, check whether it's the next input in the cheat
    ;; sequence.  If not, reset the sequence.
    lda Zp_P1ButtonsPressed_bJoypad
    beq @done  ; no button pressed
    ldx Zp_CheatSequenceIndex_u8
    cmp DataC_Title_CheatSequence_bJoypad_arr, x
    bne @resetCheatIndex  ; incorrect cheat sequence
    ;; If the cheat sequence has been fully entered, switch to the cheat menu.
    inx
    cpx #.sizeof(DataC_Title_CheatSequence_bJoypad_arr)
    blt @setCheatIndex  ; cheat sequence still in progress
    jmp MainC_Title_CheatMenu
    @resetCheatIndex:
    ldx #0
    @setCheatIndex:
    stx Zp_CheatSequenceIndex_u8
    @done:
_CheckForMenuInput:
    ;; Check Up button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Up
    beq @noUp
    lda Zp_Current_eTitle
    cmp Zp_First_eTitle
    beq @noUp
    dec Zp_Current_eTitle
    jsr Func_PlaySfxMenuMove
    @noUp:
    ;; Check Down button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    beq @noDown
    lda Zp_Current_eTitle
    cmp Zp_Last_eTitle
    beq @noDown
    inc Zp_Current_eTitle
    jsr Func_PlaySfxMenuMove
    @noDown:
    ;; Check START button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq _GameLoop
_HandleMenuItem:
    ldy Zp_Current_eTitle
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eTitle
    d_entry table, TopContinue, _MenuItemContinue
    d_entry table, TopNewGame,  _MenuItemNewGame
    d_entry table, TopCredits,  _GameLoop  ; TODO
    d_entry table, NewCancel,   _MenuItemCancel
    d_entry table, NewDelete,   _MenuItemDelete
    D_END
.ENDREPEAT
_MenuItemContinue:
    jsr Func_PlaySfxMenuConfirm
    jmp MainC_Title_BeginGame
_MenuItemNewGame:
    jsr Func_PlaySfxMenuConfirm
    ;; If no save file exists, go ahead and start a new game.
    lda Sram_MagicNumber_u8
    cmp #kSaveMagicNumber
    bne _BeginNewGame
    ;; Otherwise, ask for confirmation before erasing the saved game.
    ldax #DataC_Title_AreYouSureTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataC_Title_AreYouSureTransfer_arr)  ; param: data length
    jsr Func_BufferPpuTransfer
    lda #eTitle::NewCancel
    sta Zp_Current_eTitle
    sta Zp_First_eTitle
    lda #eTitle::NewDelete
    sta Zp_Last_eTitle
    jmp _GameLoop
_BeginNewGame:
    jsr Func_FadeOutToBlack
    jmp MainC_Title_Prologue
_MenuItemDelete:
    jsr Func_PlaySfxExplodeFracture
    jsr Func_PlaySfxMenuConfirm
    lda #<~kSaveMagicNumber
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Erase the saved game.
    sta Sram_MagicNumber_u8
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    bne _ExitEraseMenu  ; unconditional
_MenuItemCancel:
    jsr Func_PlaySfxMenuCancel
_ExitEraseMenu:
    ldax #DataC_Title_DoneConfirmTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataC_Title_DoneConfirmTransfer_arr)  ; param: data length
    jsr Func_BufferPpuTransfer
    ldx #eTitle::TopCredits
    stx Zp_Last_eTitle
    .assert eTitle::TopNewGame = eTitle::TopCredits - 1, error
    dex  ; now X is eTitle::TopNewGame
    stx Zp_Current_eTitle
    lda Sram_MagicNumber_u8
    cmp #kSaveMagicNumber
    bne @setFirstItem  ; no save file exists
    .assert eTitle::TopContinue = eTitle::TopNewGame - 1, error
    dex  ; now X is eTitle::TopContinue
    @setFirstItem:
    stx Zp_First_eTitle
    .assert eTitle::NUM_VALUES <= $80, error
    jmp _GameLoop
.ENDPROC

;;; Mode for using the New Game cheat code menu.
;;; @prereq Rendering is enabled.
.PROC MainC_Title_CheatMenu
    jsr Func_PlaySfxSecretUnlocked
    jsr Func_Window_Disable
    lda #eNewGame::Town
    sta Zp_Cheat_eNewGame
_GameLoop:
    jsr FuncC_Title_DrawCheatMenu
    jsr Func_ClearRestOfOamAndProcessFrame
_CheckForMenuInput:
    ;; Check Up button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Up
    beq @noUp
    lda Zp_Cheat_eNewGame
    beq @noUp
    dec Zp_Cheat_eNewGame
    jsr Func_PlaySfxMenuMove
    @noUp:
    ;; Check Down button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Down
    beq @noDown
    lda Zp_Cheat_eNewGame
    cmp #eNewGame::NUM_VALUES - 1
    bge @noDown
    inc Zp_Cheat_eNewGame
    jsr Func_PlaySfxMenuMove
    @noDown:
    ;; Check START button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    beq _GameLoop
_BeginNewGame:
    lda Zp_Cheat_eNewGame  ; param: eNewGame value
    fall MainC_Title_BeginGame
.ENDPROC

;;; Mode for starting the game, either continuing from existing save data (if
;;; any), or for a new game.
;;; @prereq Rendering is enabled.
;;; @param A The eNewGame value (ignored if save data exists).
.EXPORT MainC_Title_BeginGame
.PROC MainC_Title_BeginGame
    pha  ; eNewGame value
    jsr Func_FadeOutToBlack
    pla  ; eNewGame value
    ldx Sram_MagicNumber_u8
    cpx #kSaveMagicNumber
    beq @spawn
    tay  ; param: eNewGame value
    jsr FuncC_Title_ResetSramForNewGame
    @spawn:
    jmp Main_Explore_SpawnInLastSafeRoom
.ENDPROC

;;; Initializes title mode, then fades in the screen.
;;; @prereq PRGC_Title is loaded.
;;; @prereq Rendering is disabled.
.PROC FuncC_Title_InitAndFadeIn
    jsr Func_Window_Disable
    main_chr08_bank Ppu_ChrBgTitle
    main_chr10_bank Ppu_ChrObjPause
    lda #<.bank(Ppu_ChrBgFontUpper)
    sta Zp_Chr04Bank_u8
_StartMusic:
    lda #bAudio::Enable
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
    lda #eMusic::Title
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
_ClearNametables:
    ldxy #Ppu_Nametable0_sName  ; param: nametable addr
    jsr FuncC_Title_ClearNametableTiles
    ldxy #Ppu_Nametable3_sName  ; param: nametable addr
    jsr FuncC_Title_ClearNametableTiles
_DrawTitleLogoBgTiles:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_TitleTopLeft
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    ldy #.sizeof(DataC_Title_Map_u8_arr)
    ldx #0
    @loop:
    lda DataC_Title_Map_u8_arr, x
    sta Hw_PpuData_rw
    inx
    dey
    bne @loop
_DrawMenuLineBgTiles:
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable3_sName + sName::Tiles_u8_arr
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #kTileIdBgTitleMenuLine
    .assert kTitleMenuLineGapTiles .mod 2 = 0, error
    ldx #(kScreenWidthTiles - kTitleMenuLineGapTiles) / 2
    @loop1:
    sta Hw_PpuData_rw
    dex
    bne @loop1
    lda #' '
    ldx #kTitleMenuLineGapTiles
    @loop2:
    sta Hw_PpuData_rw
    dex
    bne @loop2
    lda #kTileIdBgTitleMenuLine
    ldx #(kScreenWidthTiles - kTitleMenuLineGapTiles) / 2
    @loop3:
    sta Hw_PpuData_rw
    dex
    bne @loop3
_InitAttributeTables:
    ldy #$55  ; param: attribute byte
    jsr Func_FillUpperAttributeTable  ; preserves Y
    jsr Func_FillLowerAttributeTable
_InitMenu:
    ldx #eTitle::TopCredits
    stx Zp_Last_eTitle
    .assert eTitle::TopNewGame = eTitle::TopCredits - 1, error
    dex  ; now X is eTitle::TopNewGame
    lda Sram_MagicNumber_u8
    cmp #kSaveMagicNumber
    bne @setFirstItem  ; no save file exists
    .assert eTitle::TopContinue = eTitle::TopNewGame - 1, error
    dex  ; now X is eTitle::TopContinue
    @setFirstItem:
    stx Zp_First_eTitle
    stx Zp_Current_eTitle
    lda DataC_Title_MenuItemPosY_u8_arr, x
    sta Zp_TitleMenuLinePosY_u8
    lda #0
    sta Zp_CheatSequenceIndex_u8
_FadeIn:
    jsr FuncC_Title_DrawMenu
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jmp Func_FadeInFromBlackToNormal
.ENDPROC

;;; Fills the specified nametable with blank BG tiles.
;;; @prereq Rendering is disabled.
;;; @param XY The PPU address for the nametable to clear.
.EXPORT FuncC_Title_ClearNametableTiles
.PROC FuncC_Title_ClearNametableTiles
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    .assert sName::Tiles_u8_arr = 0, error
    stx Hw_PpuAddr_w2
    sty Hw_PpuAddr_w2
    lda #' '
    ldxy #kScreenWidthTiles * kScreenHeightTiles
    @loop:
    sta Hw_PpuData_rw
    dey
    bne @loop
    dex
    bpl @loop
    rts
.ENDPROC

;;; Performs per-frame updates for the title screen menu.
.PROC FuncC_Title_TickMenu
_TickMenuLine:
    ;; Get the goal Y-position for the menu line.
    ldx Zp_Current_eTitle
    lda DataC_Title_MenuItemPosY_u8_arr, x
    ;; Compute the delta from the current menu line Y-position to the goal
    ;; position, storing it in A.  If the delta is zero, we're done.
    sub Zp_TitleMenuLinePosY_u8
    beq @done
    blt @goalLessThanCurr
    ;; If the delta is positive, then we need to move down.  Divide the delta
    ;; by (1 << kMenuLineYSlowdown) to get the amount we'll move by this frame,
    ;; but always move by at least one pixel.
    @goalMoreThanCurr:
    .repeat kMenuLineYSlowdown
    lsr a
    .endrepeat
    bne @moveByA
    lda #1
    bne @moveByA  ; unconditional
    ;; If the delta is negative, then we need to move up.  Divide the
    ;; (negative) delta by (1 << kMenuLineYSlowdown), roughly, to get the
    ;; amount we'll move by this frame.
    @goalLessThanCurr:
    .repeat kMenuLineYSlowdown
    sec
    ror a
    .endrepeat
    ;; Add A to the current scroll-Y position.
    @moveByA:
    add Zp_TitleMenuLinePosY_u8
    sta Zp_TitleMenuLinePosY_u8
    @done:
_TickMenuItems:
    ;; To slow things down, only move menu item letters once every four frames.
    lda Zp_FrameCounter_u8
    and #$03
    bne @done
    ;; Loop over all menu items.
    ldy #eTitle::NUM_VALUES - 1
    @loop:
    jsr FuncC_Title_TickMenuItem  ; preserves Y
    dey
    .assert eTitle::NUM_VALUES <= $80, error
    bpl @loop
    @done:
    rts
.ENDPROC

;;; Performs per-frame updates for the specified title screen menu item.
;;; @param Y The eTitle value for the menu item to tick.
;;; @preserve Y
.PROC FuncC_Title_TickMenuItem
    lda DataC_Title_MenuItemLength_u8_arr, y
    sta T5  ; num letters remaining
    ldx DataC_Title_MenuItemOffset_u8_arr, y
_Loop:
    cpy Zp_Current_eTitle
    beq @active
    @inactive:
    lda #0  ; goal offset (signed)
    beq @moveTowardsA  ; unconditional
    @active:
    sty T4  ; eTitle value
    txa
    mul #4
    add Zp_FrameCounter_u8
    mul #8  ; param: angle
    jsr Func_Sine  ; preserves X and T0+, returns A (param: signed dividend)
    ldy #60  ; param: unsigned divisor
    jsr Func_SignedDivFrac  ; preserves X and T4+, returns Y
    tya  ; goal offset (signed)
    ldy T4  ; eTitle value
    @moveTowardsA:
    cmp Ram_TitleLetterOffset_i8_arr, x
    beq @continue
    bpl @increase
    @decrease:
    dec Ram_TitleLetterOffset_i8_arr, x
    jmp @continue
    @increase:
    inc Ram_TitleLetterOffset_i8_arr, x
    @continue:
    inx
    dec T5  ; num letters remaining
    bne _Loop
    rts
.ENDPROC

;;; Draws objects and sets up IRQ for the title screen menu.
.PROC FuncC_Title_DrawMenu
_SetUpIrq:
    lda Zp_TitleMenuLinePosY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    ldax #Int_TitleMenuIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
_DrawMenuWords:
    ldx Zp_First_eTitle
    @loop:
    jsr FuncC_Title_DrawMenuItem  ; preserves X
    inx
    cpx Zp_Last_eTitle
    blt @loop
    beq @loop
    rts
.ENDPROC

;;; Draws objects for the specified title screen menu item.
;;; @param X The eTitle value for the menu item to draw.
;;; @preserve X
.PROC FuncC_Title_DrawMenuItem
    stx T3  ; eTitle value
    lda DataC_Title_MenuItemLength_u8_arr, x
    sta T2  ; num letters remaining
    mul #kTileWidthPx / 2
    rsub #kScreenWidthPx / 2
    sta T1  ; current X pos
    lda DataC_Title_MenuItemPosY_u8_arr, x
    sta T0  ; base Y pos
    lda DataC_Title_MenuItemOffset_u8_arr, x
    tax
_Loop:
    jsr Func_AllocOneObject  ; preserves X and T0+, returns Y
    lda T0  ; base Y pos
    add Ram_TitleLetterOffset_i8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda T1  ; current X pos
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta T1  ; current X pos
    lda DataC_Title_Letters_u8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjTitleMenuItem
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    inx
    dec T2  ; num letters remaining
    bne _Loop
    ldx T3  ; eTitle value
    rts
.ENDPROC

;;; Draws objects for the New Game cheat code menu.
.PROC FuncC_Title_DrawCheatMenu
_DrawArrows:
    lda #4  ; param: num objects
    jsr Func_AllocObjects  ; returns Y
    ;; Set Y-positions.
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    cmp #$03
    bne @noZigZag
    lda #$01
    @noZigZag:
    sta T0  ; zig-zag offset
    ldx Zp_Cheat_eNewGame
    bne @drawTopArrow
    @noTopArrow:
    lda #$ff
    bne @setTopArrowY  ; unconditional
    @drawTopArrow:
    add #kCheatMenuYPos - kCheatMenuArrowOffsetPx
    @setTopArrowY:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    cpx #eNewGame::NUM_VALUES - 1
    blt @drawBottomArrow
    @noBottomArrow:
    lda #$ff
    bne @setBottomArrowY
    @drawBottomArrow:
    lda #kCheatMenuYPos + kCheatMenuArrowOffsetPx
    sub T0  ; zig-zag offset
    @setBottomArrowY:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    ;; Set X-positions.
    lda #kScreenWidthPx / 2 - kTileWidthPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::XPos_u8, y
    lda #kScreenWidthPx / 2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::XPos_u8, y
    ;; Set tile IDs.
    lda #kTileIdObjCheatMenuArrows
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    ;; Set flags.
    lda #kPaletteObjCheatMenuArrows
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    eor #bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
_DrawMenuItem:
    lda Zp_Cheat_eNewGame
    .assert eNewGame::NUM_VALUES * 8 < $100, error
    mul #8
    tax  ; index into DataC_Title_NewGameName_u8_arr8_arr
    ;; Count how many characters to draw:
    tay  ; start index
    adc #8  ; carry is clear from MUL above
    sta T1  ; index limit
    @limitLoop:
    lda DataC_Title_NewGameName_u8_arr8_arr, y
    beq @limitBreak
    iny
    cpy T1  ; index limit
    blt @limitLoop
    @limitBreak:
    sty T1  ; index limit
    txa  ; start index
    rsub T1
    ;; Calculate start position:
    mul #kTileWidthPx / 2
    rsub #kScreenWidthPx / 2
    sta T0  ; current X pos
    @objLoop:
    jsr Func_AllocOneObject  ; preserves X and T0+, returns Y
    lda #kCheatMenuYPos
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda T0  ; current X pos
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta T0  ; current X pos
    lda DataC_Title_NewGameName_u8_arr8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjTitleMenuItem
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    inx
    cpx T1  ; index limit
    blt @objLoop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the title screen menu.  Sets the vertical
;;; scroll so as to make the menu selection line appear to move.
.PROC Int_TitleMenuIrq
    ;; Save the A register (we won't be using X or Y).
    pha
    ;; No more IRQs for the rest of this frame.
    lda #$ff  ; param: latch value
    jsr Func_AckIrqAndSetLatch
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    lda #7  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    sub #1
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the lower
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #3 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda #0
    sta Hw_PpuScroll_w2  ; new scroll-Y value (zero)
    ;; We should now be in the second HBlank.
    sta Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2    ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore the A register and return.
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
