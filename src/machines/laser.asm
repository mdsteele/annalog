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
.INCLUDE "laser.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Alloc2x2MachineShape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeLeftHalfTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT Func_HarmAvatar
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_MachineState3_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosY_i16

;;;=========================================================================;;;

;;; How many frames a launcher machine spends per ACT operation.
kLaserActFrames = 90

;;; The width of the laser beam for hit detection purposes, in pixels.
kLaserBeamWidthPx = 8

;;; How many different images the laser beam goes through during its animation.
kLaserBeamAnimCount = 5
;;; How many VBlank frames each laser beam animation frame lasts for.
.DEFINE kLaserBeamAnimSlowdown 4
;;; How many frames the laser beam stays on screen for.
kLaserBeamDurationFrames = kLaserBeamAnimCount * kLaserBeamAnimSlowdown

;;; Various OBJ tile IDs used for drawing laser machines.
kTileIdObjLaserBarrel = kTileIdObjLaserFirst + 0
kTileIdObjLaserBeam1  = kTileIdObjLaserFirst + 1
kTileIdObjLaserBeam2  = kTileIdObjLaserFirst + 2
kTileIdObjLaserBeam3  = kTileIdObjLaserFirst + 3

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; ReadReg implemention for a laser machine's C register.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The value of the register (0-9).
.EXPORT Func_MachineLaserReadRegC
.PROC Func_MachineLaserReadRegC
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; laser color
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Checks if the point stored in Zp_PointX_i16 and Zp_PointY_i16 is inside a
;;; laser machine's beam.  If the machine is not currently firing a beam, the
;;; answer will be "no".
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return C Set if the point is in the beam, cleared otherwise.
;;; @preserve T2+
.EXPORT FuncA_Room_IsPointInLaserBeam
.PROC FuncA_Room_IsPointInLaserBeam
    ;; If debugging, answer "no".
    lda Zp_ConsoleMachineIndex_u8
    bpl _Outside
    ;; If the laser is not firing, answer "no".
    ldx Zp_MachineIndex_u8
    lda Ram_MachineSlowdown_u8_arr, x  ; laser beam frames remaining
    beq _Outside
_CheckBeamBottom:
    lda Zp_PointY_i16 + 0
    cmp Ram_MachineState2_byte_arr, x  ; laser beam bottom (lo)
    lda Zp_PointY_i16 + 1
    sbc Ram_MachineState3_byte_arr, x  ; laser beam bottom (hi)
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bpl _Outside
_CheckBeamTop:
    ;; The top of the beam is the bottom of the machine platform.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; machine platform index
    lda Zp_PointY_i16 + 0
    cmp Ram_PlatformBottom_i16_0_arr, y
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformBottom_i16_1_arr, y
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bmi _Outside
_CheckBeamLeft:
    lda Ram_PlatformLeft_i16_0_arr, y
    add #(kLaserMachineWidthPx - kLaserBeamWidthPx) / 2
    sta T0  ; laser beam left (lo)
    lda Ram_PlatformLeft_i16_1_arr, y
    adc #0
    sta T1  ; laser beam left (hi)
    lda Zp_PointX_i16 + 0
    cmp T0  ; laser beam left (lo)
    lda Zp_PointX_i16 + 1
    sbc T1  ; laser beam left (hi)
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bmi _Outside
_CheckBeamRight:
    lda Ram_PlatformRight_i16_0_arr, y
    sub #(kLaserMachineWidthPx - kLaserBeamWidthPx) / 2
    sta T0  ; laser beam right (lo)
    lda Ram_PlatformRight_i16_1_arr, y
    sbc #0
    sta T1  ; laser beam right (hi)
    lda Zp_PointX_i16 + 0
    cmp T0  ; laser beam right (lo)
    lda Zp_PointX_i16 + 1
    sbc T1  ; laser beam right (hi)
    bvc @noOverflow  ; N eor V
    eor #$80
    @noOverflow:
    bpl _Outside
_Inside:
    sec
    rts
_Outside:
    clc
    rts
.ENDPROC

;;; Checks if the player avatar is being hit by this laser machine's beam, and
;;; harms the avatar if so.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @preserve T2+
.EXPORT FuncA_Room_HarmAvatarIfWithinLaserBeam
.PROC FuncA_Room_HarmAvatarIfWithinLaserBeam
    jsr Func_SetPointToAvatarCenter  ; preserves T0+
    jsr FuncA_Room_IsPointInLaserBeam  ; preserves T2+, returns C
    jcs Func_HarmAvatar  ; preserves T0+
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implemention for laser machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_LaserWriteReg
.PROC FuncA_Machine_LaserWriteReg
    ldy Zp_MachineIndex_u8
    sta Ram_MachineState1_byte_arr, y  ; laser color
    rts
