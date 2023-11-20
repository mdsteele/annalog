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
.INCLUDE "../flag.inc"
.INCLUDE "../irq.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"
.INCLUDE "../scroll.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Garden_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT Func_AckIrqAndLatchWindowFromParam3
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjGarden
.IMPORT Sram_Minimap_u16_arr
.IMPORTZP Zp_Active_sIrq
.IMPORTZP Zp_AvatarPosY_i16
.IMPORTZP Zp_Buffered_sIrq
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_RoomScrollX_u16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The index of the vertical passage at the top of the room.
kShaftPassageIndex = 1

;;; The minimal column/row for the top of the vertical shaft that leads into
;;; this room.
kShaftMinimapCol = 6
kShaftMinimapTopRow = 4

;;; The byte offset into Sram_Minimap_u16_arr for the vertical shaft.
kShaftMinimapByteOffset = 2 * kShaftMinimapCol + kShaftMinimapTopRow / 8

;;; How many times to teleport the camera and player avatar upwards while
;;; falling down the shaft.  These teleports are used to create the illusion
;;; that the shaft terrain is taller than it really is.
kNumFallingTeleports = 10
;;; How far to teleport the camera and player avatar upwards each time while
;;; falling down the shaft.
kFallingTeleportDistance = $40
;;; The vertical position on the screen at which to mirror the shaft terrain
;;; while the player avatar is falling, so as to make the shaft look taller
;;; than it really is.  This value should be the smallest multiple of
;;; kFallingTeleportDistance that is at least half the height of the screen.
kFallingIrqSeamY = kFallingTeleportDistance * 2
.ASSERT kFallingIrqSeamY >= kScreenHeightPx / 2, error

;;; When falling down the shaft, unlock horz scrolling once Zp_RoomScrollY_u8
;;; reaches this value or higher.
kFallingUnlockHorzAt = $48
;;; When falling down the shaft, unlock horz scrolling once Zp_RoomScrollY_u8
;;; reaches this value or higher.
kFallingLockVertAt   = $8d
;;; When vertical scrolling is locked, this is the value to lock it to.
kLockedRoomScrollY   = $8e

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; How many more times to teleport the camera and player avatar while
    ;; falling down the shaft.
    RemainingTeleports_u8 .byte
    ;; Counter that ticks up each frame during accellerated scrolling.  This is
    ;; used to implement fractional scrolling.
    ScrollCounter_u8      .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Garden"

.EXPORT DataC_Garden_Landing_sRoom
.PROC DataC_Garden_Landing_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $100
    d_byte Flags_bRoom, bRoom::Tall | eArea::Garden
    d_byte MinimapStartRow_u8, 6
    d_byte MinimapStartCol_u8, 6
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjGarden)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Garden_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_GardenLanding_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_GardenLanding_TickRoom
    d_addr Draw_func_ptr, FuncC_Garden_Landing_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/garden_landing.room"
    .assert * - :- = 33 * 24, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $180
    d_byte HeightPx_u8,  $30
    d_word Left_i16,   $0030
    d_word Top_i16,    $0144
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 17
    d_byte BlockCol_u8, 23
    d_byte Target_byte, eFlag::PaperJerome13
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::GardenShrine
    d_byte SpawnBlock_u8, 14
    D_END
    .assert * - :- = kShaftPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::PrisonCell
    d_byte SpawnBlock_u8, 8
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Garden_Landing_DrawRoom
_SetUpIrq:
    ;; As long as the player avatar has any more falling teleports left, set up
    ;; an IRQ to mirror the shaft along the bottom half (or so) of the screen.
    lda Zp_RoomState + sState::RemainingTeleports_u8
    beq @done
    ;; Compute the IRQ latch value to set between the IRQ seam and the top of
    ;; the window (if any), and set that as Param3_byte.
    lda <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    sub #kFallingIrqSeamY
    sta <(Zp_Buffered_sIrq + sIrq::Param3_byte)  ; window latch
    ;; Set up our own sIrq struct.
    lda #kFallingIrqSeamY
    sta <(Zp_Buffered_sIrq + sIrq::Latch_u8)
    lda Zp_RoomScrollY_u8
    sta <(Zp_Buffered_sIrq + sIrq::Param2_byte)  ; room scroll-Y
    ldax #Int_GardenLandingFallingIrq
    stax <(Zp_Buffered_sIrq + sIrq::FirstIrq_int_ptr)
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Called when the player avatar enters the GardenLanding room.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncA_Room_GardenLanding_EnterRoom
    cmp #bSpawn::Passage | kShaftPassageIndex
    beq _EnterFromShaft
_EnterNotFromShaft:
    ;; Lock vertical scrolling to the bottom of the room.
    lda #kLockedRoomScrollY
    sta Zp_RoomScrollY_u8
    lda #bScroll::LockVert
    sta Zp_Camera_bScroll
    rts
