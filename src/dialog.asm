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
.INCLUDE "devices/dialog.inc"
.INCLUDE "dialog.inc"
.INCLUDE "hud.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"
.INCLUDE "window.inc"

.IMPORT DataA_Dialog_CityBuilding2Screen_sDialog
.IMPORT DataA_Dialog_CityBuilding6Screen_sDialog
.IMPORT DataA_Dialog_CityFlowerOrcAngry_sDialog
.IMPORT DataA_Dialog_CityFlowerOrcCalm_sDialog
.IMPORT DataA_Dialog_CityOutskirtsAlex1_sDialog
.IMPORT DataA_Dialog_CityOutskirtsAlex2_sDialog
.IMPORT DataA_Dialog_CoreBossGrontaGive_sDialog
.IMPORT DataA_Dialog_CoreBossGrontaIntro_sDialog
.IMPORT DataA_Dialog_CoreLockBreakerShadow_sDialog
.IMPORT DataA_Dialog_CoreSouthCorra1_sDialog
.IMPORT DataA_Dialog_CoreSouthCorra2_sDialog
.IMPORT DataA_Dialog_CryptTombPlaque_sDialog
.IMPORT DataA_Dialog_FactoryVaultAlex_sDialog
.IMPORT DataA_Dialog_FactoryVaultScreen_sDialog
.IMPORT DataA_Dialog_GardenEastCorra_sDialog
.IMPORT DataA_Dialog_MermaidEntrySign_sDialog
.IMPORT DataA_Dialog_MermaidHut1AlexPetition_sDialog
.IMPORT DataA_Dialog_MermaidHut1BreakerCrypt1_sDialog
.IMPORT DataA_Dialog_MermaidHut1BreakerCrypt2_sDialog
.IMPORT DataA_Dialog_MermaidHut1BreakerGarden_sDialog
.IMPORT DataA_Dialog_MermaidHut1Guard_sDialog
.IMPORT DataA_Dialog_MermaidHut1Queen_sDialog
.IMPORT DataA_Dialog_MermaidHut2Guard_sDialog
.IMPORT DataA_Dialog_MermaidHut3Daphne_sDialog
.IMPORT DataA_Dialog_MermaidHut3Phoebe_sDialog
.IMPORT DataA_Dialog_MermaidHut4Florist_sDialog
.IMPORT DataA_Dialog_MermaidHut5Marie_sDialog
.IMPORT DataA_Dialog_MermaidHut5Nora_sDialog
.IMPORT DataA_Dialog_MermaidSpringAlex1_sDialog
.IMPORT DataA_Dialog_MermaidSpringAlex2_sDialog
.IMPORT DataA_Dialog_MermaidSpringSign_sDialog
.IMPORT DataA_Dialog_MermaidVillageAlex_sDialog
.IMPORT DataA_Dialog_MermaidVillageBruno_sDialog
.IMPORT DataA_Dialog_MermaidVillageCorra_sDialog
.IMPORT DataA_Dialog_MermaidVillageFarmer_sDialog
.IMPORT DataA_Dialog_MermaidVillageGuard_sDialog
.IMPORT DataA_Dialog_PaperJerome01_sDialog
.IMPORT DataA_Dialog_PaperJerome08_sDialog
.IMPORT DataA_Dialog_PaperJerome09_sDialog
.IMPORT DataA_Dialog_PaperJerome10_sDialog
.IMPORT DataA_Dialog_PaperJerome11_sDialog
.IMPORT DataA_Dialog_PaperJerome12_sDialog
.IMPORT DataA_Dialog_PaperJerome13_sDialog
.IMPORT DataA_Dialog_PaperJerome14_sDialog
.IMPORT DataA_Dialog_PaperJerome21_sDialog
.IMPORT DataA_Dialog_PaperJerome23_sDialog
.IMPORT DataA_Dialog_PaperJerome28_sDialog
.IMPORT DataA_Dialog_PaperJerome34_sDialog
.IMPORT DataA_Dialog_PaperJerome35_sDialog
.IMPORT DataA_Dialog_PaperJerome36_sDialog
.IMPORT DataA_Dialog_PaperManual1_sDialog
.IMPORT DataA_Dialog_PaperManual2_sDialog
.IMPORT DataA_Dialog_PaperManual3_sDialog
.IMPORT DataA_Dialog_PaperManual4_sDialog
.IMPORT DataA_Dialog_PaperManual5_sDialog
.IMPORT DataA_Dialog_PortraitAnimBank_u8_arr
.IMPORT DataA_Dialog_PortraitFirstTileId_u8_arr
.IMPORT DataA_Dialog_PortraitRestBank_u8_arr
.IMPORT DataA_Dialog_PrisonFlowerSign_sDialog
.IMPORT DataA_Dialog_PrisonUpperAlexCell_sDialog
.IMPORT DataA_Dialog_PrisonUpperAlexFree_sDialog
.IMPORT DataA_Dialog_PrisonUpperAlexLast_sDialog
.IMPORT DataA_Dialog_PrisonUpperBreakerTemple1_sDialog
.IMPORT DataA_Dialog_PrisonUpperBreakerTemple2_sDialog
.IMPORT DataA_Dialog_PrisonUpperBruno_sDialog
.IMPORT DataA_Dialog_PrisonUpperMarie_sDialog
.IMPORT DataA_Dialog_PrisonUpperNora_sDialog
.IMPORT DataA_Dialog_ShadowGateScreen_sDialog
.IMPORT DataA_Dialog_ShadowTeleportScreen_sDialog
.IMPORT DataA_Dialog_TempleAltarPlaque_sDialog
.IMPORT DataA_Dialog_TempleEntryCorraHi_sDialog
.IMPORT DataA_Dialog_TempleEntryCorraWait_sDialog
.IMPORT DataA_Dialog_TempleEntryGuard_sDialog
.IMPORT DataA_Dialog_TempleNaveAlexBoost1_sDialog
.IMPORT DataA_Dialog_TempleNaveAlexBoost2_sDialog
.IMPORT DataA_Dialog_TempleNaveAlexStand_sDialog
.IMPORT DataA_Dialog_TownHouse1Nora_sDialog
.IMPORT DataA_Dialog_TownHouse2Stela_sDialog
.IMPORT DataA_Dialog_TownHouse3Smith_sDialog
.IMPORT DataA_Dialog_TownHouse4BreakerLava1_sDialog
.IMPORT DataA_Dialog_TownHouse4BreakerLava2_sDialog
.IMPORT DataA_Dialog_TownHouse4BreakerLava3_sDialog
.IMPORT DataA_Dialog_TownHouse4Laura_sDialog
.IMPORT DataA_Dialog_TownHouse4Martin_sDialog
.IMPORT DataA_Dialog_TownHouse5Bruno_sDialog
.IMPORT DataA_Dialog_TownHouse5Marie_sDialog
.IMPORT DataA_Dialog_TownHouse6Elder_sDialog
.IMPORT DataC_Town_TownOutdoorsAlex1_sDialog
.IMPORT DataC_Town_TownOutdoorsAlex2_sDialog
.IMPORT DataC_Town_TownOutdoorsAlex3_sDialog
.IMPORT DataC_Town_TownOutdoorsGronta_sDialog
.IMPORT DataC_Town_TownOutdoorsIvan_sDialog
.IMPORT DataC_Town_TownOutdoorsSandra_sDialog
.IMPORT DataC_Town_TownOutdoorsSign_sDialog
.IMPORT FuncA_Dialog_PlaySfxQuestMarker
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncM_DrawObjectsForRoomAndProcessFrame
.IMPORT FuncM_ScrollTowardsAvatar
.IMPORT FuncM_ScrollTowardsGoal
.IMPORT Func_AllocOneObject
.IMPORT Func_BufferPpuTransfer
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_SetFlag
.IMPORT Func_TryPushAvatarHorz
.IMPORT Func_Window_GetRowPpuAddr
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_ScrollUp
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT MainA_Pause_Papers
.IMPORT Main_Cutscene_Continue
.IMPORT Main_Explore_Continue
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_AvatarVelX_i16
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Nearby_bDevice
.IMPORTZP Zp_Next_eCutscene
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

