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
.INCLUDE "avatar.inc"
.INCLUDE "charmap.inc"
.INCLUDE "cpu.inc"
.INCLUDE "device.inc"
.INCLUDE "dialog.inc"
.INCLUDE "flag.inc"
.INCLUDE "hud.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "upgrade.inc"
.INCLUDE "window.inc"

.IMPORT DataA_Text2_UpgradeBRemote_u8_arr
.IMPORT DataA_Text2_UpgradeOpAddSub_u8_arr
.IMPORT DataA_Text2_UpgradeOpBeep_u8_arr
.IMPORT DataA_Text2_UpgradeOpCopy_u8_arr
.IMPORT DataA_Text2_UpgradeOpGoto_u8_arr
.IMPORT DataA_Text2_UpgradeOpIf_u8_arr
.IMPORT DataA_Text2_UpgradeOpMul_u8_arr
.IMPORT DataA_Text2_UpgradeOpRest_u8_arr
.IMPORT DataA_Text2_UpgradeOpSkip_u8_arr
.IMPORT DataA_Text2_UpgradeOpSync_u8_arr
.IMPORT DataA_Text2_UpgradeOpTil_u8_arr
.IMPORT DataA_Text2_UpgradeRam_u8_arr
.IMPORT FuncM_CopyDialogText
.IMPORT FuncM_DrawObjectsForRoomAndProcessFrame
.IMPORT FuncM_ScrollTowardsAvatar
.IMPORT FuncM_ScrollTowardsGoal
.IMPORT Func_AllocObjects
.IMPORT Func_SetFlag
.IMPORT Func_SetLastSpawnPointToActiveDevice
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_ScrollDown
.IMPORT Func_Window_ScrollUp
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Explore_Continue
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_DialogText_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarHarmTimer_u8
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_DialogTextIndex_u8
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_Nearby_bDevice
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_ScrollGoalY_u8
.IMPORTZP Zp_WindowNextRowToTransfer_u8
.IMPORTZP Zp_WindowTopGoal_u8
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; The number of interior rows in the upgrade window (i.e. not including the
;;; borders or the bottom margin).
kUpgradeNumInteriorRows = 3

;;; The goal value for Zp_WindowTop_u8 while scrolling in the upgrade window.
.LINECONT +
kUpgradeWindowTopGoal = kScreenHeightPx - \
    ((kUpgradeNumInteriorRows + 2) * kTileHeightPx + kWindowMarginBottomPx)
.LINECONT -

;;; How fast the upgrade window scrolls up/down, in pixels per frame.
kUpgradeWindowScrollSpeed = 4

;;; The screen X-position of the left side of the upgrade symbol in the upgrade
;;; window.
kUpgradeSymbolLeft = $14

;;; The OBJ palette number for upgrade symbols.
kPaletteObjUpgradeSymbol = 0

;;; The OBJ tile IDs for the bottom two tiles of all upgrade symbols.
kTileIdObjUpgradeBottomLeft  = kTileIdObjUpgradeBottomFirst + 0
kTileIdObjUpgradeBottomRight = kTileIdObjUpgradeBottomFirst + 1
;;; The OBJ tile ID for the top-left tile of the symbol for RAM upgrades.  Add
;;; 1 to this to get the the top-right tile ID for that symbol.
kTileIdObjRamTopLeft         = kTileIdObjUpgradeRamFirst + 0
;;; The OBJ tile ID for the top-left tile for the symbol of the first non-RAM
;;; upgrade.  Add 1 to this to get the the top-right tile ID for that symbol,
;;; then add another 1 to get the top-left tile ID for the next upgrade, and so
;;; on.
kTileIdObjRemainingTopLeft   = kTileIdObjUpgradeBRemoteFirst + 0

;;;=========================================================================;;;

.ZEROPAGE

;;; The eFlag value for the upgrade that is currently being collected.
Zp_CurrentUpgrade_eFlag: .res 1

