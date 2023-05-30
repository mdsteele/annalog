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

.INCLUDE "../actor.inc"
.INCLUDE "../actors/particle.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../program.inc"
.INCLUDE "launcher.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjRocket
.IMPORT Func_MovePointHorz
.IMPORT Func_MovePointVert
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing launcher machines.
kTileIdObjLauncherHorzTubeFrontEmpty  = kTileIdObjLauncherHorzFirst + 0
kTileIdObjLauncherHorzTubeFrontFull   = kTileIdObjLauncherHorzFirst + 1
kTileIdObjLauncherHorzTubeRear        = kTileIdObjLauncherHorzFirst + 2
kTileIdObjLauncherVertTubeBottomEmpty = kTileIdObjLauncherVertFirst + 0
kTileIdObjLauncherVertTubeBottomFull  = kTileIdObjLauncherVertFirst + 1
kTileIdObjLauncherVertTubeTop         = kTileIdObjLauncherVertFirst + 2

;;; The OBJ palette number used for drawing launcher machines.
kPaletteObjLauncher = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryAct implemention for launcher machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The eDir value for the direction the rocket should fire in.
.EXPORT FuncA_Machine_LauncherTryAct
.PROC FuncA_Machine_LauncherTryAct
    sta T0  ; rocket direction
    ;; If the launcher is out of ammo, fail.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, y  ; ammo count
    beq _Error
_FireRocket:
    ;; Fire a rocket.
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs _Finish
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X and T0+
    ldy T0  ; rocket direction
    lda _HorzAdjust_i8_arr, y  ; param: signed offset
    jsr Func_MovePointHorz  ; preserves X, Y, and T0+
    lda _VertAdjust_i8_arr, y  ; param: signed offset
    jsr Func_MovePointVert  ; preserves X, Y, and T0+
    jsr Func_SetActorCenterToPoint  ; preserves X, Y, and T0+
    tya  ; param: rocket direction
    jsr Func_InitActorProjRocket  ; preserves X
    ;; If debugging, replace the rocket with a smoke particle.  Otherwise,
    ;; decrement the ammo count.
    lda Zp_ConsoleMachineIndex_u8
    bmi _DecrementAmmo
_DryFire:
    lda #kSmokeParticleNumFrames / 3
    sta Ram_ActorState1_byte_arr, x  ; particle age in frames
    lda #eActor::SmokeParticle
    sta Ram_ActorType_eActor_arr, x
    ;; TODO: play a sound?
    .assert eActor::SmokeParticle <> 0, error
    bne _Finish  ; unconditional
_DecrementAmmo:
    ldx Zp_MachineIndex_u8
    dec Ram_MachineParam1_u8_arr, x  ; ammo count
    ;; TODO: play a sound
_Finish:
    lda #kLauncherActFrames  ; param: wait frames
    jmp FuncA_Machine_StartWaiting
_Error:
    jmp FuncA_Machine_Error
_HorzAdjust_i8_arr:
    D_ENUM eDir
    d_byte Up, <-5
    d_byte Down, <-5
    d_byte Left, <-4
    d_byte Right, 4
    D_END
_VertAdjust_i8_arr:
    D_ENUM eDir
    d_byte Up, <-4
    d_byte Down, 4
    d_byte Left, 5
    d_byte Right, 5
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a horizontal rocket launcher machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawLauncherMachineHorz
.PROC FuncA_Objects_DrawLauncherMachineHorz
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    ;; Allocate objects.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    .assert bMachine::FlipH = bObj::FlipH, error
    .assert kPaletteObjLauncher = 0, error
    pha  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; returns C and Y
    pla  ; object flags
    bcs _Done
_SetFlags:
    eor #bObj::FlipH | kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
_SetOtherTileIds:
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjLauncherHorzTubeRear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_SetTubeFrontTileId:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, x
    .assert kTileIdObjLauncherHorzTubeFrontEmpty & $01 = 0, error
    ora #kTileIdObjLauncherHorzTubeFrontEmpty
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;; Draws a vertical rocket launcher machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawLauncherMachineVert
.PROC FuncA_Objects_DrawLauncherMachineVert
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    lda #kPaletteObjLauncher
    jsr FuncA_Objects_Alloc2x2Shape  ; returns C and Y
    bcs _Done
_SetFlags:
    lda #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #bObj::FlipHV | kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
_SetOtherTileIds:
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kTileIdObjLauncherVertTubeTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
_SetTubeBottomTileId:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, x
    .assert kTileIdObjLauncherVertTubeBottomEmpty & $01 = 0, error
    ora #kTileIdObjLauncherVertTubeBottomEmpty
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
