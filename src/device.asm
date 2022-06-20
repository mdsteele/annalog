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
.INCLUDE "mmc3.inc"
.INCLUDE "oam.inc"
.INCLUDE "ppu.inc"
.INCLUDE "room.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetUpgradeTileIds
.IMPORT Func_Noop
.IMPORT Ppu_ChrPlayerFlower
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_RoomState
.IMPORT Sram_CarryingFlower_eFlag
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp_ptr

;;;=========================================================================;;;

FuncA_Objects_DrawNoneDevice = Func_Noop
FuncA_Objects_DrawOpenDoorwayDevice = Func_Noop
FuncA_Objects_DrawSignDevice = Func_Noop

.LINECONT +
.DEFINE DeviceDrawFuncs \
    FuncA_Objects_DrawNoneDevice, \
    FuncA_Objects_DrawLockedDoorDevice, \
    FuncA_Objects_DrawConsoleDevice, \
    FuncA_Objects_DrawFlowerDevice, \
    FuncA_Objects_DrawLeverDevice, \
    FuncA_Objects_DrawOpenDoorwayDevice, \
    FuncA_Objects_DrawSignDevice, \
    FuncA_Objects_DrawUnlockedDoorDevice, \
    FuncA_Objects_DrawUpgradeDevice
.LINECONT -
.ASSERT .tcount({DeviceDrawFuncs}) = eDevice::NUM_VALUES * 2 - 1, error

;;; The number of animation frames a door device has (i.e. the number of
;;; distinct ways of drawing it).
kDoorNumAnimFrames = 6
;;; The number of VBlank frames per door animation frame.
.DEFINE kDoorAnimSlowdown 2
;;; The number of VBlank frames for a complete door animation (i.e. the value
;;; to store in Ram_DeviceAnim_u8_arr when animating the door).
kDoorAnimCountdown = kDoorNumAnimFrames * kDoorAnimSlowdown - 1

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

;;; Locks a door device, if not locked already.
;;; @param X The device index for the (locked or unlocked) door.
.EXPORT Func_LockDoorDevice
.PROC Func_LockDoorDevice
    lda #eDevice::LockedDoor
    cmp Ram_DeviceType_eDevice_arr, x
    beq @done
    sta Ram_DeviceType_eDevice_arr, x
    lda #kDoorAnimCountdown
    sub Ram_DeviceAnim_u8_arr, x
    sta Ram_DeviceAnim_u8_arr, x
    @done:
    rts
.ENDPROC

;;; Unlocks a door device, if not unlocked already.
;;; @param X The device index for the (locked or unlocked) door.
.EXPORT Func_UnlockDoorDevice
.PROC Func_UnlockDoorDevice
    lda #eDevice::UnlockedDoor
    cmp Ram_DeviceType_eDevice_arr, x
    beq @done
    sta Ram_DeviceType_eDevice_arr, x
    lda #kDoorAnimCountdown
    sub Ram_DeviceAnim_u8_arr, x
    sta Ram_DeviceAnim_u8_arr, x
    @done:
    rts
.ENDPROC

;;; Removes a flower device, and marks the player avatar as carrying that
;;; flower.
;;; @param X The device index for the flower.
.EXPORT Func_PickUpFlowerDevice
.PROC Func_PickUpFlowerDevice
    chr10_bank #<.bank(Ppu_ChrPlayerFlower)
    lda Ram_DeviceTarget_u8_arr, x
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Set the currently-carried flower.
    sta Sram_CarryingFlower_eFlag
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Remove flower device.
    lda #eDevice::None
    sta Ram_DeviceType_eDevice_arr, x
    rts
.ENDPROC

;;; Toggles a lever device to the other position, changing its state and
;;; initializing its animation.
;;; @param X The device index for the lever.
.EXPORT Func_ToggleLeverDevice
.PROC Func_ToggleLeverDevice
    lda #kLeverAnimCountdown
    sta Ram_DeviceAnim_u8_arr, x
    lda Ram_DeviceTarget_u8_arr, x
    tay
    lda Ram_RoomState, y
    eor #$01
    sta Ram_RoomState, y
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

