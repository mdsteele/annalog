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
.INCLUDE "../program.inc"
.INCLUDE "bridge.inc"
.INCLUDE "cannon.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing bridge machines.
kTileIdObjBridgeCornerBase = kTileIdObjCannonFirst + $01
kTileIdObjBridgeSegment    = kTileIdObjCannonFirst + $05

;;; The OBJ palette number used for moveable bridge segments.
kPaletteObjBridgeSegment = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "Y" register for a bridge machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The value of the machine's "Y" register (0-1).
.EXPORT Func_MachineBridgeReadRegY
.PROC Func_MachineBridgeReadRegY
    ldy Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, y  ; bridge angle (0-kBridgeMaxAngle)
    cmp #kBridgeMaxAngle / 2  ; now carry bit is 1 if angle >= this
    lda #0
    rol a  ; shift in carry bit, now A is 0 or 1
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryMove implemention for bridge machines.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param X The eDir value for the direction to move in.
.EXPORT FuncA_Machine_BridgeTryMove
.PROC FuncA_Machine_BridgeTryMove
    cpx #eDir::Down
    beq @moveDown
    @moveUp:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    bne @error
    inc Ram_MachineGoalVert_u8_arr, x
    lda #kBridgeMoveUpCountdown
    jmp FuncA_Machine_StartWaiting
    @moveDown:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    beq @error
    dec Ram_MachineGoalVert_u8_arr, x
    lda #kBridgeMoveDownCountdown
    jmp FuncA_Machine_StartWaiting
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

;;; Ticks the current bridge machine for the current frame.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
;;; @param A The platform index for the fixed pivot segment.
;;; @param X The platform index for the last movable segment.
.EXPORT FuncA_Machine_BridgeTick
.PROC FuncA_Machine_BridgeTick
    sta T0  ; pivot platform index
    stx T1  ; last platform index
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    beq _MoveDown
    bne _MoveUp  ; unconditional
_Finished:
    jmp FuncA_Machine_ReachedGoal
_MoveUp:
    ldy Ram_MachineState1_byte_arr, x  ; bridge angle (0-kBridgeMaxAngle)
    cpy #kBridgeMaxAngle
    beq _Finished
    iny
    bne _SetAngle  ; unconditional
_MoveDown:
    ldy Ram_MachineState1_byte_arr, x  ; bridge angle (0-kBridgeMaxAngle)
    beq _Finished
    dey
    dey
    bpl @noUnderflow
    ldy #0
    @noUnderflow:
_SetAngle:
    tya
    sta Ram_MachineState1_byte_arr, x  ; bridge angle (0-kBridgeMaxAngle)
_RepositionSegments:
    ldx T0  ; pivot platform index
    lda T1  ; last platform index
    pha  ; last platform index
    ;; Loop through each consequtive pair of bridge segments, starting with the
    ;; fixed pivot segment and the first movable segment.
    @loop:
    ;; Position the next segment vertically relative to the previous segment.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, y  ; bridge angle (0-kBridgeMaxAngle)
    tay
    lda Ram_PlatformTop_i16_0_arr, x
    sub _Delta_u8_arr, y
    sta Zp_PointY_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_PointY_i16 + 1
    inx
    lda #127  ; param: max distance to move by
    jsr Func_MovePlatformTopTowardPointY  ; preserves X
    dex
    ;; Position the next segment horizontally relative to the previous segment.
    ldy Zp_MachineIndex_u8
    lda #kBridgeMaxAngle
    sub Ram_MachineState1_byte_arr, y  ; bridge angle (0-kBridgeMaxAngle)
    sta T0  ; angle index
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    ldy T0  ; angle index
    and #bMachine::FlipH
    beq @facingRight
    @facingLeft:
    lda Ram_PlatformLeft_i16_0_arr, x
    sub _Delta_u8_arr, y
    sta Zp_PointX_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc #0
    sta Zp_PointX_i16 + 1
    jmp @moveHorz
    @facingRight:
    lda Ram_PlatformLeft_i16_0_arr, x
    add _Delta_u8_arr, y
    sta Zp_PointX_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    adc #0
    sta Zp_PointX_i16 + 1
    @moveHorz:
    inx
    lda #127  ; param: max distance to move by
    jsr Func_MovePlatformLeftTowardPointX  ; preserves X
    ;; Continue to the next pair of segments.
    pla  ; last platform index
    sta T0  ; last platform index
    pha  ; last platform index
    cpx T0  ; last platform index
    blt @loop
    pla  ; last platform index
    rts
_Delta_u8_arr:
    ;; [int(round(8 * sin(x * pi/32))) for x in range(0, 17)]
:   .byte 0, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 7, 7, 8, 8, 8, 8
    .assert * - :- = kBridgeMaxAngle + 1, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a drawbridge machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The platform index for the last movable segment.
.EXPORT FuncA_Objects_DrawBridgeMachine
.PROC FuncA_Objects_DrawBridgeMachine
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta T2  ; pivot platform index
_SegmentLoop:
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X and T0+
    lda #kTileIdObjBridgeSegment  ; param: tile ID
    ldy #kPaletteObjBridgeSegment  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape ; preserves X and T2+
    dex
    cpx T2  ; pivot platform index
    bne _SegmentLoop
_MainMachine:
    ;; At this point, X holds the machine's pivot (main) platform index.
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    jsr FuncA_Objects_MoveShapeDownOneTile
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    .assert bMachine::FlipH = bObj::FlipH, error
    beq @noFlip
    pha  ; horz flip
    jsr FuncA_Objects_MoveShapeRightOneTile
    pla  ; horz flip
    @noFlip:
    .assert kPaletteObjMachineLight <> 0, error
    ora #kPaletteObjMachineLight
    pha  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; returns C and Y
    pla  ; object flags
    bcs _Done
    ora #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdObjBridgeCornerBase
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
