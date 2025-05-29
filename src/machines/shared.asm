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
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_MoveShapeDownAndRightOneTile
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_InitActorSmokeParticleStationary
.IMPORT Func_IsPointInPlatform
.IMPORT Func_IsPointInPlatformHorz
.IMPORT Func_IsPointInPlatformVert
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_Current_sMachine_ptr
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Checks if the position stored in Zp_Point*_i16 is detected by the
;;; downward-facing distance sensor with the specified platform index.  If the
;;; point is in view of the sensor, and closer than the current minimum
;;; distance stored in T0, then T0 is updated with the new minimum distance.
;;; @param Y The platform index for the distance sensor.
;;; @param T0 The minimum distance detected so far, in pixels.
;;; @return T0 The new minimum distance detected so far, in pixels.
;;; @preserve Y, T1+
.EXPORT Func_DistanceSensorDownDetectPoint
.PROC Func_DistanceSensorDownDetectPoint
    ;; If the point is not horizontally lined up with the distance sensor, then
    ;; we won't detect it, so the minimum distance so far will remain
    ;; unchanged.
    jsr Func_IsPointInPlatformHorz  ; preserves Y and T0+, returns C
    bcc @done
    ;; Calculate the distance from the bottom of the sensor to the point, in
    ;; pixels.
    lda Zp_PointY_i16 + 0
    sub Ram_PlatformBottom_i16_0_arr, y
    tax  ; distance (lo)
    lda Zp_PointY_i16 + 1
    sbc Ram_PlatformBottom_i16_1_arr, y
    beq Func_DistanceSensorUpdateMinimum  ; preserves Y and T1+, returns T0
    @done:
    rts
.ENDPROC

;;; Checks if the position stored in Zp_Point*_i16 is detected by the
;;; rightware-facing distance sensor with the specified platform index.  If the
;;; point is in view of the sensor, and closer than the current minimum
;;; distance stored in T0, then T0 is updated with the new minimum distance.
;;; @param Y The platform index for the distance sensor.
;;; @param T0 The minimum distance detected so far, in pixels.
;;; @return T0 The new minimum distance detected so far, in pixels.
;;; @preserve Y, T1+
.EXPORT Func_DistanceSensorRightDetectPoint
.PROC Func_DistanceSensorRightDetectPoint
    ;; If the point is not vertically lined up with the distance sensor, then
    ;; we won't detect it, so the minimum distance so far will remain
    ;; unchanged.
    jsr Func_IsPointInPlatformVert  ; preserves Y and T0+, returns C
    bcc @done
    ;; Calculate the distance from the bottom of the sensor to the point, in
    ;; pixels.
    lda Zp_PointX_i16 + 0
    sub Ram_PlatformRight_i16_0_arr, y
    tax  ; distance (lo)
    lda Zp_PointX_i16 + 1
    sbc Ram_PlatformRight_i16_1_arr, y
    beq Func_DistanceSensorUpdateMinimum  ; preserves Y and T1+, returns T0
    @done:
    rts
.ENDPROC

;;; If the given distance is less than the minimum distance so far, updates the
;;; minimum distance.
;;; @param X The new distance to consider, in pixels.
;;; @param T0 The minimum distance detected so far, in pixels.
;;; @return T0 The new minimum distance detected so far, in pixels.
;;; @preserve Y, T1+
.PROC Func_DistanceSensorUpdateMinimum
    cpx T0  ; minimum distance so far, in pixels
    bge @done
    stx T0  ; minimum distance so far, in pixels
    @done:
    rts
.ENDPROC

;;; Helper function for machine ReadReg functions.  Divides an 8-bit distance
;;; in pixels into a distance in blocks, clamping to a maximum of 9.
;;; @param AX The distance in pixels (unsigned).
;;; @return A The distance in blocks, clamped to a maximum of 9.
;;; @preserve T0+
.EXPORT Func_DivAXByBlockSizeAndClampTo9
.PROC Func_DivAXByBlockSizeAndClampTo9
    .assert $100 >= kBlockWidthPx * 9, error
    tay  ; distance (hi)
    bne Func_Return9  ; preserves T0+
    txa  ; param: distance (lo)
    fall Func_DivAByBlockSizeAndClampTo9  ; preserves T0+
.ENDPROC

;;; Helper function for machine ReadReg functions.  Divides a 16-bit distance
;;; in pixels into a distance in blocks, clamping to a maximum of 9.
;;; @param A The distance in pixels (unsigned).
;;; @return A The distance in blocks, clamped to a maximum of 9.
;;; @preserve T0+
.EXPORT Func_DivAByBlockSizeAndClampTo9
.PROC Func_DivAByBlockSizeAndClampTo9
    .assert kBlockWidthPx = kBlockHeightPx, error
    div #kBlockWidthPx
    cmp #10
    blt Func_DoneWithClamp
    fall Func_Return9
