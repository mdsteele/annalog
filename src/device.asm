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
.INCLUDE "machine.inc"
.INCLUDE "macros.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_DrawBreakerDoneDevice
.IMPORT FuncA_Objects_DrawBreakerReadyDevice
.IMPORT FuncA_Objects_DrawBreakerRisingDevice
.IMPORT FuncA_Objects_DrawFlowerDevice
.IMPORT FuncA_Objects_DrawLeverCeilingDevice
.IMPORT FuncA_Objects_DrawLeverFloorDevice
.IMPORT FuncA_Objects_DrawLockedDoorDevice
.IMPORT FuncA_Objects_DrawUnlockedDoorDevice
.IMPORT FuncA_Objects_DrawUpgradeDevice
.IMPORT Func_Noop
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

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

;;; The "target" for each device (see sDevice::Target_u8 for details).
.EXPORT Ram_DeviceTarget_u8_arr
Ram_DeviceTarget_u8_arr: .res kMaxDevices

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
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE eDevice
    d_entry table, None,          Func_Noop
    d_entry table, BreakerDone,   FuncA_Objects_DrawBreakerDoneDevice
    d_entry table, BreakerRising, FuncA_Objects_DrawBreakerRisingDevice
    d_entry table, LockedDoor,    FuncA_Objects_DrawLockedDoorDevice
    d_entry table, Placeholder,   Func_Noop
    d_entry table, Teleporter,    Func_Noop
    d_entry table, BreakerReady,  FuncA_Objects_DrawBreakerReadyDevice
    d_entry table, Console,       FuncA_Objects_DrawConsoleDevice
    d_entry table, Flower,        FuncA_Objects_DrawFlowerDevice
    d_entry table, LeverCeiling,  FuncA_Objects_DrawLeverCeilingDevice
    d_entry table, LeverFloor,    FuncA_Objects_DrawLeverFloorDevice
    d_entry table, OpenDoorway,   Func_Noop
    d_entry table, Paper,         FuncA_Objects_DrawPaperDevice
    d_entry table, Sign,          Func_Noop
    d_entry table, TalkLeft,      Func_Noop
    d_entry table, TalkRight,     Func_Noop
    d_entry table, UnlockedDoor,  FuncA_Objects_DrawUnlockedDoorDevice
    d_entry table, Upgrade,       FuncA_Objects_DrawUpgradeDevice
    D_END
.ENDREPEAT
.ENDPROC

;;; Allocates and populates OAM slots for a console device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawConsoleDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_AdjustPosition:
    ;; Adjust X-position for the console screen.
    lda Zp_ShapePosX_i16 + 0
    add #4
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    ;; Adjust Y-position for the console screen.
    inc Zp_ShapePosY_i16 + 0
    bne @noCarry
    inc Zp_ShapePosY_i16 + 1
    @noCarry:
_AllocateObject:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    sty Zp_Tmp1_byte  ; OAM offset
    ;; Determine if the machine has an error.
    ldy Ram_DeviceTarget_u8_arr, x  ; machine index
    lda Ram_MachineStatus_eMachine_arr, y
    ldy Zp_Tmp1_byte  ; OAM offset
    cmp #eMachine::Error
    beq @machineError
    @machineOk:
    lda #kConsoleScreenPaletteOk
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kConsoleScreenTileIdOk
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    rts
    @machineError:
    lda #kConsoleScreenPaletteErr
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kConsoleScreenTileIdErr
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for a paper device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawPaperDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_AdjustPosition:
    lda Zp_ShapePosX_i16 + 0
    add #4
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
_AllocateObject:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kPaperPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kTileIdPaper
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the top-left corner of the specified device.
;;; @param X The device index.
;;; @preserve X, Y, Zp_Tmp*
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