;;; The music that was playing just before the upgrade was collected.
Zp_UpgradePrev_eMusic: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for scrolling in the upgrade window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active upgrade device.
.EXPORT Main_Upgrade_UseDevice
.PROC Main_Upgrade_UseDevice
    jsr_prga FuncA_Avatar_InitUpgradeMode  ; returns T2 and T1T0
    jsr FuncM_CopyDialogText
_GameLoop:
    jsr FuncM_DrawUpgradeObjectsAndProcessFrame
_UpdateWindow:
    jsr_prga FuncA_Dialog_ScrollUpgradeWindowUp  ; returns C
    bcs Main_Upgrade_RunWindow
_UpdateScrolling:
    jsr FuncM_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for scrolling out the upgrade window.  Switches to explore mode once
;;; the window is fully hidden.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Upgrade_CloseWindow
_GameLoop:
    jsr FuncM_DrawUpgradeObjectsAndProcessFrame
_UpdateWindow:
    lda #kUpgradeWindowScrollSpeed  ; param: scroll by
    jsr Func_Window_ScrollDown  ; sets C if fully scrolled out
    bcs _ResumeExploring
_UpdateScrolling:
    jsr FuncM_ScrollTowardsAvatar
    jmp _GameLoop
_ResumeExploring:
    lda Zp_UpgradePrev_eMusic
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    jmp Main_Explore_Continue
.ENDPROC

;;; Mode for running the upgrade window.
;;; @prereq Rendering is enabled.
;;; @prereq The upgrade window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Upgrade_RunWindow
_GameLoop:
    jsr FuncM_DrawUpgradeObjectsAndProcessFrame
_CheckButtons:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton | bJoypad::BButton
    bne Main_Upgrade_CloseWindow
_UpdateScrolling:
    jsr FuncM_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Draws all objects that should be drawn in upgrade mode, then calls
;;; Func_ClearRestOfOamAndProcessFrame.
.PROC FuncM_DrawUpgradeObjectsAndProcessFrame
    jsr_prga FuncA_Objects_DrawUpgradeSymbol
    jmp FuncM_DrawObjectsForRoomAndProcessFrame
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Initializes upgrade mode.
;;; @prereq Zp_Nearby_bDevice holds an active upgrade device.
;;; @return T2 The PRGA bank number that contains the upgrade text.
;;; @return T1T0 A pointer to the start of the upgrade text.
.PROC FuncA_Avatar_InitUpgradeMode
    lda #0
    sta Zp_AvatarState_bAvatar
    sta Zp_AvatarHarmTimer_u8
    lda #eAvatar::Reaching
    sta Zp_AvatarPose_eAvatar
_HideHud:
    lda Zp_FloatingHud_bHud
    ora #bHud::Hidden
    sta Zp_FloatingHud_bHud
_AdjustScrollGoal:
    lda Zp_ScrollGoalY_u8
    add #(kScreenHeightPx - kUpgradeWindowTopGoal) / 2
    sta Zp_ScrollGoalY_u8
_InitWindow:
    lda #kScreenHeightPx - kUpgradeWindowScrollSpeed
    sta Zp_WindowTop_u8
    lda #1
    sta Zp_WindowNextRowToTransfer_u8
    lda #kUpgradeWindowTopGoal
    sta Zp_WindowTopGoal_u8
_StartMusic:
    lda Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    sta Zp_UpgradePrev_eMusic
    lda #eMusic::Upgrade
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
_CollectUpgrade:
    jsr Func_SetLastSpawnPointToActiveDevice
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tay  ; device index
    ldx Ram_DeviceTarget_byte_arr, y  ; eFlag value
    stx Zp_CurrentUpgrade_eFlag
    ;; Remove the upgrade device from the room.
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr, y
    .assert eDevice::None = 0, error
    sta Zp_DialogTextIndex_u8
    ;; Set up return values for FuncM_CopyDialogText.
    lda DataA_Avatar_UpgradeText_ptr_0_arr, x
    sta T0
    lda DataA_Avatar_UpgradeText_ptr_1_arr, x
    sta T1
    lda #<.bank(DataA_Text2_UpgradeRam_u8_arr)
    sta T2
    ;; Set the upgrade's flag in SRAM.
    jsr Func_SetFlag  ; preserves T0+
    ;; Update Zp_MachineMaxInstructions_u8, in case we just got a RAM upgrade.
    fall FuncA_Avatar_ComputeMaxInstructions  ; preserves T0+