;;; The portrait for the current pane of dialog text.
Zp_Current_ePortrait: .res 1

;;; The index into Ram_DialogText_u8_arr for the next character to draw.
Zp_DialogTextIndex_u8: .res 1

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

;;; A pointer to the next sDialog entry to execute.
Zp_Next_sDialog_ptr: .res 2

;;;=========================================================================;;;

.SEGMENT "RAM_Dialog"

;;; A copy of the current pane of dialog text, including the end-of-line/text
;;; markers.
Ram_DialogText_u8_arr: .res (kDialogTextMaxCols + 1) * kDialogNumTextRows

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for beginning dialog by using a dialog device.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active dialog device.
;;; @param X The dialog device index.
.EXPORT Main_Dialog_UseDevice
.PROC Main_Dialog_UseDevice
    ldy Ram_DeviceTarget_byte_arr, x  ; param: eDialog value
    .assert * = Main_Dialog_WhileExploring, error, "fallthrough"
.ENDPROC

;;; Mode for beginning dialog within a cutscene.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param Y The eDialog value for the dialog.
.EXPORT Main_Dialog_WhileExploring
.PROC Main_Dialog_WhileExploring
    lda #0
    sta Zp_DialogStatus_bDialog
    beq Main_Dialog_OpenWindow  ; unconditional
