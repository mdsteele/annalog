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
.INCLUDE "blaster.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjFireball
.IMPORT Func_MovePointHorz
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_Current_sMachine_ptr

;;;=========================================================================;;;

;;; The offset, in pixels, from the center of the blaster machine's platform at
;;; which to place newly-fired projectiles.
kBlasterProjectileOffset = 9

;;; How many frames a blaster machine spends per ACT operation.
kBlasterActCountdown = $60

;;; Various OBJ tile IDs used for drawing blaster machines.
kTileIdObjBlasterBarrelVert = kTileIdObjBlasterFirst + 0
kTileIdObjBlasterBarrelHorz = kTileIdObjBlasterFirst + 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryAct implemention for horizontal blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_BlasterHorzTryAct
.PROC FuncA_Machine_BlasterHorzTryAct
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs _Finish
_SetProjectilePosition:
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    beq @shootRight
    @shootLeft:
    ldy #$80  ; projectile angle
    lda #<-kBlasterProjectileOffset  ; param: offset
    bmi @movePoint  ; unconditional
    @shootRight:
    ldy #$00  ; projectile angle
    lda #kBlasterProjectileOffset  ; param: offset
    @movePoint:
    jsr Func_MovePointHorz  ; preserves X and Y
    jsr Func_SetActorCenterToPoint  ; preserves X and Y
_InitProjectile:
    tya  ; param: projectile angle
    jsr Func_InitActorProjFireball
    ;; TODO: Play a sound for firing the blaster.
_Finish:
    lda #kBlasterActCountdown  ; param: wait frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for horizontal blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawBlasterMachineHorz
.PROC FuncA_Objects_DrawBlasterMachineHorz
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    ;; Allocate objects.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    .assert bMachine::FlipH = bObj::FlipH, error
    .assert kPaletteObjMachineLight <> 0, error
    ora #kPaletteObjMachineLight
    pha  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; returns C and Y
    pla  ; object flags
    bcs @done
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    eor #bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjBlasterBarrelHorz
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
