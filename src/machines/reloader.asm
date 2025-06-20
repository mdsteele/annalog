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

.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "reloader.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_PlaySfxRocketTransfer
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Alloc2x2MachineShape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; How quickly the rocket moves while the reloader is picking it up from the
;;; ammo rack, in pixels per frame.
.DEFINE kReloaderPickupSpeed 2

;;; Various OBJ tile IDs used for drawing reloader machines.
kTileIdObjReloaderHopperTop    = kTileIdObjReloaderFirst + 0
kTileIdObjReloaderHopperBottom = kTileIdObjReloaderFirst + 1

;;; The OBJ palette number used for drawing reloader machines.
kPaletteObjReloader = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tick implemention for reloader machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The minimum platform left position for the machine.
.EXPORT FuncA_Machine_Reloader_Tick
.PROC FuncA_Machine_Reloader_Tick
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    bne @done
    jsr FuncA_Machine_ReachedGoal
    @done:
_TickAnimation:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState2_byte_arr, x  ; pickup offset
    beq @done
    dec Ram_MachineState2_byte_arr, x  ; pickup offset
    @done:
    rts
.ENDPROC

;;; Loads the reloader machine with a rocket, plays a sound, sets up its pickup
;;; anmiation, and starts waiting.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_Reloader_PickUpAmmo
.PROC FuncA_Machine_Reloader_PickUpAmmo
    jsr FuncA_Machine_PlaySfxRocketTransfer
    ldx Zp_MachineIndex_u8
    lda #1
    sta Ram_MachineState1_byte_arr, x  ; ammo count
    lda #kBlockHeightPx / kReloaderPickupSpeed
    sta Ram_MachineState2_byte_arr, x  ; pickup offset
    lda #kReloaderActCountdown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a rocket reloader machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawReloaderMachine
.PROC FuncA_Objects_DrawReloaderMachine
_Rocket:
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; ammo count
    beq @done
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile   ; preserves X
    lda Ram_MachineState2_byte_arr, x  ; pickup offset
    mul #kReloaderPickupSpeed
    jsr FuncA_Objects_MoveShapeUpByA
    ldy #kPaletteObjReloader  ; param: object flags
    lda #kTileIdObjReloaderRocketVert  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    @done:
_MainPlatform:
    lda #kPaletteObjReloader  ; param: object flags
    jsr FuncA_Objects_Alloc2x2MachineShape  ; returns C and Y
    bcs _Done
_SetFlags:
    lda #kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
_SetTileIds:
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjReloaderHopperTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjReloaderHopperBottom
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
