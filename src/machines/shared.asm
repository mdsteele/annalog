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
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"

.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing machine status lights.
kMachineLightTileIdOff = $3e
kMachineLightTileIdOn  = $3f

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tries to move the current machine's horizontal goal value, where goal
;;; position zero is the leftmost position, and the only constraint is that the
;;; horizontal goal value must be between zero and the given max, inclusive.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param A The maximum permitted vertical goal value.
;;; @param X The eDir value for the direction to move in (up or down).
.EXPORT FuncA_Machine_GenericTryMoveX
.PROC FuncA_Machine_GenericTryMoveX
    sta Zp_Tmp1_byte  ; max goal horz
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalHorz_u8_arr, y
    cpx #eDir::Right
    bne @moveLeft
    @moveRight:
    cmp Zp_Tmp1_byte  ; max goal horz
    bge @error
    tax
    inx
    bne @success  ; unconditional
    @moveLeft:
    tax
    beq @error
    dex
    @success:
    txa
    sta Ram_MachineGoalHorz_u8_arr, y
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

;;; Tries to move the current machine's vertical goal value, where goal
;;; position zero is the lowest position, and the only constraint is that the
;;; vertical goal value must be between zero and the given max, inclusive.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param A The maximum permitted vertical goal value.
;;; @param X The eDir value for the direction to move in (up or down).
.EXPORT FuncA_Machine_GenericTryMoveY
.PROC FuncA_Machine_GenericTryMoveY
    sta Zp_Tmp1_byte  ; max goal vert
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    cpx #eDir::Up
    bne @moveDown
    @moveUp:
    cmp Zp_Tmp1_byte  ; max goal vert
    bge @error
    add #1
    bne @success  ; unconditional
    @moveDown:
    tax
    beq @error
    dex
    txa
    @success:
    sta Ram_MachineGoalVert_u8_arr, y
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

;;; Tries to move the current machine's vertical goal value, where goal
;;; position zero is the highest position, and the only constraint is that the
;;; vertical goal value must be between zero and the given max, inclusive.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param A The maximum permitted vertical goal value.
;;; @param X The eDir value for the direction to move in (up or down).
.EXPORT FuncA_Machine_GenericTryMoveZ
.PROC FuncA_Machine_GenericTryMoveZ
    sta Zp_Tmp1_byte  ; max goal vert
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    cpx #eDir::Up
    beq @moveUp
    @moveDown:
    cmp Zp_Tmp1_byte  ; max goal vert
    bge @error
    add #1
    bne @success  ; unconditional
    @moveUp:
    tax
    beq @error
    dex
    txa
    @success:
    sta Ram_MachineGoalVert_u8_arr, y
    jmp FuncA_Machine_StartWorking
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

;;; Moves the current machine's platform towards its horizontal goal position.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The minimum platform left position for the machine.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved left, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
.EXPORT FuncA_Machine_GenericMoveTowardGoalHorz
.PROC FuncA_Machine_GenericMoveTowardGoalHorz
    sta Zp_Tmp1_byte  ; min platform left (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp2_byte  ; platform index
    ;; Calculate the desired X-position for the left edge of the machine, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalHorz_u8_arr, y
    mul #kBlockHeightPx
    sta Zp_Tmp3_byte  ; goal delta
    txa               ; max platform top (lo)
    add Zp_Tmp3_byte  ; goal delta
    sta Zp_PointX_i16 + 0
    lda Zp_Tmp1_byte  ; max platform top (hi)
    adc #0
    sta Zp_PointX_i16 + 1
    ;; Determine the horizontal speed of the machine (faster if resetting).
    ldx Ram_MachineStatus_eMachine_arr, y
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the machine horizontally, as necessary.
    ldx Zp_Tmp2_byte  ; param: platform index
    jmp Func_MovePlatformLeftTowardPointX  ; returns Z, N, and A
.ENDPROC

;;; Moves the current machine's platform towards its vertical goal position.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The maximum platform top position for the machine.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved up, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
.EXPORT FuncA_Machine_GenericMoveTowardGoalVert
.PROC FuncA_Machine_GenericMoveTowardGoalVert
    sta Zp_Tmp1_byte  ; max platform top (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp2_byte  ; platform index
    ;; Calculate the desired Y-position for the top edge of the machine, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    mul #kBlockHeightPx
    sta Zp_Tmp3_byte  ; goal delta
    txa               ; max platform top (lo)
    sub Zp_Tmp3_byte  ; goal delta
    sta Zp_PointY_i16 + 0
    lda Zp_Tmp1_byte  ; max platform top (hi)
    sbc #0
    sta Zp_PointY_i16 + 1
    ;; Determine the vertical speed of the machine (faster if resetting).
    ldx Ram_MachineStatus_eMachine_arr, y
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the machine vertically, as necessary.
    ldx Zp_Tmp2_byte  ; param: platform index
    jmp Func_MovePlatformTopTowardPointY  ; returns Z, N, and A
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Returns the tile ID to use for the status light on the current machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The tile ID to use.
;;; @preserve Y, Zp_Tmp*
.EXPORT FuncA_Objects_GetMachineLightTileId
.PROC FuncA_Objects_GetMachineLightTileId
    ldx Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #eMachine::Error
    beq @error
    cpx Zp_ConsoleMachineIndex_u8
    beq @lightOn
    bne @lightOff  ; unconditional
    @error:
    lda Zp_FrameCounter_u8
    and #$08
    beq @lightOff
    @lightOn:
    lda #kMachineLightTileIdOn
    rts
    @lightOff:
    lda #kMachineLightTileIdOff
    rts
.ENDPROC

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the top-left corner of the current machine's primary platform.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @preserve Zp_Tmp*
.EXPORT FuncA_Objects_SetShapePosToMachineTopLeft
.PROC FuncA_Objects_SetShapePosToMachineTopLeft
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tax  ; param: platform index
    jmp FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves Zp_Tmp*
.ENDPROC

;;;=========================================================================;;;