_EnterFromShaft:
    ;; Lock horizontal scrolling to the western side of the room (so that the
    ;; shaft stays centered on the screen for now).
    lda #0
    sta Zp_RoomScrollX_u16 + 0
    sta Zp_RoomScrollX_u16 + 1
    lda #bScroll::LockHorz
    sta Zp_Camera_bScroll
    ;; Initialize the teleport counter.  These teleports are used to create the
    ;; illusion that the shaft terrain is taller than it really is.
    lda #kNumFallingTeleports
    sta Zp_RoomState + sState::RemainingTeleports_u8
    ;; Set the flag indicating that the player entered the garden.
    ldx #eFlag::GardenLandingDroppedIn  ; param: flag
    jsr Func_SetFlag
    ;; Compute the minimap byte we need to write to SRAM.  We want to mark the
    ;; top two minimap cells of the shaft as explored.
    .assert kShaftMinimapTopRow = 4, error
    lda Sram_Minimap_u16_arr + kShaftMinimapByteOffset
    ora #%11 << kShaftMinimapTopRow
    ;; If no change is needed to SRAM, then we're done.
    cmp Sram_Minimap_u16_arr + kShaftMinimapByteOffset
    beq @done
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Update minimap.
    sta Sram_Minimap_u16_arr + kShaftMinimapByteOffset
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_GardenLanding_TickRoom
    lda Zp_RoomState + sState::RemainingTeleports_u8
    bne _ScrollDownExtra
_UpdateScrollLock:
    ldy Zp_RoomScrollY_u8
    ;; Once the player avatar has fallen far enough, unlock horz scrolling.
    cpy #kFallingUnlockHorzAt
    blt @done
    lda Zp_Camera_bScroll
    and #<~bScroll::LockHorz
    sta Zp_Camera_bScroll
    ;; Once the player avatar has fallen even farther, lock vert scrolling.
    cpy #kFallingLockVertAt
    blt @done
    lda #kLockedRoomScrollY
    sta Zp_RoomScrollY_u8
    lda #bScroll::LockVert
    sta Zp_Camera_bScroll
    @done:
    rts
_ScrollDownExtra:
    ;; Don't start extra scrolling until the player avatar has fallen far
    ;; enough for normal scrolling to start happening.
    lda Zp_AvatarPosY_i16 + 1
    bne @scrollDown
    lda Zp_AvatarPosY_i16 + 0
    cmp #kScreenHeightPx / 2
    blt @done
    @scrollDown:
    ;; Scroll downward by an additional 3/4 pixel per frame (on top of the
    ;; normal scroll speed).  This helps the camera to keep up with the player
    ;; avatar as it falls.
    inc Zp_RoomState + sState::ScrollCounter_u8
    lda Zp_RoomState + sState::ScrollCounter_u8
    and #$03
    beq @done
    inc Zp_RoomScrollY_u8
    @done:
_TeleportUp:
    ;; Once the camera scroll-Y is at least kFallingTeleportDistance beyond its
    ;; minimum value, teleport both the camera and the avatar up by that
    ;; distance.  This keeps the player avatar in the same vertical position on
    ;; the screen as before.
    lda Zp_RoomScrollY_u8
    sub #kFallingTeleportDistance
    blt @done
    sta Zp_RoomScrollY_u8
    lda Zp_AvatarPosY_i16 + 0
    sub #kFallingTeleportDistance
    sta Zp_AvatarPosY_i16 + 0
    lda Zp_AvatarPosY_i16 + 1
    sbc #0
    sta Zp_AvatarPosY_i16 + 1
    dec Zp_RoomState + sState::RemainingTeleports_u8
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PaperJerome13_sDialog
.PROC DataA_Dialog_PaperJerome13_sDialog
    dlg_Text Paper, DataA_Text0_PaperJerome13_Page1_u8_arr
    dlg_Text Paper, DataA_Text0_PaperJerome13_Page2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_PaperJerome13_Page1_u8_arr
    .byte "Day 13: And now, there$"
    .byte "is nothing left of us$"
    .byte "but our machines.#"
.ENDPROC

.PROC DataA_Text0_PaperJerome13_Page2_u8_arr
    .byte "I wonder for how long$"
    .byte "those will keep on$"
    .byte "working. A long time.$"
    .byte "Maybe forever.#"
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGE_Irq"

;;; HBlank IRQ handler function for the GardenLanding room when falling.  Sets
;;; the vertical scroll partway down the screen to create the illusion that the
;;; shaft is taller than it is.
.PROC Int_GardenLandingFallingIrq
    ;; Save A and X registers (we won't be using Y).
    pha
    txa
    pha
    ;; At this point, the first HBlank is already just about over.  Ack the
    ;; current IRQ and prepare for the next one.
    jsr Func_AckIrqAndLatchWindowFromParam3  ; preserves Y
    ;; Busy-wait for a bit, that our final writes in this function will occur
    ;; during the next HBlank.
    ldx #5  ; This value is hand-tuned to help wait for second HBlank.
    @busyLoop:
    dex
    bne @busyLoop
    ;; Set the PPU's new scroll-Y and scroll-X values, and also set the upper
    ;; nametable as the scrolling origin.  All of this takes four writes, and
    ;; the last two must happen during HBlank (between dots 256 and 320).
    ;; See https://www.nesdev.org/wiki/PPU_scrolling#Split_X.2FY_scroll
    lda #0 << 2  ; nametable number << 2
    sta Hw_PpuAddr_w2
    lda <(Zp_Active_sIrq + sIrq::Param2_byte)  ; new scroll-Y value
    sta Hw_PpuScroll_w2
    and #$38
    mul #4
    ;; We should now be in the second HBlank.
    stx Hw_PpuScroll_w2  ; new scroll-X value (zero)
    sta Hw_PpuAddr_w2  ; ((Y & $38) << 2) | (X >> 3)
    ;; Restore registers and return.
    pla
    tax
    pla
    rti
.ENDPROC

;;;=========================================================================;;;
