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
.INCLUDE "blaster.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Alloc2x2MachineShape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjFireball
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointHorz
.IMPORT Func_ReinitActorProjFireballVelocity
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState2_byte_arr
.IMPORT Ram_MachineState3_byte_arr
.IMPORT Ram_MachineState4_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; The offset, in pixels, from the center of the blaster machine's platform at
;;; which to place newly-fired projectiles.
kBlasterProjectileOffset = 9

;;; How many frames a blaster machine spends per ACT operation.
kBlasterActCountdown = $60

;;; Various OBJ tile IDs used for drawing blaster machines.
kTileIdObjBlasterBarrelVert = kTileIdObjBlasterFirst + 0
kTileIdObjBlasterBarrelHorz = kTileIdObjBlasterFirst + 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; ReadReg implemention for a blaster machine's mirrors.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The mirror register to read ($c or $d).
;;; @return A The value of the register (0-9).
.EXPORT Func_MachineBlasterReadRegMirrors
.PROC Func_MachineBlasterReadRegMirrors
    ldx Zp_MachineIndex_u8
    cmp #$0d
    beq @mirror2
    @mirror1:
    lda Ram_MachineState1_byte_arr, x
    rts
    @mirror2:
    lda Ram_MachineState2_byte_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implemention for a blaster machine's mirrors.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c or $d).
.EXPORT FuncA_Machine_BlasterWriteRegMirrors
.PROC FuncA_Machine_BlasterWriteRegMirrors
    ldy Zp_MachineIndex_u8
    cpx #$0d
    beq @mirror2
    @mirror1:
    cmp Ram_MachineState1_byte_arr, y
    beq @done
    sta Ram_MachineState1_byte_arr, y
    jmp FuncA_Machine_StartWorking
    @mirror2:
    cmp Ram_MachineState2_byte_arr, y
    beq @done
    sta Ram_MachineState2_byte_arr, y
    jmp FuncA_Machine_StartWorking
    @done:
    rts
.ENDPROC

;;; TryAct implemention for vertical blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_BlasterVertTryAct
.PROC FuncA_Machine_BlasterVertTryAct
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    lda #kBlasterProjectileOffset  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    ldy #$40  ; param: projectile angle
    bne FuncA_Machine_BlasterShootFireball  ; unconditional
.ENDPROC

;;; TryAct implemention for horizontal blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_BlasterHorzTryAct
.PROC FuncA_Machine_BlasterHorzTryAct
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    beq @shootRight
    @shootLeft:
    ldy #$80  ; projectile angle
    lda #<-kBlasterProjectileOffset  ; param: offset
    bmi @movePoint  ; unconditional
    @shootRight:
    ldy #$00  ; projectile angle
    lda #kBlasterProjectileOffset  ; param: offset
    @movePoint:
    jsr Func_MovePointHorz  ; preserves X and Y
    .assert * = FuncA_Machine_BlasterShootFireball, error, "fallthrough"
.ENDPROC

;;; Shoots a fireball from a blaster machine, and makes the machine starting
;;; waiting for a bit.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Point* stores the starting position of the fireball.
;;; @param Y The angle to fire at, measured in increments of tau/256.
.PROC FuncA_Machine_BlasterShootFireball
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs _Finish
_InitProjectile:
    jsr Func_SetActorCenterToPoint  ; preserves X and Y
    tya  ; param: projectile angle
    jsr Func_InitActorProjFireball
    ;; If the console is active, then we must be debugging, so immediately
    ;; replace the fireball with a smoke particle (so as to dry-fire the
    ;; blaster).
    lda Zp_ConsoleMachineIndex_u8
    bmi @done
    lda #eActor::SmokeParticle
    sta Ram_ActorType_eActor_arr, x
    lda #0
    sta Ram_ActorState1_byte_arr, x  ; particle age in frames
    @done:
_PlaySound:
    ;; TODO: Play a sound for firing the blaster.
_Finish:
    lda #kBlasterActCountdown  ; param: wait frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;; Tick implemention for blaster machine mirrors.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The number of mirrors that moved.
;;; @return Z Set if no mirrors moved.
;;; @preserve T1+
.EXPORT FuncA_Machine_BlasterTickMirrors
.PROC FuncA_Machine_BlasterTickMirrors
    lda #0
    sta T0  ; num mirrors moved
    ldx Zp_MachineIndex_u8
_Mirror1:
    lda Ram_MachineState1_byte_arr, x  ; mirror 1 goal
    mul #kBlasterMirrorAnimSlowdown
    cmp Ram_MachineState3_byte_arr, x  ; mirror 1 animation angle
    beq @done
    blt @decrement
    @increment:
    inc Ram_MachineState3_byte_arr, x  ; mirror 1 animation angle
    bne @moved  ; unconditional
    @decrement:
    dec Ram_MachineState3_byte_arr, x  ; mirror 1 animation angle
    @moved:
    inc T0  ; num mirrors moved
    @done:
