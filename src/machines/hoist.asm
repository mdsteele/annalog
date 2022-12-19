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

.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "hoist.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw2x2Shape
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; How many pixels above the bottom of a pulley platform the rope must extend
;;; in order to appear to feed into the pulley.
kPulleyRopeOverlapPx = 4

;;; OBJ tile IDs used for drawing various parts of hoist machines.
kTileIdObjPulley   = kTileIdObjHoistFirst + 1
kTileIdObjRopeDiag = kTileIdObjHoistFirst + 4
kTileIdObjRopeVert = kTileIdObjHoistFirst + 5

;;; The OBJ palette number to use for drawing hoist ropes.
kPaletteObjRope = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Moves the current hoist machine's platform towards its goal position.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The platform index for the hoist machine's load.
;;; @param YA The minimum platform top position for the hoist machine's load.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved up, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
.EXPORT FuncA_Machine_HoistMoveTowardGoal
.PROC FuncA_Machine_HoistMoveTowardGoal
    sta Zp_Tmp1_byte  ; min platform top (lo)
    sty Zp_Tmp2_byte  ; min platform top (hi)
    ;; Calculate the desired Y-position for the top edge of the load, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    mul #kBlockHeightPx
    adc Zp_Tmp1_byte  ; min platform top (lo) (carry is alredy clear from mul)
    sta Zp_PointY_i16 + 0
    lda #0
    adc Zp_Tmp2_byte  ; min platform top (hi)
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the hoist (faster if resetting).
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Resetting
    beq @fast
    @slow:
    lda #1
    bne @move  ; unconditional
    @fast:
    lda #2
    @move:
    ;; Move the load platform vertically, as necessary.
    jmp Func_MovePlatformTopTowardPointY  ; returns Z, N, and A
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for hoist machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The low byte of the Y-position of the hoist load platform.
.EXPORT FuncA_Objects_DrawHoistMachine
.PROC FuncA_Objects_DrawHoistMachine
    pha  ; rope position
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    pla  ; rope position
    tax  ; rope position
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    .assert bMachine::FlipH = bObj::FlipH, error
    pha  ; object flags
    tay  ; param: object flags
    lda #kTileIdObjHoistFirst
    jsr FuncA_Objects_Draw2x2Shape  ; preserves X, returns C and Y
    pla  ; object flags
    bcs @done
    ;; Set machine light flags:
    ora #bObj::FlipV | kPaletteObjMachineLight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    ;; Set spindle flags:
    txa  ; rope position
    and #$04
    beq @noTurnSpindle
    lda Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    @noTurnSpindle:
    ;; Set machine light tile:
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draws a pulley that a hoist load is suspended from.
;;; @param X The pulley platform index.
;;; @param Y The low byte of the Y-position of the hoist load platform.
.EXPORT FuncA_Objects_DrawHoistPulley
.PROC FuncA_Objects_DrawHoistPulley
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves Y
    tya
    and #$04
    mul #bObj::FlipH / $04
    tay  ; param: object flags
    lda #kTileIdObjPulley  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;; Draws a girder platform, and the rope triangle above it, for a hoist
;;; machine load.  When this returns, the shape position will be set to the
;;; bottom-left corner of the the vertical rope that the rope triangle should
;;; be hanging from.
;;; @param X The girder platform index.
.EXPORT FuncA_Objects_DrawHoistGirder
.PROC FuncA_Objects_DrawHoistGirder
    jsr FuncA_Objects_DrawGirderPlatform
_RopeTriangle:
    jsr FuncA_Objects_MoveShapeUpOneTile
    lda #1
    jsr FuncA_Objects_MoveShapeLeftByA
    ldy #kPaletteObjRope | bObj::FlipH  ; param: object flags
    lda #kTileIdObjRopeDiag  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    lda #kTileWidthPx - 1
    jsr FuncA_Objects_MoveShapeLeftByA
    ldy #kPaletteObjRope  ; param: object flags
    lda #kTileIdObjRopeDiag  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
.ENDPROC

;;; Draws a vertical rope that feeds into a hoist pulley.
;;; @prereq The shape position is set to the bottom-left corner of the rope.
;;; @param X The platform index for the pulley.
.EXPORT FuncA_Objects_DrawHoistRopeToPulley
.PROC FuncA_Objects_DrawHoistRopeToPulley
    ;; Calculate the offset to the room-space platform bottom Y-position that
    ;; will give us the screen-space Y-position for the top of the rope.  Note
    ;; that we offset by an additional (kTileHeightPx - 1), so that when we
    ;; divide by kTileHeightPx later, it will effectively round up instead of
    ;; down.
    lda Zp_RoomScrollY_u8
    add #kPulleyRopeOverlapPx + (kTileHeightPx - 1)
    sta Zp_Tmp1_byte  ; offset
    ;; Calculate the screen-space Y-position of the top of the rope, storing
    ;; the lo byte in Zp_Tmp1_byte and the hi byte in Zp_Tmp2_byte.
    lda Ram_PlatformBottom_i16_0_arr, x
    sub Zp_Tmp1_byte  ; offset
    sta Zp_Tmp1_byte  ; screen-space chain top (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    sbc #0
    sta Zp_Tmp2_byte  ; screen-space chain top (hi)
    ;; Calculate the length of the rope, in pixels, storing the lo byte in
    ;; Zp_Tmp1_byte and the hi byte in A.
    lda Zp_ShapePosY_i16 + 0
    sub Zp_Tmp1_byte  ; screen-space chain top (lo)
    sta Zp_Tmp1_byte  ; chain pixel length (lo)
    lda Zp_ShapePosY_i16 + 1
    sbc Zp_Tmp2_byte  ; screen-space chain top (hi)
    ;; Divide the chain pixel length by kTileHeightPx to get the length of the
    ;; chain in tiles, storing it in X.  Because we added an additional
    ;; (kTileHeightPx - 1) to the chain length above, this division will
    ;; effectively round up instead of down.
    .assert kTileHeightPx = 8, error
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte  ; chain pixel length (lo)
    .endrepeat
    ldx Zp_Tmp1_byte  ; param: chain length in tiles
_Loop:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X
    ldy #kPaletteObjRope | bObj::Pri  ; param: object flags
    lda #kTileIdObjRopeVert  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    dex
    bne _Loop
    rts
.ENDPROC

;;;=========================================================================;;;
