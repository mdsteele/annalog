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
.INCLUDE "cannon.inc"

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitGrenadeActor
.IMPORT Func_MachineFinishResetting
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
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

.SEGMENT "PRG8"

;;; Reads the "Y" register for a cannon machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The value of the machine's "Y" register (0-1).
.EXPORT Func_MachineCannonReadRegY
.PROC Func_MachineCannonReadRegY
    ldy Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, y
    and #$80
    asl a
    rol a
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryMove implemention for cannon machines.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param X The eDir value for the direction to move in.
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.EXPORT FuncA_Machine_CannonTryMove
.PROC FuncA_Machine_CannonTryMove
    txa
    ldx Zp_MachineIndex_u8
    cmp #eDir::Down
    beq @moveDown
    @moveUp:
    ldy Ram_MachineGoalVert_u8_arr, x
    bne @error
    iny
    bne @success  ; unconditional
    @moveDown:
    ldy Ram_MachineGoalVert_u8_arr, x
    beq @error
    dey
    @success:
    tya
    sta Ram_MachineGoalVert_u8_arr, x
    lda #kCannonMoveCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
.ENDPROC

;;; TryAct implemention for cannon machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.EXPORT FuncA_Machine_CannonTryAct
.PROC FuncA_Machine_CannonTryAct
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @doneGrenade
    ;; Get the cannon's platform index, storing it in Y.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay
    ;; Position the new grenade actor:
    lda Ram_PlatformLeft_i16_0_arr, y
    add #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, y
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    lda Ram_PlatformTop_i16_0_arr, y
    add #kTileWidthPx
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, y
    adc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Determine the aim angle.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    beq @noFlip
    lda #$02
    @noFlip:
    ldy Zp_MachineIndex_u8
    ora Ram_MachineGoalVert_u8_arr, y  ; param: aim angle (0-3)
    ;; Initialize the grenade and finish.
    jsr Func_InitGrenadeActor
    @doneGrenade:
    lda #kCannonActCountdown
    clc  ; clear C to indicate success
    rts
.ENDPROC

;;; Tick implemention for cannon machines.
;;; Function to call each frame to update the machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.EXPORT FuncA_Machine_CannonTick
.PROC FuncA_Machine_CannonTick
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    beq @moveDown
    @moveUp:
    lda Ram_MachineParam1_u8_arr, x
    add #$100 / kCannonMoveCountdown
    bcc @setAngle
    lda #$ff
    sta Ram_MachineParam1_u8_arr, x
    jmp Func_MachineFinishResetting
    @moveDown:
    lda Ram_MachineParam1_u8_arr, x
    sub #$100 / kCannonMoveCountdown
    bge @setAngle
    lda #0
    sta Ram_MachineParam1_u8_arr, x
    jmp Func_MachineFinishResetting
    @setAngle:
    sta Ram_MachineParam1_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for cannon machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawCannonMachine
.PROC FuncA_Objects_DrawCannonMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    ;; Allocate objects.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    .assert bMachine::FlipH = bObj::FlipH, error
    .assert kMachineLightPalette <> 0, error
    ora #kMachineLightPalette
    pha  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; returns C and Y
    pla  ; object flags
    bcs _Done
    ora #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
_SetBarrelTileId:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, x  ; aim angle
    cmp #$40
    blt @barrelLow
    cmp #$c0
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
