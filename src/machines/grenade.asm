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

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT Ram_Oam_sObj_arr64

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing grenade launcher machines.
kLauncherTileIdCornerTop  = $7a
kLauncherTileIdCornerBase = $7b
kLauncherTileIdBarrelHigh = $7c
kLauncherTileIdBarrelMid  = $7d
kLauncherTileIdBarrelLow  = $7e

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a grenade launcher machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @prereq The shape position is set to the top-left corner of the machine.
;;; @param X The aim angle (0-255).
;;; @param Y The facing direction (either 0 or bObj::FlipH).
.EXPORT FuncA_Objects_DrawGrenadeLauncherMachine
.PROC FuncA_Objects_DrawGrenadeLauncherMachine
    jsr FuncA_Objects_MoveShapeDownOneTile   ; preserves X and Y
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and Y
    ;; Allocate objects.
    tya
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
    lda #kLauncherTileIdBarrelHigh
    bne @setBarrel  ; unconditional
    @barrelMid:
    lda #kLauncherTileIdBarrelMid
    bne @setBarrel  ; unconditional
    @barrelLow:
    lda #kLauncherTileIdBarrelLow
    @setBarrel:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
_SetLightTileId:
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_SetCornerTileIds:
    lda #kLauncherTileIdCornerTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kLauncherTileIdCornerBase
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