_Mirror2:
    lda Ram_MachineState2_byte_arr, x  ; mirror 2 goal
    mul #kBlasterMirrorAnimSlowdown
    cmp Ram_MachineState4_byte_arr, x  ; mirror 2 animation angle
    beq @done
    blt @decrement
    @increment:
    inc Ram_MachineState4_byte_arr, x  ; mirror 2 animation angle
    bne @moved  ; unconditional
    @decrement:
    dec Ram_MachineState4_byte_arr, x  ; mirror 2 animation angle
    @moved:
    inc T0  ; num mirrors moved
    @done:
_Finish:
    lda T0  ; num mirrors moved
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Checks if any fireballs are hitting the specified mirror, and if so,
;;; reflects them off of the mirror.
;;; @param A The absolute mirror angle, in increments of tau/16.
;;; @param Y The platform index for the mirror.
;;; @preserve Y, T3+
.EXPORT FuncA_Room_ReflectFireballsOffMirror
.PROC FuncA_Room_ReflectFireballsOffMirror
    mul #$10
    sta T2  ; absolute mirror angle (in tau/256 units)
    ldx #kMaxActors - 1
_Loop:
    ;; If this actor isn't a fireball projectile, skip it.
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjFireball
    bne _Continue
    ;; If the fireball was recently reflected off of a mirror (probably this
    ;; one), skip it.
    lda Ram_ActorState3_byte_arr, x  ; fireball reflection timer
    bne _Continue
    ;; If the fireball isn't hitting this mirror this frame, skip it.
    jsr Func_SetPointToActorCenter  ; preserves X, Y, and T0+
    jsr Func_IsPointInPlatform  ; preserves X, Y, and T0+; returns C
    bcc _Continue
    ;; Compute the reversed fireball angle relative to the mirror angle.
    lda Ram_ActorState1_byte_arr, x  ; fireball angle (in tau/256 units)
    eor #$80
    sub T2  ; absolute mirror angle (in tau/256 units)
    ;; If the fireball hits the back of the mirror, remove the fireball.
    cmp #$c1
    bge _Reflect
    cmp #$40
    bge _Remove
_Reflect:
    ;; Negate the fireball's relative angle, and add it to the mirror's
    ;; absolute angle to get a new absolute angle for the fireball.
    eor #$ff
    add #1
    add T2  ; absolute mirror angle (in tau/256 units)
    sta Ram_ActorState1_byte_arr, x  ; fireball angle (in tau/256 units)
    jsr Func_ReinitActorProjFireballVelocity  ; preserves X, Y, and T2+
    ;; Snap the fireball to the center of the mirror.
    jsr Func_SetPointToPlatformCenter  ; preserves X, Y, and T0+
    jsr Func_SetActorCenterToPoint  ; preserves X, Y, and T0+
    ;; Set the fireball's reflection timer, so that it won't immediately hit
    ;; this mirror again.
    lda #3
    sta Ram_ActorState3_byte_arr, x  ; reflection timer
    bne _Continue  ; unconditional
_Remove:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
_Continue:
    dex
    .assert kMaxActors <= $80, error
    bpl _Loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for horizontal blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawBlasterMachineHorz
.PROC FuncA_Objects_DrawBlasterMachineHorz
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2MachineShape  ; returns C, A, and Y
    bcs @done
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    eor #bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdObjBlasterBarrelHorz
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draw implemention for vertical blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawBlasterMachineVert
.PROC FuncA_Objects_DrawBlasterMachineVert
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2MachineShape  ; returns C, A, and Y
    bcs @done
    eor #bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #kTileIdObjMachineCorner
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdObjBlasterBarrelVert
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draws a mirror that can reflect blaster machine projectiles.
;;; @param A The absolute mirror angle, in increments of tau/16.
;;; @param X The platform index for the mirror.
;;; @preserve T2+
.EXPORT FuncA_Objects_DrawBlasterMirror
.PROC FuncA_Objects_DrawBlasterMirror
    tay  ; mirror angle
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves Y and T0+
    tya  ; mirror angle
    div #4
    and #$03
    tax
    tya  ; mirror angle
    ldy _Flags_bObj_arr4, x  ; param: object flags
    and #$07
    tax  ; mirror angle (mod 8)
    lda _TileId_u8_arr8, x  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape  ; preserves T2+
_TileId_u8_arr8:
    .byte kTileIdObjMirrorFirst + 0
    .byte kTileIdObjMirrorFirst + 1
    .byte kTileIdObjMirrorFirst + 2
    .byte kTileIdObjMirrorFirst + 3
    .byte kTileIdObjMirrorFirst + 4
    .byte kTileIdObjMirrorFirst + 3
    .byte kTileIdObjMirrorFirst + 2
    .byte kTileIdObjMirrorFirst + 1
_Flags_bObj_arr4:
    .byte 0, bObj::FlipH, bObj::FlipHV, bObj::FlipV
.ENDPROC

;;;=========================================================================;;;
