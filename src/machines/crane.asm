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

.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "crane.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; TODO: combine crane/trolley tile IDs
;;; Various OBJ tile IDs used for drawing crane/trolley machine.
kTileIdCraneWheel      = kTileIdCraneFirst + 0
kTileIdCraneRope       = kTileIdCraneFirst + 1
kTileIdCraneClawOpen   = kTileIdCraneFirst + 2
kTileIdCraneClawClosed = kTileIdCraneFirst + 3
kTileIdCraneCorner     = kTileIdCraneFirst + 4
kTileIdTrolleyCorner   = kTileIdMachineCorner
kTileIdTrolleyRope     = $7c
kTileIdTrolleyWheel    = $7b

;;; OBJ palette numbers used for various parts of crane/trolley machines.
kRopePalette = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for crane machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawCraneMachine
.PROC FuncA_Objects_DrawCraneMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_MainPlatform:
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    lda #kRopePalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kRopePalette | bObj::FlipV | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipV | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdCraneWheel
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdCraneCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_Claw:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalHorz_u8_arr, x
    beq @open
    @closed:
    ldx #kTileIdCraneClawClosed
    .assert kTileIdCraneClawClosed <> 0, error
    bne @done
    @open:
    ldx #kTileIdCraneClawOpen
    @done:
_RightClaw:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X; returns C and Y
    bcs @done
    txa  ; tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kMachineLightPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
_LeftClaw:
    jsr FuncA_Objects_MoveShapeLeftOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X; returns C and Y
    bcs @done
    txa  ; tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;; Draw implemention for trolley machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawTrolleyMachine
.PROC FuncA_Objects_DrawTrolleyMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kRopePalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kRopePalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdTrolleyCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdTrolleyWheel
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draws a rope hanging from the current trolley machine down to the specified
;;; crane machine platform.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The platform index for the crane machine.
.EXPORT FuncA_Objects_DrawTrolleyRopeToCrane
.PROC FuncA_Objects_DrawTrolleyRopeToCrane
    stx Zp_Tmp1_byte  ; crane platform index
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte  ; crane platform index
    ;; Calculate the offset to the rope position.  This combines three things:
    ;; the room scroll, the height of the trolley (since Zp_ShapePosY_i16 is
    ;; set to its top instead of bottom), and an extra (kTileHeightPx - 1), so
    ;; that our later division by kTileHeightPx will effectively round up.
    lda Zp_RoomScrollY_u8
    add #kBlockHeightPx - (kTileHeightPx - 1)
    sta Zp_Tmp1_byte  ; offset
    ;; Calculate the offset screen-space Y-position of the bottom of the rope,
    ;; storing the lo byte in Zp_Tmp1_byte and the hi byte in Zp_Tmp2_byte.
    lda Ram_PlatformTop_i16_0_arr, x
    sub Zp_Tmp1_byte  ; offset
    sta Zp_Tmp1_byte  ; offset screen-space rope bottom (lo)
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_Tmp2_byte  ; offset screen-space rope bottom (hi)
    ;; Calculate the length of the rope, in pixels, storing the lo byte in
    ;; Zp_Tmp1_byte and the hi byte in A.
    lda Zp_Tmp1_byte  ; offset screen-space rope bottom (lo)
    sub Zp_ShapePosY_i16 + 0
    sta Zp_Tmp1_byte  ; rope pixel length (lo)
    lda Zp_Tmp2_byte  ; offset screen-space rope bottom (hi)
    sbc Zp_ShapePosY_i16 + 1
    ;; Divide the rope pixel length by kTileHeightPx to get the length of the
    ;; rope in tiles.  Because of the (kTileHeightPx - 1) offset to the rope
    ;; length above, this division will effectively round up instead of down.
    .assert kTileHeightPx = 8, error
    .repeat 3
    lsr a             ; rope pixel length (hi)
    ror Zp_Tmp1_byte  ; rope pixel length (lo)
    .endrepeat
    ;; Draw the rope (if it contains a nonzero number of tiles).
    ldx Zp_Tmp1_byte  ; param: rope length in tiles
    bne FuncA_Objects_DrawTrolleyRopeWithLength
    rts
.ENDPROC

;;; Draws a rope with the specified length hanging down from the current
;;; trolley machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The number of tiles in the rope (nonzero).
.EXPORT FuncA_Objects_DrawTrolleyRopeWithLength
.PROC FuncA_Objects_DrawTrolleyRopeWithLength
    stx Zp_Tmp1_byte  ; rope length in tiles
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves Zp_Tmp*
    ldx Zp_Tmp1_byte  ; rope length in tiles
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    lda #kTileWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    @loop:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kTileIdTrolleyRope
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kRopePalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;
