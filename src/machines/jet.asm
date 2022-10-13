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

.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_DivMod
.IMPORT Func_MovePlatformTopToward
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing jet elevator machines.
kTileIdJetUpperCorner      = kTileIdMachineCorner
kTileIdJetTopSurface       = $7a
kTileIdJetLowerCornerFirst = kTileIdJetFirst + 0
kTileIdJetLowerMiddleFirst = kTileIdJetFirst + 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "Y" register for a jet elevator machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The maximum platform top position for the jet machine.
;;; @return A The value of the machine's "Y" register (0-9).
.EXPORT Func_MachineJetReadRegY
.PROC Func_MachineJetReadRegY
    ;; Add kJetMoveInterval/2 to the max platform top to get an offset origin.
    sta Zp_Tmp2_byte  ; max platform top (hi)
    txa
    add #kJetMoveInterval / 2
    sta Zp_Tmp1_byte  ; offset origin (lo)
    lda Zp_Tmp2_byte  ; max platform top (hi)
    adc #0
    sta Zp_Tmp2_byte  ; offset origin (lo)
    ;; Get the machine's platform index, storing it in Y.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; platform index
    ;; Compute the platform's 16-bit relative position, storing the lo byte in
    ;; Zp_Tmp1_byte and the hi byte in A.
    lda Zp_Tmp1_byte  ; offset origin (lo)
    sub Ram_PlatformTop_i16_0_arr, y
    sta Zp_Tmp1_byte  ; relative position (lo)
    lda Zp_Tmp2_byte  ; offset origin (hi)
    sbc Ram_PlatformTop_i16_1_arr, y
    ;; We need to divide the 16-bit relative position by kJetMoveInterval, but
    ;; it's not a power of two, so we need to use Func_DivMod.  Assert that
    ;; dividing by two will make the relative position fit in 8 bits.
    .assert kJetMoveInterval * 9 < $200, error
    .assert kJetMoveInterval .mod 2 = 0, error
    lsr a
    ror Zp_Tmp1_byte  ; relative position (lo)
    lda Zp_Tmp1_byte  ; relative position / 2
    ldy #kJetMoveInterval / 2  ; param: divisor
    jsr Func_DivMod  ; returns quotient in Y
    tya
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tick implementation for jet elevator machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The maximum platform top position for the jet machine.
.EXPORT FuncA_Machine_JetTick
.PROC FuncA_Machine_JetTick
    sta Zp_Tmp1_byte  ; max platform top (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp2_byte  ; platform index
    ;; Calculate the goal delta from the max platform top position, storing the
    ;; lo byte in Zp_Tmp3_byte and the hi byte in Zp_Tmp4_byte.
    ldy Zp_MachineIndex_u8
    lda #0
    sta Zp_Tmp4_byte  ; goal delta (hi)
    .assert kJetMoveInterval = %110000, error
    lda Ram_MachineGoalVert_u8_arr, y
    .assert 9 * %10000 < $100, error
    mul #%10000  ; fits in one byte
    sta Zp_Tmp3_byte
    asl a
    .assert 9 * %100000 >= $100, error
    rol Zp_Tmp4_byte  ; goal delta (hi)
    adc Zp_Tmp3_byte  ; carry is already cleared
    sta Zp_Tmp3_byte  ; goal delta (lo)
    lda Zp_Tmp4_byte  ; goal delta (hi)
    adc #0
    sta Zp_Tmp4_byte  ; goal delta (hi)
    ;; Calculate the desired Y-position for the top edge of the jet, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    txa               ; max platform top (lo)
    sub Zp_Tmp3_byte  ; goal delta (lo)
    sta Zp_PlatformGoal_i16 + 0
    lda Zp_Tmp1_byte  ; max platform top (hi)
    sbc Zp_Tmp4_byte  ; goal delta (hi)
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine the vertical speed of the jet (faster if resetting).
    ldx Ram_MachineStatus_eMachine_arr, y
    lda #kJetMoveSpeed
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the jet vertically, as necessary.
    ldx Zp_Tmp2_byte  ; param: platform index
    jsr Func_MovePlatformTopToward  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
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
    lda Ram_MachineGoalVert_u8_arr, x
    beq @done
    lda Zp_FrameCounter_u8
    and #$04
    lsr a
    adc #$02
    @done:
    tax  ; tile ID offset
_LeftHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    ;; Set tile IDs.
    stx Zp_Tmp1_byte  ; tile ID offset
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y and Zp_Tmp*, ret A
    ldx Zp_Tmp1_byte  ; param: tile ID offset
    jsr FuncA_Objects_SetJetMachineTiles  ; preserves X and Y
    @done:
_RightHalf:
    ;; Allocate objects.
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    lda #kMachineLightPalette | bObj::FlipH  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X; returns C and Y
    bcc @notDone
    rts
    @notDone:
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kTileIdJetUpperCorner
    .assert * = FuncA_Objects_SetJetMachineTiles, error, "fallthrough"
.ENDPROC

;;; Helper function for FuncA_Objects_DrawJetMachine.  Populates object tile
;;; IDs for half of a jet elevator machine.
;;; @param A The tile ID for the upper corner tile.
;;; @param X The tile ID offset for the bottom two tiles.
;;; @param Y The OAM byte offset for the first of the four tiles.
;;; @preserve X, Y
.PROC FuncA_Objects_SetJetMachineTiles
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    stx Zp_Tmp1_byte  ; tile ID offset
    lda #kTileIdJetLowerCornerFirst
    add Zp_Tmp1_byte  ; tile ID offset
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdJetTopSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdJetLowerMiddleFirst
    add Zp_Tmp1_byte  ; tile ID offset
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    rts
.ENDPROC

;;;=========================================================================;;;