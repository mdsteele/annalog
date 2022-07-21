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
.INCLUDE "../program.inc"
.INCLUDE "cannon.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing cannon machines.
kCannonTileIdCornerTop  = kTileIdCannonFirst + $00
kCannonTileIdCornerBase = kTileIdCannonFirst + $01
kCannonTileIdBarrelHigh = kTileIdCannonFirst + $02
kCannonTileIdBarrelMid  = kTileIdCannonFirst + $03
kCannonTileIdBarrelLow  = kTileIdCannonFirst + $04

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a grenade launcher machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq The shape position is set to the top-left corner of the machine.
;;; @param X The aim angle (0-255).
.EXPORT FuncA_Objects_DrawCannonMachine
.PROC FuncA_Objects_DrawCannonMachine
    jsr FuncA_Objects_MoveShapeDownOneTile   ; preserves X and Y
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and Y
    ;; Allocate objects.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    .assert bMachine::FlipH = bObj::FlipH, error
    .assert kMachineLightPalette <> 0, error
    ora #kMachineLightPalette
    pha  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    pla  ; object flags
    bcs _Done
    ora #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
_SetBarrelTileId:
    cpx #$40
    blt @barrelLow
    cpx #$c0
    blt @barrelMid
    @barrelHigh:
    lda #kCannonTileIdBarrelHigh
    bne @setBarrel  ; unconditional
    @barrelMid:
    lda #kCannonTileIdBarrelMid
    bne @setBarrel  ; unconditional
    @barrelLow:
    lda #kCannonTileIdBarrelLow
    @setBarrel:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
_SetLightTileId:
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_SetCornerTileIds:
    lda #kCannonTileIdCornerTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kCannonTileIdCornerBase
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