.ENDPROC

;;; Helper function for Func_Div*ByBlockSizeAndClampTo9.  Returns 9 in A.
;;; @return A Always equal to 9.
;;; @preserve T0+
.PROC Func_Return9
    lda #9
    fall Func_DoneWithClamp  ; preserves T0+, returns A unchanged
.ENDPROC

;;; Helper function for Func_Div*ByBlockSizeAndClampTo9.  Returns A unchanged.
;;; @param A A value from 0-9.
;;; @return A The value unchanged.
;;; @preserve T0+
.PROC Func_DoneWithClamp
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Returns the speed at which the current machine should move, in pixels per
;;; frame.  If the machine is resetting, returns 2; otherwise, returns 1.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The speed the machine should move at.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Machine_GetGenericMoveSpeed
.PROC FuncA_Machine_GetGenericMoveSpeed
    lda #1  ; param: base value
    fall FuncA_Machine_DoubleIfResetting  ; preserves X, Y, and T0+; returns A
.ENDPROC

;;; If the current machine is resetting, doubles the given value; otherwise,
;;; returns it unchanged.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param A The base value to possibly double.
;;; @return A The possibly-doubled value.
;;; @preserve X, Y, T0+
.EXPORT FuncA_Machine_DoubleIfResetting
.PROC FuncA_Machine_DoubleIfResetting
    pha  ; base value
    txa  ; X (to preserve)
    pha  ; X (to preserve)
    ldx Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, x
    cmp #kFirstResetStatus  ; sets C if machine is resetting
    pla  ; X (to preserve)
    tax  ; X (to preserve)
    pla  ; base value
    bcc @done
    mul #2
    @done:
    rts
.ENDPROC

