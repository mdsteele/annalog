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
.INCLUDE "cpu.inc"
.INCLUDE "cursor.inc"
.INCLUDE "device.inc"
.INCLUDE "dialog.inc"
.INCLUDE "hud.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "window.inc"

.IMPORT DataA_Dialog_CoreSouthCorra_sDialog
.IMPORT DataA_Dialog_CryptTombPlaque_sDialog
.IMPORT DataA_Dialog_GardenEastCorra_sDialog
.IMPORT DataA_Dialog_GardenLandingPaper_sDialog
.IMPORT DataA_Dialog_GardenShaftPaper_sDialog
.IMPORT DataA_Dialog_LavaStationPaper_sDialog
.IMPORT DataA_Dialog_MermaidDrainSign_sDialog
.IMPORT DataA_Dialog_MermaidEntrySign_sDialog
.IMPORT DataA_Dialog_MermaidHut1BreakerGarden_sDialog
.IMPORT DataA_Dialog_MermaidHut1Guard_sDialog
.IMPORT DataA_Dialog_MermaidHut1Queen_sDialog
.IMPORT DataA_Dialog_MermaidHut2Guard_sDialog
.IMPORT DataA_Dialog_MermaidHut3MermaidAdult_sDialog
.IMPORT DataA_Dialog_MermaidHut3MermaidPhoebe_sDialog
.IMPORT DataA_Dialog_MermaidHut4Florist_sDialog
.IMPORT DataA_Dialog_MermaidHut5Nora_sDialog
.IMPORT DataA_Dialog_MermaidVillageCorra_sDialog
.IMPORT DataA_Dialog_MermaidVillageFarmer_sDialog
.IMPORT DataA_Dialog_MermaidVillageGuard_sDialog
.IMPORT DataA_Dialog_PrisonEscapePaper_sDialog
.IMPORT DataA_Dialog_PrisonFlowerSign_sDialog
.IMPORT DataA_Dialog_PrisonUpperAlexCell_sDialog
.IMPORT DataA_Dialog_PrisonUpperAlexFree_sDialog
.IMPORT DataA_Dialog_PrisonUpperBreakerTemple_sDialog
.IMPORT DataA_Dialog_PrisonUpperBruno_sDialog
.IMPORT DataA_Dialog_PrisonUpperMarie_sDialog
.IMPORT DataA_Dialog_PrisonUpperNora_sDialog
.IMPORT DataA_Dialog_TempleAltarPlaque_sDialog
.IMPORT DataA_Dialog_TempleEntryMermaid_sDialog
.IMPORT DataA_Dialog_TempleFoyerPaper_sDialog
.IMPORT DataA_Dialog_TempleNaveAlexBoosting_sDialog
.IMPORT DataA_Dialog_TempleNaveAlexStanding_sDialog
.IMPORT DataA_Dialog_TemplePitPaper_sDialog
.IMPORT DataA_Dialog_TownHouse1Nora_sDialog
.IMPORT DataA_Dialog_TownHouse3Smith_sDialog
.IMPORT DataA_Dialog_TownHouse4Laura_sDialog
.IMPORT DataA_Dialog_TownHouse4Martin_sDialog
.IMPORT DataA_Dialog_TownHouse5Bruno_sDialog
.IMPORT DataA_Dialog_TownHouse5Marie_sDialog
.IMPORT DataA_Dialog_TownHouse6Elder_sDialog
.IMPORT DataC_Prison_PrisonCellPaper_sDialog
.IMPORT DataC_Town_TownHouse2Stela_sDialog
.IMPORT DataC_Town_TownOutdoorsAlex1_sDialog
.IMPORT DataC_Town_TownOutdoorsAlex2_sDialog
.IMPORT DataC_Town_TownOutdoorsAlex3_sDialog
.IMPORT DataC_Town_TownOutdoorsGronta_sDialog
.IMPORT DataC_Town_TownOutdoorsIvan_sDialog
.IMPORT DataC_Town_TownOutdoorsSandra_sDialog
.IMPORT DataC_Town_TownOutdoorsSign_sDialog
.IMPORT FuncA_Dialog_PlaySfxQuestMarker
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Terrain_ScrollTowardsAvatar
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_AllocOneObject
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_SetFlag
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Cutscene_Continue
.IMPORT Main_Explore_Continue
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_AvatarWaterDepth_u8
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Nearby_bDevice
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_ScrollGoalY_u8
.IMPORTZP Zp_WindowNextRowToTransfer_u8
.IMPORTZP Zp_WindowTopGoal_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The number of text rows in the dialog window (i.e. not including the
;;; borders or the bottom margin).
kDialogNumTextRows = 4

;;; The window tile row/col to start drawing dialog text.
kDialogTextStartRow = 1
kDialogTextStartCol = 7

;;; How many columns wide a line of dialog text is allowed to be at most.
kDialogTextMaxCols = 22

