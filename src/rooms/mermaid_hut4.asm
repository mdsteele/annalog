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
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_MermaidAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_MermaidAreaName_u8_arr
.IMPORT DataA_Room_Hut_sTileset
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT Func_IsFlagSet
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjAnnaNormal
.IMPORT Ppu_ChrObjTownsfolk
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Sram_CarryingFlower_eFlag
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_OamOffset_u8
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut4_sRoom
.PROC DataC_Mermaid_Hut4_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte IsTall_bool, $00
    d_byte MinimapStartRow_u8, 11
    d_byte MinimapStartCol_u8, 12
    d_byte MinimapWidth_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTownsfolk)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncC_Mermaid_Hut4_Draw
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_MermaidAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_MermaidAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Hut_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    .linecont +
    d_addr Dialogs_sDialog_ptr_arr_ptr, \
           DataA_Dialog_MermaidHut4_sDialog_ptr_arr
    .linecont -
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Init_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mermaid_hut4.room"
    .assert * - :- = 16 * 16, error
_Platforms_sPlatform_arr:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0020
    d_word Top_i16,   $00c4
    D_END
    .byte ePlatform::None
_Actors_sActor_arr:
    D_STRUCT sActor
    d_byte Type_eActor, eActor::Adult
    d_byte TileRow_u8, 21
    d_byte TileCol_u8, 18
    d_byte Param_byte, kTileIdMermaidFloristFirst
    D_END
    .byte eActor::None
_Devices_sDevice_arr:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 8
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 9
    d_byte Target_u8, 0
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::OpenDoorway
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_u8, eRoom::MermaidVillage
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LockedDoor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 11
    d_byte Target_u8, eRoom::MermaidHut4  ; TODO
    D_END
    .byte eDevice::None
.ENDPROC

;;;=========================================================================;;;

;;; Returns the number of flowers that have been delivered.
;;; @return A The number of delivered flowers.
;;; @return Z Set if zero flowers have been delivered.
.PROC FuncC_Mermaid_CountDeliveredFlowers
    lda #0
    sta Zp_Tmp1_byte  ; num flowers delivered
    ldx #kFirstFlowerFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X and Zp_Tmp*, sets Z if flag is not set
    beq @continue
    inc Zp_Tmp1_byte  ; num flowers delivered
    @continue:
    inx
    .assert kLastFlowerFlag < $ff, error
    cpx #kLastFlowerFlag + 1
    blt @loop
    lda Zp_Tmp1_byte  ; num flowers delivered
    rts
.ENDPROC

;;; Allocates and populates OAM slots for this room.
.PROC FuncC_Mermaid_Hut4_Draw
    ldx #kFirstFlowerFlag
    @loop:
    jsr Func_IsFlagSet  ; preserves X, sets Z if flag is not set
    beq @continue
    jsr FuncC_Mermaid_Hut4_DrawFlower  ; preserves X
    @continue:
    inx
    .assert kLastFlowerFlag < $ff, error
    cpx #kLastFlowerFlag + 1
    blt @loop
    rts
.ENDPROC

;;; Allocates and populates OAM slots for one delivered flower.
;;; @param X The eFlag value for the flower.
;;; @preserve X
.PROC FuncC_Mermaid_Hut4_DrawFlower
    ;; Determine the position for the object.
    txa
    sub #kFirstFlowerFlag
    tay
    lda _PosX_u8_arr, y
    sta Zp_Tmp1_byte  ; X-pos
    lda _PosY_u8_arr, y
    sub Zp_RoomScrollY_u8
    sta Zp_Tmp2_byte  ; Y-pos
    ;; Allocate the object.
    ldy Zp_OamOffset_u8
    lda Zp_Tmp1_byte  ; X-pos
    sta Ram_Oam_sObj_arr64 + sObj::XPos_u8, y
    lda Zp_Tmp2_byte  ; Y-pos
    sta Ram_Oam_sObj_arr64 + sObj::YPos_u8, y
    lda #kFlowerTileIdTop
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kFlowerPaletteTop
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    tya
    add #.sizeof(sObj)
    sta Zp_OamOffset_u8
    rts