.ENDPROC

;;; Mode for beginning dialog within a cutscene.
;;; @prereq Rendering is enabled.
;;; @prereq There is a cutscene in progress.
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
    jsr_prga FuncA_Dialog_InitTextAndAvatar  ; returns C, T2, and T1T0
    bcs Main_Dialog_Finish  ; dialog is empty
    jsr FuncM_CopyDialogText
_GameLoop:
    jsr FuncM_DrawObjectsForRoomAndProcessFrame
    jsr_prga FuncA_Dialog_ScrollWindowUp  ; sets C if window is now fully open
    bcs Main_Dialog_RunWindow
_UpdateScrolling:
    jsr FuncM_ScrollTowardsGoal
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
    jsr FuncM_DrawObjectsForRoomAndProcessFrame
    jsr_prga FuncA_Dialog_ScrollWindowDown  ; sets C if window is now closed
    bcs Main_Dialog_Finish
_UpdateScrolling:
    jsr FuncM_ScrollTowardsAvatar
    jmp _GameLoop
.ENDPROC

;;; Mode for running the dialog window.
;;; @prereq Rendering is enabled.
;;; @prereq The dialog window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Dialog_RunWindow
_GameLoop:
    jsr_prga FuncA_Objects_DrawDialogCursorAndObjectsForRoom
    jsr Func_ClearRestOfOamAndProcessFrame
_Tick:
    jsr_prga FuncA_Dialog_Tick  ; returns C, Z, T2, and T1T0
    bcs Main_Dialog_CloseWindow
    beq @done
    jsr FuncM_CopyDialogText
    @done:
_UpdateScrolling:
    jsr FuncM_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for running dialog on the pause screen.
;;; @prereq Rendering is enabled.
;;; @prereq The dialog window is fully visible.
;;; @param Y The eDialog value for the dialog.
.EXPORT Main_Dialog_OnPauseScreen
.PROC Main_Dialog_OnPauseScreen
    jsr_prga FuncA_Dialog_InitText  ; returns C, T2, and T1T0
    bcs _Finish  ; dialog is empty
_CopyText:
    jsr FuncM_CopyDialogText
_GameLoop:
    jsr_prga FuncA_Objects_DrawDialogCursor
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr_prga FuncA_Dialog_Tick  ; returns C, Z, T2, and T1T0
    bcs _Finish
    beq _GameLoop
    bne _CopyText  ; unconditional
_Finish:
    ;; Pump PPU transfer array once more before returning to the paper grid, so
    ;; it can tranfser more without overfilling the buffer.
    jsr Func_ClearRestOfOamAndProcessFrame
    jmp_prga MainA_Pause_Papers
.ENDPROC

;;; Given the bank/pointer returned by FuncA_Dialog_GetNextDialogTextPointer,
;;; switches the PRGA bank and copies the dialog text into
;;; Ram_DialogText_u8_arr.
;;; @param T2 The PRGA bank that contains the dialog text.
;;; @param T1T0 A pointer to the start of the dialog text.
.PROC FuncM_CopyDialogText
    main_prga T2
    ldy #$ff
    @loop:
    iny
    lda (T1T0), y
    sta Ram_DialogText_u8_arr, y
    bpl @loop
    cmp #kDialogTextNewline
    beq @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.LINECONT +
