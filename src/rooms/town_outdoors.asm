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

.INCLUDE "../actor.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Outdoors_sTileset
.IMPORT Func_Noop
.IMPORT Int_WindowTopIrq
.IMPORT Ppu_ChrObjTown
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_NextIrq_int_ptr
.IMPORTZP Zp_PpuScrollX_u8
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The dialog index for the sign in this room.
kSignDialogIndex = 0

;;; The room pixel Y-positions for the top and bottom of the treeline.  These
;;; are the breaks between separate parallax scrolling bands.
kTreelineTopY    = $2e
kTreelineBottomY = $62

;;;=========================================================================;;;

.SEGMENT "PRGC_Town"

.EXPORT DataC_Town_Outdoors_sRoom
.PROC DataC_Town_Outdoors_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $500
    d_byte Flags_bRoom, eArea::Town
    d_byte MinimapStartRow_u8, 0
    d_byte MinimapStartCol_u8, 11
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTown)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Town_Outdoors_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Outdoors_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    .linecont +
    d_addr Dialogs_sDialog_ptr_arr_ptr, \
           DataA_Dialog_TownOutdoors_sDialog_ptr_arr
    .linecont -
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, Func_Noop
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/town_outdoors1.room"
    .incbin "out/data/town_outdoors2.room"
    .incbin "out/data/town_outdoors3.room"
    .assert * - :- = 96 * 16, error
_Platforms_sPlatform_arr:
    .byte ePlatform::None
_Actors_sActor_arr:
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 6
    d_byte Target_u8, eRoom::TownHouse1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 13
    d_byte Target_u8, eRoom::TownHouse2
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 24
    d_byte Target_u8, eRoom::TownHouse3
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 32
    d_byte Target_u8, kSignDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 37
    d_byte Target_u8, eRoom::TownHouse4
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 59
    d_byte Target_u8, eRoom::TownHouse5
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 71
    d_byte Target_u8, eRoom::TownHouse6
    D_END
    .byte eDevice::None
.ENDPROC

;;; Draw function for the TownOutdoors room.
.PROC FuncC_Town_Outdoors_DrawRoom
    ;; Fix the horizontal scrolling position for the top of the screen, so that
    ;; the stars and moon don't scroll.
    lda #0
    sta Zp_PpuScrollX_u8
    ;; Compute the IRQ latch value to set between the bottom of the treeline
    ;; and the top of the window (if any), and set that as Param3_byte.
    lda <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    sub #kTreelineBottomY
    add Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param3_byte)  ; window latch
    ;; Set up our own sIrq struct to handle parallax scrolling.
    lda #kTreelineTopY - 1
    sub Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    ldax #Int_TownOutdoorsTreeTopIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    ;; Compute the PPU scroll-X for the treeline (which scrolls horizontally at
    ;; 1/4 speed) and houses (which scroll at full speed), and set those as
    ;; Param1_byte and Param2_byte, respectively.
    lda Zp_RoomScrollX_u16 + 1
    lsr a
    sta Zp_Tmp1_byte
    lda Zp_RoomScrollX_u16 + 0
    sta <(Zp_Buffered_sIrq + sIrq::Param2_byte)  ; houses scroll-X
    ror a
    lsr Zp_Tmp1_byte
    ror a
    sta <(Zp_Buffered_sIrq + sIrq::Param1_byte)  ; treeline scroll-X
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the top of the treeline in the TownOutdoors
;;; room.  Sets the horizontal scroll for the treeline to a fraction of the
;;; room scroll, so that the treeline scrolls more slowly than the main portion
;;; of the room (thus making it look far away).
.PROC Int_TownOutdoorsTreeTopIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    ;; Set up the latch value for next IRQ.
    lda #kTreelineBottomY - kTreelineTopY - 1
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; Update Zp_NextIrq_int_ptr for the next IRQ.
    ldax #Int_TownOutdoorsTreeBottomIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #6  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #$00  ; nametable number << 2 (so $00 for nametable 0)
    sta Hw_PpuAddr_w2
    lda #kTreelineTopY  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    ;; Scroll the treeline horizontally.
    lda <(Zp_Active_sIrq + sIrq::Param1_byte)  ; treeline scroll-X
    tax  ; new scroll-X value
    div #8
    ora #(kTreelineTopY & $38) << 2
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;; HBlank IRQ handler function for the bottom of the treeline in the
;;; TownOutdoors room.  Sets the horizontal scroll back to match the room
;;; scroll, so that the bottom portion of the room scrolls normally.
.PROC Int_TownOutdoorsTreeBottomIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ.
    sta Hw_Mmc3IrqDisable_wo  ; ack
    sta Hw_Mmc3IrqEnable_wo  ; re-enable
    ;; Set up the latch value for next IRQ.
    lda <(Zp_Active_sIrq + sIrq::Param3_byte)  ; window latch
    sta Hw_Mmc3IrqLatch_wo
    sta Hw_Mmc3IrqReload_wo
    ;; Update Zp_NextIrq_int_ptr for the next IRQ.
    ldax #Int_WindowTopIrq
    stax Zp_NextIrq_int_ptr
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #6  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #$00  ; nametable number << 2 (so $00 for nametable 0)
    sta Hw_PpuAddr_w2
    lda #kTreelineBottomY  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    lda <(Zp_Active_sIrq + sIrq::Param2_byte)  ; houses scroll-X
    tax  ; new scroll-X value
    div #8
    ora #(kTreelineBottomY & $38) << 2
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the TownOutdoors room.
.PROC DataA_Dialog_TownOutdoors_sDialog_ptr_arr
:   .assert * - :- = kSignDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_TownOutdoors_Sign_sDialog
.ENDPROC

.PROC DataA_Dialog_TownOutdoors_Sign_sDialog
    .word ePortrait::Sign
    .byte "$"
    .byte " Bartik Town Hall#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
