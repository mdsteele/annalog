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

.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_PpuScrollY_u8
.IMPORTZP Zp_ScrollXHi_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp_ptr
.IMPORTZP Zp_WindowTop_u8

;;;=========================================================================;;;

.DEFINE DeviceTypeLabels _DevNone, _DevConsole, _DevSign, _DevLever

;;; The OBJ palette numbers used for console screens.
kConsoleScreenPaletteOk = 1
kConsoleScreenPaletteErr = 0

;;; The OBJ tile IDs used for console screens.
kConsoleScreenTileIdOk = $08
kConsoleScreenTileIdErr = $09

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
;;;   * For levers, this is TODO switch state index?
;;;   * For signs, this is TODO dialogue number?
.EXPORT Ram_DeviceTarget_u8_arr
Ram_DeviceTarget_u8_arr: .res kMaxDevices

;;; TODO: Store other data for each device (e.g. machine number for consoles).

;;;=========================================================================;;;

.SEGMENT "PRG8_Device"

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
    ;; Set object attributes.
    ldy Zp_OamOffset_u8
    lda Zp_Tmp1_byte  ; screen pixel Y-pos
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda Zp_Tmp2_byte  ; screen pixel X-pos
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda #kConsoleScreenPaletteOk
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    lda #kConsoleScreenTileIdOk
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    ;; Update the OAM offset.
    .repeat .sizeof(sObj)
    iny
    .endrepeat
    sty Zp_OamOffset_u8
    @notVisible:
    rts
_DevLever:
    ;; TODO: Draw lever objects.
    rts
.ENDPROC

;;;=========================================================================;;;
