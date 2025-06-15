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
.INCLUDE "../devices/teleporter.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "field.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_IsFlagSet
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_PlaySfxExplodeSmall
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORTZP Zp_AvatarPosX_i16
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; How many frames it takes for a teleport field machine to charge up for a
;;; teleport.
.DEFINE kFieldFramesPerChargePoint $10
kFieldMaxChargePoints = 9

;;; How many frames a teleport field machine spends per act operation.
kFieldActCooldown = $20

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "P" register for a teleport field machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The value of the machine's "T" register (0-9).
.EXPORT Func_MachineFieldReadRegP
.PROC Func_MachineFieldReadRegP
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; charge frames
    div #kFieldFramesPerChargePoint
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Reset implemention for teleport field machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Room_MachineFieldReset := Func_Noop

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
    jsr Func_PlaySfxExplodeSmall
    lda #kTeleporterAnimPartial
    sta Ram_DeviceAnim_u8_arr + kTeleporterDeviceIndex
    .assert kTeleporterAnimPartial > 0, error
    bne _Cooldown  ; unconditional
_IsCharged:
    jsr Func_PlaySfxExplodeBig
    lda #kTeleportShakeFrames
    jsr Func_ShakeRoom
    lda #kTeleporterAnimFull
    sta Ram_DeviceAnim_u8_arr + kTeleporterDeviceIndex
_TryTeleport:
    ;; Get the platform index for the machine's primary platform.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; param: platform index
    ;; Set Zp_PointY_i16 to the top of the teleport field.
    jsr Func_SetPointToPlatformCenter  ; preserves Y
    .assert kTeleportFieldHeight .mod 2 = 0, error
    lda #kTeleportFieldHeight / 2  ; param: offset
    jsr Func_MovePointUpByA  ; preserves Y
    ;; If the player avatar is above the top of the field, then no teleport
    ;; will occur.
    lda Zp_AvatarPosY_i16 + 0
    cmp Zp_PointY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    sbc Zp_PointY_i16 + 1
    bmi @noTeleport  ; avatar is above top of field
    ;; Move Zp_PointY_i16 to the bottom of the teleport field.
    lda #kTeleportFieldHeight  ; param: offset
    jsr Func_MovePointDownByA  ; preserves Y
    ;; If the player avatar is below the bottom of the field, then no teleport
    ;; will occur.
    lda Zp_PointY_i16 + 0
    cmp Zp_AvatarPosY_i16 + 0
    lda Zp_PointY_i16 + 1
    sbc Zp_AvatarPosY_i16 + 1
    bmi @noTeleport  ; avatar is above top of field
    ;; Check if the player avatar is at or to the right of the left side of the
    ;; field; if not, then no teleport will occur.
    lda Zp_AvatarPosX_i16 + 1
    cmp Ram_PlatformLeft_i16_1_arr, y
    blt @noTeleport
    bne @doneLeft
    lda Zp_AvatarPosX_i16 + 0
    cmp Ram_PlatformLeft_i16_0_arr, y
    blt @noTeleport
    @doneLeft:
    ;; Check if the player avatar is to the left of the right side of the
    ;; field; if not, then no teleport will occur.
    lda Zp_AvatarPosX_i16 + 0
    sub #kTeleportFieldWidth
    sta T0  ; shifted avatar pos X (lo)
    lda Zp_AvatarPosX_i16 + 1
    sbc #0
    cmp Ram_PlatformRight_i16_1_arr, y
    blt @doneRight
    bne @noTeleport
    lda T0  ; shifted avatar pos X (lo)
    cmp Ram_PlatformRight_i16_0_arr, y
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
    ;; If the console window is open, don't charge up.
    ldx Zp_ConsoleMachineIndex_u8
    bpl _Discharge  ; a console window is open
    ;; If the machine's breaker hasn't been activated, don't charge up.
    ldy #sMachine::Breaker_eFlag
    lda (Zp_Current_sMachine_ptr), y
    beq _Charge  ; No breaker flag, so the machine always has power.
    tax  ; param: flag
    jsr Func_IsFlagSet  ; returns Z
    beq _Discharge  ; The breaker isn't activated, so the machine has no power.
_Charge:
    ;; Charge by one point per frame.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; charge frames
    cmp #kFieldMaxChargePoints * kFieldFramesPerChargePoint
    bge _Finish  ; max charge has been reached
    inc Ram_MachineState1_byte_arr, x  ; charge frames
    bne _Finish  ; unconditional
_Discharge:
    ;; Discharge by two points per frame.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; charge frames
    beq _Finish  ; fully discharged
    dec Ram_MachineState1_byte_arr, x  ; charge frames
    beq _Finish  ; fully discharged
    dec Ram_MachineState1_byte_arr, x  ; charge frames
_Finish:
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a teleport field machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawFieldMachine
.PROC FuncA_Objects_DrawFieldMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A (param: tile ID)
    ldy #kPaletteObjMachineLight  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;;=========================================================================;;;
