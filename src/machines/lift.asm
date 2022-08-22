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
.INCLUDE "../program.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_MovePlatformTopToward
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte

;;;=========================================================================;;;

;;; How many frames a lift machine spends per move operation.
kLiftMoveCooldown = kBlockHeightPx

;;; Various OBJ tile IDs used for drawing lift machines.
kTileIdLiftCorner  = $79
kTileIdLiftSurface = $78

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tries to move the current lift machine's vertical goal value.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param A The maximum permitted vertical goal value.
;;; @param X The eDir value for the direction to move in (up or down).
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.EXPORT FuncA_Machine_LiftTryMove
.PROC FuncA_Machine_LiftTryMove
    sta Zp_Tmp1_byte  ; max goal vert
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    cpx #eDir::Up
    bne @moveDown
    @moveUp:
    cmp Zp_Tmp1_byte  ; max goal vert
    bge @error
    add #1
    bne @success  ; unconditional
    @moveDown:
    tax
    beq @error
    dex
    txa
    @success:
    sta Ram_MachineGoalVert_u8_arr, y
    lda #kLiftMoveCooldown
    clc  ; success
    rts
    @error:
    sec  ; failure
    rts
.ENDPROC

;;; Moves the current lift machine's platform towards its goal position.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The maximum platform top position for the lift machine.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved left, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
.EXPORT FuncA_Machine_LiftMoveTowardGoal
.PROC FuncA_Machine_LiftMoveTowardGoal
    sta Zp_Tmp1_byte  ; max platform top (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp2_byte  ; platform index
    ;; Calculate the desired Y-position for the top edge of the lift, in
    ;; room-space pixels, storing it in Zp_PlatformGoal_i16.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    mul #kBlockHeightPx
    sta Zp_Tmp3_byte  ; goal delta
    txa               ; max platform top (lo)
    sub Zp_Tmp3_byte  ; goal delta
    sta Zp_PlatformGoal_i16 + 0
    lda Zp_Tmp1_byte  ; max platform top (hi)
    sbc #0
    sta Zp_PlatformGoal_i16 + 1
    ;; Determine the vertical speed of the lift (faster if resetting).
    sta $ff
    ldx Ram_MachineStatus_eMachine_arr, y
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the lift vertically, as necessary.
    ldx Zp_Tmp2_byte  ; param: platform index
    jmp Func_MovePlatformTopToward  ; returns Z, N, and A
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for lift machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawLiftMachine
.PROC FuncA_Objects_DrawLiftMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_TopHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette | bObj::FlipH | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kTileIdLiftCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdLiftSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_BottomHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeDownOneTile
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipH | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdLiftCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdLiftSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