;;; The goal value for Zp_WindowTop_u8 while scrolling in the dialog window.
.LINECONT +
kDialogWindowTopGoal = kScreenHeightPx - \
    ((kDialogNumTextRows + 2) * kTileHeightPx + kWindowMarginBottomPx)
.LINECONT -

;;; How fast the dialog window scrolls up/down, in pixels per frame.
kDialogWindowScrollSpeed = 4

;;; The OBJ palette number and tile ID used for the visual prompt that appears
;;; when dialog is paused.
kPaletteObjDialogPrompt = 1
kTileIdObjDialogPrompt = $08

;;; The tile row/col within the window where the "yes"/"no" options start.
kDialogYesNoWindowRow = 4
kDialogYesWindowCol = 13
kDialogNoWindowCol = 19

;;; The object X/Y positions for the start of the "yes"/"no" options.
.LINECONT +
kDialogYesNoObjY = kDialogWindowTopGoal + \
    kDialogYesNoWindowRow * kTileHeightPx - 1
kDialogYesObjX = kDialogYesWindowCol * kTileWidthPx
kDialogNoObjX = kDialogNoWindowCol * kTileWidthPx
.LINECONT -

;;; The PPU address (within the lower nametable) for the start of the
;;; "yes"/"no" options' background tiles in the dialog window.
.LINECONT +
Ppu_DialogYesNoStart = Ppu_Nametable3_sName + sName::Tiles_u8_arr + \
    kScreenWidthTiles * (kWindowStartRow + kDialogYesNoWindowRow) + \
    kDialogYesWindowCol
.LINECONT -

;;; The PPU address (within the lower nametable) for the start of the attribute
;;; bytes that cover the dialog portrait.
.LINECONT +
.ASSERT (kWindowStartRow + 1) .mod 4 = 0, error
Ppu_PortraitAttrStart = Ppu_Nametable3_sName + sName::Attrs_u8_arr64 + \
    ((kWindowStartRow + 1) / 4) * 8
.LINECONT -

;;;=========================================================================;;;

;;; Status bits for dialog mode.
.SCOPE bDialog
    Paused   = %10000000  ; if set, the current pane of text is complete
    YesNo    = %01000000  ; if set, we're in a yes-or-no question
    Cutscene = %00000001  ; if set, dialog was started from within a cutscene
.ENDSCOPE

;;;=========================================================================;;;

.ZEROPAGE

;;; Status bits for the current dialog.
Zp_DialogStatus_bDialog: .res 1

;;; The CHR04 bank to set when the dialog portrait is at rest.
Zp_PortraitRestBank_u8: .res 1

;;; The CHR04 bank to alternate with Zp_PortraitRestBank_u8 when animating the
;;; dialog portrait.
Zp_PortraitAnimBank_u8: .res 1

;;; The window tile row/col where the next character of dialog text will be
;;; drawn.
Zp_DialogTextRow_u8: .res 1
Zp_DialogTextCol_u8: .res 1

;;; This is set to true ($ff) whenever the player chooses "yes" for a yes-or-no
;;; dialog question, and is set to false ($00) whenever the player chooses
;;; "no".  Dynamic dialog functions can read this variable to react to the
;;; player's choice.
.EXPORTZP Zp_DialogAnsweredYes_bool
Zp_DialogAnsweredYes_bool: .res 1

;;; A pointer into the current dialog data.  If bDialog::Paused is set, this
;;; points to the 2-byte ePortrait value for the next block of text; otherwise,
;;; this points to the next character of text to draw.
Zp_DialogText_ptr: .res 2

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for beginning dialog by using a dialog device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active dialog device.
;;; @param X The dialog device index.
.EXPORT Main_Dialog_UseDevice
.PROC Main_Dialog_UseDevice
    ldy Ram_DeviceTarget_u8_arr, x  ; param: eDialog value
    lda #0
    sta Zp_DialogStatus_bDialog
    beq Main_Dialog_OpenWindow  ; unconditional
.ENDPROC

;;; Mode for beginning dialog within a cutscene.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param Y The eDialog value for the dialog.
.EXPORT Main_Dialog_WithinCutscene
.PROC Main_Dialog_WithinCutscene
    lda #bDialog::Cutscene
    sta Zp_DialogStatus_bDialog
    .assert * = Main_Dialog_OpenWindow, error, "fallthrough"
.ENDPROC

;;; Mode for scrolling in the dialog window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param Y The eDialog value for the dialog.
.PROC Main_Dialog_OpenWindow
    jsr_prga FuncA_Dialog_Init  ; sets C if dialog is empty
    bcs Main_Dialog_Finish
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Dialog_ScrollWindowUp  ; sets C if window is now fully open
    bcs Main_Dialog_Run
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for ending dialog an
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq The dialog window is fully scrolled out.
.PROC Main_Dialog_Finish
    lda Zp_DialogStatus_bDialog
    .assert bDialog::Cutscene = $01, error
    lsr a
    jcs Main_Cutscene_Continue
    jmp Main_Explore_Continue
