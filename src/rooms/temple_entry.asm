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
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Pause_TempleAreaCells_u8_arr2_arr
.IMPORT DataA_Pause_TempleAreaName_u8_arr
.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MovePlatformTopToward
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_PlatformGoal_i16

;;;=========================================================================;;;

;;; The actor index for the mermaid in this room.
kMermaidActorIndex = 0
;;; The dialog index for the mermaid in this room.
kMermaidDialogIndex = 0
;;; The talk devices indices for the mermaid in this room.
kMermaidDeviceIndexLeft = 1
kMermaidDeviceIndexRight = 0

;;; The platform index for the movable column in this room.
kColumnPlatformIndex = 1

;;; The minimum and maximum Y-positions for the top of the movable column
;;; platform.
kColumnPlatformMinTop = $140
kColumnPlatformMaxTop = $160

;;; How many frames it takes for the movable column to move one pixel.
kColumnPlatformSlowdown = 3

;;; Various OBJ tile IDs used for drawing the movable column.
kTileIdObjColumnFirst  = $9a
kTileIdObjColumnCorner = kTileIdObjColumnFirst + 0
kTileIdObjColumnSide   = kTileIdObjColumnFirst + 1

;;; The OBJ palette number to use for drawing the movable column.
kColumnPalette = 0

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; How many more frames before the movable column can move another pixel.
    ColumnSlowdown_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Entry_sRoom
.PROC DataC_Temple_Entry_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $0008
    d_byte IsTall_bool, $ff
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 5
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Tick_func_ptr, FuncC_Temple_Entry_TickRoom
    d_addr Draw_func_ptr, FuncC_Temple_Entry_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr AreaName_u8_arr_ptr, DataA_Pause_TempleAreaName_u8_arr
    d_addr AreaCells_u8_arr2_arr_ptr, DataA_Pause_TempleAreaCells_u8_arr2_arr
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    .linecont +
    d_addr Dialogs_sDialog_ptr_arr_ptr, \
           DataA_Dialog_TempleEntry_sDialog_ptr_arr
    .linecont -
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, FuncC_Temple_Entry_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/temple_entry.room"
    .assert * - :- = 18 * 24, error
_Platforms_sPlatform_arr:
:   D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $c0
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0030
    d_word Top_i16,   $0154
    D_END
    .assert * - :- = kColumnPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0040
    d_word Top_i16, kColumnPlatformMaxTop
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kMermaidActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_byte TileRow_u8, 43
    d_byte TileCol_u8, 14
    d_byte Param_byte, kTileIdMermaidGuardFFirst
    D_END
    ;; TODO: add a couple enemies on the upper platforms
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kMermaidDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 6
    d_byte Target_u8, kMermaidDialogIndex
    D_END
    .assert * - :- = kMermaidDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 7
    d_byte Target_u8, kMermaidDialogIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::TemplePit  ; TODO
    d_byte SpawnBlock_u8, 6
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::GardenHallway
    d_byte SpawnBlock_u8, 19
    D_END
.ENDPROC

.PROC FuncC_Temple_Entry_InitRoom
    ;; Remove the mermaid from this room if the temple breaker has been
    ;; activated.
    lda Sram_ProgressFlags_arr + (eFlag::BreakerTemple >> 3)
    and #1 << (eFlag::BreakerTemple & $07)
    beq @done
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kMermaidActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kMermaidDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kMermaidDeviceIndexRight
    ;; Also raise the column in this case (for safety, since the mermaid is no
    ;; longer there to raise it for you; although normally, you can't get to
    ;; the breaker without first raising the column).
    beq _DoRaiseColumn  ; unconditional
    @done:
_MaybeRaiseColumn:
    ;; If the column has been raised before, raise it.
    lda Sram_ProgressFlags_arr + (eFlag::TempleEntryColumnRaised >> 3)
    and #1 << (eFlag::TempleEntryColumnRaised & $07)
    beq _Return
_DoRaiseColumn:
    lda #<kColumnPlatformMinTop
    sta Ram_PlatformTop_i16_0_arr + kColumnPlatformIndex
    lda #>kColumnPlatformMinTop
    sta Ram_PlatformTop_i16_1_arr + kColumnPlatformIndex
_Return:
    rts
.ENDPROC

.PROC FuncC_Temple_Entry_TickRoom
    ;; If the column-raised flag is set, move the column upward towards its
    ;; highest position.
    lda Sram_ProgressFlags_arr + (eFlag::TempleEntryColumnRaised >> 3)
    and #1 << (eFlag::TempleEntryColumnRaised & $07)
    beq @done
    ;; Move the column by one pixel every kColumnPlatformSlowdown frames.
    lda Ram_RoomState + sState::ColumnSlowdown_u8
    bne @slowdown
    lda #kColumnPlatformSlowdown
    sta Ram_RoomState + sState::ColumnSlowdown_u8
    ldax #kColumnPlatformMinTop
    stax Zp_PlatformGoal_i16
    lda #1  ; param: move speed
    ldx #kColumnPlatformIndex  ; param: platform index
    jmp Func_MovePlatformTopToward
    @slowdown:
    dec Ram_RoomState + sState::ColumnSlowdown_u8
    @done:
    rts
.ENDPROC

;;; Draw function for the TempleEntry room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Temple_Entry_DrawRoom
    ldx #kColumnPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
_ColumnTop:
    jsr FuncA_Objects_MoveShapeRightOneTile
    jsr FuncA_Objects_MoveShapeDownOneTile
    lda #kColumnPalette | bObj::Pri  ; param: obj flags
    jsr FuncA_Objects_Alloc2x2Shape  ; returns C and Y
    bcs @done
    lda #kTileIdObjColumnCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjColumnSide
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kColumnPalette | bObj::Pri | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
_ColumnBody:
    ldx #2
    @loop:
    lda #kBlockHeightPx  ; param: move delta
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X
    lda #kColumnPalette | bObj::Pri  ; param: obj flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kTileIdObjColumnSide
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kColumnPalette | bObj::Pri | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the TempleEntry room.
.PROC DataA_Dialog_TempleEntry_sDialog_ptr_arr
:   .assert * - :- = kMermaidDialogIndex * kSizeofAddr, error
    .addr _Mermaid_sDialog
_Mermaid_sDialog:
    .word ePortrait::Mermaid
    .byte "I am guarding the$"
    .byte "entrance to the temple$"
    .byte "you see above us.#"
    .addr _MermaidCheckPermissionFunc
_MermaidCheckPermissionFunc:
    ;; TODO: check flag to see if the queen has given you permission.
    jmp _MermaidRaiseColumnFunc
    ldya #_MermaidNoPermission_sDialog
    rts
_MermaidNoPermission_sDialog:
    .word ePortrait::Mermaid
    .byte "I cannot help you to$"
    .byte "enter it without the$"
    .byte "queen's permission.#"
    .word ePortrait::Done
_MermaidRaiseColumnFunc:
    ldx #eFlag::TempleEntryColumnRaised  ; param: flag
    jsr Func_SetFlag
    ldya #_MermaidEnter_sDialog
    rts
_MermaidEnter_sDialog:
    .word ePortrait::Mermaid
    .byte "Our queen has sent$"
    .byte "word: I am to allow$"
    .byte "you to enter.#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;