.REPEAT 2, t
    D_TABLE_LO t, DataA_Dialog_Table_sDialog_ptr_0_arr
    D_TABLE_HI t, DataA_Dialog_Table_sDialog_ptr_1_arr
    D_TABLE .enum, eDialog
    d_entry t, CityBuilding2Screen,  DataA_Dialog_CityBuilding2Screen_sDialog
    d_entry t, CityBuilding6Screen,  DataA_Dialog_CityBuilding6Screen_sDialog
    d_entry t, CityFlowerOrcAngry,   DataA_Dialog_CityFlowerOrcAngry_sDialog
    d_entry t, CityFlowerOrcCalm,    DataA_Dialog_CityFlowerOrcCalm_sDialog
    d_entry t, CityOutskirtsAlex1,   DataA_Dialog_CityOutskirtsAlex1_sDialog
    d_entry t, CityOutskirtsAlex2,   DataA_Dialog_CityOutskirtsAlex2_sDialog
    d_entry t, CoreBossGrontaGive,   DataA_Dialog_CoreBossGrontaGive_sDialog
    d_entry t, CoreBossGrontaIntro,  DataA_Dialog_CoreBossGrontaIntro_sDialog
    d_entry t, CoreLockBreakerShadow, \
            DataA_Dialog_CoreLockBreakerShadow_sDialog
    d_entry t, CoreSouthCorra1,      DataA_Dialog_CoreSouthCorra1_sDialog
    d_entry t, CoreSouthCorra2,      DataA_Dialog_CoreSouthCorra2_sDialog
    d_entry t, CryptTombPlaque,      DataA_Dialog_CryptTombPlaque_sDialog
    d_entry t, FactoryVaultAlex,     DataA_Dialog_FactoryVaultAlex_sDialog
    d_entry t, FactoryVaultScreen,   DataA_Dialog_FactoryVaultScreen_sDialog
    d_entry t, GardenEastCorra,      DataA_Dialog_GardenEastCorra_sDialog
    d_entry t, MermaidEntrySign,     DataA_Dialog_MermaidEntrySign_sDialog
    d_entry t, MermaidHut1AlexPetition, \
            DataA_Dialog_MermaidHut1AlexPetition_sDialog
    d_entry t, MermaidHut1BreakerCrypt1, \
            DataA_Dialog_MermaidHut1BreakerCrypt1_sDialog
    d_entry t, MermaidHut1BreakerCrypt2, \
            DataA_Dialog_MermaidHut1BreakerCrypt2_sDialog
    d_entry t, MermaidHut1BreakerGarden, \
            DataA_Dialog_MermaidHut1BreakerGarden_sDialog
    d_entry t, MermaidHut1Guard,     DataA_Dialog_MermaidHut1Guard_sDialog
    d_entry t, MermaidHut1Queen,     DataA_Dialog_MermaidHut1Queen_sDialog
    d_entry t, MermaidHut2Guard,     DataA_Dialog_MermaidHut2Guard_sDialog
    d_entry t, MermaidHut3Daphne,    DataA_Dialog_MermaidHut3Daphne_sDialog
    d_entry t, MermaidHut3Phoebe,    DataA_Dialog_MermaidHut3Phoebe_sDialog
    d_entry t, MermaidHut4Florist,   DataA_Dialog_MermaidHut4Florist_sDialog
    d_entry t, MermaidHut5Marie,     DataA_Dialog_MermaidHut5Marie_sDialog
    d_entry t, MermaidHut5Nora,      DataA_Dialog_MermaidHut5Nora_sDialog
    d_entry t, MermaidSpringAlex1,   DataA_Dialog_MermaidSpringAlex1_sDialog
    d_entry t, MermaidSpringAlex2,   DataA_Dialog_MermaidSpringAlex2_sDialog
    d_entry t, MermaidSpringSign,    DataA_Dialog_MermaidSpringSign_sDialog
    d_entry t, MermaidVillageAlex,   DataA_Dialog_MermaidVillageAlex_sDialog
    d_entry t, MermaidVillageBruno,  DataA_Dialog_MermaidVillageBruno_sDialog
    d_entry t, MermaidVillageCorra,  DataA_Dialog_MermaidVillageCorra_sDialog
    d_entry t, MermaidVillageFarmer, DataA_Dialog_MermaidVillageFarmer_sDialog
    d_entry t, MermaidVillageGuard,  DataA_Dialog_MermaidVillageGuard_sDialog
    d_entry t, PaperJerome01,        DataA_Dialog_PaperJerome01_sDialog
    d_entry t, PaperJerome08,        DataA_Dialog_PaperJerome08_sDialog
    d_entry t, PaperJerome09,        DataA_Dialog_PaperJerome09_sDialog
    d_entry t, PaperJerome10,        DataA_Dialog_PaperJerome10_sDialog
    d_entry t, PaperJerome11,        DataA_Dialog_PaperJerome11_sDialog
    d_entry t, PaperJerome12,        DataA_Dialog_PaperJerome12_sDialog
    d_entry t, PaperJerome13,        DataA_Dialog_PaperJerome13_sDialog
    d_entry t, PaperJerome14,        DataA_Dialog_PaperJerome14_sDialog
    d_entry t, PaperJerome21,        DataA_Dialog_PaperJerome21_sDialog
    d_entry t, PaperJerome23,        DataA_Dialog_PaperJerome23_sDialog
    d_entry t, PaperJerome28,        DataA_Dialog_PaperJerome28_sDialog
    d_entry t, PaperJerome34,        DataA_Dialog_PaperJerome34_sDialog
    d_entry t, PaperJerome35,        DataA_Dialog_PaperJerome35_sDialog
    d_entry t, PaperJerome36,        DataA_Dialog_PaperJerome36_sDialog
    d_entry t, PaperManual1,         DataA_Dialog_PaperManual1_sDialog
    d_entry t, PaperManual2,         DataA_Dialog_PaperManual2_sDialog
    d_entry t, PaperManual3,         DataA_Dialog_PaperManual3_sDialog
    d_entry t, PaperManual4,         DataA_Dialog_PaperManual4_sDialog
    d_entry t, PaperManual5,         DataA_Dialog_PaperManual5_sDialog
    d_entry t, PrisonFlowerSign,     DataA_Dialog_PrisonFlowerSign_sDialog
    d_entry t, PrisonUpperAlexCell,  DataA_Dialog_PrisonUpperAlexCell_sDialog
    d_entry t, PrisonUpperAlexFree,  DataA_Dialog_PrisonUpperAlexFree_sDialog
    d_entry t, PrisonUpperAlexLast,  DataA_Dialog_PrisonUpperAlexLast_sDialog
    d_entry t, PrisonUpperBreakerTemple1, \
            DataA_Dialog_PrisonUpperBreakerTemple1_sDialog
    d_entry t, PrisonUpperBreakerTemple2, \
            DataA_Dialog_PrisonUpperBreakerTemple2_sDialog
    d_entry t, PrisonUpperBruno,     DataA_Dialog_PrisonUpperBruno_sDialog
    d_entry t, PrisonUpperMarie,     DataA_Dialog_PrisonUpperMarie_sDialog
    d_entry t, PrisonUpperNora,      DataA_Dialog_PrisonUpperNora_sDialog
    d_entry t, ShadowGateScreen,     DataA_Dialog_ShadowGateScreen_sDialog
    d_entry t, ShadowTeleportScreen, DataA_Dialog_ShadowTeleportScreen_sDialog
    d_entry t, TempleAltarPlaque,    DataA_Dialog_TempleAltarPlaque_sDialog
    d_entry t, TempleEntryCorraHi,   DataA_Dialog_TempleEntryCorraHi_sDialog
    d_entry t, TempleEntryCorraWait, DataA_Dialog_TempleEntryCorraWait_sDialog
    d_entry t, TempleEntryGuard,     DataA_Dialog_TempleEntryGuard_sDialog
    d_entry t, TempleNaveAlexBoost1, DataA_Dialog_TempleNaveAlexBoost1_sDialog
    d_entry t, TempleNaveAlexBoost2, DataA_Dialog_TempleNaveAlexBoost2_sDialog
    d_entry t, TempleNaveAlexStand,  DataA_Dialog_TempleNaveAlexStand_sDialog
    d_entry t, TownHouse1Nora,       DataA_Dialog_TownHouse1Nora_sDialog
    d_entry t, TownHouse2Stela,      DataA_Dialog_TownHouse2Stela_sDialog
    d_entry t, TownHouse3Smith,      DataA_Dialog_TownHouse3Smith_sDialog
    d_entry t, TownHouse4BreakerLava1, \
            DataA_Dialog_TownHouse4BreakerLava1_sDialog
    d_entry t, TownHouse4BreakerLava2, \
            DataA_Dialog_TownHouse4BreakerLava2_sDialog
    d_entry t, TownHouse4BreakerLava3, \
            DataA_Dialog_TownHouse4BreakerLava3_sDialog
    d_entry t, TownHouse4Laura,      DataA_Dialog_TownHouse4Laura_sDialog
    d_entry t, TownHouse4Martin,     DataA_Dialog_TownHouse4Martin_sDialog
    d_entry t, TownHouse5Bruno,      DataA_Dialog_TownHouse5Bruno_sDialog
    d_entry t, TownHouse5Marie,      DataA_Dialog_TownHouse5Marie_sDialog
    d_entry t, TownHouse6Elder,      DataA_Dialog_TownHouse6Elder_sDialog
    d_entry t, TownOutdoorsAlex1,    DataC_Town_TownOutdoorsAlex1_sDialog
    d_entry t, TownOutdoorsAlex2,    DataC_Town_TownOutdoorsAlex2_sDialog
    d_entry t, TownOutdoorsAlex3,    DataC_Town_TownOutdoorsAlex3_sDialog
    d_entry t, TownOutdoorsGronta,   DataC_Town_TownOutdoorsGronta_sDialog
    d_entry t, TownOutdoorsIvan,     DataC_Town_TownOutdoorsIvan_sDialog
    d_entry t, TownOutdoorsSandra,   DataC_Town_TownOutdoorsSandra_sDialog
    d_entry t, TownOutdoorsSign,     DataC_Town_TownOutdoorsSign_sDialog
    D_END
