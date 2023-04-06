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
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing crane/trolley machine.
kTileIdObjCraneWheel      = kTileIdCraneFirst + 0
kTileIdObjCraneRope       = kTileIdCraneFirst + 1
kTileIdObjCraneClawOpen   = kTileIdCraneFirst + 2
kTileIdObjCraneClawClosed = kTileIdCraneFirst + 3
kTileIdObjCraneCorner     = kTileIdCraneFirst + 4
kTileIdObjPulley          = kTileIdCraneFirst + 7
kTileIdObjTrolleyCorner   = kTileIdObjMachineCorner
kTileIdObjTrolleyRope     = kTileIdObjCraneRope
kTileIdObjTrolleyWheel    = kTileIdObjCraneWheel

;;; OBJ palette numbers used for various parts of crane/trolley machines.
kPaletteObjPulley = 0
kPaletteObjRope   = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for crane machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawCraneMachine
.PROC FuncA_Objects_DrawCraneMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_MainPlatform:
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    lda #kPaletteObjRope | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kPaletteObjRope | bObj::FlipV | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipV | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjCraneWheel
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjCraneCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_Claw:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalHorz_u8_arr, x
    beq @open
    @closed:
    ldx #kTileIdObjCraneClawClosed
    .assert kTileIdObjCraneClawClosed <> 0, error
    bne @done
    @open:
    ldx #kTileIdObjCraneClawOpen
    @done:
_RightClaw:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X; returns C and Y
    bcs @done
    txa  ; tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjMachineLight | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @done:
_LeftClaw:
    jsr FuncA_Objects_MoveShapeLeftOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X; returns C and Y
    bcs @done
    txa  ; tile ID
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjMachineLight
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
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    lda #kPaletteObjMachineLight | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjRope
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kPaletteObjRope | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjTrolleyCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjTrolleyWheel
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draws a fixed pulley that the current crane machine is suspended from, and
;;; a double-rope between the crane and the pulley.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The platform index for the pulley.
.EXPORT FuncA_Objects_DrawCranePulleyAndRope
.PROC FuncA_Objects_DrawCranePulleyAndRope
    txa  ; pulley platform index
    pha  ; pulley platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldy #kPaletteObjPulley  ; param: object flags
    lda #kTileIdObjPulley  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    pla  ; pulley platform index
    tax  ; param: pulley platform index
    .assert * = FuncA_Objects_DrawCraneRopeToPulley, error, "fallthrough"
.ENDPROC

;;; Draws a rope that the current crane machine is hanging from up to the
;;; specified pulley platform.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The platform index for the pulley.
.EXPORT FuncA_Objects_DrawCraneRopeToPulley
.PROC FuncA_Objects_DrawCraneRopeToPulley
    stx T0  ; crane platform index
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    ldx T0  ; crane platform index
    ;; Calculate the screen-space position for the bottom of the pulley.
    lda Ram_PlatformBottom_i16_0_arr, x
    sub Zp_RoomScrollY_u8
    sta T0  ; screen-space rope top (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    sbc #0
    sta T1  ; screen-space rope top (hi)
    ;; Calculate the length of the rope, in pixels.
    lda Zp_ShapePosY_i16 + 0
    sub T0  ; screen-space rope top (lo)
    sta T0  ; rope length in pixels (lo)
    lda Zp_ShapePosY_i16 + 1
    sbc T1  ; screen-space rope top (hi)
    sta T1  ; rope length in pixels (hi)
    ;; Add (kTileHeightPx - 1) before dividing by kTileHeightPx, so that the
    ;; division will round up.
    lda T0  ; rope length in pixels (lo)
    add #kTileHeightPx - 1
    sta T0
    lda T1  ; rope length in pixels (hi)
    adc #0
    .assert kTileHeightPx = 1 << 3, error
    .repeat 3
    lsr a
    ror T0
    .endrepeat
    ;; Draw the rope (if it contains a nonzero number of tiles).
    ldx T0  ; param: rope length in tiles
    beq _Return
_DrawRope:
    lda #kTileWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kTileIdObjCraneRope
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjRope
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
_Return:
    rts
.ENDPROC

;;; Draws a rope with the specified length hanging down from the current
;;; trolley machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The number of tiles in the rope (nonzero).
.EXPORT FuncA_Objects_DrawTrolleyRopeWithLength
.PROC FuncA_Objects_DrawTrolleyRopeWithLength
    stx T0  ; rope length in tiles
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    ldx T0  ; rope length in tiles
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    lda #kTileWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    @loop:
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kTileIdObjTrolleyRope
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kPaletteObjRope
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;
