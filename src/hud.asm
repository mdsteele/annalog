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
.INCLUDE "flag.inc"
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT Func_MachineRead
.IMPORT Func_SetMachineIndex
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_Current_sRoom
.IMPORTZP Zp_OamOffset_u8

;;;=========================================================================;;;

;;; The screen pixel position for the top-left corner of the HUD.
kHudTop = kTileHeightPx * 3
kHudLeft = kScreenWidthPx - kTileWidthPx * 4

;;; The vertical spacing between the tops of consecutive HUD registers.
kHudSpacingPx = kTileHeightPx

;;; The OBJ palette number to use for the HUD.
kHudObjPalette = 1

;;;=========================================================================;;;

.ZEROPAGE

;;; The machine index to draw the HUD for, or $ff to disable the HUD.
.EXPORTZP Zp_HudMachineIndex_u8
Zp_HudMachineIndex_u8: .res 1

;;; Temporary variable used by FuncA_Objects_DrawMachineHud to pass the screen
;;; Y-position of the next register to draw to FuncA_Objects_DrawHudRegister.
Zp_HudBottom_u8: .res 1

;;; Temporary variable used by FuncA_Objects_DrawMachineHud to pass the name of
;;; the current register to draw to FuncA_Objects_DrawHudRegister.
Zp_HudRegisterName_u8: .res 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for the machine HUD, with names/values of
;;; all registers, for the machine with index Zp_HudMachineIndex_u8.  Draws
;;; nothing if Zp_HudMachineIndex_u8 is not the index of a machine in the
;;; current room (for example, if it's set to $ff).
.EXPORT FuncA_Objects_DrawMachineHud
.PROC FuncA_Objects_DrawMachineHud
    ldx Zp_HudMachineIndex_u8  ; param: machine index
    cpx <(Zp_Current_sRoom + sRoom::NumMachines_u8)
    bge _Done
    jsr Func_SetMachineIndex
    lda #kHudTop
    sta Zp_HudBottom_u8
_RegisterA:
    ;; Only show register A if it is unlocked (by the COPY upgrade).
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeOpcodeCopy >> 3)
    and #1 << (eFlag::UpgradeOpcodeCopy & $07)
    beq @done
    lda #kMachineRegNameA
    sta Zp_HudRegisterName_u8
    lda #$a  ; param: register
    jsr FuncA_Objects_DrawHudRegister
    @done:
_RegisterB:
    ;; Only show register B if it is unlocked.
    lda Sram_ProgressFlags_arr + (eFlag::UpgradeRegisterB >> 3)
    and #1 << (eFlag::UpgradeRegisterB & $07)
    beq @done
    lda #kMachineRegNameB
    sta Zp_HudRegisterName_u8
    lda #$b  ; param: register
    jsr FuncA_Objects_DrawHudRegister
    @done:
_OtherRegisters:
    .repeat 4, index
    .scope
    ldy #sMachine::RegNames_u8_arr4 + index
    lda (Zp_Current_sMachine_ptr), y
    beq @done
    sta Zp_HudRegisterName_u8
    lda #$c + index  ; param: register number
    jsr FuncA_Objects_DrawHudRegister
    @done:
    .endscope
    .endrepeat
_Done:
    rts
.ENDPROC

;;; Draws one register name/value pair for the HUD.  The name (tile ID) of the
;;; register is taken from Zp_HudRegisterName_u8 and the screen Y-position of
;;; the pair is taken from Zp_HudBottom_u8, then Zp_HudBottom_u8 is advanced
;;; for the next pair.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_HudBottom_u8 is initialized.
;;; @prereq Zp_HudRegisterName_u8 holds the name of the register to draw.
;;; @param A The register number ($a-$f) whose value should be read.
;;; @preserve X
.PROC FuncA_Objects_DrawHudRegister
    jsr Func_MachineRead  ; returns A
    ldy Zp_OamOffset_u8
    ;; Set the tile ID for the register value.
    .assert '0' & $0f = 0, error
    ora #'0'
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    ;; Set the tile ID for the register name.
    lda Zp_HudRegisterName_u8
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    ;; Set the Y-positions of the objects, then advance the HUD bottom.
    lda Zp_HudBottom_u8
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::YPos_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::YPos_u8, y
    add #kHudSpacingPx
    sta Zp_HudBottom_u8
    ;; Set the X-positions of the objects, then advance the HUD bottom.
    lda #kHudLeft
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::XPos_u8, y
    add #kTileWidthPx
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::XPos_u8, y
    ;; Set flags for the objects.
    lda #kHudObjPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    ;; Finish the allocation.
    tya
    add #.sizeof(sObj) * 2
    sta Zp_OamOffset_u8
    rts
.ENDPROC

;;;=========================================================================;;;
