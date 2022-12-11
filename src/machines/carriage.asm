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
.INCLUDE "../terrain.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_GetTerrainColumnPtrForTileIndex
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_TerrainColumn_u8_arr_ptr
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte
.IMPORTZP Zp_Tmp3_byte
.IMPORTZP Zp_Tmp4_byte
.IMPORTZP Zp_Tmp5_byte

;;;=========================================================================;;;

;;; Tile IDs for drawing the TempleLobbyCarriage machine.
kTileIdObjCarriageCorner  = kTileIdMachineCorner
kTileIdObjCarriageSurface = $7a

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Tries to move the current carriage machine's horizontal or vertical goal
;;; value.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The maximum permitted horizontal goal value.
;;; @param Y The maximum permitted vertical goal value.
;;; @param X The eDir value for the direction to move in.
.EXPORT FuncA_Machine_CarriageTryMove
.PROC FuncA_Machine_CarriageTryMove
    sta Zp_Tmp4_byte  ; max goal horz
    sty Zp_Tmp5_byte  ; max goal vert
    ;; Get the carriage platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp1_byte  ; platform index
    ;; Check if the direction is vertical or horizontal.
    cpx #kFirstHorzDir
    bge _TryMoveHorz
_TryMoveVert:
    ;; Calculate the room tile column index for the left side of the carriage,
    ;; storing it in Zp_Tmp2_byte.
    ldy Zp_Tmp1_byte  ; platform index
    lda Ram_PlatformLeft_i16_0_arr, y
    add #kTileWidthPx
    sta Zp_Tmp2_byte  ; X position (lo)
    lda Ram_PlatformLeft_i16_1_arr, y
    adc #0
    .assert kTileWidthPx = (1 << 3), error
    .repeat 3
    lsr a
    ror Zp_Tmp2_byte  ; room tile column index
    .endrepeat
    ;; Check if the carriage is trying to move up or down.
    txa  ; eDir value
    .assert eDir::Up = 0, error
    bne _TryMoveDown
_TryMoveUp:
    ;; If the current vert goal is the maximum, the carriage can't move up.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    cmp Zp_Tmp5_byte  ; max goal vert
    bge _Error
    ;; If either terrain block above the carriage is solid, the carriage can't
    ;; move up.
    ldy Zp_Tmp1_byte  ; platform index
    lda Ram_PlatformTop_i16_0_arr, y
    sub #kTileHeightPx
    sta Zp_Tmp3_byte  ; Y position (lo)
    lda Ram_PlatformTop_i16_1_arr, y
    sbc #0
    jsr _CheckIfSolidVert  ; sets C if the terrain is solid
    bcs _Error
    ;; Start moving the carriage upwards.
    ldx Zp_MachineIndex_u8
    inc Ram_MachineGoalVert_u8_arr, x
    jmp FuncA_Machine_StartWorking
_TryMoveDown:
    ;; If the current vert goal is zero, the carriage can't move left.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    beq _Error
    ;; If either terrain block below the carriage is solid, the carriage can't
    ;; move down.
    ldy Zp_Tmp1_byte  ; platform index
    lda Ram_PlatformBottom_i16_0_arr, y
    add #kTileHeightPx
    sta Zp_Tmp3_byte  ; Y position (lo)
    lda Ram_PlatformBottom_i16_1_arr, y
    adc #0
    jsr _CheckIfSolidVert  ; sets C if the terrain is solid
    bcs _Error
    ;; Start moving the carriage downwards.
    ldx Zp_MachineIndex_u8
    dec Ram_MachineGoalVert_u8_arr, x
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
_TryMoveHorz:
    ;; Calculate the room block row index for the center of the carriage,
    ;; storing it in Zp_Tmp2_byte.
    ldy Zp_Tmp1_byte  ; platform index
    lda Ram_PlatformTop_i16_0_arr, y
    add #kTileHeightPx
    sta Zp_Tmp2_byte  ; Y position (lo)
    lda Ram_PlatformTop_i16_1_arr, y
    adc #0
    .assert kBlockHeightPx = (1 << 4), error
    .repeat 4
    lsr a
    ror Zp_Tmp2_byte  ; room block row index
    .endrepeat
    ;; Check if the carriage is trying to move left or right.
    cpx #eDir::Right
    beq _TryMoveRight
_TryMoveLeft:
    ;; If the current horz goal is zero, the carriage can't move left.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalHorz_u8_arr, x
    beq _Error
    ;; If the terrain block to the left of the carriage is solid, the carriage
    ;; can't move left.
    ldx Zp_Tmp1_byte  ; platform index
    lda Ram_PlatformLeft_i16_0_arr, x
    sub #kTileWidthPx
    sta Zp_Tmp3_byte  ; X position (lo)
    lda Ram_PlatformLeft_i16_1_arr, x
    sbc #0
    jsr _CheckIfSolidHorz  ; sets C if the terrain is solid
    bcs _Error
    ;; Start moving the carriage to the left.
    ldx Zp_MachineIndex_u8
    dec Ram_MachineGoalHorz_u8_arr, x
    jmp FuncA_Machine_StartWorking