.ENDREPEAT
.LINECONT -

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

;;; Initializes text for dialog mode.  If the dialog is not empty, then the
;;; caller must subsequently call FuncM_CopyDialogText to load the first pane
;;; of dialog text from its PRGA bank.
;;; @param Y The eDialog value for the dialog.
;;; @return C Set if the dialog is empty, cleared otherwise.
;;; @return T2 The PRGA bank number that contains the first dialog text.
;;; @return T1T0 A pointer to the start of the first dialog text.
.PROC FuncA_Dialog_InitText
    lda DataA_Dialog_Table_sDialog_ptr_0_arr, y
    sta Zp_Next_sDialog_ptr + 0
    lda DataA_Dialog_Table_sDialog_ptr_1_arr, y
    sta Zp_Next_sDialog_ptr + 1
    ;; Load the first portrait of the dialog.
    jmp FuncA_Dialog_GetNextDialogTextPointer  ; returns C, T2, and T1T0
.ENDPROC

;;; Initializes dialog mode.  If the dialog is not empty, then the caller must
;;; subsequently call FuncM_CopyDialogText to load the first pane of dialog
;;; text from its PRGA bank.
;;; @param Y The eDialog value for the dialog.
;;; @return C Set if the dialog is empty, cleared otherwise.
;;; @return T2 The PRGA bank number that contains the first dialog text.
;;; @return T1T0 A pointer to the start of the first dialog text.
.PROC FuncA_Dialog_InitTextAndAvatar
    jsr FuncA_Dialog_InitText  ; returns C, T2, and T1T0
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
    beq @talkLeft
    cmp #eDevice::TalkRight
    beq @talkRight
    @faceWall:
    ldy #eAvatar::Reading
    bne @faceRight  ; unconditional
    @talkLeft:
    ldy #eAvatar::Standing
    lda Zp_AvatarFlags_bObj
    ora #bObj::FlipH
    bne @setFlags  ; unconditional
    @talkRight:
    ldy #eAvatar::Standing
    @faceRight:
    lda Zp_AvatarFlags_bObj
    and #<~bObj::FlipH
    @setFlags:
    sta Zp_AvatarFlags_bObj
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Swimming = bProc::Overflow, error
    bvs @done
    sty Zp_AvatarPose_eAvatar
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