;;; Tries to move the current machine's horizontal goal value, where goal
;;; position zero is the leftmost position, and the only constraint is that the
;;; horizontal goal value must be between zero and the given max, inclusive.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param A The maximum permitted vertical goal value.
;;; @param X The eDir value for the direction to move in (up or down).
.EXPORT FuncA_Machine_GenericTryMoveX
.PROC FuncA_Machine_GenericTryMoveX
    sta T0  ; max goal horz
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalHorz_u8_arr, y
    cpx #eDir::Right
    bne @moveLeft
    @moveRight:
    cmp T0  ; max goal horz
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
    sta T0  ; max goal vert
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    cpx #eDir::Up
    bne @moveDown
    @moveUp:
    cmp T0  ; max goal vert
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
    sta T0  ; max goal vert
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, y
    cpx #eDir::Up
    beq @moveUp
    @moveDown:
    cmp T0  ; max goal vert
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
    sta T0  ; min platform left (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta T1  ; platform index
    ;; Calculate the desired X-position for the left edge of the machine, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    ldy Zp_MachineIndex_u8
    lda Ram_MachineGoalHorz_u8_arr, y
    mul #kBlockHeightPx
    sta T2  ; goal delta
    txa     ; min platform left (lo)
    add T2  ; goal delta
    sta Zp_PointX_i16 + 0
    lda T0  ; min platform left (hi)
    adc #0
    sta Zp_PointX_i16 + 1
    ;; Move the machine horizontally, as necessary.
    ldx T1  ; param: platform index
    jsr FuncA_Machine_GetGenericMoveSpeed  ; preserves X, returns A
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
    sta T0  ; max platform top (hi)
    ;; Get the machine's platform index.
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    sta T1  ; platform index
    ;; Calculate the desired Y-position for the top edge of the machine, in
    ;; room-space pixels, storing it in Zp_PointY_i16.
    ldy Zp_MachineIndex_u8
    lda #0
    sta T3  ; goal delta (hi)
    lda Ram_MachineGoalVert_u8_arr, y
    .assert kBlockHeightPx = 1 << 4, error
    .repeat 4
    asl a
    rol T3  ; goal delta (hi)
    .endrepeat
    sta T2  ; goal delta (lo)
    txa     ; max platform top (lo)
    sub T2  ; goal delta (lo)
    sta Zp_PointY_i16 + 0
    lda T0  ; max platform top (hi)
    sbc T3  ; goal delta (hi)
    sta Zp_PointY_i16 + 1
    ;; Move the machine vertically, as necessary.
    ldx T1  ; param: platform index
    jsr FuncA_Machine_GetGenericMoveSpeed  ; preserves X, returns A
    jmp Func_MovePlatformTopTowardPointY  ; returns Z, N, and A
.ENDPROC

;;; Checks if any fireball projectiles are within the specified platform, and
;;; expires them if so.  Does nothing if the platform isn't solid.
;;; @param Y The platform index.
;;; @preserve Y, T2+
.EXPORT FuncA_Machine_ExpireFireballsWithinSolidPlatform
.PROC FuncA_Machine_ExpireFireballsWithinSolidPlatform
    lda #eActor::ProjFireball  ; param: actor type
    fall FuncA_Machine_ExpireProjectilesWithinSolidPlatform  ; preserves Y, T2+
.ENDPROC

;;; Checks if any projectiles of the specified type are within the specified
;;; platform, and expires them if so.  Does nothing if the platform isn't
;;; solid.
;;; @param A The eActor::Proj* type for projectiles to expire.
;;; @param Y The platform index.
;;; @preserve Y, T2+
.EXPORT FuncA_Machine_ExpireProjectilesWithinSolidPlatform
.PROC FuncA_Machine_ExpireProjectilesWithinSolidPlatform
    sta T1  ; actor type
    lda Ram_PlatformType_ePlatform_arr, y
    cmp #kFirstSolidPlatformType
    blt @done
    ldx #kMaxActors - 1
    @loop:
    ;; If this actor isn't a fireball projectile, skip it.
    lda Ram_ActorType_eActor_arr, x
    cmp T1  ; actor type
    bne @continue
    ;; If the fireball isn't in the forcefield platform, skip it.
    jsr Func_SetPointToActorCenter  ; preserves X, Y, and T0+
    jsr Func_IsPointInPlatform  ; preserves X, Y, and T0+; returns C
    bcc @continue
    ;; Expire the fireball.
    sty T0  ; platform index
    jsr Func_InitActorSmokeParticleStationary  ; preserves X and T0+
    ldy T0  ; platform index
    @continue:
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; If a machine console window is open, turns all projectile actors of the
;;; specified type into smoke particles.  This should generally be called from
;;; a room's Tick function.
;;; @param A The eActor::Proj* value.
;;; @preserve X
.EXPORT FuncA_Room_TurnProjectilesToSmokeIfConsoleOpen
.PROC FuncA_Room_TurnProjectilesToSmokeIfConsoleOpen
    ldy Zp_ConsoleMachineIndex_u8
    bpl FuncA_Room_TurnProjectilesToSmoke  ; preserves X
    rts
.ENDPROC

;;; Turns all projectile actors of the specified type into smoke particles.
;;; @param A The eActor::Proj* value.
;;; @preserve X
.EXPORT FuncA_Room_TurnProjectilesToSmoke
.PROC FuncA_Room_TurnProjectilesToSmoke
    sta T0  ; projectile type
    ldy #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, y
    cmp T0  ; projectile type
    bne @continue
    ;; Replace the projectile with a smoke particle, keeping the same position
    ;; and velocity as the projectile, and setting the particle's age counter
    ;; such that the particle starts at half size and decays from there.
    lda #eActor::SmokeParticle
    sta Ram_ActorType_eActor_arr, y
    lda #kSmokeParticleNumFrames / 2
    sta Ram_ActorState1_byte_arr, y  ; particle age in frames
    @continue:
    dey
    .assert kMaxActors <= $80, error
    bpl @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Returns the tile ID to use for the status light on the current machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The tile ID to use.
;;; @preserve Y, T0+
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
    lda #kTileIdObjMachineLightOn
    rts
    @lightOff:
    lda #kTileIdObjMachineLightOff
    rts
.ENDPROC

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the top-left corner of the current machine's primary platform.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @preserve T0+
.EXPORT FuncA_Objects_SetShapePosToMachineTopLeft
.PROC FuncA_Objects_SetShapePosToMachineTopLeft
    ldy #sMachine::MainPlatform_u8
    lda (Zp_Current_sMachine_ptr), y
    tax  ; param: platform index
    jmp FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves T0+
.ENDPROC

;;; Allocates a 2x2 grid of objects for the current machine, assuming that that
;;; machine's platform is 2x2 tiles in size.  If the current machine has the
;;; bMachine::FlipH bit set, that will be applied to the object flags, along
;;; with the specified flags/palette.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The base object flags to apply.
;;; @return C Set if no OAM slots were allocated, cleared otherwise.
;;; @retrun A The actual object flags that were set for the four objects.
;;; @return Y The OAM byte offset for the first of the four objects.
;;; @preserve T2+
.EXPORT FuncA_Objects_Alloc2x2MachineShape
.PROC FuncA_Objects_Alloc2x2MachineShape
    sta T0  ; base object flags
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    jsr FuncA_Objects_MoveShapeDownAndRightOneTile  ; preserves T0+
    ldy #sMachine::Flags_bMachine
    lda (Zp_Current_sMachine_ptr), y
    and #bMachine::FlipH
    .assert bMachine::FlipH = bObj::FlipH, error
    eor T0  ; base object flags
    pha  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves T2+, returns C and Y
    pla  ; object flags
    rts
.ENDPROC

;;;=========================================================================;;;