_PosX_u8_arr:
    .byte $54, $64, $74, $84, $94, $a4, $54, $64, $74, $84, $94, $a4
    .assert * - _PosX_u8_arr = kNumFlowerFlags, error
_PosY_u8_arr:
    .byte $4f, $4f, $4f, $4f, $4f, $4f, $6f, $6f, $6f, $6f, $6f, $6f
    .assert * - _PosY_u8_arr = kNumFlowerFlags, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the MermaidHut4 room.
.PROC DataA_Dialog_MermaidHut4_sDialog_ptr_arr
    .addr _Initial_sDialog
_Initial_sDialog:
    .addr _InitialDialogFunc
_InitialDialogFunc:
    lda Sram_CarryingFlower_eFlag
    beq @notCarryingFlower
    ldya #_BroughtFlower_sDialog
    rts
    @notCarryingFlower:
    jsr FuncC_Mermaid_CountDeliveredFlowers  ; returns A and Z
    bne @hasDeliveredSomeFlowers
    ldya #_NoFlowersYet_sDialog
    rts
    @hasDeliveredSomeFlowers:
    cmp #kNumFlowerFlags
    bge @hasDeliveredAllFlowers
    ldya #_WantMoreFlowers_sDialog
    rts
    @hasDeliveredAllFlowers:
    ldya #_ThankYou_sDialog
    rts
_NoFlowersYet_sDialog:
    .word ePortrait::Woman
    .byte "Bring me flowers.#"
    .byte 0
_BroughtFlower_sDialog:
    .word ePortrait::Woman
    .byte "Ah, I see you've$"
    .byte "brought me a flower!$"
    .byte "How kind of you.#"
    .addr _DeliverFlowerFunc
_DeliverFlowerFunc:
    chr10_bank #<.bank(Ppu_ChrObjAnnaNormal)
    ;; Get the bitmask for this eFlag, and store it in Zp_Tmp1_byte.
    lda Sram_CarryingFlower_eFlag
    and #$07
    tax
    lda Data_PowersOfTwo_u8_arr8, x
    sta Zp_Tmp1_byte  ; flag bitmask
    ;; Get the byte offset into Sram_ProgressFlags_arr for this eFlag, and
    ;; store it in X.
    lda Sram_CarryingFlower_eFlag
    div #8
    tax
    ;; Enable writes to SRAM.
    lda #bMmc3PrgRam::Enable
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Mark the carried flower as delivered.
    lda Sram_ProgressFlags_arr, x
    ora Zp_Tmp1_byte  ; flag bitmask
    sta Sram_ProgressFlags_arr, x
    ;; Mark the player as no longer carrying a flower.
    lda #0
    sta Sram_CarryingFlower_eFlag
    ;; Disable writes to SRAM.
    lda #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sta Hw_Mmc3PrgRamProtect_wo
    ;; Check if we have all the flowers yet.
    jsr FuncC_Mermaid_CountDeliveredFlowers  ; returns A
    cmp #kNumFlowerFlags
    bge @allFlowersDelivered
    ldya #_WantMoreFlowers_sDialog
    rts
    @allFlowersDelivered:
    ldya #_DeliveredLastFlower_sDialog
    rts
_WantMoreFlowers_sDialog:
    .word ePortrait::Woman
    .byte "I want more flowers.#"
    .byte 0
_DeliveredLastFlower_sDialog:
    .word ePortrait::Woman
    .byte "Now I have a dozen.#"
    .byte 0
_ThankYou_sDialog:
    .word ePortrait::Woman
    .byte "Thank you for all the$"
    .byte "flowers.#"
    .byte 0
.ENDPROC

;;;=========================================================================;;;