;;; Updates the dialog text based on joypad input and animates the dialog
;;; portrait appropriately.  The return values indicate whether dialog should
;;; end or continue, and whether it's time to copy the next pane of dialog
;;; text.
;;; @return C Set if dialog is finished and the window should be closed.
;;; @return Z Cleared if we should copy the next pane of dialog text.
;;; @return T2 The PRGA bank number that contains the next dialog text.
;;; @return T1T0 A pointer to the start of the next dialog text.
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
    bpl _TransferRestOfText
    ;; Otherwise, the player pressed the A button when we're already at
    ;; end-of-text, so begin the next page of text.
    jsr FuncA_Dialog_TransferClearText
    jsr FuncA_Dialog_GetNextDialogTextPointer  ; returns C, T2, and T1T0
    bcs _CloseWindow
    jsr _AnimatePortrait  ; preserves T0+, clears C
    lda #1  ; Clear Z to indicate that we should copy the next pane of text.
    rts
    @noAButton:
_UpdateText:
    bit Zp_DialogStatus_bDialog
    .assert bDialog::Paused = bProc::Negative, error
    bmi _RestPortrait
    jsr FuncA_Dialog_TransferNextCharacter
_AnimatePortrait:
    lda Zp_FrameCounter_u8
    and #$08
    beq _RestPortrait
    ldy Zp_Current_ePortrait
    ldx DataA_Dialog_PortraitAnimBank_u8_arr, y
    jmp _ContinueDialog
_TransferRestOfText:
    jsr FuncA_Dialog_TransferRestOfText
_RestPortrait:
    ldy Zp_Current_ePortrait
    ldx DataA_Dialog_PortraitRestBank_u8_arr, y
