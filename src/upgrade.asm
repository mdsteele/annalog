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
.INCLUDE "device.inc"
.INCLUDE "flag.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "window.inc"

.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Objects_DrawObjectsForRoom
.IMPORT FuncA_Terrain_ScrollTowardsGoal
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ProcessFrame
.IMPORT Func_SetScrollGoalFromAvatar
.IMPORT Func_UpdateButtons
.IMPORT Func_Window_PrepareRowTransfer
.IMPORT Func_Window_SetUpIrq
.IMPORT Func_Window_TransferBottomBorder
.IMPORT Func_Window_TransferClearRow
.IMPORT Main_Explore_Continue
.IMPORT Ram_DeviceTarget_u8_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PpuTransfer_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineMaxInstructions_u8
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuTransferLen_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr
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
kUpgradeSymbolPalette = 0

;;; The OBJ tile IDs for the bottom two tiles of all upgrade symbols.
kUpgradeTileIdBottomLeft  = $80
kUpgradeTileIdBottomRight = $81
;;; The OBJ tile ID for the top-left tile of the symbol for max-instruction
;;; upgrades.  Add 1 to this to get the the top-right tile ID for that symbol.
kMaxInstTileIdTopLeft     = $82
;;; The OBJ tile ID for the top-left tile for the symbol of the first
;;; non-max-instruction upgrade.  Add 1 to this to get the the top-right tile
;;; ID for that symbol, then add another 1 to get the top-left tile ID for the
;;; next upgrade, and so on.
kRemainingTileIdTopLeft   = $84

;;;=========================================================================;;;

.ZEROPAGE

;;; The eFlag value for the upgrade that is currently being collected.
Zp_CurrentUpgrade_eFlag: .res 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Mode for scrolling in the upgrade window.
;;; @prereq Rendering is enabled.
;;; @prereq Explore mode is initialized.
;;; @param X The upgrade's device index.
.EXPORT Main_Upgrade_OpenWindow
.PROC Main_Upgrade_OpenWindow
    jsr_prga FuncA_Upgrade_Collect
_InitWindow:
    lda #kScreenHeightPx - kUpgradeWindowScrollSpeed
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
    lda #1
    sta Zp_WindowNextRowToTransfer_u8
    lda #kUpgradeWindowTopGoal
    sta Zp_WindowTopGoal_u8
_GameLoop:
    prga_bank #<.bank(FuncA_Objects_DrawUpgradeSymbol)
    jsr FuncA_Objects_DrawUpgradeSymbol
    jsr FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowUp:
    lda Zp_WindowTop_u8
    sub #kUpgradeWindowScrollSpeed
    cmp Zp_WindowTopGoal_u8
    bge @notDone
    lda Zp_WindowTopGoal_u8
    @notDone:
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
    jsr_prga FuncA_Upgrade_TransferNextWindowRow
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp Zp_WindowTopGoal_u8
    jeq Main_Upgrade_RunWindow
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
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
    jsr FuncA_Objects_DrawUpgradeSymbol
    jsr FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_ScrollWindowDown:
    lda Zp_WindowTop_u8
    add #kUpgradeWindowScrollSpeed
    cmp #kScreenHeightPx
    blt @notDone
    lda #$ff
    @notDone:
    sta Zp_WindowTop_u8
    jsr Func_Window_SetUpIrq
_CheckIfDone:
    lda Zp_WindowTop_u8
    cmp #$ff
    jeq Main_Explore_Continue
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;; Mode for running the upgrade window.
;;; @prereq Rendering is enabled.
;;; @prereq The upgrade window is fully visible.
;;; @prereq Explore mode is initialized.
.PROC Main_Upgrade_RunWindow
_GameLoop:
    prga_bank #<.bank(FuncA_Objects_DrawUpgradeSymbol)
    jsr FuncA_Objects_DrawUpgradeSymbol
    jsr FuncA_Objects_DrawObjectsForRoom
    jsr Func_ClearRestOfOam
    jsr Func_ProcessFrame
    jsr Func_UpdateButtons
_CheckButtons:
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::AButton | bJoypad::BButton
    beq @done
    jmp Main_Upgrade_CloseWindow
    @done:
_UpdateScrolling:
    jsr Func_SetScrollGoalFromAvatar
    jsr_prga FuncA_Terrain_ScrollTowardsGoal
    jmp _GameLoop
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Upgrade"

;;; Removes the specified upgrade device from the room, sets that upgrade's
;;; flag in SRAM as collected (updating Zp_MachineMaxInstructions_u8 as
;;; needed), and stores the upgrade's eFlag value in Zp_CurrentUpgrade_eFlag.
;;; @param X The upgrade device index.
.PROC FuncA_Upgrade_Collect
    ;; Remove the upgrade device from the room.
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr, x
    ;; Set the upgrade's flag in SRAM.
    lda Ram_DeviceTarget_u8_arr, x  ; eFlag value
    sta Zp_CurrentUpgrade_eFlag
    and #$07
    tay
    lda Ram_DeviceTarget_u8_arr, x  ; eFlag value
    div #$08
    tax
    lda Data_PowersOfTwo_u8_arr8, y
    ora Sram_ProgressFlags_arr, x
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Write progress flag.
    sta Sram_ProgressFlags_arr, x
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Update Zp_MachineMaxInstructions_u8, in case we just got a
    ;; max-instructions upgrade.
    .assert * = FuncA_Upgrade_ComputeMaxInstructions, error, "fallthrough"
