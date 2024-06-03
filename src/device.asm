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

.INCLUDE "device.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Objects_DrawDeviceBreakerDone
.IMPORT FuncA_Objects_DrawDeviceBreakerReady
.IMPORT FuncA_Objects_DrawDeviceBreakerRising
.IMPORT FuncA_Objects_DrawDeviceConsole
.IMPORT FuncA_Objects_DrawDeviceFakeConsole
.IMPORT FuncA_Objects_DrawDeviceFlower
.IMPORT FuncA_Objects_DrawDeviceLeverCeiling
.IMPORT FuncA_Objects_DrawDeviceLeverFloor
.IMPORT FuncA_Objects_DrawDeviceLockedDoor
.IMPORT FuncA_Objects_DrawDevicePaper
.IMPORT FuncA_Objects_DrawDeviceScreen
.IMPORT FuncA_Objects_DrawDeviceTeleporter
.IMPORT FuncA_Objects_DrawDeviceUnlockedDoor
.IMPORT FuncA_Objects_DrawDeviceUpgrade
.IMPORT Func_Noop
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

.SEGMENT "RAM_Device"

;;; The type for each device in the room (or eDevice::None for an empty slot).
.EXPORT Ram_DeviceType_eDevice_arr
Ram_DeviceType_eDevice_arr: .res kMaxDevices

;;; The room block row for each device.
.EXPORT Ram_DeviceBlockRow_u8_arr
Ram_DeviceBlockRow_u8_arr: .res kMaxDevices

;;; The room block column for each device.
.EXPORT Ram_DeviceBlockCol_u8_arr
Ram_DeviceBlockCol_u8_arr: .res kMaxDevices

;;; The "target" for each device (see sDevice::Target_byte for details).
.EXPORT Ram_DeviceTarget_byte_arr
Ram_DeviceTarget_byte_arr: .res kMaxDevices

;;; An animation counter for each device (not used by all device types).
.EXPORT Ram_DeviceAnim_u8_arr
Ram_DeviceAnim_u8_arr: .res kMaxDevices

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Decrements the animation counter for each device in the room (if that
;;; counter is nonzero; otherwise, leaves it at zero).
.EXPORT Func_TickAllDevices
.PROC Func_TickAllDevices
    ldx #kMaxDevices - 1
_Loop:
    ;; If the animation counter is nonzero, decrement it.
    lda Ram_DeviceAnim_u8_arr, x
    beq _Continue
    dec Ram_DeviceAnim_u8_arr, x
    bne _Continue
    ;; When a BreakerRising device's animation counter reaches zero, it
    ;; automatically turns into a BreakerReady device.
    lda Ram_DeviceType_eDevice_arr, x
    cmp #eDevice::BreakerRising
    bne _Continue
    lda #eDevice::BreakerReady
    sta Ram_DeviceType_eDevice_arr, x
_Continue:
    dex
    bpl _Loop
    rts
.ENDPROC

;;; Returns the index of the device whose block the point stored in
;;; Zp_PointX_i16 and Zp_PointY_i16 is in, if any.
;;; @return N Set if there was no device nearby, cleared otherwise.
;;; @return Y The device index of the nearby device, or $ff for none.
;;; @preserve X, T2+
.EXPORT Func_FindDeviceNearPoint
.PROC Func_FindDeviceNearPoint
    ;; Calculate the point's room block row and store it in T0.
    lda Zp_PointY_i16 + 0
    sta T0
    lda Zp_PointY_i16 + 1
    .assert kBlockHeightPx = 1 << 4, error
    .repeat 4
    lsr a
    ror T0
    .endrepeat
    ;; Calculate the point's room block column and store it in T1.
    lda Zp_PointX_i16 + 0
    sta T1
    lda Zp_PointX_i16 + 1
    .assert kBlockWidthPx = 1 << 4, error
    .repeat 4
    lsr a
    ror T1
    .endrepeat
    ;; Find a device in the same room block row/col.
    ldy #kMaxDevices - 1
    @loop:
    lda Ram_DeviceType_eDevice_arr, y
    .assert eDevice::None = 0, error
    beq @continue
    lda Ram_DeviceBlockRow_u8_arr, y
    cmp T0  ; point block row
    bne @continue
    lda Ram_DeviceBlockCol_u8_arr, y
    cmp T1  ; point block col
    beq @done
    @continue:
    dey
    bpl @loop
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws all devices in the room.
.EXPORT FuncA_Objects_DrawAllDevices
.PROC FuncA_Objects_DrawAllDevices
    ldx #kMaxDevices - 1
    @loop:
    jsr FuncA_Objects_DrawOneDevice  ; preserves X
    dex
    bpl @loop
    rts