.ENDPROC

;;; Mode for scrolling out the dialog window.  Switches to explore mode once
;;; the window is fully hidden.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Dialog_CloseWindow
_GameLoop:
    jsr_prga FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Dialog_ScrollWindowDown  ; sets C if window is now closed
    bcs Main_Dialog_Finish
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsAvatar
    jmp _GameLoop
.ENDPROC

;;; Mode for running the dialog window.
;;; @prereq Rendering is enabled.
;;; @prereq The dialog window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Dialog_Run
_GameLoop:
    jsr_prga FuncA_Objects_DrawDialogCursorAndObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
_Tick:
    jsr_prga FuncA_Dialog_Tick  ; sets C if window should be closed; returns X
    chr04_bank x
    jcs Main_Dialog_CloseWindow
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.LINECONT +
.REPEAT 2, table
    D_TABLE_LO table, DataA_Dialog_Table_sDialog_ptr_0_arr
    D_TABLE_HI table, DataA_Dialog_Table_sDialog_ptr_1_arr
    D_TABLE eDialog
    d_entry table, CoreSouthCorra,     DataA_Dialog_CoreSouthCorra_sDialog
    d_entry table, CryptTombPlaque,    DataA_Dialog_CryptTombPlaque_sDialog
    d_entry table, GardenEastCorra,    DataA_Dialog_GardenEastCorra_sDialog
    d_entry table, GardenLandingPaper, DataA_Dialog_GardenLandingPaper_sDialog
    d_entry table, GardenShaftPaper,   DataA_Dialog_GardenShaftPaper_sDialog
    d_entry table, LavaStationPaper,   DataA_Dialog_LavaStationPaper_sDialog
    d_entry table, MermaidDrainSign,   DataA_Dialog_MermaidDrainSign_sDialog
    d_entry table, MermaidEntrySign,   DataA_Dialog_MermaidEntrySign_sDialog
    d_entry table, MermaidHut1BreakerGarden, \
            DataA_Dialog_MermaidHut1BreakerGarden_sDialog
    d_entry table, MermaidHut1Guard,   DataA_Dialog_MermaidHut1Guard_sDialog
    d_entry table, MermaidHut1Queen,   DataA_Dialog_MermaidHut1Queen_sDialog
    d_entry table, MermaidHut2Guard,   DataA_Dialog_MermaidHut2Guard_sDialog
    d_entry table, MermaidHut3MermaidAdult, \
            DataA_Dialog_MermaidHut3MermaidAdult_sDialog
    d_entry table, MermaidHut3MermaidPhoebe, \
            DataA_Dialog_MermaidHut3MermaidPhoebe_sDialog
    d_entry table, MermaidHut4Florist, DataA_Dialog_MermaidHut4Florist_sDialog
    d_entry table, MermaidHut5Nora,    DataA_Dialog_MermaidHut5Nora_sDialog
    d_entry table, MermaidVillageCorra, \
            DataA_Dialog_MermaidVillageCorra_sDialog
    d_entry table, MermaidVillageFarmer, \
            DataA_Dialog_MermaidVillageFarmer_sDialog
    d_entry table, MermaidVillageGuard, \
            DataA_Dialog_MermaidVillageGuard_sDialog
    d_entry table, PrisonCellPaper,    DataC_Prison_PrisonCellPaper_sDialog
    d_entry table, PrisonEscapePaper,  DataA_Dialog_PrisonEscapePaper_sDialog
    d_entry table, PrisonFlowerSign,   DataA_Dialog_PrisonFlowerSign_sDialog
    d_entry table, PrisonUpperAlexCell, \
            DataA_Dialog_PrisonUpperAlexCell_sDialog
    d_entry table, PrisonUpperAlexFree, \
            DataA_Dialog_PrisonUpperAlexFree_sDialog
    d_entry table, PrisonUpperBreakerTemple, \
            DataA_Dialog_PrisonUpperBreakerTemple_sDialog
    d_entry table, PrisonUpperBruno,   DataA_Dialog_PrisonUpperBruno_sDialog
    d_entry table, PrisonUpperMarie,   DataA_Dialog_PrisonUpperMarie_sDialog
    d_entry table, PrisonUpperNora,    DataA_Dialog_PrisonUpperNora_sDialog
    d_entry table, TempleAltarPlaque,  DataA_Dialog_TempleAltarPlaque_sDialog
    d_entry table, TempleEntryMermaid, DataA_Dialog_TempleEntryMermaid_sDialog
    d_entry table, TempleFoyerPaper,   DataA_Dialog_TempleFoyerPaper_sDialog
    d_entry table, TempleNaveAlexBoosting, \
            DataA_Dialog_TempleNaveAlexBoosting_sDialog
    d_entry table, TempleNaveAlexStanding, \
            DataA_Dialog_TempleNaveAlexStanding_sDialog
    d_entry table, TemplePitPaper,     DataA_Dialog_TemplePitPaper_sDialog
    d_entry table, TownHouse1Nora,     DataA_Dialog_TownHouse1Nora_sDialog
    d_entry table, TownHouse2Stela,    DataC_Town_TownHouse2Stela_sDialog
    d_entry table, TownHouse3Smith,    DataA_Dialog_TownHouse3Smith_sDialog
    d_entry table, TownHouse4Laura,    DataA_Dialog_TownHouse4Laura_sDialog
    d_entry table, TownHouse4Martin,   DataA_Dialog_TownHouse4Martin_sDialog
    d_entry table, TownHouse5Bruno,    DataA_Dialog_TownHouse5Bruno_sDialog
    d_entry table, TownHouse5Marie,    DataA_Dialog_TownHouse5Marie_sDialog
    d_entry table, TownHouse6Elder,    DataA_Dialog_TownHouse6Elder_sDialog
    d_entry table, TownOutdoorsAlex1,  DataC_Town_TownOutdoorsAlex1_sDialog
    d_entry table, TownOutdoorsAlex2,  DataC_Town_TownOutdoorsAlex2_sDialog
    d_entry table, TownOutdoorsAlex3,  DataC_Town_TownOutdoorsAlex3_sDialog
    d_entry table, TownOutdoorsGronta, DataC_Town_TownOutdoorsGronta_sDialog
    d_entry table, TownOutdoorsIvan,   DataC_Town_TownOutdoorsIvan_sDialog
    d_entry table, TownOutdoorsSandra, DataC_Town_TownOutdoorsSandra_sDialog
    d_entry table, TownOutdoorsSign,   DataC_Town_TownOutdoorsSign_sDialog
    D_END
