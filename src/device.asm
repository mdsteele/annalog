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

.IMPORT Ram_MachineState
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_ScrollXHi_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.DEFINE DeviceTypeLabels _DevNone, _DevConsole, _DevLever, _DevSign

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

;;; The "target" for each device, whose meaning depends on the device type:
;;;   * For consoles, this is the machine index.
;;;   * For levers, this is the byte offset into Ram_MachineState for the
;;;     lever's state value (0 or 1).
;;;   * For signs, this is TODO dialogue number?
.EXPORT Ram_DeviceTarget_u8_arr
Ram_DeviceTarget_u8_arr: .res kMaxDevices

;;; An animation counter for each device (not used by all device types).
.EXPORT Ram_DeviceAnim_u8_arr
Ram_DeviceAnim_u8_arr: .res kMaxDevices

;;;=========================================================================;;;

.SEGMENT "PRG8_Device"

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

;;; Allocates and populates OAM slots for all devices in the room.
.EXPORT Func_DrawObjectsForAllDevices
.PROC Func_DrawObjectsForAllDevices
    ldx #kMaxDevices - 1
    @loop:
    jsr Func_DrawObjectsForOneDevice  ; preserves X
    dex
    bpl @loop
    rts
.ENDPROC

;;; Allocates and populates OAM slots (if any) for one device.
;;; @param X The device index.
;;; @preserve X
.PROC Func_DrawObjectsForOneDevice
    lda Ram_DeviceType_eDevice_arr, x
    tay
    lda _JumpTable_ptr_0_arr, y
    sta Zp_Tmp_ptr + 0
    lda _JumpTable_ptr_1_arr, y
    sta Zp_Tmp_ptr + 1
    jmp (Zp_Tmp_ptr)
_JumpTable_ptr_0_arr: .lobytes DeviceTypeLabels
_JumpTable_ptr_1_arr: .hibytes DeviceTypeLabels
_DevNone:
_DevSign:
    rts
_DevConsole:
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
_DevLever:
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
    add #8
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

;;;=========================================================================;;;
