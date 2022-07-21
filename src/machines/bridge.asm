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

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MachineFinishResetting
.IMPORT Func_MovePlatformLeftToward
.IMPORT Func_MovePlatformTopToward
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; Various OBJ tile IDs used for drawing bridge machines.
kTileIdBridgeCornerBase = kTileIdCannonFirst + $01
kTileIdBridgeSegment    = kTileIdCannonFirst + $05

;;; The OBJ palette number used for moveable bridge segments.
kBridgeSegmentPalette = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "Y" register for a bridge machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The value of the machine's "Y" register (0-1).
.EXPORT Func_MachineBridgeReadRegY
.PROC Func_MachineBridgeReadRegY
    ldy Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, y
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
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
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
    clc  ; clear C to indicate success
    rts
    @moveDown:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    beq @error
    dec Ram_MachineGoalVert_u8_arr, x
    lda #kBridgeMoveDownCountdown
    clc  ; clear C to indicate success
    rts
    @error:
    sec  ; set C to indicate failure
    rts
.ENDPROC

;;; Ticks the current bridge machine for the current frame.
;;; @param A The platform index for the fixed pivot segment.
;;; @param X The platform index for the last movable segment.
.EXPORT FuncA_Machine_BridgeTick
.PROC FuncA_Machine_BridgeTick
    sta Zp_Tmp1_byte  ; pivot platform index
    stx Zp_Tmp2_byte  ; last platform index
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    beq _MoveDown
    bne _MoveUp  ; unconditional
_Finished:
    jmp Func_MachineFinishResetting
_MoveUp:
    ldy Ram_MachineParam1_u8_arr, x
    cpy #kBridgeMaxAngle
    beq _Finished
    iny
    bne _SetAngle  ; unconditional
_MoveDown:
    ldy Ram_MachineParam1_u8_arr, x
    beq _Finished
    dey
    dey
    bpl @noUnderflow
    ldy #0
    @noUnderflow:
_SetAngle:
    tya
    sta Ram_MachineParam1_u8_arr, x
_RepositionSegments:
    ldx Zp_Tmp1_byte  ; pivot platform index
    lda Zp_Tmp2_byte  ; last platform index
    pha  ; last platform index
    ;; Loop through each consequtive pair of bridge segments, starting with the
    ;; fixed pivot segment and the first movable segment.
    @loop:
    ;; Position the next segment vertically relative to the previous segment.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, y
    tay
    lda Ram_PlatformTop_i16_0_arr, x
    sub _Delta_u8_arr, y
    sta Zp_PlatformGoal_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, x
    sbc #0
    sta Zp_PlatformGoal_i16 + 1
    inx
    lda #127  ; param: max distance to move by
    jsr Func_MovePlatformTopToward  ; preserves X
    dex
    ;; Position the next segment horizontally relative to the previous segment.
    ldy Zp_MachineIndex_u8
    lda #kBridgeMaxAngle
    sub Ram_MachineParam1_u8_arr, y
    sta Zp_Tmp1_byte  ; angle index
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    ldy Zp_Tmp1_byte  ; angle index
    and #bMachine::FlipH
    beq @facingRight
    @facingLeft:
    lda Ram_PlatformLeft_i16_0_arr, x
    sub _Delta_u8_arr, y
    sta Zp_PlatformGoal_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc #0
    sta Zp_PlatformGoal_i16 + 1
    jmp @moveHorz
    @facingRight:
    lda Ram_PlatformLeft_i16_0_arr, x
    add _Delta_u8_arr, y
    sta Zp_PlatformGoal_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, x
    adc #0
    sta Zp_PlatformGoal_i16 + 1
    @moveHorz:
    inx
    lda #127  ; param: max distance to move by
    jsr Func_MovePlatformLeftToward  ; preserves X
    ;; Continue to the next pair of segments.
    pla  ; last platform index
    sta Zp_Tmp1_byte  ; last platform index
    pha  ; last platform index
    cpx Zp_Tmp1_byte  ; last platform index
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
;;; @param A The platform index for the fixed pivot segment.
;;; @param X The platform index for the last movable segment.
.EXPORT FuncA_Objects_DrawBridgeMachine
.PROC FuncA_Objects_DrawBridgeMachine
_SegmentLoop:
    pha  ; pivot platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape ; preserves X, returns Y and C
    bcs @continue
    lda #kTileIdBridgeSegment
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kBridgeSegmentPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    pla  ; pivot platform index
    sta Zp_Tmp1_byte  ; pivot platform index
    dex
    cpx Zp_Tmp1_byte  ; pivot platform index
    bne _SegmentLoop
_MainMachine:
    tax  ; param: platform index
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
    .assert kMachineLightPalette <> 0, error
    ora #kMachineLightPalette
    pha  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; returns C and Y
    pla  ; object flags
    bcs _Done
    ora #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdBridgeCornerBase
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
