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
.INCLUDE "flag.inc"
.INCLUDE "hud.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"

.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT Func_AllocObjects
.IMPORT Func_MachineRead
.IMPORT Func_SetMachineIndex
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

;;; How many pixels below the top of the window to draw the HUD when drawing it
;;; in the window.
kHudWindowMarginTop = 11

;;; The screen pixel Y-position for the top of the floating HUD (when fully
;;; scrolled in).
kFloatingHudTop = kTileHeightPx * 3

;;; The screen pixel X-position for the left of the HUD (for both the in-window
;;; HUD and the floating HUD).
kFloatingHudLeft = $12
kInWindowHudLeft = kScreenWidthPx - $22

;;; The OBJ palette number to use for the HUD.
kPaletteObjHud = 1

;;; Ensure that bHud::IndexMask is wide enough to include any machine index.
.ASSERT bHud::IndexMask + 1 >= kMaxMachines, error

;;;=========================================================================;;;

.ZEROPAGE

;;; Current settings for the floating HUD.
.EXPORTZP Zp_FloatingHud_bHud
Zp_FloatingHud_bHud: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a HUD for the current machine in the console window.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawHudInWindow
.PROC FuncA_Objects_DrawHudInWindow
    ;; If the in-window HUD would be completely offscreen, we're done.
    lda Zp_WindowTop_u8
    cmp #kScreenHeightPx - kHudWindowMarginTop
    bge @done
    ;; Otherwise, calculate the screen position for the top of the HUD.
    adc #kHudWindowMarginTop  ; carry is already clear
    sta Zp_ShapePosY_i16 + 0
    lda #kInWindowHudLeft
    sta Zp_ShapePosX_i16 + 0
    lda #0
    sta Zp_ShapePosY_i16 + 1
    jmp FuncA_Objects_DrawHudRegisters
    @done:
    rts
.ENDPROC

;;; Draws the floating HUD, with names/values of all registers, if it has a
;;; machine index set and isn't hidden.
.EXPORT FuncA_Objects_DrawFloatingHud
.PROC FuncA_Objects_DrawFloatingHud
    bit Zp_FloatingHud_bHud
    .assert bHud::NoMachine = bProc::Overflow, error
    bvs @done
    .assert bHud::Hidden = bProc::Negative, error
    bpl @draw
    @done:
    rts
    @draw:
    ;; Set the X-position of the floating HUD.
    lda #kFloatingHudLeft
    sta Zp_ShapePosX_i16 + 0
    ;; Set the Y-position of the floating HUD.
    lda Zp_FloatingHud_bHud
    and #bHud::IndexMask
    tax  ; param: machine index
    lda #kScreenHeightPx
    sub Zp_WindowTop_u8
    bge @setDelta
    lda #0
    @setDelta:
    sta T0  ; Y-delta
    lda #<kFloatingHudTop
    sub T0  ; Y-delta
    sta Zp_ShapePosY_i16 + 0
    lda #>kFloatingHudTop
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    jsr Func_SetMachineIndex
    .assert * = FuncA_Objects_DrawHudRegisters, error, "fallthrough"
.ENDPROC

;;; Draws all register name/value pairs for the HUD.  The screen Y-position of
;;; the top of the HUD is taken from Zp_ShapePosY_i16, and the screen
;;; X-position of the left of the HUD is taken from the lo byte of
;;; Zp_ShapePosX_i16 (the hi byte is ignored).
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncA_Objects_DrawHudRegisters
_RegisterA:
    ;; Only show register A if it is unlocked (by the COPY upgrade).
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeOpCopy
    beq @done
    lda #kMachineRegNameA  ; param: register name
    ldx #$a  ; param: register number
    jsr FuncA_Objects_DrawHudRegister
    @done:
_RegisterB:
    ;; Only show register B if it is unlocked.
    flag_bit Sram_ProgressFlags_arr, eFlag::UpgradeBRemote
    beq @done
    lda #kMachineRegNameB  ; param: register name
    ldx #$b  ; param: register number
    jsr FuncA_Objects_DrawHudRegister
    @done:
_OtherRegisters:
    ldx #$c
    @loop:
    txa  ; register number
    pha  ; register number
    .assert sMachine::RegNames_u8_arr4 < $c, error
    sub #$c - sMachine::RegNames_u8_arr4
    tay
    lda (Zp_Current_sMachine_ptr), y  ; param: register name
    beq @continue
    jsr FuncA_Objects_DrawHudRegister
    @continue:
    pla  ; register number
    tax  ; register number
    inx
    cpx #$10
    blt @loop
    rts
.ENDPROC

;;; Draws one register name/value pair for the HUD.  The screen Y-position of
;;; the pair is taken from Zp_ShapePosY_i16, and Zp_ShapePosY_i16 is advanced
;;; for the next pair.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_ShapePosY_i16 is set to the top position of the HUD register.
;;; @param A The name of the register ('A'-'Z').
;;; @param X The register number ($a-$f) whose value should be read.
.PROC FuncA_Objects_DrawHudRegister
    tay  ; register name tile ID
    ;; Calulcate the Y-positions of the objects.  If they would be offscreen
    ;; vertically, skip object allocation.
    lda Zp_ShapePosY_i16 + 1
    bne @skip
    lda Zp_ShapePosY_i16 + 0
    cmp #kScreenHeightPx
    bge @skip
    pha  ; object Y-position
    tya  ; register name tile ID
    pha  ; register name tile ID
    ;; Get the tile ID for the register value.
    txa  ; param: register number
    jsr Func_MachineRead  ; returns A
    .assert '0' & $0f = 0, error
    ora #'0'
    pha  ; register value tile ID
    ;; Allocate objects.
    lda #2  ; param: num objects
    jsr Func_AllocObjects  ; returns Y
    pla  ; register value tile ID
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    pla  ; register name tile ID
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    pla  ; object Y-position
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    lda Zp_ShapePosX_i16 + 0
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    lda #kPaletteObjHud
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    @skip:
    jmp FuncA_Objects_MoveShapeDownOneTile  ; preserves X and Y
.ENDPROC

;;;=========================================================================;;;
