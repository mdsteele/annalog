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

.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "lever.inc"

.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.IMPORT Func_PlaySfxLeverOff
.IMPORT Func_PlaySfxLeverOn
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing lever handles.
kTileIdObjLeverHandleDown = $04
kTileIdObjLeverHandleUp   = $05

;;; The OBJ palette number used for drawing lever handles.
kPaletteObjLeverHandle = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Toggles a lever device to the other position, changing its state and
;;; initializing its animation.
;;; @param X The device index for the lever.
.EXPORT FuncA_Avatar_ToggleLeverDevice
.PROC FuncA_Avatar_ToggleLeverDevice
    lda #kLeverAnimCountdown
    sta Ram_DeviceAnim_u8_arr, x
    ldy Ram_DeviceTarget_byte_arr, x
    lda Zp_RoomState, y
    beq @setToOne
    @setToZero:
    lda #0
    beq @set  ; unconditional
    @setToOne:
    lda #1
    @set:
    sta Zp_RoomState, y
    jne Func_PlaySfxLeverOn
    jmp Func_PlaySfxLeverOff
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Writes a value to a register that represents a lever.  This should be
;;; called from a machine's WriteReg_func_ptr implementation.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The device index for the lever.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_WriteToLever
.PROC FuncA_Machine_WriteToLever
    sta T0  ; value to write
    ldy Ram_DeviceTarget_byte_arr, x
    lda Zp_RoomState, y
    beq _CurrentlyZero
_CurrentlyNonzero:
    lda T0  ; value to write
    sta Zp_RoomState, y
    bne _NoAnimate
    jsr Func_PlaySfxLeverOff  ; preserves X
_Animate:
    lda #kLeverAnimCountdown  ; param: num frames
    sta Ram_DeviceAnim_u8_arr, x
    jmp FuncA_Machine_StartWaiting
_CurrentlyZero:
    lda T0  ; value to write
    beq _NoAnimate
    sta Zp_RoomState, y
    jsr Func_PlaySfxLeverOff  ; preserves X
    jmp _Animate
_NoAnimate:
    rts
.ENDPROC

;;; Writes a value to a register that represents a lever, where the lever
;;; device isn't actually in this room.  This should be called from a machine's
;;; WriteReg_func_ptr implementation.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The byte offset into Zp_RoomState for the lever's state value.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_WriteToPhantomLever
.PROC FuncA_Machine_WriteToPhantomLever
    sta T0  ; value to write
    lda Zp_RoomState, y
    beq _CurrentlyZero
_CurrentlyNonzero:
    lda T0  ; value to write
    sta Zp_RoomState, y
    bne _NoAnimate
_Animate:
    lda #kLeverAnimCountdown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
_CurrentlyZero:
    lda T0  ; value to write
    sta Zp_RoomState, y
    bne _Animate
_NoAnimate:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Resets the specified lever device to value zero.  This should be called
;;; from a machine's Reset_func_ptr implementation (it can also be called from
;;; a machine's Init_func_ptr implementation, although it isn't generally
;;; necessary).
;;; @param X The device index for the lever.
.EXPORT FuncA_Room_ResetLever
.PROC FuncA_Room_ResetLever
    ldy Ram_DeviceTarget_byte_arr, x
    lda Zp_RoomState, y
    beq @done
    lda #kLeverAnimCountdown  ; param: num frames
    sta Ram_DeviceAnim_u8_arr, x
    lda #0
    sta Zp_RoomState, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a ceiling-mounted lever device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceLeverCeiling
.PROC FuncA_Objects_DrawDeviceLeverCeiling
    ldy #kPaletteObjLeverHandle | bObj::FlipV  ; param: flags
    bne FuncA_Objects_DrawDeviceLever  ; unconditional
.ENDPROC

;;; Draws a floor-mounted lever device.
;;; @param X The device index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawDeviceLeverFloor
.PROC FuncA_Objects_DrawDeviceLeverFloor
    ldy #kPaletteObjLeverHandle  ; param: flags
    fall FuncA_Objects_DrawDeviceLever
.ENDPROC

;;; Draws a lever device.
;;; @param X The device index.
;;; @param Y The base object flags to use (modulo bObj::FlipH).
;;; @preserve X
.PROC FuncA_Objects_DrawDeviceLever
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X and Y
    sty T1  ; object flags
_Animation:
    ;; Compute the animation frame number, storing it in Y.
    lda Ram_DeviceAnim_u8_arr, x
    div #kLeverAnimSlowdown
    sta T0  ; animation delta
    ldy Ram_DeviceTarget_byte_arr, x
    lda Zp_RoomState, y
    bne @leverIsOn
    @leverIsOff:
    lda T0  ; animation delta
    bpl @setAnimFrame  ; unconditional
    @leverIsOn:
    lda #kLeverNumAnimFrames - 1
    sub T0  ; animation delta
    @setAnimFrame:
    sta T0  ; animation frame
_AdjustPosition:
    ;; Adjust X-position for the lever handle.
    cmp #kLeverNumAnimFrames / 2
    blt @leftSide
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and T0+
    @leftSide:
    ;; Adjust Y-position for the lever handle.
    bit T1  ; object flags
    .assert bObj::FlipV = bProc::Negative, error
    bpl @floor
    @ceiling:
    lda #5
    bne @moveDown  ; unconditional
    @floor:
    lda #3
    @moveDown:
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and T0+
_AllocateObject:
    stx T2  ; device index
    ldx T0  ; animation frame
    lda T1  ; object flags
    cpx #kLeverNumAnimFrames / 2
    blt @noFlip
    eor #bObj::FlipH
    @noFlip:
    tay  ; param: object flags
    lda _LeverTileIds_u8_arr, x  ; param: tile ID
    ldx T2  ; device index
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X
_LeverTileIds_u8_arr:
    .byte kTileIdObjLeverHandleDown
    .byte kTileIdObjLeverHandleUp
    .byte kTileIdObjLeverHandleUp
    .byte kTileIdObjLeverHandleDown
    .assert * - _LeverTileIds_u8_arr = kLeverNumAnimFrames, error
.ENDPROC

;;;=========================================================================;;;
