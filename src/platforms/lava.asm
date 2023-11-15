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

.INCLUDE "../macros.inc"
.INCLUDE "../ppu.inc"

.IMPORT Ppu_ChrBgAnimB0
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Sets the bottom two block rows of the upper nametable to use BG palette 1.
;;; This should be called from a room's FadeIn_func_ptr.
;;; @prereq Rendering is disabled.
.EXPORT FuncA_Terrain_FadeInShortRoomWithLava
.PROC FuncA_Terrain_FadeInShortRoomWithLava
    ldax #Ppu_Nametable0_sName + sName::Attrs_u8_arr64 + $30
    jmp FuncA_Terrain_FadeInRoomWithLava
.ENDPROC

;;; Sets two block rows of the lower nametable to use BG palette 1.  This
;;; should be called from a room's FadeIn_func_ptr.
;;; @prereq Rendering is disabled.
.EXPORT FuncA_Terrain_FadeInTallRoomWithLava
.PROC FuncA_Terrain_FadeInTallRoomWithLava
    ldax #Ppu_Nametable3_sName + sName::Attrs_u8_arr64 + $18
    .assert * = FuncA_Terrain_FadeInRoomWithLava, error, "fallthrough"
.ENDPROC

;;; Sets two block rows of a PPU nametable to use BG palette 1.
;;; @prereq Rendering is disabled.
;;; @param AX The PPU address to start writing at.
.PROC FuncA_Terrain_FadeInRoomWithLava
    bit Hw_PpuStatus_ro  ; reset the Hw_PpuAddr_w2 write-twice latch
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
_FirstRow:
    lda #$50
    ldx #8
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_SecondRow:
    lda #$05
    ldx #8
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Animates lava platform terrain tiles.  This should be called from a room's
;;; Draw_func_ptr.
.EXPORT FuncA_Objects_AnimateLavaTerrain
.PROC FuncA_Objects_AnimateLavaTerrain
    lda Zp_FrameCounter_u8
    div #8
    and #$03
    add #<.bank(Ppu_ChrBgAnimB0)
    sta Zp_Chr04Bank_u8
    rts
.ENDPROC

;;;=========================================================================;;;
