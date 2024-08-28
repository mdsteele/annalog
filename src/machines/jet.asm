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

.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "jet.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_DoubleIfResetting
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_DivMod
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing jet elevator machines.
kTileIdObjJetUpperCorner      = kTileIdObjMachineCorner
kTileIdObjJetTopSurface       = kTileIdObjMachineSurfaceHorz
kTileIdObjJetLowerCornerFirst = kTileIdObjJetFirst + 0
kTileIdObjJetLowerMiddleFirst = kTileIdObjJetFirst + 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "Y" register for a jet elevator machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The maximum platform top position for the jet machine.
;;; @return A The value of the machine's "Y" register (0-9).
.EXPORT Func_MachineJetReadRegY
.PROC Func_MachineJetReadRegY
    ;; Add kJetMoveInterval/2 to the max platform top to get an offset origin.
    sta T1  ; max platform top (hi)
    txa
    add #kJetMoveInterval / 2
    sta T0  ; offset origin (lo)
    lda T1  ; max platform top (hi)
    adc #0
    sta T1  ; offset origin (lo)
    ;; Get the machine's platform index, storing it in Y.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; platform index
    ;; Compute the platform's 16-bit relative position, storing the lo byte in
    ;; T0 and the hi byte in A.
    lda T0  ; offset origin (lo)
    sub Ram_PlatformTop_i16_0_arr, y
    sta T0  ; relative position (lo)
    lda T1  ; offset origin (hi)
    sbc Ram_PlatformTop_i16_1_arr, y
    ;; We need to divide the 16-bit relative position by kJetMoveInterval, but
    ;; it's not a power of two, so we need to use Func_DivMod.  Assert that
    ;; dividing by two will make the relative position fit in 8 bits.
    .assert kJetMoveInterval * 9 < $200, error
    .assert kJetMoveInterval .mod 2 = 0, error
    lsr a
    ror T0  ; relative position (lo)
    lda T0  ; relative position / 2
    ldy #kJetMoveInterval / 2  ; param: divisor
    jsr Func_DivMod  ; returns quotient in Y
    tya
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tick implementation for jet elevator machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
;;; @param AX The maximum platform top position for the jet machine.
.EXPORT FuncA_Machine_JetTick
.PROC FuncA_Machine_JetTick
    sta T0  ; max platform top (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta T1  ; platform index
    ;; Calculate the goal delta from the max platform top position, storing the
    ;; lo byte in T2 and the hi byte in T3.
    ldy Zp_MachineIndex_u8
    lda #0
    sta T3  ; goal delta (hi)
    .assert kJetMoveInterval = %110000, error
    lda Ram_MachineGoalVert_u8_arr, y
    .assert 9 * %10000 < $100, error
    mul #%10000  ; fits in one byte
    sta T2
    asl a
    .assert 9 * %100000 >= $100, error
    rol T3  ; goal delta (hi)
    adc T2  ; carry is already cleared
    sta T2  ; goal delta (lo)
    lda T3  ; goal delta (hi)
    adc #0
    sta T3  ; goal delta (hi)
    ;; Calculate the desired Y-position for the top edge of the jet, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    txa               ; max platform top (lo)
    sub T2  ; goal delta (lo)
    sta Zp_PointY_i16 + 0
    lda T0  ; max platform top (hi)
    sbc T3  ; goal delta (hi)
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the jet (faster if resetting).
    lda #kJetMoveSpeed
    jsr FuncA_Machine_DoubleIfResetting  ; preserves T0+, returns A
    ;; Move the jet vertically, as necessary.
    ldx T1  ; param: platform index
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    beq _ReachedGoal
_Moved:
    ldx Zp_MachineIndex_u8
    lda #kJetMaxFlamePower
    sta Ram_MachineState1_byte_arr, x  ; flame power
    rts
_ReachedGoal:
    ;; Determine minimum flame power (0 if at min/max height, or
    ;; kJetMaxFlamePower/2 if hovering).
    ldx Zp_MachineIndex_u8
    lda #0
    ldy Ram_MachineGoalVert_u8_arr, x
    beq @setMin  ; jet is at minimum height
    cpy #9
    beq @setMin  ; jet is at maximum height
    @hovering:
    lda #kJetMaxFlamePower / 2
    @setMin:
    ;; Decrement flame power (down to minimum).
    cmp Ram_MachineState1_byte_arr, x  ; flame power
    bge @done
    dec Ram_MachineState1_byte_arr, x  ; flame power
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a jet elevator machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawJetMachine
.PROC FuncA_Objects_DrawJetMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    ;; Calculate the offset to use for the tile IDs for the bottom of the jet.
    ldx Zp_MachineIndex_u8
    ldy #0  ; flame level
    lda Ram_MachineState1_byte_arr, x  ; flame power
    beq @doneFlameLevel
    iny  ; now Y is 1
    cmp #kJetMaxFlamePower / 2 + 1
    blt @checkFrameCounter
    iny  ; now Y is 2
    @checkFrameCounter:
    lda Zp_FrameCounter_u8
    and #$04
    beq @doneFlameLevel
    iny
    @doneFlameLevel:
    tya  ; flame level
    mul #2
    sta T2  ; tile ID offset
_LeftHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves T0+
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves T2+, returns C and Y
    bcs @done
    ;; Set tile IDs.
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y and T0+, returns A
    ldx T2  ; param: tile ID offset
    jsr FuncA_Objects_SetJetMachineTiles  ; preserves T1+
    @done:
_RightHalf:
    ;; Allocate objects.
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kPaletteObjMachineLight | bObj::FlipH  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves T2+, returns C and Y
    bcc @notDone
    rts
    @notDone:
    lda #kPaletteObjMachineLight | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kTileIdObjJetUpperCorner  ; param: upper corner tile ID
    ldx T2  ; param: tile ID offset
    fall FuncA_Objects_SetJetMachineTiles
.ENDPROC

;;; Helper function for FuncA_Objects_DrawJetMachine.  Populates object tile
;;; IDs for half of a jet elevator machine.
;;; @param A The tile ID for the upper corner tile.
;;; @param X The tile ID offset for the bottom two tiles.
;;; @param Y The OAM byte offset for the first of the four tiles.
;;; @preserve X, Y, T1+
.PROC FuncA_Objects_SetJetMachineTiles
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    stx T0  ; tile ID offset
    lda #kTileIdObjJetLowerCornerFirst
    add T0  ; tile ID offset
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjJetTopSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjJetLowerMiddleFirst
    add T0  ; tile ID offset
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    rts
.ENDPROC

;;;=========================================================================;;;
