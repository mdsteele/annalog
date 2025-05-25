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

.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Alloc2x2MachineShape
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjFireblast
.IMPORT Func_InitActorSmokeParticleStationary
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePointDownByA
.IMPORT Func_PlaySfxShootFire
.IMPORT Func_ReinitActorProjFireblastVelocity
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineState3_byte_arr
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

;;; The offset from relative to absolute angles for blaster mirrors, in
;;; increments of tau/16.
kMirrorAngleOffset = 7

;;; Various OBJ tile IDs used for drawing blaster machines.
kTileIdObjBlasterBarrel = kTileIdObjBlasterFirst + 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; ReadReg implemention for a blaster machine's M (mirror) register.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The value of the register (0-9).
.EXPORT Func_MachineBlasterReadRegM
.PROC Func_MachineBlasterReadRegM
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implemention for a blaster machine's M (mirror) register.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_BlasterWriteRegM
.PROC FuncA_Machine_BlasterWriteRegM
    ldy Zp_MachineIndex_u8
    cmp Ram_MachineState1_byte_arr, y
    beq @done
    sta Ram_MachineState1_byte_arr, y
    jmp FuncA_Machine_StartWorking
    @done:
    rts
.ENDPROC

;;; TryAct implemention for vertical blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_BlasterTryAct
.PROC FuncA_Machine_BlasterTryAct
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs _Finish
_InitProjectile:
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay  ; param: platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X
    lda #kBlasterProjectileOffset  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
    lda #$40  ; param: projectile angle
    jsr Func_InitActorProjFireblast  ; preserves X
    ;; If the console is active, then we must be debugging, so immediately
    ;; replace the fireblast with a smoke particle (so as to dry-fire the
    ;; blaster).
    lda Zp_ConsoleMachineIndex_u8
    bmi @done
    lda #eActor::SmokeParticle
    sta Ram_ActorType_eActor_arr, x
    lda #0
    sta Ram_ActorState1_byte_arr, x  ; particle age in frames
    @done:
_PlaySound:
    jsr Func_PlaySfxShootFire
_Finish:
    lda #kBlasterActCountdown  ; param: wait frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;; Tick implemention for vertical blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param AX The minimum platform left position for the machine.
.EXPORT FuncA_Machine_BlasterTick
.PROC FuncA_Machine_BlasterTick
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns A
    sta T0  ; nonzero if moved
_TickMirrors:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; mirror goal
    mul #kBlasterMirrorAnimSlowdown
    cmp Ram_MachineState3_byte_arr, x  ; mirror animation angle
    beq @done
    blt @decrement
    @increment:
    inc Ram_MachineState3_byte_arr, x  ; mirror 1 animation angle
    bne @moved  ; unconditional
    @decrement:
    dec Ram_MachineState3_byte_arr, x  ; mirror 1 animation angle
    @moved:
    inc T0  ; nonzero if moved
    @done:
_CheckIfReachedGoal:
    lda T0  ; nonzero if moved
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Checks if any fireblasts are hitting the specified mirror, and if so,
;;; reflects them off of the mirror.
;;; @param X The machine index for the blaster that controls this mirror.
;;; @param Y The platform index for the mirror.
;;; @preserve X, Y
.EXPORT FuncA_Room_ReflectFireblastsOffMirror
.PROC FuncA_Room_ReflectFireblastsOffMirror
    stx T5  ; blaster machine index
    lda Ram_MachineState3_byte_arr, x  ; mirror anim
    div #kBlasterMirrorAnimSlowdown
    add #kMirrorAngleOffset
    mul #$10
    sta T4  ; absolute mirror angle (in tau/256 units)
    ldx #kMaxActors - 1
_Loop:
    ;; If this actor isn't a fireblast projectile, skip it.
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjFireblast
    bne _Continue
    ;; If the fireblast was recently reflected off of a mirror (probably this
    ;; one), skip it.
    lda Ram_ActorState3_byte_arr, x  ; fireblast reflection timer
    bne _Continue
    ;; If the fireblast isn't hitting this mirror this frame, skip it.
    jsr Func_SetPointToActorCenter  ; preserves X, Y, and T0+
    jsr Func_IsPointInPlatform  ; preserves X, Y, and T0+; returns C
    bcc _Continue
    ;; Compute the reversed fireblast angle relative to the mirror angle.
    lda Ram_ActorState1_byte_arr, x  ; fireblast angle (in tau/256 units)
    eor #$80
    sub T4  ; absolute mirror angle (in tau/256 units)
    ;; If the fireblast hits the back of the mirror, remove the fireblast.
    cmp #$c1
    bge _Reflect
    cmp #$40
    bge _Remove
_Reflect:
    ;; Subtract the fireblast's relative angle from the mirror's absolute angle
    ;; to get a new absolute angle for the fireblast.
    rsub T4  ; absolute mirror angle (in tau/256 units)
    sta Ram_ActorState1_byte_arr, x  ; fireblast angle (in tau/256 units)
    sty T3  ; mirror platform index
    jsr Func_ReinitActorProjFireblastVelocity  ; preserves X and T3+
    ;; Snap the fireblast to the center of the mirror.
    ldy T3  ; param: mirror platform index
    jsr Func_SetPointToPlatformCenter  ; preserves X, Y, and T0+
    jsr Func_SetActorCenterToPoint  ; preserves X, Y, and T0+
    ;; Set the fireblast's reflection timer, so that it won't immediately hit
    ;; this mirror again.
    lda #3
    sta Ram_ActorState3_byte_arr, x  ; reflection timer
    bne _Continue  ; unconditional
_Remove:
    sty T0  ; mirror platform index
    jsr Func_InitActorSmokeParticleStationary  ; preserves X and T0+
    ldy T0  ; mirror platform index
_Continue:
    dex
    .assert kMaxActors <= $80, error
    bpl _Loop
    ldx T5  ; blaster machine index
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for vertical blaster machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawBlasterMachine
.PROC FuncA_Objects_DrawBlasterMachine
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
    lda #kTileIdObjBlasterBarrel
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Draws a mirror that can reflect blaster machine projectiles.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param X The platform index for the mirror.
;;; @preserve X, T2+
.EXPORT FuncA_Objects_DrawBlasterMirror
.PROC FuncA_Objects_DrawBlasterMirror
    stx T0  ; mirror platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves T0+
    ldy Zp_MachineIndex_u8
    lda Ram_MachineState3_byte_arr, y  ; mirror anim
    div #kBlasterMirrorAnimSlowdown
    add #kMirrorAngleOffset
    tay  ; absolute mirror angle (in increments of tau/16)
    div #4
    and #$03
    tax
    tya  ; absolute mirror angle (in increments of tau/16)
    ldy _Flags_bObj_arr4, x  ; param: object flags
    and #$07
    tax  ; mirror angle (mod 8)
    lda _TileId_u8_arr8, x  ; param: tile ID
    ldx T0  ; mirror platform index
    jmp FuncA_Objects_Draw1x1Shape  ; preserves X and T2+
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