.ENDREPEAT
.LINECONT -

;;; If the specified flag isn't already set to true, then sets it and plays the
;;; sound effect for a newly-added quest marker.
;;; @param X The eFlag value to set.
.EXPORT FuncA_Dialog_AddQuestMarker
.PROC FuncA_Dialog_AddQuestMarker
    jsr Func_SetFlag  ; sets C if flag was already set
    jcc FuncA_Dialog_PlaySfxQuestMarker
    rts
.ENDPROC

;;; The PPU transfer entry for setting nametable attributes for the dialog
;;; portrait.
.PROC DataA_Dialog_PortraitAttrTransfer_arr
    .byte kPpuCtrlFlagsHorz       ; control flags
    .dbyt Ppu_PortraitAttrStart   ; destination address
    .byte @dataEnd - @dataStart   ; transfer length
    @dataStart:
    .byte $44, $11
    @dataEnd:
.ENDPROC

;;; The PPU transfer entry for undoing the nametable attributes changes made by
;;; DataA_Dialog_PortraitAttrTransfer_arr above.
.PROC DataA_Dialog_UndoPortraitAttrTransfer_arr
    .byte kPpuCtrlFlagsHorz       ; control flags
    .dbyt Ppu_PortraitAttrStart   ; destination address
    .byte @dataEnd - @dataStart   ; transfer length
    @dataStart:
    .byte $00, $00
    @dataEnd:
.ENDPROC

;;; The PPU transfer entry for drawing the "yes"/"no" options for a yes-or-no
;;; dialog question.
.PROC DataA_Dialog_YesNoTransfer_arr
    .byte kPpuCtrlFlagsHorz      ; control flags
    .dbyt Ppu_DialogYesNoStart   ; destination address
    .byte @dataEnd - @dataStart  ; transfer length
    @dataStart:
    .byte "YES   NO"
    @dataEnd:
.ENDPROC

;;; Initializes dialog mode.
;;; @param Y The eDialog value for the dialog.
;;; @return C Set if the dialog is empty, cleared otherwise.
.PROC FuncA_Dialog_Init
    lda DataA_Dialog_Table_sDialog_ptr_0_arr, y
    sta Zp_DialogText_ptr + 0
    lda DataA_Dialog_Table_sDialog_ptr_1_arr, y
    sta Zp_DialogText_ptr + 1
    ;; Load the first portrait of the dialog.
    jsr FuncA_Dialog_LoadNextPortrait  ; sets C if dialog is already done
    bcs _Done
_HideHud:
    lda Zp_FloatingHud_bHud
    ora #bHud::Hidden
    sta Zp_FloatingHud_bHud
_AdjustScrollGoal:
    lda Zp_ScrollGoalY_u8
    add #(kScreenHeightPx - kDialogWindowTopGoal) / 2
    sta Zp_ScrollGoalY_u8