.ENDPROC

;;; Recomputes Zp_MachineMaxInstructions_u8 from Sram_ProgressFlags_arr.
;;; @preserve T0+
.EXPORT FuncA_Avatar_ComputeMaxInstructions
.PROC FuncA_Avatar_ComputeMaxInstructions
    ;; Store the RAM upgrade flags in the bottom kNumRamUpgrades bits of A.
    .assert eFlag::UpgradeRam1 = 1, error
    .assert eFlag::UpgradeRam2 = 2, error
    .assert eFlag::UpgradeRam3 = 3, error
    .assert eFlag::UpgradeRam4 = 4, error
    .assert kNumRamUpgrades = 4, error
    lda Sram_ProgressFlags_arr + 0
    lsr a
    and #$0f
    ;; Loop over each of the kNumRamUpgrades bottom bits of A.  Start with a
    ;; max instructions count of kMaxProgramLength, and for each RAM upgrade
    ;; that we *don't* have, decrement that count by
    ;; kNumExtraInstructionsPerRamUpgrade.
    ldx #kMaxProgramLength  ; max instructions
    ldy #kNumRamUpgrades
    @loop:
    lsr a
    bcs @continue
    .repeat kNumExtraInstructionsPerRamUpgrade
    dex
    .endrepeat
    @continue:
    dey
    bne @loop
    stx Zp_MachineMaxInstructions_u8
    rts
.ENDPROC

.REPEAT 2, table
    D_TABLE_LO table, DataA_Avatar_UpgradeText_ptr_0_arr
    D_TABLE_HI table, DataA_Avatar_UpgradeText_ptr_1_arr
    D_TABLE kNumUpgradeFlags + kFirstUpgradeFlag
    d_entry table, eFlag::None,            DataA_Text2_UpgradeRam_u8_arr
    d_entry table, eFlag::UpgradeRam1,     DataA_Text2_UpgradeRam_u8_arr
    d_entry table, eFlag::UpgradeRam2,     DataA_Text2_UpgradeRam_u8_arr
    d_entry table, eFlag::UpgradeRam3,     DataA_Text2_UpgradeRam_u8_arr
    d_entry table, eFlag::UpgradeRam4,     DataA_Text2_UpgradeRam_u8_arr
    d_entry table, eFlag::UpgradeBRemote,  DataA_Text2_UpgradeBRemote_u8_arr
    d_entry table, eFlag::UpgradeOpIf,     DataA_Text2_UpgradeOpIf_u8_arr
    d_entry table, eFlag::UpgradeOpTil,    DataA_Text2_UpgradeOpTil_u8_arr
    d_entry table, eFlag::UpgradeOpCopy,   DataA_Text2_UpgradeOpCopy_u8_arr
    d_entry table, eFlag::UpgradeOpAddSub, DataA_Text2_UpgradeOpAddSub_u8_arr
    d_entry table, eFlag::UpgradeOpMul,    DataA_Text2_UpgradeOpMul_u8_arr
    d_entry table, eFlag::UpgradeOpBeep,   DataA_Text2_UpgradeOpBeep_u8_arr
    d_entry table, eFlag::UpgradeOpGoto,   DataA_Text2_UpgradeOpGoto_u8_arr
    d_entry table, eFlag::UpgradeOpSkip,   DataA_Text2_UpgradeOpSkip_u8_arr
    d_entry table, eFlag::UpgradeOpRest,   DataA_Text2_UpgradeOpRest_u8_arr
    d_entry table, eFlag::UpgradeOpSync,   DataA_Text2_UpgradeOpSync_u8_arr
    D_END
