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
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"
.INCLUDE "../scroll.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Garden_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjGarden
.IMPORT Sram_Minimap_u16_arr
.IMPORTZP Zp_AvatarPosY_i16
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

;;; Once the player avatar falls to this room pixel Y-position, the camera
;;; changes from being horizontally locked to vertically locked.
kScrollCutoffPosY = $0140

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; Whether the camera should be locked horizontally instead of vertically.
    LockHorz_bool .byte
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
    d_addr Enter_func_ptr, FuncC_Garden_Landing_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncC_Garden_Landing_UpdateScrollLock
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/garden_landing.room"
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
    d_byte Target_byte, eDialog::GardenLandingPaper
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

;;; Called when the player avatar enters the GardenLanding room.  If the avatar
;;; enters the room from the vertical shaft at the top, sets the rest of the
;;; shaft as explored on the minimap.
;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncC_Garden_Landing_EnterRoom
    ;; If the player avatar didn't enter from the vertical shaft at the top, do
    ;; nothing.
    cmp #bSpawn::Passage | kShaftPassageIndex
    bne @done
    ;; Arrange to lock the camera horizontally.
    dec Zp_RoomState + sState::LockHorz_bool  ; now LockHorz_bool is $ff
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
    .assert * = FuncC_Garden_Landing_UpdateScrollLock, error, "fallthrough"
.ENDPROC

.PROC FuncC_Garden_Landing_UpdateScrollLock
    bit Zp_RoomState + sState::LockHorz_bool
    bpl _LockVert
    lda Zp_AvatarPosY_i16 + 0
    cmp #<kScrollCutoffPosY
    lda Zp_AvatarPosY_i16 + 1
    sbc #>kScrollCutoffPosY
    bge _UnlockHorz
_LockHorz:
    ldax #$0000
    stax Zp_RoomScrollX_u16
    lda #bScroll::LockHorz
    sta Zp_Camera_bScroll
    rts
_UnlockHorz:
    inc Zp_RoomState + sState::LockHorz_bool  ; now LockHorz_bool is $00
_LockVert:
    lda #$90
    sta Zp_RoomScrollY_u8
    lda #bScroll::LockVert
    sta Zp_Camera_bScroll
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_GardenLandingPaper_sDialog
.PROC DataA_Dialog_GardenLandingPaper_sDialog
    dlg_Text Paper, DataA_Text0_GardenLandingPaper_Page1_u8_arr
    dlg_Text Paper, DataA_Text0_GardenLandingPaper_Page2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_GardenLandingPaper_Page1_u8_arr
    .byte "Day 13: And now, there$"
    .byte "is nothing left of us$"
    .byte "but our machines.#"
.ENDPROC

.PROC DataA_Text0_GardenLandingPaper_Page2_u8_arr
    .byte "I wonder for how long$"
    .byte "those will keep on$"
    .byte "working. A long time.$"
    .byte "Maybe forever.#"
.ENDPROC

;;;=========================================================================;;;