_InitAvatar:
    ;; If the player is activating a dialog device, we need to set up the
    ;; avatar.  Otherwise, this is cutscene dialog, so don't change the avatar.
    bit Zp_Nearby_bDevice
    .assert bDevice::NoneNearby = bProc::Negative, error
    bmi @done
    .assert bDevice::Active = bProc::Overflow, error
    bvc @done
    ;; Make the player avatar stand still.
    lda #0
    sta Zp_AvatarVelX_i16 + 0
    sta Zp_AvatarVelX_i16 + 1
    ;; Set the player avatar's appearance and facing direction based on the
    ;; device type.
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tax  ; device index
    lda Ram_DeviceType_eDevice_arr, x
    cmp #eDevice::TalkLeft
    beq @faceLeft
    cmp #eDevice::TalkRight
    beq @faceRight
    @faceWall:
    lda #eAvatar::Reading
    bne @setPose  ; unconditional
    @faceLeft:
    lda Zp_AvatarFlags_bObj
    ora #bObj::FlipH
    bne @setFlags  ; unconditional
    @faceRight:
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
    @setFlags:
    sta Zp_AvatarFlags_bObj
    lda Zp_AvatarWaterDepth_u8
    bne @done
    lda #eAvatar::Standing
    @setPose:
    sta Zp_AvatarPose_eAvatar
    @done:
_DeactivateDevice:
    ;; Now that the player avatar is set up, clear Zp_Nearby_bDevice so that
    ;; the active dialog device type won't interfere with any futher cutscene
    ;; dialog that may be triggered by this device's dialog.
    lda #bDevice::NoneNearby
    sta Zp_Nearby_bDevice
_InitWindow:
    lda #kScreenHeightPx - kDialogWindowScrollSpeed
    sta Zp_WindowTop_u8
    lda #0
    sta Zp_WindowNextRowToTransfer_u8
    lda #kDialogWindowTopGoal
    sta Zp_WindowTopGoal_u8
    clc  ; nonempty dialog
_Done:
    rts
.ENDPROC

;;; Updates the dialog text based on joypad input.
;;; @return X The CHR04 bank number that should be set.
;;; @return C Set if dialog is finished and the window should be closed.
.PROC FuncA_Dialog_Tick
_CheckDPad:
    ;; Ignore the D-pad if yes-or-no question mode isn't currently active.
    bit Zp_DialogStatus_bDialog
    .assert bDialog::YesNo = bProc::Overflow, error
    bvc @done
    ;; If the player presses left, select "YES".
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Left
    beq @noLeft
    lda #$ff
    sta Zp_DialogAnsweredYes_bool
    bne @done  ; unconditional
    @noLeft:
    ;; If the player presses right, select "NO".
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Right
    beq @done
    lda #$00
    sta Zp_DialogAnsweredYes_bool
    @done:
_CheckAButton:
    ;; Check if the player pressed the A button.
    bit Zp_P1ButtonsPressed_bJoypad
    .assert bJoypad::AButton = bProc::Negative, error
    bpl @noAButton
    ;; If the player pressed the A button before we reached the end of the
    ;; current text, then skip to the end of the current text.
    bit Zp_DialogStatus_bDialog
    .assert bDialog::Paused = bProc::Negative, error
    bmi @atEndOfText
    jsr FuncA_Dialog_TransferRestOfText
    ldx Zp_PortraitRestBank_u8
    bne _ContinueDialog  ; unconditional
    @atEndOfText:
    ;; Otherwise, the player pressed the A button when we're already at
    ;; end-of-text, so begin the next page of text.
    jsr FuncA_Dialog_TransferClearText
    jsr FuncA_Dialog_LoadNextPortrait  ; sets C if dialog is now done
    bcs _CloseWindow
    bcc _AnimatePortrait  ; unconditional
    @noAButton:
_UpdateText:
    bit Zp_DialogStatus_bDialog
    .assert bDialog::Paused = bProc::Negative, error
    bpl @notPaused
    ldx Zp_PortraitRestBank_u8
    bne _ContinueDialog  ; unconditional
    @notPaused:
    jsr FuncA_Dialog_TransferNextCharacter
_AnimatePortrait:
    lda Zp_FrameCounter_u8
    and #$08
    beq @rest
    ldx Zp_PortraitAnimBank_u8
    bne @done  ; unconditional
    @rest:
    ldx Zp_PortraitRestBank_u8
    @done:
_ContinueDialog:
    clc  ; Clear C to indicate that dialog should continue.
    rts
_CloseWindow:
    ldx Zp_PortraitRestBank_u8
    sec  ; Set C to indicate that we should close the dialog window.
    rts
.ENDPROC

;;; Reads the first two bytes of the next sDialog entry that Zp_DialogText_ptr
;;; points to.
;;;   * If it is a portrait, initializes dialog variables appropriately, and
;;;     then advances Zp_DialogText_ptr to point to the start of the text.
;;;   * If it is a dynamic dialog function pointer, calls the function and then
;;;     tries again with the dialog entry returned by the function.
;;;   * If it is ePortrait::Done, sets the C flag and returns.
;;; @prereq Zp_DialogText_ptr is pointing to the next sDialog entry.
;;; @return C Set if the dialog is now done, cleared otherwise.
.PROC FuncA_Dialog_LoadNextPortrait
    lda #kDialogTextStartCol
    sta Zp_DialogTextCol_u8
    lda #kDialogTextStartRow
    sta Zp_DialogTextRow_u8