.ENDPROC

;;; Recomputes Zp_MachineMaxInstructions_u8 from Sram_ProgressFlags_arr.
.EXPORT FuncA_Upgrade_ComputeMaxInstructions
.PROC FuncA_Upgrade_ComputeMaxInstructions
    ;; Store the max-instruction upgrade flags in the bottom
    ;; kNumMaxInstructionUpgrades bits of A.
    .assert eFlag::UpgradeMaxInstructions0 = 0, error
    .assert eFlag::UpgradeMaxInstructions1 = 1, error
    .assert eFlag::UpgradeMaxInstructions2 = 2, error
    .assert eFlag::UpgradeMaxInstructions3 = 3, error
    .assert kNumMaxInstructionUpgrades = 4, error
    lda Sram_ProgressFlags_arr + 0
    and #$0f
    ;; Loop over each of the kNumMaxInstructionUpgrades bottom bits of A.
    ;; Start with a max instructions count of kMaxProgramLength, and for each
    ;; max-instructions upgrade that we *don't* have, decrement that count by
    ;; kNumExtraInstructionsPerUpgrade.
    ldx #kMaxProgramLength  ; max instructions
    ldy #kNumMaxInstructionUpgrades
    @loop:
    lsr a
    bcs @continue
    .repeat kNumExtraInstructionsPerUpgrade
    dex
    .endrepeat
    @continue:
    dey
    bne @loop
    stx Zp_MachineMaxInstructions_u8
    rts
.ENDPROC

.PROC DataA_Upgrade_Descriptions
MaxInstructions1_u8_arr: .byte "     PROGRAM RAM", $ff
MaxInstructions2_u8_arr: .byte "Increases max program", $ff
MaxInstructions3_u8_arr: .byte "size by 2 instructions.", $ff
OpcodeCopy1_u8_arr:      .byte "     COPY OPCODE", $ff
OpcodeCopy2_u8_arr:      .byte "Copys a value into a", $ff
OpcodeCopy3_u8_arr:      .byte "register.", $ff
OpcodeSwap1_u8_arr:      .byte "     SWAP OPCODE", $ff
OpcodeSwap2_u8_arr:      .byte "Exchanges the values of", $ff
OpcodeSwap3_u8_arr:      .byte "two registers.", $ff
OpcodeAddSub1_u8_arr:    .byte "   ADD SUB OPCODES", $ff
OpcodeAddSub2_u8_arr:    .byte "Adds or subtracts two", $ff
OpcodeAddSub3_u8_arr:    .byte "values.", $ff
OpcodeMul1_u8_arr:       .byte "      MUL OPCODE", $ff
OpcodeMul2_u8_arr:       .byte "Multiplies two values.", $ff
OpcodeMul3_u8_arr:       .byte $ff
OpcodeIfGoto1_u8_arr:    .byte "      IF OPCODE", $ff
OpcodeIfGoto2_u8_arr:    .byte "Skips next instruction", $ff
OpcodeIfGoto3_u8_arr:    .byte "if condition is false.", $ff
OpcodeSkip1_u8_arr:      .byte "     SKIP OPCODE", $ff
OpcodeSkip2_u8_arr:      .byte "Skips over a variable", $ff
OpcodeSkip3_u8_arr:      .byte "number of instructions.", $ff
OpcodeTil1_u8_arr:       .byte "      TIL OPCODE", $ff
OpcodeTil2_u8_arr:       .byte "Repeats last instruction", $ff
OpcodeTil3_u8_arr:       .byte "until condition is met.", $ff
OpcodeNop1_u8_arr:       .byte "      NOP OPCODE", $ff
OpcodeNop2_u8_arr:       .byte "Has no effect.", $ff
OpcodeNop3_u8_arr:       .byte $ff
.ENDPROC

;;; Transfers the next upgrade window row (if any) that still needs to be
;;; transferred to the PPU.
.PROC FuncA_Upgrade_TransferNextWindowRow
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    cpy #kUpgradeNumInteriorRows
    blt _Interior
    beq _BottomBorder
    cpy #kWindowMaxNumRows
    blt _BottomMargin
    rts
_BottomMargin:
    jmp Func_Window_TransferClearRow
_BottomBorder:
    jmp Func_Window_TransferBottomBorder