.ENDPROC

;;; Draws one device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawOneDevice
    ldy Ram_DeviceType_eDevice_arr, x
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eDevice
    d_entry table, None,          Func_Noop
    d_entry table, Boiler,        Func_Noop
    d_entry table, BreakerDone,   FuncA_Objects_DrawDeviceBreakerDone
    d_entry table, BreakerRising, FuncA_Objects_DrawDeviceBreakerRising
    d_entry table, Door1Locked,   FuncA_Objects_DrawDeviceLockedDoor
    d_entry table, FlowerInert,   FuncA_Objects_DrawDeviceFlower
    d_entry table, Mousehole,     Func_Noop
    d_entry table, Placeholder,   Func_Noop
    d_entry table, Teleporter,    FuncA_Objects_DrawDeviceTeleporter
    d_entry table, BreakerReady,  FuncA_Objects_DrawDeviceBreakerReady
    d_entry table, Console,       FuncA_Objects_DrawDeviceConsole
    d_entry table, Door1Open,     Func_Noop
    d_entry table, Door1Unlocked, FuncA_Objects_DrawDeviceUnlockedDoor
    d_entry table, Door2Open,     Func_Noop
    d_entry table, Door3Open,     Func_Noop
    d_entry table, FakeConsole,   FuncA_Objects_DrawDeviceFakeConsole
    d_entry table, Flower,        FuncA_Objects_DrawDeviceFlower
    d_entry table, LeverCeiling,  FuncA_Objects_DrawDeviceLeverCeiling
    d_entry table, LeverFloor,    FuncA_Objects_DrawDeviceLeverFloor
    d_entry table, Paper,         FuncA_Objects_DrawDevicePaper
    d_entry table, Screen,        FuncA_Objects_DrawDeviceScreen
    d_entry table, Sign,          Func_Noop
    d_entry table, TalkLeft,      Func_Noop
    d_entry table, TalkRight,     Func_Noop
    d_entry table, Upgrade,       FuncA_Objects_DrawDeviceUpgrade
    D_END
.ENDREPEAT
.ENDPROC

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the top-left corner of the specified device.
;;; @param X The device index.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.PROC FuncA_Objects_SetShapePosToDeviceTopLeft
    lda #0
    sta Zp_ShapePosX_i16 + 1
    sta Zp_ShapePosY_i16 + 1
    ;; Compute the room pixel Y-position of the top of the device, storing the
    ;; hi byte in Zp_ShapePosY_i16 + 1 and the lo byte in A.
    lda Ram_DeviceBlockRow_u8_arr, x
    .assert kTallRoomHeightBlocks <= $20, error
    asl a  ; Since kTallRoomHeightBlocks <= $20, the device block row fits in
    asl a  ; five bits, so the first three ASL's won't set the carry bit, so
    asl a  ; we only need to ROL Zp_ShapePosY_i16 + 1 after the fourth ASL.
    asl a
    rol Zp_ShapePosY_i16 + 1
    ;; Compute the screen pixel Y-position of the top of the device, storing
    ;; it in Zp_ShapePosY_i16.
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Compute the room pixel X-position of the left side of the device,
    ;; storing the hi byte in Zp_ShapePosX_i16 + 1 and the lo byte in A.
    lda Ram_DeviceBlockCol_u8_arr, x
    .assert kMaxRoomWidthBlocks <= $80, error
    asl a      ; Since kMaxRoomWidthBlocks <= $80, the device block col fits in
    .repeat 3  ; seven bits, so the first ASL won't set the carry bit, so we
    asl a      ; only need to ROL Zp_ShapePosX_i16 + 1 after the second ASL.
    rol Zp_ShapePosX_i16 + 1
    .endrepeat
    ;; Compute the screen pixel X-position of the left side of the device,
    ;; storing it in Zp_ShapePosX_i16.
    sub Zp_RoomScrollX_u16 + 0
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    sbc Zp_RoomScrollX_u16 + 1
    sta Zp_ShapePosX_i16 + 1
    rts
.ENDPROC

;;;=========================================================================;;;
