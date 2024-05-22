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

.IMPORT Func_WriteToLowerAttributeTable
.IMPORT Func_WriteToUpperAttributeTable
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
    ldx #8    ; param: num bytes to write
    ldy #$50  ; param: attribute value
    lda #$30  ; param: initial byte offset
    jsr Func_WriteToUpperAttributeTable
    ldx #8    ; param: num bytes to write
    ldy #$05  ; param: attribute value
    lda #$38  ; param: initial byte offset
    jmp Func_WriteToUpperAttributeTable
.ENDPROC

;;; Sets two block rows of the lower nametable to use BG palette 1.  This
;;; should be called from a room's FadeIn_func_ptr.
;;; @prereq Rendering is disabled.
.EXPORT FuncA_Terrain_FadeInTallRoomWithLava
.PROC FuncA_Terrain_FadeInTallRoomWithLava
    ldx #8    ; param: num bytes to write
    ldy #$50  ; param: attribute value
    lda #$18  ; param: initial byte offset
    jsr Func_WriteToLowerAttributeTable
    ldx #8    ; param: num bytes to write
    ldy #$05  ; param: attribute value
    lda #$20  ; param: initial byte offset
    jmp Func_WriteToLowerAttributeTable
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Animates lava platform terrain tiles.  This should be called from a room's
;;; Draw_func_ptr.
.EXPORT FuncA_Objects_AnimateLavaTerrain
.PROC FuncA_Objects_AnimateLavaTerrain
    lda Zp_FrameCounter_u8
    div #8
    mod #4
    .assert .bank(Ppu_ChrBgAnimB0) .mod 4 = 0, error
    ora #<.bank(Ppu_ChrBgAnimB0)
    sta Zp_Chr04Bank_u8
    rts
.ENDPROC

;;;=========================================================================;;;
