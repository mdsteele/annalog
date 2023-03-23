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
.INCLUDE "../actors/particle.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "minigun.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjBullet
.IMPORT Func_SetActorCenterToPoint
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_MachineParam2_i16_0_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; The cooldown time between minigun shots, in frames.
kMinigunCooldownFrames = 16

;;; Tile IDs for drawing minigun machines.
kTileIdObjMinigunCorner  = kTileIdObjMachineCorner
kTileIdObjMinigunSurface = kTileIdObjMachineSurfaceHorz

;;; The OBJ palette number used for drawing minigun barrels.
kPaletteObjMinigun = 0

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryAct implemention for minigun machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The eDir value for the bullet direction.
.EXPORT FuncA_Machine_MinigunTryAct
.PROC FuncA_Machine_MinigunTryAct
    jsr Func_FindEmptyActorSlot  ; preserves Y, sets C on failure, returns X
    jcs _DoneWithBullet
    sty Zp_Tmp1_byte  ; bullet direction
    ;; Compute the firing offset, storing it in Zp_Tmp2_byte.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, y  ; shot counter
    and #$03
    tay
    lda _FiringOffset_i8_arr4, y
    sta Zp_Tmp2_byte  ; firing offset (signed)
    ;; Get the minigun's platform index, storing it in Y.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; platform index
_SetBulletPosition:
    ;; Position the new bullet actor.
    lda Zp_Tmp1_byte  ; bullet direction
    .assert eDir::Up = 0, error
    beq _BulletUp
    cmp #eDir::Down
    beq _BulletDown
_BulletLeft:
    lda Ram_PlatformLeft_i16_0_arr, y
    sub #kTileWidthPx / 2
    sta Zp_PointX_i16 + 0
    lda Ram_PlatformLeft_i16_1_arr, y
    sbc #0
    sta Zp_PointX_i16 + 1
_BulletHorz:
    lda Ram_PlatformBottom_i16_0_arr, y
    sub Ram_PlatformTop_i16_0_arr, y
    div #2
    add Zp_Tmp2_byte  ; firing offset (signed)
    add Ram_PlatformTop_i16_0_arr, y
    sta Zp_PointY_i16 + 0
    lda #0
    adc Ram_PlatformTop_i16_1_arr, y
    sta Zp_PointY_i16 + 1
    jmp _InitBullet
_BulletUp:
    lda Ram_PlatformTop_i16_0_arr, y
    sub #kTileHeightPx / 2
    sta Zp_PointY_i16 + 0
    lda Ram_PlatformTop_i16_1_arr, y
    sbc #0
    sta Zp_PointY_i16 + 1
    jmp _BulletVert
_BulletDown:
    lda Ram_PlatformBottom_i16_0_arr, y
    add #kTileHeightPx / 2
    sta Zp_PointY_i16 + 0
    lda Ram_PlatformBottom_i16_1_arr, y
    adc #0
    sta Zp_PointY_i16 + 1
_BulletVert:
    lda Ram_PlatformRight_i16_0_arr, y
    sub Ram_PlatformLeft_i16_0_arr, y
    div #2
    add Zp_Tmp2_byte  ; firing offset (signed)
    add Ram_PlatformLeft_i16_0_arr, y
    sta Zp_PointX_i16 + 0
    lda #0
    adc Ram_PlatformLeft_i16_1_arr, y
    sta Zp_PointY_i16 + 1
_InitBullet:
    jsr Func_SetActorCenterToPoint  ; preserves X, Y, and Zp_Tmp*
    lda Zp_Tmp1_byte  ; param: bullet direction
    jsr Func_InitActorProjBullet  ; preserves X
    ;; If debugging, replace the bullet with a smoke particle.
    lda Zp_ConsoleMachineIndex_u8
    bmi _DoneWithBullet
    lda #eActor::SmokeParticle
    sta Ram_ActorType_eActor_arr, x
    lda #0
    sta Ram_ActorState1_byte_arr, x  ; particle age in frames
_DoneWithBullet:
    ldx Zp_MachineIndex_u8
    inc Ram_MachineParam1_u8_arr, x  ; shot counter
    lda #kMinigunCooldownFrames  ; param: number of frames
    sta Ram_MachineParam2_i16_0_arr, x  ; barrel rotation counter
    jmp FuncA_Machine_StartWaiting
_FiringOffset_i8_arr4:
    .byte 2, 0, <-2, 0
.ENDPROC

;;; Updates the minigun machine's barrel rotation.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_MinigunRotateBarrel
.PROC FuncA_Machine_MinigunRotateBarrel
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam2_i16_0_arr, x  ; barrel rotation counter
    beq @done
    dec Ram_MachineParam2_i16_0_arr, x  ; barrel rotation counter
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for upward-facing minigun machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawMinigunUpMachine
.PROC FuncA_Objects_DrawMinigunUpMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_BarrelAnimation:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam2_i16_0_arr, x  ; barrel rotation counter
    div #2
    and #$06
    tax  ; barrel tile ID offset
_LeftHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X
    lda #kPaletteObjMinigun  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X; returns C and Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kPaletteObjMinigun | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kPaletteObjMinigun | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kPaletteObjMinigun | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjMinigunCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    txa  ; barrel tile ID offset
    adc #kTileIdObjMinigunVertFirst + 0  ; carry is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjMinigunSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_RightHalf:
    ;; Allocate objects.
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    lda #kPaletteObjMinigun  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X; returns C and Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kPaletteObjMinigun | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    txa  ; barrel tile ID offset
    adc #kTileIdObjMinigunVertFirst + 1  ; carry is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdObjMinigunSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjMinigunCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draw implemention for upward-facing minigun machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawMinigunDownMachine
.PROC FuncA_Objects_DrawMinigunDownMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_BarrelAnimation:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam2_i16_0_arr, x  ; barrel rotation counter
    div #2
    and #$06
    tax  ; barrel tile ID offset
_LeftHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X
    lda #kPaletteObjMinigun  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X; returns C and Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kPaletteObjMinigun | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kPaletteObjMinigun | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kTileIdObjMinigunCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjMinigunSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    txa  ; barrel tile ID offset
    adc #kTileIdObjMinigunVertFirst + 1  ; carry is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_RightHalf:
    ;; Allocate objects.
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    lda #kPaletteObjMinigun  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X; returns C and Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kPaletteObjMinigun | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kPaletteObjMinigun | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjMinigunSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    txa  ; barrel tile ID offset
    adc #kTileIdObjMinigunVertFirst + 0  ; carry is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjMinigunCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draw implemention for side-facing minigun machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawMinigunSideMachine
.PROC FuncA_Objects_DrawMinigunSideMachine
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
_BarrelAnimation:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineParam2_i16_0_arr, x  ; barrel rotation counter
    div #2
    and #$06
    tax  ; barrel tile ID offset
_LeftHalf:
    ;; Allocate objects.
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves X
    lda #kPaletteObjMinigun  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X; returns C and Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kPaletteObjMinigun | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    txa  ; barrel tile ID offset
    adc #kTileIdObjMinigunHorzFirst  ; carry is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjMinigunSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
_RightHalf:
    ;; Allocate objects.
    lda #kTileWidthPx * 2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA  ; preserves X
    lda #kPaletteObjMinigun  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X; returns C and Y
    bcs @done
    ;; Set flags and tile IDs.
    lda #kPaletteObjMinigun | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjMachineLight | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    lda #kTileIdObjMinigunSurface
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjMinigunCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
