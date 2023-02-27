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
.INCLUDE "flag.inc"
.INCLUDE "joypad.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "ppu.inc"
.INCLUDE "program.inc"
.INCLUDE "room.inc"
.INCLUDE "spawn.inc"

.IMPORT FuncA_Upgrade_ComputeMaxInstructions
.IMPORT Func_ClearRestOfOam
.IMPORT Func_ClearRestOfOamAndProcessFrame
.IMPORT Func_FadeInFromBlack
.IMPORT Func_FadeOutToBlack
.IMPORT Func_FillUpperAttributeTable
.IMPORT Func_GetRandomByte
.IMPORT Func_SetFlag
.IMPORT Func_Window_Disable
.IMPORT Main_Explore_SpawnInLastSafeRoom
.IMPORT Ppu_ChrBgTitle
.IMPORT Sram_LastSafe_bSpawn
.IMPORT Sram_LastSafe_eRoom
.IMPORT Sram_MagicNumber_u8
.IMPORT Sram_Minimap_u16_arr
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_P1ButtonsPressed_bJoypad
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_Render_bPpuMask
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The starting location for a new game.
kStartingRoom = eRoom::PrisonCell
kStartingSpawn = bSpawn::Device | 0

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
_GameLoop:
    ;; Check START button.
    lda Zp_P1ButtonsPressed_bJoypad
    and #bJoypad::Start
    bne _StartGame
    jsr Func_ClearRestOfOamAndProcessFrame
    jsr Func_GetRandomByte  ; tick the RNG (and discard the result)
    jmp _GameLoop
_StartGame:
    jsr Func_FadeOutToBlack
    jsr_prga FuncA_Title_ResetSramForNewGame
    jsr_prga FuncA_Upgrade_ComputeMaxInstructions
    jmp Main_Explore_SpawnInLastSafeRoom
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Title"

;;; The tile ID grid for the game title (stored in row-major order).
.PROC DataA_Title_Map_u8_arr
:   .incbin "out/data/title.map"
    .assert * - :- = kScreenWidthTiles * 3, error
End:
.ENDPROC

;;; Initializes title mode, then fades in the screen.
;;; @prereq Rendering is disabled.
.PROC FuncA_Title_Init
    jsr Func_Window_Disable
    chr08_bank #<.bank(Ppu_ChrBgTitle)
_StartMusic:
    lda #$ff
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Enable_bool
    sta Zp_Next_sAudioCtrl + sAudioCtrl::MasterVolume_u8
    lda #eMusic::Title
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
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
    jsr Func_FillUpperAttributeTable
_FadeIn:
    lda #bPpuMask::BgMain | bPpuMask::ObjMain
    sta Zp_Render_bPpuMask
    lda #0
    sta Zp_PpuScrollX_u8
    sta Zp_PpuScrollY_u8
    jmp Func_FadeInFromBlack
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
    ;; TODO: For testing, reveal whole minimap (remove this later).
.IF 0
    lda #$ff
    ldx #0
    @minimapLoop:
    sta Sram_Minimap_u16_arr, x
    inx
    cpx #$30
    blt @minimapLoop
.ENDIF
    ;; Set starting location.
    lda #kStartingRoom
    sta Sram_LastSafe_eRoom
    lda #kStartingSpawn
    sta Sram_LastSafe_bSpawn
    ;; Mark the save file as present.
    lda #kSaveMagicNumber
    sta Sram_MagicNumber_u8
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    ;; TODO: For testing, set some flags (remove this later).
    ldy #0
    @flagLoop:
    ldx _Flags_eFlag_arr, y  ; param: flag to set
    .assert eFlag::None = 0, error
    beq @doneFlags
    sty Zp_Tmp1_byte
    jsr Func_SetFlag  ; preserves Zp_Tmp*
    ldy Zp_Tmp1_byte
    iny
    bne @flagLoop  ; unconditional
    @doneFlags:
    rts
_Flags_eFlag_arr:
    .byte eFlag::None
.ENDPROC

;;;=========================================================================;;;