_TryMoveRight:
    ;; If the current horz goal is the maximum, the carriage can't move right.
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalHorz_u8_arr, x
    cmp Zp_Tmp4_byte  ; max goal horz
    bge _Error
    ;; If the terrain block to the right of the carriage is solid, the carriage
    ;; can't move right.
    ldx Zp_Tmp1_byte  ; platform index
    lda Ram_PlatformRight_i16_0_arr, x
    add #kTileWidthPx
    sta Zp_Tmp3_byte  ; X position (lo)
    lda Ram_PlatformRight_i16_1_arr, x
    adc #0
    jsr _CheckIfSolidHorz  ; sets C if the terrain is solid
    bcs _Error
    ;; Start moving the carriage to the right.
    ldx Zp_MachineIndex_u8
    inc Ram_MachineGoalHorz_u8_arr, x
    jmp FuncA_Machine_StartWorking
_CheckIfSolidHorz:
    ;; At this point, Zp_Tmp2_byte holds the room block row index to check, and
    ;; A (hi) and Zp_Tmp3_byte (lo) store the room pixel X-position to check.
    .assert kTileWidthPx = (1 << 3), error
    .repeat 3
    lsr a
    ror Zp_Tmp3_byte  ; X position (lo)
    .endrepeat
    lda Zp_Tmp3_byte  ; param: room tile column index
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldy Zp_Tmp2_byte  ; room block row index
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType  ; sets C if the terrain is solid
    rts
_CheckIfSolidVert:
    ;; At this point, Zp_Tmp2_byte holds the left-hand block column index to
    ;; check, and A (hi) and Zp_Tmp3_byte (lo) store the room pixel Y-position
    ;; to check.
    .assert kBlockHeightPx = (1 << 4), error
    .repeat 4
    lsr a
    ror Zp_Tmp3_byte  ; room block row index
    .endrepeat
    ;; Check the left-hand terrain block:
    lda Zp_Tmp2_byte  ; param: room tile column index
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldy Zp_Tmp3_byte  ; room block row index
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType  ; sets C if the terrain is solid
    bcs @return
    ;; Check the right-hand terrain block:
    lda Zp_Tmp2_byte
    adc #2  ; param: room tile column index (carry is already clear)
    jsr Func_GetTerrainColumnPtrForTileIndex  ; preserves Zp_Tmp*
    ldy Zp_Tmp3_byte  ; room block row index
    lda (Zp_TerrainColumn_u8_arr_ptr), y
    cmp #kFirstSolidTerrainType  ; sets C if the terrain is solid
    @return:
    rts
.ENDPROC

;;; Moves the current carriage machine's platform towards its horizontal goal
;;; position.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The minimum platform left position for the carriage machine.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved left, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
.EXPORT FuncA_Machine_CarriageMoveTowardGoalHorz
.PROC FuncA_Machine_CarriageMoveTowardGoalHorz
    sta Zp_Tmp1_byte  ; min platform left (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp2_byte  ; platform index
    ;; Calculate the desired X-position for the left edge of the carriage, in
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
    ;; Determine the horizontal speed of the carriage (faster if resetting).
    ldx Ram_MachineStatus_eMachine_arr, y
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the carriage horizontally, as necessary.
    ldx Zp_Tmp2_byte  ; param: platform index
    jmp Func_MovePlatformLeftTowardPointX  ; returns Z, N, and A
.ENDPROC

;;; Moves the current carriage machine's platform towards its vertical goal
;;; position.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The maximum platform top position for the carriage machine.
;;; @return A The pixel delta that the platform actually moved by (signed).
;;; @return N Set if the platform moved up, cleared otherwise.
;;; @return Z Cleared if the platform moved, set if it didn't.
.EXPORT FuncA_Machine_CarriageMoveTowardGoalVert
.PROC FuncA_Machine_CarriageMoveTowardGoalVert
    sta Zp_Tmp1_byte  ; max platform top (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta Zp_Tmp2_byte  ; platform index
    ;; Calculate the desired Y-position for the top edge of the carriage, in
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
    ;; Determine the vertical speed of the carriage (faster if resetting).
    ldx Ram_MachineStatus_eMachine_arr, y
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the carriage vertically, as necessary.
    ldx Zp_Tmp2_byte  ; param: platform index
    jmp Func_MovePlatformTopTowardPointY  ; returns Z, N, and A
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for carriage machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawCarriageMachine
.PROC FuncA_Objects_DrawCarriageMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_LeftHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjCarriageCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjCarriageSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_RightHalf:
    ;; Allocate objects.
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kMachineLightPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; sets C if offscreen; returns Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kMachineLightPalette | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kMachineLightPalette | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjCarriageSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjCarriageCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