_ContinueDialog:
    main_chr0c x
    lda #0  ; Set Z to indicate that we shouldn't copy the next pane of text.
    clc  ; Clear C to indicate that dialog should continue.
    rts
_CloseWindow:
    jsr _RestPortrait  ; sets Z
    sec  ; Set C to indicate that we should close the dialog window.
    rts
.ENDPROC

;;; Reads the next sDialog entry, and handles it accordingly:
;;;   * If it is a portrait, initializes dialog variables appropriately,
;;;     advances Zp_Next_sDialog_ptr to point to the next sDialog entry, and
;;;     returns the bank/pointer for the dialog text that should be copied into
;;;     Ram_DialogText_u8_arr.
;;;   * If it is a dynamic dialog function pointer, calls the function and then
;;;     tries again with the dialog entry returned by the function.
;;;   * If it is ePortrait::Done, sets the C flag and returns.
;;; @prereq Zp_Next_sDialog_ptr is pointing to the next sDialog entry.
;;; @return C Set if the dialog is now done, cleared otherwise.
;;; @return T2 The PRGA bank number that contains the next dialog text.
;;; @return T1T0 A pointer to the start of the next dialog text.
.PROC FuncA_Dialog_GetNextDialogTextPointer
    ;; Prepare to start a new pane of dialog text.
    lda #0
    sta Zp_DialogTextIndex_u8
    lda #kDialogTextStartCol
    sta Zp_DialogTextCol_u8
    lda #kDialogTextStartRow
    sta Zp_DialogTextRow_u8
    ;; Clear the Paused and YesNo dialog status bits.
    lda Zp_DialogStatus_bDialog
    and #<~(bDialog::Paused | bDialog::YesNo)
    sta Zp_DialogStatus_bDialog
_ReadPortraitByte:
    ldy #0
    lda (Zp_Next_sDialog_ptr), y
    cmp #kDialogEntryDone
    beq _DialogDone
    iny
    cmp #kDialogEntryCutscene
    beq _StartCutscene
    cmp #kDialogEntryQuest
    beq _AddQuestMarker
    cmp #ePortrait::NUM_VALUES
    blt _SetPortrait
_DialogFunction:
    tax  ; entry kind (kDialogEntryCall or kDialogEntryFunc)
    lda (Zp_Next_sDialog_ptr), y
    sta T0
    iny
    lda (Zp_Next_sDialog_ptr), y
    sta T1
    iny
    cpx #kDialogEntryGoto
    beq @entryGoto
    cpx #kDialogEntryFunc
    beq @entryFunc
    @entryCall:
    jsr _UpdateDialogPointer
    jsr _CallT1T0
    jmp _ReadPortraitByte
    @entryGoto:
    ldya T1T0
    bmi @setNext  ; unconditional (enforced by dlg_Goto macro)
    @entryFunc:
    jsr _CallT1T0  ; returns YA
    @setNext:
    stya Zp_Next_sDialog_ptr
    jmp _ReadPortraitByte
_CallT1T0:
    jmp (T1T0)
_StartCutscene:
    lda (Zp_Next_sDialog_ptr), y
    sta Zp_Next_eCutscene
_DialogDone:
    sec  ; dialog done
    rts
_AddQuestMarker:
    lda (Zp_Next_sDialog_ptr), y
    tax  ; eFlag value for quest marker
    iny
    jsr _UpdateDialogPointer  ; preserves X
    jsr Func_SetFlag  ; sets C if flag was already set
    bcs _ReadPortraitByte
    jsr FuncA_Dialog_PlaySfxQuestMarker
    jmp _ReadPortraitByte
_SetPortrait:
    sta Zp_Current_ePortrait
    tax  ; ePortrait value
    main_chr0c DataA_Dialog_PortraitRestBank_u8_arr, x
_ReadTextPointer:
    lda (Zp_Next_sDialog_ptr), y
    iny
    sta T0  ; dialog text address (lo)
    lda (Zp_Next_sDialog_ptr), y
    iny
    tax  ; banked text pointer (hi)
    and #$1f
    ora #$a0
    sta T1  ; dialog text address (hi)
    txa  ; banked text pointer (hi)
    div #32
    sta T2  ; dialog text PRGA bank
