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

.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_SetUpgradeFlagsAndTileIds
.IMPORT Func_Noop
.IMPORT Ram_MachineState
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_ScrollXHi_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

FuncA_Objects_DrawNoneDevice = Func_Noop
FuncA_Objects_DrawDoorDevice = Func_Noop
FuncA_Objects_DrawSignDevice = Func_Noop

.LINECONT +
.DEFINE DeviceDrawFuncs \
    FuncA_Objects_DrawNoneDevice, \
    FuncA_Objects_DrawConsoleDevice, \
    FuncA_Objects_DrawDoorDevice, \
    FuncA_Objects_DrawLeverDevice, \
    FuncA_Objects_DrawSignDevice, \
    FuncA_Objects_DrawUpgradeDevice
.LINECONT -

;;; The OBJ palette numbers used for various device objects.
kConsoleScreenPaletteOk  = 2
kConsoleScreenPaletteErr = 1
kLeverHandlePalette      = 0

;;; The number of animation frames a lever device has (i.e. the number of
;;; distinct ways of drawing it).
kLeverNumAnimFrames = 4
;;; The number of VBlank frames per lever animation frame.
.DEFINE kLeverAnimSlowdown 4
;;; The number of VBlank frames for a complete lever animation (i.e. the value
;;; to store in Ram_DeviceAnim_u8_arr when the lever is flipped).
kLeverAnimCountdown = kLeverNumAnimFrames * kLeverAnimSlowdown - 1

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

;;; Toggles a lever device to the other position, changing its state and
;;; initializing its animation.
;;; @param X The device index for the lever.
.EXPORT Func_ToggleLeverDevice
.PROC Func_ToggleLeverDevice
    lda #kLeverAnimCountdown
    sta Ram_DeviceAnim_u8_arr, x
    lda Ram_DeviceTarget_u8_arr, x
    tay
    lda Ram_MachineState, y
    eor #$01
    sta Ram_MachineState, y
    rts
.ENDPROC

;;; Decrements the animation counter for each device in the room (if that
;;; counter is nonzero; otherwise, leaves it at zero).
.EXPORT Func_TickAllDevices
.PROC Func_TickAllDevices
    ldx #kMaxDevices - 1
    @loop:
    lda Ram_DeviceAnim_u8_arr, x
    beq @continue
    dec Ram_DeviceAnim_u8_arr, x
    @continue:
    dex
    bpl @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for all devices in the room.
.EXPORT FuncA_Objects_DrawAllDevices
.PROC FuncA_Objects_DrawAllDevices
    ldx #kMaxDevices - 1
    @loop:
    jsr FuncA_Objects_DrawOneDevice  ; preserves X
    dex
    bpl @loop
    rts
.ENDPROC

