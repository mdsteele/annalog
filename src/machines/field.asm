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

.INCLUDE "../cutscene.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "field.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_Next_eCutscene

;;;=========================================================================;;;

;;; How many frames it takes for a teleport field machine to charge up for a
;;; teleport.
.DEFINE kFieldFramesPerChargePoint $10
kFieldMaxChargePoints = 9

;;; How many frames a teleport field machine spends per act operation.
kFieldActCooldown = $20

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "T" register for a teleport field machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The value of the machine's "T" register (0-9).
.EXPORT Func_MachineFieldReadRegT
.PROC Func_MachineFieldReadRegT
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; charge frames
    div #kFieldFramesPerChargePoint
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Reset implemention for teleport field machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Room_MachineFieldReset
.PROC FuncA_Room_MachineFieldReset
    ldx Zp_MachineIndex_u8
    lda #0
    sta Ram_MachineState1_byte_arr, x  ; charge frames
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryAct implemention for teleport field machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.EXPORT FuncA_Machine_FieldTryAct
.PROC FuncA_Machine_FieldTryAct
    ;; Check if the machine is fully charged; if not, then no teleport will
    ;; occur.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; charge frames
    cmp #kFieldMaxChargePoints * kFieldFramesPerChargePoint
    bge _IsCharged
_NotCharged:
    ;; TODO: small smoke puff
    jmp _Cooldown
_IsCharged:
    ;; TODO: large smoke puff
_TryTeleport:
    ;; Get the platform index for the machine's primary platform.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tax
    ;; Check if the player avatar is at or below the top of the field; if not,
    ;; then no teleport will occur.
    lda Zp_AvatarPosY_i16 + 1
    cmp Ram_PlatformTop_i16_1_arr, x
    blt @noTeleport
    bne @doneTop
    lda Zp_AvatarPosY_i16 + 0
    cmp Ram_PlatformTop_i16_0_arr, x
    blt @noTeleport
    @doneTop:
    ;; Check if the player avatar is above the bottom of the field; if not,
    ;; then no teleport will occur.
    lda Zp_AvatarPosY_i16 + 1
    cmp Ram_PlatformBottom_i16_1_arr, x
    blt @doneBottom
    bne @noTeleport
    lda Zp_AvatarPosY_i16 + 0
    cmp Ram_PlatformBottom_i16_0_arr, x
    bge @noTeleport
    @doneBottom:
    ;; Check if the player avatar is at or to the right of the left side of the
    ;; field; if not, then no teleport will occur.
    lda Zp_AvatarPosX_i16 + 1
    cmp Ram_PlatformLeft_i16_1_arr, x
    blt @noTeleport
    bne @doneLeft
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_PlatformLeft_i16_0_arr, x
    blt @noTeleport
    @doneLeft:
    ;; Check if the player avatar is to the left of the right side of the
    ;; field; if not, then no teleport will occur.
    lda Zp_AvatarPosX_i16 + 0
    sub #kTeleportFieldWidth
    sta T0  ; shifted avatar pos X (lo)
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    cmp Ram_PlatformRight_i16_1_arr, x
    blt @doneRight
    bne @noTeleport
    lda T0  ; shifted avatar pos X (lo)
    cmp Ram_PlatformRight_i16_0_arr, x
    bge @noTeleport
    @doneRight:
    ;; Teleport the avatar.
    lda #eCutscene::SharedTeleportOut
    sta Zp_Next_eCutscene
    @noTeleport:
_Cooldown:
    ldx Zp_MachineIndex_u8
    lda #0
    sta Ram_MachineState1_byte_arr, x  ; charge frames
    lda #kFieldActCooldown
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;; Tick implemention for teleport field machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT FuncA_Machine_FieldTick
.PROC FuncA_Machine_FieldTick
    ;; TODO: don't charge if console is open
    ;; TODO: don't charge if machine's breaker isn't activated
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; charge frames
    cmp #kFieldMaxChargePoints * kFieldFramesPerChargePoint
    bge @done
    inc Ram_MachineState1_byte_arr, x  ; charge frames
    @done:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a teleport field machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawFieldMachine
.PROC FuncA_Objects_DrawFieldMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_Light:
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @done
    lda #kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_BottomLeftCorner:
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @done
    lda #bObj::FlipH | kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_BottomRightCorner:
    lda #kFieldMachineWidth + kTeleportFieldWidth + kTileWidthPx
    jsr FuncA_Objects_MoveShapeRightByA
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @done
    lda #kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_TopRightCorner:
    jsr FuncA_Objects_MoveShapeUpOneTile
    jsr FuncA_Objects_Alloc1x1Shape  ; returns C and Y
    bcs @done
    lda #bObj::FlipV | kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_Zap:
    ;; TODO: draw teleportation effect
    rts
.ENDPROC

;;;=========================================================================;;;
