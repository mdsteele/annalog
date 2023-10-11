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
.INCLUDE "cpu.inc"
.INCLUDE "device.inc"
.INCLUDE "flag.inc"
.INCLUDE "hud.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "upgrade.inc"
.INCLUDE "window.inc"

.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Terrain_ScrollTowardsAvatar
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_AllocObjects
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_SetFlag
.IMPORT Func_SetLastSpawnPointToActiveDevice
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Explore_Continue
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_Nearby_bDevice
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

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for scrolling in the upgrade window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @prereq Zp_Nearby_bDevice holds an active upgrade device.
.EXPORT Main_Upgrade_UseDevice
.PROC Main_Upgrade_UseDevice
    jsr_prga FuncA_Upgrade_Init
_GameLoop:
    prga_bank #<.bank(FuncA_Objects_DrawUpgradeSymbol)
    jsr FuncA_Objects_DrawObjectsForRoom
    jsr FuncA_Objects_DrawUpgradeSymbol
    jsr Func_ClearRestOfOamAndProcessFrame
_UpdateWindow:
    jsr_prga FuncA_Upgrade_ScrollWindowUp  ; returns C
    jcs Main_Upgrade_RunWindow
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for scrolling out the upgrade window.  Switches to explore mode once
;;; the window is fully hidden.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
.PROC Main_Upgrade_CloseWindow
_GameLoop:
    prga_bank #<.bank(FuncA_Objects_DrawUpgradeSymbol)
    jsr FuncA_Objects_DrawObjectsForRoom
    jsr FuncA_Objects_DrawUpgradeSymbol
    jsr Func_ClearRestOfOamAndProcessFrame
_UpdateWindow:
    jsr_prga FuncA_Upgrade_ScrollWindowDown  ; returns C
    jcs Main_Explore_Continue
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsAvatar
    jmp _GameLoop
.ENDPROC

;;; Mode for running the upgrade window.
;;; @prereq Rendering is enabled.
;;; @prereq The upgrade window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Upgrade_RunWindow
_GameLoop:
    prga_bank #<.bank(FuncA_Objects_DrawUpgradeSymbol)
    jsr FuncA_Objects_DrawObjectsForRoom
    jsr FuncA_Objects_DrawUpgradeSymbol
    jsr Func_ClearRestOfOamAndProcessFrame
_CheckButtons:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton | bJoypad::BButton
    beq @done
    jmp Main_Upgrade_CloseWindow
    @done:
_UpdateScrolling:
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Upgrade"

;;; Initializes upgrade mode.
;;; @prereq Zp_Nearby_bDevice holds an active upgrade device.
.PROC FuncA_Upgrade_Init
    jsr FuncA_Upgrade_Collect
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
    rts
.ENDPROC

;;; Removes the specified upgrade device from the room, sets that upgrade's
;;; flag in SRAM as collected (updating Zp_MachineMaxInstructions_u8 as
;;; needed), and stores the upgrade's eFlag value in Zp_CurrentUpgrade_eFlag.
;;; @prereq Zp_Nearby_bDevice holds an active upgrade device.
.PROC FuncA_Upgrade_Collect
    jsr Func_SetLastSpawnPointToActiveDevice
    lda Zp_Nearby_bDevice
    and #bDevice::IndexMask
    tax  ; device index
    ;; Remove the upgrade device from the room.
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr, x
    ;; Set the upgrade's flag in SRAM.
    lda Ram_DeviceTarget_byte_arr, x
    sta Zp_CurrentUpgrade_eFlag
    tax  ; param: eFlag value
    jsr Func_SetFlag
    ;; Update Zp_MachineMaxInstructions_u8, in case we just got a RAM upgrade.
    .assert * = FuncA_Upgrade_ComputeMaxInstructions, error, "fallthrough"
.ENDPROC

;;; Recomputes Zp_MachineMaxInstructions_u8 from Sram_ProgressFlags_arr.
.EXPORT FuncA_Upgrade_ComputeMaxInstructions
.PROC FuncA_Upgrade_ComputeMaxInstructions
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

.PROC DataA_Upgrade_Descriptions
Ram1_u8_arr:      .byte "     PROGRAM RAM", $ff
Ram2_u8_arr:      .byte "Increases max program", $ff
Ram3_u8_arr:      .byte "size by 2 instructions.", $ff
BRemote1_u8_arr:  .byte "       B-REMOTE", $ff
BRemote2_u8_arr:  .byte "Uses the B button to", $ff
BRemote3_u8_arr:  .byte "control the B register.", $ff
OpIf1_u8_arr:     .byte "      IF OPCODE", $ff
OpIf2_u8_arr:     .byte "Skips next instruction", $ff
OpIf3_u8_arr:     .byte "unless condition is met.", $ff
OpTil1_u8_arr:    .byte "      TIL OPCODE", $ff
OpTil2_u8_arr:    .byte "Repeats last instruction", $ff
OpTil3_u8_arr:    .byte "until condition is met.", $ff
OpCopy1_u8_arr:   .byte "     COPY OPCODE", $ff
OpCopy2_u8_arr:   .byte "Copies a value into a", $ff
OpCopy3_u8_arr:   .byte "register.", $ff
OpAddSub1_u8_arr: .byte "   ADD/SUB OPCODES", $ff
OpAddSub2_u8_arr: .byte "Adds or subtracts one", $ff
OpAddSub3_u8_arr: .byte "value from another.", $ff
OpMul1_u8_arr:    .byte "      MUL OPCODE", $ff
OpMul2_u8_arr:    .byte "Multiplies one value by", $ff
OpMul3_u8_arr:    .byte "another.", $ff
OpGoto1_u8_arr:   .byte "     GOTO OPCODE", $ff
OpGoto2_u8_arr:   .byte "Jumps directly to a", $ff
OpGoto3_u8_arr:   .byte "specific instruction.", $ff
OpSkip1_u8_arr:   .byte "     SKIP OPCODE", $ff
OpSkip2_u8_arr:   .byte "Skips over a variable", $ff
OpSkip3_u8_arr:   .byte "number of instructions.", $ff
OpRest1_u8_arr:   .byte "     REST OPCODE", $ff
OpRest2_u8_arr:   .byte "Pauses execution for a", $ff
OpRest3_u8_arr:   .byte "short time.", $ff
OpSync1_u8_arr:   .byte "     SYNC OPCODE", $ff
OpSync2_u8_arr:   .byte "Pauses execution until", $ff
OpSync3_u8_arr:   .byte "all machines sync.", $ff
OpBeep1_u8_arr:   .byte "     BEEP OPCODE", $ff
OpBeep2_u8_arr:   .byte "Plays one of ten musical", $ff
OpBeep3_u8_arr:   .byte "tones.", $ff
.ENDPROC