;;; Allocates and populates OAM slots (if any) for one device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawOneDevice
    lda Ram_DeviceType_eDevice_arr, x
    tay
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
    ;; Compute the room pixel Y-position of the top of the console, storing the
    ;; hi byte in Zp_Tmp2_byte and the lo byte in A.
    lda #0
    sta Zp_Tmp2_byte
    lda Ram_DeviceBlockRow_u8_arr, x
    .assert kTallRoomHeightBlocks <= $20, error
    asl a  ; Since kTallRoomHeightBlocks <= $20, the device block row fits in
    asl a  ; five bits, so the first three ASL's won't set the carry bit, so
    asl a  ; we only need to ROL Zp_Tmp2_byte after the fourth ASL.
    asl a
    rol Zp_Tmp2_byte
    ;; Compute the screen pixel Y-position of the top of the console, storing
    ;; it in Zp_Tmp1_byte.
    sub Zp_PpuScrollY_u8
    sta Zp_Tmp1_byte  ; screen pixel Y-pos
    lda Zp_Tmp2_byte
    sbc #0
    bne @notVisible
    ;; Check if the object is below the screen/window.
    lda Zp_Tmp1_byte  ; screen pixel Y-pos
    cmp #kScreenHeightPx
    bge @notVisible
    cmp Zp_WindowTop_u8
    bge @notVisible
    ;; Compute the room pixel X-position of the left side of the console,
    ;; storing the hi byte in Zp_Tmp3_byte and the lo byte in A.
    lda #0
    sta Zp_Tmp3_byte
    lda Ram_DeviceBlockCol_u8_arr, x
    .assert kMaxRoomWidthBlocks <= $80, error
    asl a      ; Since kMaxRoomWidthBlocks <= $80, the device block col fits in
    .repeat 3  ; seven bits, so the first ASL won't set the carry bit, so we
    asl a      ; only need to ROL Zp_Tmp3_byte starting after the second ASL.
    rol Zp_Tmp3_byte
    .endrepeat
    ;; Compute the room pixel X-position of the left side of the console
    ;; screen, storing the hi byte in Zp_Tmp3_byte and the lo byte in
    ;; Zp_Tmp2_byte.
    add #4
    sta Zp_Tmp2_byte  ; room pixel X-pos (lo)
    lda Zp_Tmp3_byte
    adc #0
    sta Zp_Tmp3_byte  ; room pixel X-pos (hi)
    ;; Compute the screen pixel X-position of the left side of the console
    ;; screen, storing it in Zp_Tmp2_byte.
    lda Zp_Tmp2_byte  ; room pixel X-pos (lo)
    sub Zp_PpuScrollX_u8
    sta Zp_Tmp2_byte  ; screen pixel X-pos
    lda Zp_Tmp3_byte  ; room pixel X-pos (hi)
    sbc Zp_ScrollXHi_u8
    bne @notVisible
    ;; Determine if the machine has an error.
    lda Ram_DeviceTarget_u8_arr, x
    tay  ; machine index
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Error
    beq @machineError
    lda #kConsoleScreenPaletteOk
    sta Zp_Tmp3_byte  ; object flags
    lda #kConsoleScreenTileIdOk
    sta Zp_Tmp4_byte  ; tile ID
    .assert kConsoleScreenTileIdOk > 0, error
    bne @setAttrs  ; unconditional
    @machineError:
    lda #kConsoleScreenPaletteErr
    sta Zp_Tmp3_byte  ; object flags
    lda #kConsoleScreenTileIdErr
    sta Zp_Tmp4_byte  ; tile ID
    ;; Set object attributes.
    @setAttrs:
    ldy Zp_OamOffset_u8
    lda Zp_Tmp1_byte  ; screen pixel Y-pos
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda Zp_Tmp2_byte  ; screen pixel X-pos
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda Zp_Tmp3_byte  ; object flags
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda Zp_Tmp4_byte  ; tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Update the OAM offset.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    sty Zp_OamOffset_u8
    @notVisible:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for a lever device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawLeverDevice
    ;; Compute the animation frame number, storing it in Zp_Tmp4_byte.
    lda Ram_DeviceAnim_u8_arr, x
    div #kLeverAnimSlowdown
    sta Zp_Tmp4_byte  ; animation delta
    lda Ram_DeviceTarget_u8_arr, x
    tay
    lda Ram_MachineState, y
    bne @leverIsOn
    @leverIsOff:
    lda Zp_Tmp4_byte  ; animation delta
    bpl @setAnimFrame  ; unconditional
    @leverIsOn:
    lda #kLeverNumAnimFrames - 1
    sub Zp_Tmp4_byte  ; animation delta
    @setAnimFrame:
    sta Zp_Tmp4_byte  ; animation frame
    ;; Compute the room pixel Y-position of the top of the lever, storing the
    ;; hi byte in Zp_Tmp2_byte and the lo byte in A.
    lda #0
    sta Zp_Tmp2_byte
    lda Ram_DeviceBlockRow_u8_arr, x
    .assert kTallRoomHeightBlocks <= $20, error
    asl a  ; Since kTallRoomHeightBlocks <= $20, the device block row fits in
    asl a  ; five bits, so the first three ASL's won't set the carry bit, so
    asl a  ; we only need to ROL Zp_Tmp2_byte after the fourth ASL.
    asl a
    rol Zp_Tmp2_byte
    ;; Compute the room pixel Y-position of the top of the lever handle,
    ;; storing the hi byte in Zp_Tmp2_byte and the lo byte in Zp_Tmp1_byte.
    add #2
    sta Zp_Tmp1_byte
    lda Zp_Tmp2_byte
    adc #0
    sta Zp_Tmp2_byte
    ;; Compute the screen pixel Y-position of the top of the lever handle,
    ;; storing it in Zp_Tmp1_byte.
    lda Zp_Tmp1_byte
    sub Zp_PpuScrollY_u8
    sta Zp_Tmp1_byte  ; screen pixel Y-pos
    lda Zp_Tmp2_byte
    sbc #0
    bne @notVisible
    ;; Check if the object is below the screen/window.
    lda Zp_Tmp1_byte  ; screen pixel Y-pos
    cmp #kScreenHeightPx
    bge @notVisible
    cmp Zp_WindowTop_u8
    bge @notVisible
    ;; Compute the room pixel X-position of the left side of the lever,
    ;; storing the hi byte in Zp_Tmp3_byte and the lo byte in A.
    lda #0
    sta Zp_Tmp3_byte
    lda Ram_DeviceBlockCol_u8_arr, x
    .assert kMaxRoomWidthBlocks <= $80, error
    asl a      ; Since kMaxRoomWidthBlocks <= $80, the device block col fits in
    .repeat 3  ; seven bits, so the first ASL won't set the carry bit, so we
    asl a      ; only need to ROL Zp_Tmp3_byte starting after the second ASL.
    rol Zp_Tmp3_byte
    .endrepeat
    ;; Compute the room pixel X-position of the left side of the lever handle,
    ;; storing the hi byte in Zp_Tmp3_byte and the lo byte in Zp_Tmp2_byte.
    ldy Zp_Tmp4_byte  ; animation frame
    cpy #kLeverNumAnimFrames / 2
    bge @rightSide
    @leftSide:
    sta Zp_Tmp2_byte  ; room pixel X-pos (lo)
    jmp @sideDone
    @rightSide:
    add #kTileWidthPx
    sta Zp_Tmp2_byte  ; room pixel X-pos (lo)
    lda Zp_Tmp3_byte
    adc #0
    sta Zp_Tmp3_byte  ; room pixel X-pos (hi)
    @sideDone:
    ;; Compute the screen pixel X-position of the left side of the lever
    ;; handle, storing it in Zp_Tmp2_byte.
    lda Zp_Tmp2_byte  ; room pixel X-pos (lo)
    sub Zp_PpuScrollX_u8
    sta Zp_Tmp2_byte  ; screen pixel X-pos
    lda Zp_Tmp3_byte  ; room pixel X-pos (hi)
    sbc Zp_ScrollXHi_u8
    bne @notVisible
    ;; Set object attributes.
    stx Zp_Tmp3_byte  ; device index
    ldx Zp_Tmp4_byte  ; animation frame
    ldy Zp_OamOffset_u8
    lda Zp_Tmp1_byte  ; screen pixel Y-pos
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda Zp_Tmp2_byte  ; screen pixel X-pos
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda #kLeverHandlePalette
    cpx #2
    blt @noFlip
    ora #bObj::FlipH
    @noFlip:
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda _LeverTileIds_u8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ldx Zp_Tmp3_byte  ; device index
    ;; Update the OAM offset.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    sty Zp_OamOffset_u8
    @notVisible:
    rts
