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
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Ram_Oam_sObj_arr64

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing lift machines.
kTileIdObjLiftCorner  = kTileIdObjMachineCorner
kTileIdObjLiftSurface = kTileIdObjMachineSurfaceVert

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tries to move the current lift machine's vertical goal value.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The maximum permitted vertical goal value.
;;; @param X The eDir value for the direction to move in (up or down).
.EXPORT FuncA_Machine_LiftTryMove := FuncA_Machine_GenericTryMoveY

;;; Tick implementation for lift machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
;;; @param AX The maximum platform top position for the lift machine.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the lift moved up, cleared otherwise.
;;; @return Z Set if the lift's goal was reached.
.EXPORT FuncA_Machine_LiftTick
.PROC FuncA_Machine_LiftTick
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z, N, and A
    php
    pha
    bne @notAtGoal
    jsr FuncA_Machine_ReachedGoal
    @notAtGoal:
    pla
    plp
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for lift machines that appear behind the background.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawLiftMachineBg
.PROC FuncA_Objects_DrawLiftMachineBg
    lda #kPaletteObjMachineLight | bObj::Pri
    bne FuncA_Objects_DrawLiftMachineWithFlags  ; unconditional
.ENDPROC

;;; Draw implemention for normal lift machines (that appear in front of the
;;; background).
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawLiftMachine
.PROC FuncA_Objects_DrawLiftMachine
    lda #kPaletteObjMachineLight
    fall FuncA_Objects_DrawLiftMachineWithFlags
.ENDPROC

;;; Draw implemention for lift machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The base object flags to set.
.PROC FuncA_Objects_DrawLiftMachineWithFlags
    sta T2  ; base object flags
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
_TopHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves T0+
    lda T2  ; param: base object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves T2+, returns C and Y
    bcs @done
    ;; Set flags and tile IDs.
    lda T2  ; base object flags
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kTileIdObjLiftCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjLiftSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_BottomHalf:
    ;; Allocate objects.
    lda #kTileHeightPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves T0+
    lda T2  ; param: base object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves T2+, returns C and Y
    bcs @done
    ;; Set flags and tile IDs.
    lda T2  ; base object flags
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjLiftCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjLiftSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