_UpdateDialogPointer:
    tya
    add Zp_Next_sDialog_ptr + 0
    sta Zp_Next_sDialog_ptr + 0
    lda #0
    adc Zp_Next_sDialog_ptr + 1  ; carry will be clear after this
    sta Zp_Next_sDialog_ptr + 1
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
    ldax #DataA_Dialog_UndoPortraitAttrTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Dialog_UndoPortraitAttrTransfer_arr)  ; param: length
    jsr Func_BufferPpuTransfer
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
_AdjustAvatar:
    ;; Only adjust the player avatar's position if this dialog was started by
    ;; using a device, rather than from a cutscene.
    lda Zp_DialogStatus_bDialog
    .assert bDialog::Cutscene = $01, error
    lsr a
    bcs @done
    ;; Determine the goal X-offset for the player avatar to stand within the
    ;; device block.
    lda Zp_AvatarPose_eAvatar
    cmp #eAvatar::Reading
    beq @reading
    bit Zp_AvatarFlags_bObj
    .assert bObj::FlipH = bProc::Overflow, error
    bvc @facingRight
    @facingLeft:
    lda #kTalkLeftAvatarOffset
    bpl @setGoal  ; unconditional
    @facingRight:
    lda #kTalkRightAvatarOffset
    bpl @setGoal  ; unconditional
    @reading:
    lda #kReadingAvatarOffset
    @setGoal:
    sta T0  ; goal X-offset within block
    ;; Push the player avatar towards the goal position.
    lda Zp_AvatarPosX_i16 + 0
    and #$0f
    cmp T0  ; goal X-offset within block
    beq @done
    blt @adjustRight
    @adjustLeft:
    lda #<-1
    bne @pushAvatarByA  ; unconditional
    @adjustRight:
    lda #1
    @pushAvatarByA:
    sta Zp_AvatarPushDelta_i8
    jsr Func_TryPushAvatarHorz
    @done:
_ScrollWindow:
    jsr FuncA_Dialog_TransferNextWindowRow
    lda #kDialogWindowScrollSpeed  ; param: scroll by
    jmp Func_Window_ScrollUp  ; sets C if fully scrolled in
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
    jsr Func_Window_PrepareRowTransfer  ; returns X
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
    sub #2
    ldy Zp_Current_ePortrait
    add DataA_Dialog_PortraitFirstTileId_u8_arr, y
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
    ;; Buffer PPU transfer to set nametable attributes for the portrait
    ldax #DataA_Dialog_PortraitAttrTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Dialog_PortraitAttrTransfer_arr)  ; param: data length
    jmp Func_BufferPpuTransfer
.ENDPROC

;;; Transfers the next character of dialog text (if any) to the PPU.  If an
;;; end-of-line/text marker is reached, updates dialog variables accordingly.
;;; @prereq bDialog::Paused is cleared and Zp_DialogText_ptr points to text.
.PROC FuncA_Dialog_TransferNextCharacter
    ;; Read the next character, then advance past it.
    ldx Zp_DialogTextIndex_u8
    lda Ram_DialogText_u8_arr, x
    inx
    stx Zp_DialogTextIndex_u8
    ;; If the character is printable, then perform a PPU transfer to draw it to
    ;; the screen.
    tax
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
    ldax #DataA_Dialog_YesNoTransfer_arr  ; param: data pointer
    ldy #.sizeof(DataA_Dialog_YesNoTransfer_arr)  ; param: data length
    jmp Func_BufferPpuTransfer
.ENDPROC

;;; Buffers a PPU transfer to draw all remaining dialog text (if any) until the
;;; next end-of-text, then updates dialog variables accordingly (in particular,
;;; bDialog::Paused will be set when this returns).
;;; @prereq bDialog::Paused is cleared and Zp_DialogText_ptr points to text.
.PROC FuncA_Dialog_TransferRestOfText
_TransferLine:
    ;; If the next character is already an end-of-line/text marker, don't
    ;; create a transfer entry for this line.
    ldy Zp_DialogTextIndex_u8
    lda Ram_DialogText_u8_arr, y
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
    ldy Zp_DialogTextIndex_u8
    @loop:
    lda Ram_DialogText_u8_arr, y
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
    tya     ; index of end-of-line/text byte
    sub Zp_DialogTextIndex_u8
    sta Ram_PpuTransfer_arr, x
    pla  ; end-of-line/text marker
_EndOfLine:
    ;; At this point, A holds the end-of-line/text byte, and Y holds the index
    ;; of that byte within Ram_DialogText_u8_arr.
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
    @advance:
    iny  ; Skip past the end-of-line/text marker.
    sty Zp_DialogTextIndex_u8
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
    .assert * = FuncA_Objects_DrawDialogCursor, error, "fallthrough"
.ENDPROC

;;; Draws the dialog cursor/prompt.
.PROC FuncA_Objects_DrawDialogCursor
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