_LeverTileIds_u8_arr:
    .byte kLeverHandleTileIdDown
    .byte kLeverHandleTileIdUp
    .byte kLeverHandleTileIdUp
    .byte kLeverHandleTileIdDown
    .assert * - _LeverTileIds_u8_arr = kLeverNumAnimFrames, error
.ENDPROC

;;; Allocates and populates OAM slots for an upgrade device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawUpgradeDevice
    ;; Compute the room pixel Y-position of the top of the upgrade device,
    ;; storing the hi byte in Zp_Tmp1_byte and the lo byte in A.
    lda #0
    sta Zp_Tmp1_byte
    lda Ram_DeviceBlockRow_u8_arr, x
    .assert kTallRoomHeightBlocks <= $20, error
    asl a  ; Since kTallRoomHeightBlocks <= $20, the device block row fits in
    asl a  ; five bits, so the first three ASL's won't set the carry bit, so
    asl a  ; we only need to ROL Zp_Tmp1_byte after the fourth ASL.
    asl a
    rol Zp_Tmp1_byte
    ;; Compute the room pixel Y-position of the center of the upgrade shape,
    ;; storing the hi byte in Zp_Tmp1_byte and the lo byte in Zp_Tmp2_byte.
    ldy Ram_DeviceAnim_u8_arr, x
    add _YOffsets_u8_arr, y
    sta Zp_Tmp2_byte  ; room pixel Y-pos (lo)
    lda Zp_Tmp1_byte
    adc #0
    sta Zp_Tmp1_byte  ; room pixel Y-pos (hi)
    ;; Compute the screen pixel Y-position of the center of the upgrade shape,
    ;; storing it in Zp_ShapePosY_i16.
    lda Zp_Tmp2_byte  ; room pixel Y-pos (lo)
    sub Zp_PpuScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Zp_Tmp1_byte  ; room pixel Y-pos (hi)
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Compute the room pixel X-position of the left side of the upgrade,
    ;; storing the hi byte in Zp_Tmp1_byte and the lo byte in A.
    lda #0
    sta Zp_Tmp1_byte  ; room pixel X-pos (hi)
    lda Ram_DeviceBlockCol_u8_arr, x
    .assert kMaxRoomWidthBlocks <= $80, error
    asl a      ; Since kMaxRoomWidthBlocks <= $80, the device block col fits in
    .repeat 3  ; seven bits, so the first ASL won't set the carry bit, so we
    asl a      ; only need to ROL Zp_Tmp1_byte starting after the second ASL.
    rol Zp_Tmp1_byte
    .endrepeat
    ;; Compute the room pixel X-position of the center of the upgrade, storing
    ;; the hi byte in Zp_Tmp1_byte and the lo byte in Zp_Tmp2_byte.
    add #kTileWidthPx
    sta Zp_Tmp2_byte  ; room pixel X-pos (lo)
    lda Zp_Tmp1_byte
    adc #0
    sta Zp_Tmp1_byte  ; room pixel X-pos (hi)
    ;; Compute the screen pixel X-position of the center of the upgrade,
    ;; storing it in Zp_ShapePosX_i16.
    lda Zp_Tmp2_byte  ; room pixel X-pos (lo)
    sub Zp_PpuScrollX_u8
    sta Zp_ShapePosX_i16 + 0
    lda Zp_Tmp1_byte  ; room pixel X-pos (hi)
    sbc Zp_ScrollXHi_u8
    sta Zp_ShapePosX_i16 + 1
    ;; Allocate objects.
    txa
    pha
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    pla
    tax
    bcc @onscreen
    rts
    @onscreen:
    ;; Set flags and tile IDs.
    lda Ram_DeviceTarget_u8_arr, x  ; param: eFlag value
    jmp FuncA_Objects_SetUpgradeFlagsAndTileIds  ; preserves X
_YOffsets_u8_arr:
    ;; [12 - int(round(40 * x * (1-x))) for x in (y/24. for y in range(24))]
    .byte 12, 10, 9, 8, 6, 5, 4, 4, 3, 3, 2, 2
    .byte 2, 2, 2, 3, 3, 4, 4, 5, 6, 8, 9, 10
    .assert * - _YOffsets_u8_arr = kUpgradeDeviceAnimStart + 1, error
.ENDPROC

;;;=========================================================================;;;