.ENDPROC

;;; TryAct implemention for laser machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param YA The room pixel Y-position for the bottom of the laser beam.
.EXPORT FuncA_Machine_LaserTryAct
.PROC FuncA_Machine_LaserTryAct
    ldx Zp_MachineIndex_u8
    sta Ram_MachineState2_byte_arr, x  ; laser beam bottom (lo)
    tya                                ; laser beam bottom (hi)
    sta Ram_MachineState3_byte_arr, x  ; laser beam bottom (hi)
    lda #kLaserBeamDurationFrames
    sta Ram_MachineSlowdown_u8_arr, x  ; laser beam frames remaining
    lda #kLaserActFrames  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for laser machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawLaserMachine
.PROC FuncA_Objects_DrawLaserMachine
_MainPlatform:
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2MachineShape  ; returns C, A, and Y
    bcs @done
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    eor #bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjLaserBarrel
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_LaserBeam:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineSlowdown_u8_arr, x  ; laser beam frames remaining
    beq @done
    ;; Compute the OBJ tile ID to use for the beam objects, storing it in T2.
    div #kLaserBeamAnimSlowdown
    tay
    lda _BeamTileId_u8_arr, y
    sta T2  ; beam tile ID
    ;; Compute the flags to use for the beam objets, storing it in T3.
    lda Ram_MachineState1_byte_arr, x  ; laser color
    and #$01
    tay
    iny
    sty T3  ; beam object flags
    ;; Set the shape position to the bottom-left corner of the beam.
    jsr FuncA_Objects_MoveShapeLeftHalfTile  ; preserves X and T0+
    lda Ram_MachineState2_byte_arr, x  ; laser beam bottom (lo)
    sub Zp_RoomScrollY_u8
    sta Zp_ShapePosY_i16 + 0
    lda Ram_MachineState3_byte_arr, x  ; laser beam bottom (hi)
    sbc #0
    sta Zp_ShapePosY_i16 + 1
    ;; Calculate the offset to the room-space beam bottom Y-position that will
    ;; give us the screen-space Y-position for the top of the beam.  Note that
    ;; we offset by an additional (kTileHeightPx - 1), so that when we divide
    ;; by kTileHeightPx later, it will effectively round up instead of down.
    lda Zp_RoomScrollY_u8
    add #kTileHeightPx - 1
    sta T0  ; offset
    ;; Calculate the screen-space Y-position of the top of the beam, storing
    ;; the lo byte in T0 and the hi byte in T1.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tax  ; machine platform index
    lda Ram_PlatformBottom_i16_0_arr, x
    sub T0  ; offset
    sta T0  ; screen-space beam top (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    sbc #0
    sta T1  ; screen-space beam top (hi)
    ;; Calculate the length of the beam, in pixels, storing the lo byte in
    ;; T0 and the hi byte in A.
    lda Zp_ShapePosY_i16 + 0
    sub T0  ; screen-space beam top (lo)
    sta T0  ; beam pixel length (lo)
    lda Zp_ShapePosY_i16 + 1
    sbc T1  ; screen-space beam top (hi)
    ;; Divide the beam pixel length by kTileHeightPx to get the length of the
    ;; beam in tiles, storing it in X.  Because we added an additional
    ;; (kTileHeightPx - 1) to the beam length above, this division will
    ;; effectively round up instead of down.
    .assert kTileHeightPx = 8, error
    .repeat 3
    lsr a
    ror T0  ; beam pixel length (lo)
    .endrepeat
    ldx T0  ; param: beam length in tiles
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X
    ldy T3  ; param: beam object flags
    lda T2  ; param: beam tile ID
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    dex
    bne @loop
    @done:
    rts
_BeamTileId_u8_arr:
:   .byte kTileIdObjLaserBeam1
    .byte kTileIdObjLaserBeam2
    .byte kTileIdObjLaserBeam3
    .byte kTileIdObjLaserBeam2
    .byte kTileIdObjLaserBeam1
    .assert * - :- = kLaserBeamAnimCount, error
.ENDPROC

;;;=========================================================================;;;
