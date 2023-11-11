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
.INCLUDE "carriage.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_FindDeviceNearPoint
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; Tile IDs for drawing carriage machines.
kTileIdObjCarriageCorner  = kTileIdObjMachineCorner
kTileIdObjCarriageSurface = kTileIdObjMachineSurfaceHorz

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tries to move the current carriage machine's horizontal or vertical goal
;;; value.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The maximum permitted horizontal goal value.
;;; @param Y The maximum permitted vertical goal value.
;;; @param X The eDir value for the direction to move in.
.EXPORT FuncA_Machine_CarriageTryMove
.PROC FuncA_Machine_CarriageTryMove
    sta T0  ; max goal horz
    sty T1  ; max goal vert
    ;; Get the carriage platform index and position.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X and T0+
    ;; Try moving in the desired direction.
    txa  ; eDir value
    ldx Zp_MachineIndex_u8
    cmp #eDir::Left
    beq _TryMoveLeft
    cmp #eDir::Right
    beq _TryMoveRight
    cmp #eDir::Down
    beq _TryMoveDown
_TryMoveUp:
    ;; If the current vert goal is the maximum, the carriage can't move up.
    lda Ram_MachineGoalVert_u8_arr, x
    cmp T1  ; max goal vert
    bge _Error
    ;; If either terrain block above the carriage is solid, the carriage can't
    ;; move up.
    lda #kBlockHeightPx  ; param: offset
    jsr Func_MovePointUpByA  ; preserves X
    jsr FuncA_Machine_CarriageCanMoveVert  ; preserves X, returns C
    bcs _Error
    ;; Start moving the carriage upwards.
    inc Ram_MachineGoalVert_u8_arr, x
    jmp FuncA_Machine_StartWorking
_TryMoveDown:
    ;; If the current vert goal is zero, the carriage can't move left.
    lda Ram_MachineGoalVert_u8_arr, x
    beq _Error
    ;; If either terrain block below the carriage is solid, the carriage can't
    ;; move down.
    lda #kBlockHeightPx  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    jsr FuncA_Machine_CarriageCanMoveVert  ; preserves X, returns C
    bcs _Error
    ;; Start moving the carriage downwards.
    dec Ram_MachineGoalVert_u8_arr, x
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
_TryMoveLeft:
    ;; If the current horz goal is zero, the carriage can't move left.
    lda Ram_MachineGoalHorz_u8_arr, x
    beq _Error
    ;; If the terrain block to the right of the carriage is solid, the carriage
    ;; can't move right.
    lda #kCarriageMachineWidthPx / 2 + kTileWidthPx
    jsr Func_MovePointLeftByA  ; preserves X
    jsr FuncA_Machine_PointHitsTerrainOrDevice  ; preserves X, returns C
    bcs _Error
    ;; Start moving the carriage to the left.
    dec Ram_MachineGoalHorz_u8_arr, x
    jmp FuncA_Machine_StartWorking
_TryMoveRight:
    ;; If the current horz goal is the maximum, the carriage can't move right.
    lda Ram_MachineGoalHorz_u8_arr, x
    cmp T0  ; max goal horz
    bge _Error
    ;; If the terrain block to the right of the carriage is solid, the carriage
    ;; can't move right.
    lda #kCarriageMachineWidthPx / 2 + kTileWidthPx
    jsr Func_MovePointRightByA  ; preserves X
    jsr FuncA_Machine_PointHitsTerrainOrDevice  ; preserves X, returns C
    bcs _Error
    ;; Start moving the carriage to the right.
    inc Ram_MachineGoalHorz_u8_arr, x
    jmp FuncA_Machine_StartWorking
.ENDPROC

;;; Helper function for FuncA_Machine_CarriageTryMove; checks if a carriage
;;; machine can move vertically.
;;; @prereq Zp_Point* is set one block above/below the carriage center.
;;; @return C Cleared if the carriage can move, or set if it is blocked.
;;; @preserve X
.PROC FuncA_Machine_CarriageCanMoveVert
    .assert kCarriageMachineWidthPx = kBlockWidthPx * 2, error
_CheckLeftSide:
    lda #kTileWidthPx
    jsr Func_MovePointLeftByA  ; preserves X
    jsr FuncA_Machine_PointHitsTerrainOrDevice  ; preserves X+, returns C
    bcc _CheckRightSide
    rts
_CheckRightSide:
    lda #kTileWidthPx * 2
    jsr Func_MovePointRightByA  ; preserves X
    jmp FuncA_Machine_PointHitsTerrainOrDevice  ; preserves X, returns C
.ENDPROC

;;; Determines if the point stored in Zp_PointX_i16 and Zp_PointY_i16 is
;;; colliding with solid terrain or with a device (including non-interactive
;;; devices).  It is assumed that both coordinates are nonnegative and within
;;; the bounds of the room terrain.
;;; @return C Set if point hits solid terrain or any device, cleared otherwise.
;;; @preserve X
.PROC FuncA_Machine_PointHitsTerrainOrDevice
    jsr Func_FindDeviceNearPoint  ; preserves X, returns N
    bpl @collision
    jmp Func_PointHitsTerrain  ; preserves X, returns C
    @collision:
    sec
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for carriage machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawCarriageMachine
.PROC FuncA_Objects_DrawCarriageMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_LeftHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kPaletteObjMachineLight | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjCarriageCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjCarriageSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_RightHalf:
    ;; Allocate objects.
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kPaletteObjMachineLight | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjCarriageSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjCarriageCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