.ENDREPEAT

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Scrolls the upgrade window in a bit, and transfers PPU data as needed; call
;;; this each frame when the window is opening.
;;; @return C Set if the window is now fully scrolled in.
.PROC FuncA_Dialog_ScrollUpgradeWindowUp
    jsr FuncA_Dialog_TransferNextUpgradeWindowRow
    lda #kUpgradeWindowScrollSpeed  ; param: scroll by
    jmp Func_Window_ScrollUp  ; sets C if fully scrolled in
.ENDPROC

;;; Transfers the next upgrade window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC FuncA_Dialog_TransferNextUpgradeWindowRow
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    cpy #kUpgradeNumInteriorRows
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
    ;; Draw left-hand border and margin.
    lda #kTileIdBgWindowVert
    sta Ram_PpuTransfer_arr + 1, x
    lda #' '
    sta Ram_PpuTransfer_arr, x
    inx
    inx
    ;; Indent by three columns.
    ldy #3
    @indentLoop:
    sta Ram_PpuTransfer_arr, x
    inx
    dey
    bne @indentLoop
_CopyUpgradeDescription:
    ldy Zp_DialogTextIndex_u8
    @loop:
    lda Ram_DialogText_u8_arr, y
    iny
    cmp #kDialogTextNewline
    bge @break
    sta Ram_PpuTransfer_arr, x
    inx
    bne @loop  ; unconditional
    @break:
    sty Zp_DialogTextIndex_u8
_ClearRest:
    lda #' '
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    cpx Zp_PpuTransferLen_u8
    blt @loop
    ;; Draw right-hand border.
    dex
    dex
    lda #kTileIdBgWindowVert
    sta Ram_PpuTransfer_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the upgrade symbol that appears
;;; within the upgrade window.
.PROC FuncA_Objects_DrawUpgradeSymbol
    ;; Compute the screen pixel Y-position of the top of the symbol.
    lda Zp_FrameCounter_u8
    div #4
    mod #16
    tax
    lda _YOffsets_u8_arr16, x
    add Zp_WindowTop_u8
    ;; If the symbol would be completely off-screen, we're done.
    cmp #kScreenHeightPx
    blt _Draw
    rts
_Draw:
    tax  ; top Y-position
    lda #4  ; param: num objects
    jsr Func_AllocObjects  ; preserves X, returns Y
    txa  ; top Y-position
    ;; Set Y-positions.
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::YPos_u8, y
    add #kTileHeightPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::YPos_u8, y
    ;; Set X-positions.
    lda #kUpgradeSymbolLeft
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    lda #kUpgradeSymbolLeft + kTileWidthPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::XPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::XPos_u8, y
    ;; Set flags.
    lda #kPaletteObjUpgradeSymbol
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    ;; Set tile IDs.
    lda Zp_CurrentUpgrade_eFlag  ; param: eFlag
    jmp FuncA_Objects_SetUpgradeTileIds
_YOffsets_u8_arr16:
    ;; [13 + int(round(sin(x * pi / 8))) for x in range(16)]
    .byte 13, 13, 14, 14, 14, 14, 14, 13, 13, 13, 12, 12, 12, 12, 12, 13
    .assert * - _YOffsets_u8_arr16 = 16, error
.ENDPROC

;;; Populates the tile IDs for four objects making up an upgrade symbol.
;;; The allocated objects must be in the order: top-left, bottom-left,
;;; top-right, bottom-right.
;;; @param A The eFlag value for the upgrade.
;;; @param Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.EXPORT FuncA_Objects_SetUpgradeTileIds
.PROC FuncA_Objects_SetUpgradeTileIds
    sub #kLastRamUpgradeFlag + 1
    blt @isRamUpgrade
    mul #2
    add #kTileIdObjRemainingTopLeft
    bcc @setTileIds  ; unconditional
    @isRamUpgrade:
    lda #kTileIdObjRamTopLeft
    @setTileIds:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjUpgradeBottomLeft
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjUpgradeBottomRight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    rts
.ENDPROC

;;;=========================================================================;;;
