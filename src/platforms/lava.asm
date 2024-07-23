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

.INCLUDE "../irq.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../ppu.inc"

.IMPORT Func_WriteToLowerAttributeTable
.IMPORT Func_WriteToUpperAttributeTable
.IMPORT Int_SetChr04ToParam3ThenLatchWindowFromParam4
.IMPORT Ppu_ChrBgAnimB0
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Chr04Bank_u8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_RoomScrollY_u8

;;;=========================================================================;;;

;;; The screen pixel Y-position at which the lava IRQ should change the CHR04
;;; bank.
kLavaChr04IrqY = $cf

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

;;; Calulates the CHR04 bank number to use for animated lava terrain this
;;; frame.
;;; @return A The CHR04 bank number.
.PROC FuncA_Objects_GetLavaAnimationBank
    lda Zp_FrameCounter_u8
    div #8
    mod #4
    .assert .bank(Ppu_ChrBgAnimB0) .mod 4 = 0, error
    ora #<.bank(Ppu_ChrBgAnimB0)
    rts
.ENDPROC

;;; Animates lava platform terrain tiles.  This should be called from a room's
;;; Draw_func_ptr.
.EXPORT FuncA_Objects_AnimateLavaTerrain
.PROC FuncA_Objects_AnimateLavaTerrain
    jsr FuncA_Objects_GetLavaAnimationBank  ; returns A
    sta Zp_Chr04Bank_u8
    rts
.ENDPROC

;;; Sets up an HBlank IRQ to animate lava platform terrain tiles in a room that
;;; must use a different CHR04 bank for the upper portion of the room.  This
;;; should be called from a room's Draw_func_ptr.
.EXPORT FuncA_Objects_SetUpLavaAnimationIrq
.PROC FuncA_Objects_SetUpLavaAnimationIrq
    ;; Compute the IRQ latch value to set between the top of the lava and the
    ;; top of the window (if any), and set that as Param4_byte.
    lda #kLavaChr04IrqY
    sub Zp_RoomScrollY_u8
    sta T0  ; IRQ latch for lava
    rsub Zp_Buffered_sIrq + sIrq::Latch_u8
    blt @done  ; window top is above lava top
    sta Zp_Buffered_sIrq + sIrq::Param4_byte  ; window latch
    ;; Set up our own sIrq struct to handle lava animation.
    lda T0  ; IRQ latch for lava
    sta Zp_Buffered_sIrq + sIrq::Latch_u8
    ldax #Int_SetChr04ToParam3ThenLatchWindowFromParam4
    stax Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr
    ;; Calculate and store the CHR04 bank that the IRQ should set for the
    ;; bottom part of the terrain.
    jsr FuncA_Objects_GetLavaAnimationBank  ; returns A
    sta Zp_Buffered_sIrq + sIrq::Param3_byte  ; lava CHR04 bank
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