_ReadPortrait:
    lda Zp_DialogStatus_bDialog
    and #<~(bDialog::Paused | bDialog::YesNo)
    sta Zp_DialogStatus_bDialog
    ldy #0
    lda (Zp_DialogText_ptr), y
    tax
    iny
    lda (Zp_DialogText_ptr), y
    beq _DialogDone
    bpl _SetPortrait
_DynamicDialog:
    stax T1T0
    jsr _CallT1T0
    stya Zp_DialogText_ptr
    jmp _ReadPortrait
_CallT1T0:
    jmp (T1T0)
_DialogDone:
    sec  ; dialog done
    rts
_SetPortrait:
    iny
    sta Zp_PortraitAnimBank_u8
    stx Zp_PortraitRestBank_u8
    chr04_bank x
    .assert * = FuncA_Dialog_AdvanceTextPtr, error, "fallthrough"
.ENDPROC

;;; Adds Y to Zp_DialogText_ptr and stores the result in Zp_DialogText_ptr.
;;; @param Y The byte offset to add to Zp_DialogText_ptr.
;;; @return C Always cleared.
.PROC FuncA_Dialog_AdvanceTextPtr
    tya
    add Zp_DialogText_ptr + 0
    sta Zp_DialogText_ptr + 0
    lda Zp_DialogText_ptr + 1
    adc #0
    sta Zp_DialogText_ptr + 1
    rts
.ENDPROC

;;; Scrolls the dialog window down a bit; call this each frame when the window
;;; is closing.
;;; @return C Set if the window is now fully scrolled out.
.PROC FuncA_Dialog_ScrollWindowDown
    lda Zp_WindowTop_u8
    add #kDialogWindowScrollSpeed
    cmp #kScreenHeightPx
    bge _FullyClosed
    sta Zp_WindowTop_u8
    cmp #kScreenHeightPx - kDialogWindowScrollSpeed
    blt _StillClosing
_ResetBgAttributes:
    ;; Buffer PPU transfer to reset nametable attributes for the portrait.
    ldx Zp_PpuTransferLen_u8
    ldy #0
    @loop:
    lda DataA_Dialog_UndoPortraitAttrTransfer_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #.sizeof(DataA_Dialog_UndoPortraitAttrTransfer_arr)
    blt @loop
    stx Zp_PpuTransferLen_u8
_StillClosing:
    clc
    rts
_FullyClosed:
    lda #$ff
    sta Zp_WindowTop_u8
    sec
    rts
.ENDPROC

;;; Scrolls the dialog window in a bit, and transfers PPU data as needed; call
;;; this each frame when the window is opening.
;;; @return C Set if the window is now fully scrolled in.
.PROC FuncA_Dialog_ScrollWindowUp
    lda Zp_WindowTop_u8
    sub #kDialogWindowScrollSpeed
    cmp Zp_WindowTopGoal_u8
    bge @notDone
    lda Zp_WindowTopGoal_u8
    @notDone:
    sta Zp_WindowTop_u8
    jsr FuncA_Dialog_TransferNextWindowRow
    lda Zp_WindowTopGoal_u8
    cmp Zp_WindowTop_u8  ; clears C if Zp_WindowTopGoal_u8 < Zp_WindowTop_u8
    rts
.ENDPROC

;;; Transfers the next dialog window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC FuncA_Dialog_TransferNextWindowRow
    ldy Zp_WindowNextRowToTransfer_u8
    beq _BgAttributes
    dey
    cpy #kDialogNumTextRows
    blt _Interior
    beq _BottomBorder
    cpy #kWindowMaxNumRows - 1
    blt _BottomMargin
    rts
_BottomMargin:
    jmp Func_Window_TransferClearRow
_BottomBorder:
    jmp Func_Window_TransferBottomBorder
_Interior:
    jsr Func_Window_PrepareRowTransfer
    ;; Draw borders and margins:
    lda #' '
    sta Ram_PpuTransfer_arr, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 1, x
    lda #kTileIdBgWindowVert
    sta Ram_PpuTransfer_arr + 1, x
    sta Ram_PpuTransfer_arr + kScreenWidthTiles - 2, x
    inx
    inx
    ;; Draw portrait:
    lda Zp_WindowNextRowToTransfer_u8
    add #$6e
    ldy #4
    @portraitLoop:
    sta Ram_PpuTransfer_arr, x
    adc #4
    inx
    dey
    bne @portraitLoop
    ;; Clear interior:
    lda #' '
    ldy #kScreenWidthTiles - 8
    @clearLoop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @clearLoop
    rts
