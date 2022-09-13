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
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_DrawBreakerDoneDevice
.IMPORT FuncA_Objects_DrawBreakerReadyDevice
.IMPORT FuncA_Objects_DrawBreakerRisingDevice
.IMPORT FuncA_Objects_DrawFlowerDevice
.IMPORT FuncA_Objects_DrawLeverDevice
.IMPORT FuncA_Objects_DrawLockedDoorDevice
.IMPORT FuncA_Objects_DrawUnlockedDoorDevice
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetUpgradeTileIds
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

FuncA_Objects_DrawNoneDevice        = Func_Noop
FuncA_Objects_DrawOpenDoorwayDevice = Func_Noop
FuncA_Objects_DrawPlaceholderDevice = Func_Noop
FuncA_Objects_DrawSignDevice        = Func_Noop
FuncA_Objects_DrawTalkLeftDevice    = Func_Noop
FuncA_Objects_DrawTalkRightDevice   = Func_Noop
FuncA_Objects_DrawTeleporterDevice  = Func_Noop

.LINECONT +
.DEFINE DeviceDrawFuncs \
    FuncA_Objects_DrawNoneDevice, \
    FuncA_Objects_DrawBreakerDoneDevice, \
    FuncA_Objects_DrawBreakerRisingDevice, \
    FuncA_Objects_DrawLockedDoorDevice, \
    FuncA_Objects_DrawPlaceholderDevice, \
    FuncA_Objects_DrawTeleporterDevice, \
    FuncA_Objects_DrawBreakerReadyDevice, \
    FuncA_Objects_DrawConsoleDevice, \
    FuncA_Objects_DrawFlowerDevice, \
    FuncA_Objects_DrawLeverDevice, \
    FuncA_Objects_DrawOpenDoorwayDevice, \
    FuncA_Objects_DrawPaperDevice, \
    FuncA_Objects_DrawSignDevice, \
    FuncA_Objects_DrawTalkLeftDevice, \
    FuncA_Objects_DrawTalkRightDevice, \
    FuncA_Objects_DrawUnlockedDoorDevice, \
    FuncA_Objects_DrawUpgradeDevice
.LINECONT -
.ASSERT .tcount({DeviceDrawFuncs}) = eDevice::NUM_VALUES * 2 - 1, error

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
_JumpTable_ptr_0_arr: .lobytes DeviceDrawFuncs
_JumpTable_ptr_1_arr: .hibytes DeviceDrawFuncs
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

;;; Allocates and populates OAM slots for an upgrade device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawUpgradeDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_AdjustPosition:
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X
    ldy Ram_DeviceAnim_u8_arr, x
    lda Zp_ShapePosY_i16 + 0
    add _YOffsets_u8_arr, y
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #0
    sta Zp_ShapePosY_i16 + 1
_AllocateObjects:
    lda #kUpgradePalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda Ram_DeviceTarget_u8_arr, x  ; param: eFlag value
    jmp FuncA_Objects_SetUpgradeTileIds  ; preserves X
    @done:
    rts
_YOffsets_u8_arr:
    ;; [12 - int(round(40 * x * (1-x))) for x in (y/24. for y in range(24))]
    .byte 12, 10, 9, 8, 6, 5, 4, 4, 3, 3, 2, 2
    .byte 2, 2, 2, 3, 3, 4, 4, 5, 6, 8, 9, 10
    .assert * - _YOffsets_u8_arr = kUpgradeDeviceAnimStart + 1, error
.ENDPROC

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the top-left corner of the specified device.
;;; @param X The device index.
;;; @preserve X, Y
.EXPORT FuncA_Objects_SetShapePosToDeviceTopLeft
.PROC FuncA_Objects_SetShapePosToDeviceTopLeft
    ;; Compute the room pixel Y-position of the top of the device, storing the
    ;; hi byte in Zp_ShapePosY_i16 + 1 and the lo byte in A.
    lda #0
    sta Zp_ShapePosY_i16 + 1
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
    lda #0
    sta Zp_ShapePosX_i16 + 1
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