_Interior:
    jsr Func_Window_PrepareRowTransfer
    ;; Draw left-hand border and margin.
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr + 1, x
    lda #kWindowTileIdBlank
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
    ;; Store a pointer to the description text for this row in Zp_Tmp_ptr.
    ldy Zp_WindowNextRowToTransfer_u8
    dey
    dey
    sty Zp_Tmp1_byte
    lda Zp_CurrentUpgrade_eFlag
    asl a
    adc Zp_CurrentUpgrade_eFlag
    adc Zp_Tmp1_byte
    asl a
    tay
    lda _DescTable_ptr_arr, y
    sta Zp_Tmp_ptr + 0
    iny
    lda _DescTable_ptr_arr, y
    sta Zp_Tmp_ptr + 1
    ;; Copy upgrade description.
    ldy #0
    @loop:
    lda (Zp_Tmp_ptr), y
    bmi @done
    sta Ram_PpuTransfer_arr, x
    inx
    iny
    bne @loop  ; unconditional
    @done:
_ClearRest:
    lda #kWindowTileIdBlank
    @loop:
    sta Ram_PpuTransfer_arr, x
    inx
    cpx Zp_PpuTransferLen_u8
    blt @loop
    ;; Draw right-hand border.
    dex
    dex
    lda #kWindowTileIdVert
    sta Ram_PpuTransfer_arr, x
    rts
_DescTable_ptr_arr:
    .repeat kNumMaxInstructionUpgrades
    .addr DataA_Upgrade_Descriptions::MaxInstructions1_u8_arr
    .addr DataA_Upgrade_Descriptions::MaxInstructions2_u8_arr
    .addr DataA_Upgrade_Descriptions::MaxInstructions3_u8_arr
    .endrepeat
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpcodeCopy, error
    .addr DataA_Upgrade_Descriptions::OpcodeCopy1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeCopy2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeCopy3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpcodeSwap, error
    .addr DataA_Upgrade_Descriptions::OpcodeSwap1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeSwap2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeSwap3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpcodeAddSub, error
    .addr DataA_Upgrade_Descriptions::OpcodeAddSub1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeAddSub2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeAddSub3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpcodeMul, error
    .addr DataA_Upgrade_Descriptions::OpcodeMul1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeMul2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeMul3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpcodeIfGoto, error
    .addr DataA_Upgrade_Descriptions::OpcodeIfGoto1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeIfGoto2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeIfGoto3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpcodeSkip, error
    .addr DataA_Upgrade_Descriptions::OpcodeSkip1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeSkip2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeSkip3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpcodeTil, error
    .addr DataA_Upgrade_Descriptions::OpcodeTil1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeTil2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeTil3_u8_arr
    .assert * - _DescTable_ptr_arr = 6 * eFlag::UpgradeOpcodeNop, error
    .addr DataA_Upgrade_Descriptions::OpcodeNop1_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeNop2_u8_arr
    .addr DataA_Upgrade_Descriptions::OpcodeNop3_u8_arr
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the upgrade symbol that appears
;;; within the upgrade window.
.PROC FuncA_Objects_DrawUpgradeSymbol
    ldy Zp_OamOffset_u8
    ;; Compute the screen pixel Y-position of the top of the symbol.
    lda Zp_FrameCounter_u8
    div #4
    and #$0f
    tax
    lda _YOffsets_u8_arr16, x
    add Zp_WindowTop_u8
    cmp #kScreenHeightPx
    bge _Done
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
    ;; Set flags and tile IDs.
    lda Zp_CurrentUpgrade_eFlag  ; param: eFlag
    jsr FuncA_Objects_SetUpgradeFlagsAndTileIds
    ;; Finish.
    tya
    add #.sizeof(sObj) * 4
    sta Zp_OamOffset_u8
_Done:
    rts
_YOffsets_u8_arr16:
    ;; [13 + int(round(sin(x * pi / 8))) for x in range(16)]
    .byte 13, 13, 14, 14, 14, 14, 14, 13, 13, 13, 12, 12, 12, 12, 12, 13
    .assert * - _YOffsets_u8_arr16 = 16, error
.ENDPROC

;;; Populates the OAM flags and tile IDs for four objects making up an upgrade
;;; symbol.  The allocated objects must be in the order: top-left, bottom-left,
;;; top-right, bottom-right.
;;; @param A The eFlag value for the upgrade.
;;; @param Y The OAM byte offset for the first of the four objects.
;;; @preserve X
.EXPORT FuncA_Objects_SetUpgradeFlagsAndTileIds
.PROC FuncA_Objects_SetUpgradeFlagsAndTileIds
    .assert kNumMaxInstructionUpgrades = 4, error
    sub #eFlag::UpgradeMaxInstructions3 + 1
    blt @upgradeMaxInstructions
    mul #2
    add #kRemainingTileIdTopLeft
    bcc @setTileIds  ; unconditional
    @upgradeMaxInstructions:
    lda #kMaxInstTileIdTopLeft
    @setTileIds:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    add #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kUpgradeTileIdBottomLeft
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kUpgradeTileIdBottomRight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kUpgradeSymbolPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    rts
.ENDPROC

;;;=========================================================================;;;