_BgAttributes:
    inc Zp_WindowNextRowToTransfer_u8
    ;; Buffer PPU transfer to set nametable attributes for the portrait.
    ldx Zp_PpuTransferLen_u8
    ldy #0
    @loop:
    lda DataA_Dialog_PortraitAttrTransfer_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #.sizeof(DataA_Dialog_PortraitAttrTransfer_arr)
    blt @loop
    stx Zp_PpuTransferLen_u8
    rts
.ENDPROC

;;; Transfers the next character of dialog text (if any) to the PPU.  If an
;;; end-of-line/text marker is reached, updates dialog variables accordingly.
;;; @prereq bDialog::Paused is cleared and Zp_DialogText_ptr points to text.
.PROC FuncA_Dialog_TransferNextCharacter
    ;; Read the next character, then advance past it.
    ldy #0
    lda (Zp_DialogText_ptr), y
    pha  ; next character
    iny
    jsr FuncA_Dialog_AdvanceTextPtr
    pla  ; next character
    ;; If the character is printable, then perform a PPU transfer to draw it to
    ;; the screen.
    bpl _TransferCharacter
    ;; Or, if the character is an end-of-line marker, then get ready for the
    ;; next line of text.
    cmp #kDialogTextNewline
    beq _Newline
    ;; Otherwise, the character is some kind of end-of-text marker.  If it's a
    ;; yes-or-no-question marker, then we need to set that up.
    cmp #kDialogTextYesNo
    beq _YesNoQuestion
    ;; Otherwise, this is a regular end-of-text marker, so mark the dialog as
    ;; paused.
    lda Zp_DialogStatus_bDialog
    ora #bDialog::Paused
    sta Zp_DialogStatus_bDialog
    rts
_TransferCharacter:
    pha  ; character to transfer
    lda Zp_DialogTextRow_u8  ; param: window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    stx T0  ; destination address (hi)
    ;; Update Zp_PpuTransferLen_u8.
    ldx Zp_PpuTransferLen_u8
    txa
    add #5
    sta Zp_PpuTransferLen_u8
    ;; Write the transfer entry.
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr + 0, x
    lda T0  ; destination address (hi)
    sta Ram_PpuTransfer_arr + 1, x
    tya     ; destination address (lo)
    ora Zp_DialogTextCol_u8
    sta Ram_PpuTransfer_arr + 2, x
    lda #1
    sta Ram_PpuTransfer_arr + 3, x
    pla  ; character to transfer
    sta Ram_PpuTransfer_arr + 4, x
    inc Zp_DialogTextCol_u8
    rts
_Newline:
    lda #kDialogTextStartCol
    sta Zp_DialogTextCol_u8
    inc Zp_DialogTextRow_u8
    rts
_YesNoQuestion:
    .assert * = FuncA_Dialog_BeginYesNoQuestion, error, "fallthrough"
.ENDPROC

;;; Gets dialog ready for a yes-or-no question.
;;; @prereq bDialog::Paused is set.
;;; @preserve T0+
.PROC FuncA_Dialog_BeginYesNoQuestion
    ;; Enable the yes-or-no cursor, putting it on "yes" by default.
    lda Zp_DialogStatus_bDialog
    ora #bDialog::Paused | bDialog::YesNo
    sta Zp_DialogStatus_bDialog
    lda #$ff
    sta Zp_DialogAnsweredYes_bool
    ;; Buffer a PPU transfer to draw the "yes"/"no" options.
    ldx Zp_PpuTransferLen_u8
    ldy #0
    @loop:
    lda DataA_Dialog_YesNoTransfer_arr, y
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    cpy #.sizeof(DataA_Dialog_YesNoTransfer_arr)
    blt @loop
    stx Zp_PpuTransferLen_u8
    rts
.ENDPROC

