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
.INCLUDE "cannon.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_PlaySfxCannonFire
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Alloc2x2MachineShape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjGrenade
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; How many frames a cannon machine spends per move/act operation.
kCannonMoveCountdown = $20
kCannonActCountdown = $60

;;; Various OBJ tile IDs used for drawing cannon machines.
kTileIdObjCannonCornerTop  = kTileIdObjCannonFirst + $00
kTileIdObjCannonCornerBase = kTileIdObjCannonFirst + $01
kTileIdObjCannonBarrelHigh = kTileIdObjCannonFirst + $02
kTileIdObjCannonBarrelMid  = kTileIdObjCannonFirst + $03
kTileIdObjCannonBarrelLow  = kTileIdObjCannonFirst + $04

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Reads the "Y" register for a cannon machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The value of the machine's "Y" register (0-1).
.EXPORT Func_MachineCannonReadRegY
.PROC Func_MachineCannonReadRegY
    ldy Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, y  ; aim angle (0-255)
    and #$80
    asl a
    rol a
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Reset implemention for cannon machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Room_MachineCannonReset
.PROC FuncA_Room_MachineCannonReset
    ldx Zp_MachineIndex_u8
    lda #0
    sta Ram_MachineGoalVert_u8_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; TryMove implemention for cannon machines.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param X The eDir value for the direction to move in.
.EXPORT FuncA_Machine_CannonTryMove
.PROC FuncA_Machine_CannonTryMove
    txa
    ldx Zp_MachineIndex_u8
    cmp #eDir::Down
    beq @moveDown
    @moveUp:
    ldy Ram_MachineGoalVert_u8_arr, x
    bne @error
    iny
    bne @success  ; unconditional
    @moveDown:
    ldy Ram_MachineGoalVert_u8_arr, x
    beq @error
    dey
    @success:
    tya
    sta Ram_MachineGoalVert_u8_arr, x
    lda #kCannonMoveCountdown
    jmp FuncA_Machine_StartWaiting
    @error:
    jmp FuncA_Machine_Error
.ENDPROC

;;; TryAct implemention for cannon machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Machine_CannonTryAct
.PROC FuncA_Machine_CannonTryAct
    jsr Func_FindEmptyActorSlot  ; sets C on failure, returns X
    bcs @doneGrenade
    ;; Get the cannon's platform index, storing it in Y.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tay
    ;; Position the new grenade actor:
    lda Ram_PlatformLeft_i16_0_arr, y
    add #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, y
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    lda Ram_PlatformTop_i16_0_arr, y
    add #kTileWidthPx
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, y
    adc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Determine the aim angle.
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    beq @noFlip
    lda #$02
    @noFlip:
    ldy Zp_MachineIndex_u8
    ora Ram_MachineGoalVert_u8_arr, y  ; param: aim angle (0-3)
    ;; Initialize the grenade.
    jsr Func_InitActorProjGrenade  ; preserves X
    ;; If the console is active, then we must be debugging, so immediately
    ;; replace the grenade with a smoke particle (so as to dry-fire the
    ;; cannon).
    lda Zp_ConsoleMachineIndex_u8
    bmi @noDryFire
    lda #eActor::SmokeParticle
    sta Ram_ActorType_eActor_arr, x
    lda #kSmokeParticleNumFrames / 2
    sta Ram_ActorState1_byte_arr, x  ; particle age in frames
    @noDryFire:
    jsr FuncA_Machine_PlaySfxCannonFire
    @doneGrenade:
    ;; Set the cooldown for the ACT instruction.
    lda #kCannonActCountdown  ; param: wait frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;; Tick implemention for cannon machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @prereq Zp_Current_sProgram_ptr is initialized.
.EXPORT FuncA_Machine_CannonTick
.PROC FuncA_Machine_CannonTick
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    beq @moveDown
    @moveUp:
    lda Ram_MachineState1_byte_arr, x  ; aim angle (0-255)
    add #$100 / kCannonMoveCountdown
    bcc @setAngle
    lda #$ff
    sta Ram_MachineState1_byte_arr, x  ; aim angle (0-255)
    jmp FuncA_Machine_ReachedGoal
    @moveDown:
    lda Ram_MachineState1_byte_arr, x  ; aim angle (0-255)
    sub #$100 / kCannonMoveCountdown
    bge @setAngle
    lda #0
    sta Ram_MachineState1_byte_arr, x  ; aim angle (0-255)
    jmp FuncA_Machine_ReachedGoal
    @setAngle:
    sta Ram_MachineState1_byte_arr, x  ; aim angle (0-255)
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draw implemention for cannon machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawCannonMachine
.PROC FuncA_Objects_DrawCannonMachine
    lda #kPaletteObjMachineLight  ; param: object flags
    jsr FuncA_Objects_Alloc2x2MachineShape  ; returns C, A, and Y
    bcs _Done
    eor #bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
_SetBarrelTileId:
    ldx Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, x  ; aim angle (0-255)
    cmp #$40
    blt @barrelLow
    cmp #$c0
    blt @barrelMid
    @barrelHigh:
    lda #kTileIdObjCannonBarrelHigh
    bne @setBarrel  ; unconditional
    @barrelMid:
    lda #kTileIdObjCannonBarrelMid
    bne @setBarrel  ; unconditional
    @barrelLow:
    lda #kTileIdObjCannonBarrelLow
    @setBarrel:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
_SetLightTileId:
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
_SetCornerTileIds:
    lda #kTileIdObjCannonCornerTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdObjCannonCornerBase
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