;;; Allocates and populates OAM slots for a flower device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawFlowerDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_AdjustPosition:
    ;; Adjust X-position for the flower.
    lda Zp_ShapePosX_i16 + 0
    add #4
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
_AllocateUpperObject:
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kFlowerPaletteTop
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kFlowerTileIdTop
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
_AllocateLowerObject:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kFlowerPaletteBottom
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kFlowerTileIdBottom
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for a lever device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawLeverDevice
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
_Animation:
    ;; Compute the animation frame number, storing it in Y.
    lda Ram_DeviceAnim_u8_arr, x
    div #kLeverAnimSlowdown
    sta Zp_Tmp1_byte  ; animation delta
    ldy Ram_DeviceTarget_u8_arr, x
    lda Ram_RoomState, y
    bne @leverIsOn
    @leverIsOff:
    lda Zp_Tmp1_byte  ; animation delta
    bpl @setAnimFrame  ; unconditional
    @leverIsOn:
    lda #kLeverNumAnimFrames - 1
    sub Zp_Tmp1_byte  ; animation delta
    @setAnimFrame:
    tay  ; animation frame
_AdjustPosition:
    ;; Adjust X-position for the lever handle.
    cpy #kLeverNumAnimFrames / 2
    blt @leftSide
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X and Y
    @leftSide:
    ;; Adjust Y-position for the lever handle.
    lda Zp_ShapePosY_i16 + 0
    add #3
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #0
    sta Zp_ShapePosY_i16 + 1
_AllocateObject:
    tya
    pha  ; animation frame
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    pla  ; animation frame
    bcs @done
    stx Zp_Tmp1_byte  ; device index
    tax  ; animation frame
    lda #kLeverHandlePalette
    cpx #kLeverNumAnimFrames / 2
    blt @noFlip
    ora #bObj::FlipH
    @noFlip:
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda _LeverTileIds_u8_arr, x
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ldx Zp_Tmp1_byte  ; device index
    @done:
    rts
_LeverTileIds_u8_arr:
    .byte kLeverHandleTileIdDown
    .byte kLeverHandleTileIdUp
    .byte kLeverHandleTileIdUp
    .byte kLeverHandleTileIdDown
    .assert * - _LeverTileIds_u8_arr = kLeverNumAnimFrames, error
.ENDPROC

;;; Allocates and populates OAM slots for a locked door device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawLockedDoorDevice
    lda Ram_DeviceAnim_u8_arr, x
    bne FuncA_Objects_DrawDoorDevice  ; preserves X
    rts
.ENDPROC

;;; Allocates and populates OAM slots for an unlocked door device.
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawUnlockedDoorDevice
    lda #kDoorAnimCountdown
    sub Ram_DeviceAnim_u8_arr, x
    .assert * = FuncA_Objects_DrawDoorDevice, error, "fallthrough"
.ENDPROC

;;; Allocates and populates OAM slots for a locked or unlocked door device.
;;; @param A The animation value, from 0 (open) to kDoorAnimCountdown (closed).
;;; @param X The device index.
;;; @preserve X
.PROC FuncA_Objects_DrawDoorDevice
    ;; Calculate the door animation frame, from 0 to kDoorNumAnimFrames - 1.
    div #kDoorAnimSlowdown
    beq _Done
    ;; Start drawing from the bottom of the doorway.
    pha  ; half-tiles
    jsr FuncA_Objects_SetShapePosToDeviceTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    lda Zp_ShapePosX_i16 + 0
    add #kTileWidthPx / 2
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    pla  ; half-tiles
_Loop:
    pha  ; half-tiles
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    pla  ; half-tiles
    pha  ; half-tiles
    cmp #2
    blt @half
    @full:
    lda #kTileIdDoorwayFull
    bne @setTileId  ; unconditional
    @half:
    lda #kTileIdDoorwayHalf
    @setTileId:
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kDoorwayPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    jsr FuncA_Objects_MoveShapeUpOneTile
    pla  ; half-tiles
    sub #2
    blt _Done
    bne _Loop
_Done:
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