;;; Buffers a PPU transfer to draw all remaining dialog text (if any) until the
;;; next end-of-text, then updates dialog variables accordingly (in particular,
;;; bDialog::Paused will be set when this returns).
;;; @prereq bDialog::Paused is cleared and Zp_DialogText_ptr points to text.
.PROC FuncA_Dialog_TransferRestOfText
_TransferLine:
    ;; If the next character is already an end-of-line/text marker, don't
    ;; create a transfer entry for this line.
    ldy #0
    lda (Zp_DialogText_ptr), y
    bmi _EndOfLine
    ;; Write the transfer entry header (except for transfer len) for the rest
    ;; of the current line of text.
    lda Zp_DialogTextRow_u8  ; param: window row
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    stx T0  ; destination address (hi)
    ldx Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda T0  ; destination address (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    tya     ; destination address (lo)
    ora Zp_DialogTextCol_u8
    sta Ram_PpuTransfer_arr, x
    inx
    stx T0  ; byte offset for transfer data length
    inx
    ;; Write the transfer data for the rest of the current line of text.
    ldy #0
    @loop:
    lda (Zp_DialogText_ptr), y
    bmi @finish
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    bne @loop  ; unconditional
    ;; Finish the transfer.
    @finish:
    pha  ; end-of-line/text marker
    stx Zp_PpuTransferLen_u8
    ldx T0  ; byte offset for transfer data length
    tya     ; transfer data length
    sta Ram_PpuTransfer_arr, x
    pla  ; end-of-line/text marker
_EndOfLine:
    ;; Update the dialog text position.
    cmp #kDialogTextEnd
    beq @endOfText
    cmp #kDialogTextYesNo
    beq @yesNo
    @newline:
    lda #kDialogTextStartCol
    sta Zp_DialogTextCol_u8
    inc Zp_DialogTextRow_u8
    bne @advance  ; unconditional
    @yesNo:
    sty T0  ; dialog text byte offset
    jsr FuncA_Dialog_BeginYesNoQuestion  ; preserves T0+
    ldy T0  ; dialog text byte offset
    @endOfText:
    lda Zp_DialogStatus_bDialog
    ora #bDialog::Paused
    sta Zp_DialogStatus_bDialog
    bne @advance  ; unconditional
    @advance:
    iny  ; Skip past the end-of-line/text marker.
    jsr FuncA_Dialog_AdvanceTextPtr
    ;; Check whether there are still more lines to transfer.
    bit Zp_DialogStatus_bDialog
    .assert bDialog::Paused = bProc::Negative, error
    bpl _TransferLine
    rts
.ENDPROC

;;; Buffers a PPU transfer to clear all text from the dialog window.
.PROC FuncA_Dialog_TransferClearText
    lda #kDialogTextStartRow
    @rowLoop:
    pha
    ;; Write the transfer entry header.
    jsr Func_Window_GetRowPpuAddr  ; returns XY
    stx T0  ; destination address (hi)
    ldx Zp_PpuTransferLen_u8
    lda #kPpuCtrlFlagsHorz
    sta Ram_PpuTransfer_arr, x
    inx
    lda T0  ; destination address (hi)
    sta Ram_PpuTransfer_arr, x
    inx
    tya     ; destination address (lo)
    ora #kDialogTextStartCol
    sta Ram_PpuTransfer_arr, x
    inx
    lda #kDialogTextMaxCols
    sta Ram_PpuTransfer_arr, x
    inx
    ;; Write the transfer data.
    lda #' '
    ldy #kDialogTextMaxCols
    @columnLoop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @columnLoop
    stx Zp_PpuTransferLen_u8
    pla
    add #1
    cmp #kDialogTextStartRow + kDialogNumTextRows
    bne @rowLoop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the dialog cursor/prompt, as well as any objects in the room.
.PROC FuncA_Objects_DrawDialogCursorAndObjectsForRoom
    jsr FuncA_Objects_DrawObjectsForRoom
    bit Zp_DialogStatus_bDialog
    .assert bDialog::Paused = bProc::Negative, error
    bmi @paused
    rts
    @paused:
    .assert bDialog::YesNo = bProc::Overflow, error
    bvs FuncA_Objects_DrawDialogYesNoCursor
    .assert * = FuncA_Objects_DrawDialogButtonPrompt, error, "fallthrough"
.ENDPROC

;;; Draws the dialog-paused button prompt.
;;; @prereq bDialog::Paused is set.
.PROC FuncA_Objects_DrawDialogButtonPrompt
    jsr Func_AllocOneObject  ; returns Y
    ;; Calculate the screen Y-position.
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    cmp #$03
    bne @noZigZag
    lda #$01
    @noZigZag:
    add #kScreenHeightPx - kWindowMarginBottomPx - $12
    ;; Set object attributes.
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda #$e8
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda #kPaletteObjDialogPrompt
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjDialogPrompt
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    rts
.ENDPROC

;;; Draws the yes/no cursor.
;;; @prereq Yes-or-no question mode is active.
.PROC FuncA_Objects_DrawDialogYesNoCursor
    ;; Determine cursor position and width.
    ldx #2  ; width - 1 (2 for "YES")
    lda #kDialogYesObjX
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    dex  ; width - 1 (now 1 for "NO")
    lda #kDialogNoObjX
    @yes:
    sta T0  ; obj left
    stx T1  ; width - 1
_Loop:
    jsr Func_AllocOneObject  ; preserves X and T0+, returns Y
    ;; Set tile ID.
    txa
    beq @side  ; right side
    cpx T1  ; width - 1
    beq @side  ; left side
    lda #kTileIdObjCursorSolidMiddle
    bpl @setTileId  ; unconditional
    @side:
    lda #kTileIdObjCursorSolidLeft
    @setTileId:
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Set flags.
    lda #bObj::Pri | kPaletteObjCursor
    cpx #0
    bne @noFlip
    eor #bObj::FlipH
    @noFlip:
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    ;; Set position.
    lda #kDialogYesNoObjY
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda T0  ; obj left
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta T0  ; obj left
    dex
    bpl _Loop
    rts
.ENDPROC

;;;=========================================================================;;;