;;; Scrolls the upgrade window in a bit, and transfers PPU data as needed; call
;;; this each frame when the window is opening.
;;; @return C Set if the window is now fully scrolled in.
.PROC FuncA_Upgrade_ScrollWindowUp
    lda Zp_WindowTop_u8
    sub #kUpgradeWindowScrollSpeed
    cmp Zp_WindowTopGoal_u8
    bge @notDone
    lda Zp_WindowTopGoal_u8
    @notDone:
    sta Zp_WindowTop_u8
    jsr FuncA_Upgrade_TransferNextWindowRow
    lda Zp_WindowTopGoal_u8
    cmp Zp_WindowTop_u8  ; clears C if Zp_WindowTopGoal_u8 < Zp_WindowTop_u8
    rts
.ENDPROC

;;; Scrolls the dialog window down a bit; call this each frame when the window
;;; is closing.
;;; @return C Set if the window is now fully scrolled out.
.PROC FuncA_Upgrade_ScrollWindowDown
    lda Zp_WindowTop_u8
    add #kUpgradeWindowScrollSpeed
    cmp #kScreenHeightPx
    blt @notDone
    lda #$ff
    @notDone:
    sta Zp_WindowTop_u8
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp #$ff  ; clears C if Zp_WindowTop_u8 < $ff
    rts
.ENDPROC

;;; Transfers the next upgrade window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC FuncA_Upgrade_TransferNextWindowRow
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
    jsr Func_Window_PrepareRowTransfer
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
    ;; Store a pointer to the description text for this row in T1T0.
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    dey
    sty T2  ; text row
    lda Zp_CurrentUpgrade_eFlag
    mul #2
    adc Zp_CurrentUpgrade_eFlag
    adc T2  ; text row
    mul #kSizeofAddr
    tay  ; kSizeofAddr * (eFlag * 3 + text_row)
    lda _DescTable_ptr_arr, y
    sta T0  ; text pointer (lo)
    iny
    lda _DescTable_ptr_arr, y
    sta T1  ; text pointer (hi)
    ;; Copy upgrade description.
    ldy #0
    @loop:
    lda (T1T0), y
    bmi @done
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    bne @loop  ; unconditional
    @done:
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
_DescTable_ptr_arr:
    .res 6
    .assert * - _DescTable_ptr_arr = 6 * kFirstRamUpgradeFlag, error
    .repeat kNumRamUpgrades
    .addr DataA_Upgrade_Descriptions::Ram1_u8_arr
    .addr DataA_Upgrade_Descriptions::Ram2_u8_arr
    .addr DataA_Upgrade_Descriptions::Ram3_u8_arr
    .endrepeat
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeBRemote, error
    .addr DataA_Upgrade_Descriptions::BRemote1_u8_arr
    .addr DataA_Upgrade_Descriptions::BRemote2_u8_arr
    .addr DataA_Upgrade_Descriptions::BRemote3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpIf, error
    .addr DataA_Upgrade_Descriptions::OpIf1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpIf2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpIf3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpTil, error
    .addr DataA_Upgrade_Descriptions::OpTil1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpTil2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpTil3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpCopy, error
    .addr DataA_Upgrade_Descriptions::OpCopy1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpCopy2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpCopy3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpAddSub, error
    .addr DataA_Upgrade_Descriptions::OpAddSub1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpAddSub2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpAddSub3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpMul, error
    .addr DataA_Upgrade_Descriptions::OpMul1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpMul2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpMul3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpBeep, error
    .addr DataA_Upgrade_Descriptions::OpBeep1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpBeep2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpBeep3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpGoto, error
    .addr DataA_Upgrade_Descriptions::OpGoto1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpGoto2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpGoto3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpSkip, error
    .addr DataA_Upgrade_Descriptions::OpSkip1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpSkip2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpSkip3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpRest, error
    .addr DataA_Upgrade_Descriptions::OpRest1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpRest2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpRest3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpSync, error
    .addr DataA_Upgrade_Descriptions::OpSync1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpSync2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpSync3_u8_arr
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the upgrade symbol that appears
;;; within the upgrade window.
.PROC FuncA_Objects_DrawUpgradeSymbol
    ;; Compute the screen pixel Y-position of the top of the symbol.
    lda Zp_FrameCounter_u8
    div #4
    and #$0f
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
