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
.INCLUDE "../avatar.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "emitter.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Machine_PlaySfxEmitterBeam
.IMPORT FuncA_Machine_PlaySfxEmitterForcefield
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftByA
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT Func_AvatarDepthIntoPlatformBottom
.IMPORT Func_AvatarDepthIntoPlatformLeft
.IMPORT Func_AvatarDepthIntoPlatformRight
.IMPORT Func_AvatarDepthIntoPlatformTop
.IMPORT Func_DivMod
.IMPORT Func_GetRandomByte
.IMPORT Func_HarmAvatar
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsAvatarInPlatformHorz
.IMPORT Func_IsPointInPlatform
.IMPORT Func_KillAvatar
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_PlaySfxBaddieDeath
.IMPORT Func_SetPlatformTopLeftToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformTopLeft
.IMPORT Func_TryPushAvatarHorz
.IMPORT Func_TryPushAvatarVert
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_AvatarCollided_ePlatform
.IMPORTZP Zp_AvatarPushDelta_i8
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_MachineIndex_u8

;;;=========================================================================;;;

;;; How long an emitter machine's beam fires for after an ACT operation, in
;;; frames.
kEmitterBeamDuration = 10

;;; How long an emitter machine must wait after an ACT operation before it can
;;; continue executing, in frames.
kEmitterActCooldown = 30

;;; OBJ tiles IDs used for drawing emitter machines.
kTileIdObjEmitterBeamHorz   = kTileIdObjEmitterFirst + 0
kTileIdObjEmitterBeamVert   = kTileIdObjEmitterFirst + 1
kTileIdObjEmitterGlowXFirst = kTileIdObjEmitterFirst + 2
kTileIdObjEmitterGlowYFirst = kTileIdObjEmitterFirst + 4

;;; OBJ palette numbers used for drawing emitter machines.
kPaletteObjEmitterBeam = 1
kPaletteObjEmitterGlow = 1

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; ReadReg implementation for emitter machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @return A The value of the emitter's position register (0-9).
.EXPORT Func_MachineEmitterReadReg
.PROC Func_MachineEmitterReadReg
    ldy Zp_MachineIndex_u8
    lda Ram_MachineState1_byte_arr, y  ; X/Y register value
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Init/Reset implementation for emitter-Y machines.
;;; @param A The initial value of the Y register (0-9).
.EXPORT FuncA_Room_MachineEmitterYInitReset
.PROC FuncA_Room_MachineEmitterYInitReset
    sta Ram_MachineState1_byte_arr + kEmitterYMachineIndex  ; Y register value
    pha  ; register value
    lda Ram_PlatformBottom_i16_0_arr + kEmitterRegionPlatformIndex
    sub Ram_PlatformTop_i16_0_arr + kEmitterRegionPlatformIndex
    div #kBlockHeightPx
    sta T2  ; num rows
    tay  ; num rows (param: divisor)
    pla  ; register value (param: dividend)
    jsr Func_DivMod  ; preserves T2+, returns remainder in A
    clc
    rsbc T2
    sta Ram_MachineGoalVert_u8_arr + kEmitterYMachineIndex  ; beam row
    bpl FuncA_Room_RemoveEmitterForcefield  ; unconditional
.ENDPROC

;;; Init/Reset implementation for emitter-X machines.
;;; @param A The initial value of the X register (0-9).
.EXPORT FuncA_Room_MachineEmitterXInitReset
.PROC FuncA_Room_MachineEmitterXInitReset
    sta Ram_MachineState1_byte_arr + kEmitterXMachineIndex  ; X register value
    sta Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex  ; beam col
    fall FuncA_Room_RemoveEmitterForcefield
.ENDPROC

;;; Removes the forcefield (if any) created by the emitter machines.
.EXPORT FuncA_Room_RemoveEmitterForcefield
.PROC FuncA_Room_RemoveEmitterForcefield
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kEmitterForcefieldPlatformIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; WriteReg implementation for emitter-X machines.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_EmitterXWriteReg
.PROC FuncA_Machine_EmitterXWriteReg
    sta Ram_MachineState1_byte_arr + kEmitterXMachineIndex  ; X register value
    sta Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex  ; beam column
    rts
.ENDPROC

;;; WriteReg implementation for emitter-Y machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
.EXPORT FuncA_Machine_EmitterYWriteReg
.PROC FuncA_Machine_EmitterYWriteReg
    sta Ram_MachineState1_byte_arr + kEmitterYMachineIndex  ; Y register value
    pha  ; register value
    lda Ram_PlatformBottom_i16_0_arr + kEmitterRegionPlatformIndex
    sub Ram_PlatformTop_i16_0_arr + kEmitterRegionPlatformIndex
    div #kBlockHeightPx
    sta T2  ; num rows
    tay  ; num rows (param: divisor)
    pla  ; register value (param: dividend)
    jsr Func_DivMod  ; preserves T2+, returns remainder in A
    clc
    rsbc T2
    sta Ram_MachineGoalVert_u8_arr + kEmitterYMachineIndex  ; beam row
    rts
.ENDPROC

;;; TryAct implementation for emitter machines.
;;; @return C Set if the forcefield platform is now solid, cleared otherwise.
.EXPORT FuncA_Machine_EmitterTryAct
.PROC FuncA_Machine_EmitterTryAct
    ldy #kEmitterRegionPlatformIndex  ; param: platform index
    jsr Func_SetPointToPlatformTopLeft
    ;; Start this emitter machine's beam firing.
    lda #kEmitterActCooldown  ; param: num frames to wait
    jsr FuncA_Machine_StartWaiting
    ldy Zp_MachineIndex_u8
    lda #kEmitterBeamDuration
    sta Ram_MachineSlowdown_u8_arr, y
    jsr FuncA_Machine_PlaySfxEmitterBeam
    ;; Remove any existing forcefield.
    lda #ePlatform::Zone
    sta Ram_PlatformType_ePlatform_arr + kEmitterForcefieldPlatformIndex
    ;; Only make a new forcefield if both emitters are firing at once.
    lda Ram_MachineSlowdown_u8_arr + kEmitterXMachineIndex
    beq _NoForcefield
    lda Ram_MachineSlowdown_u8_arr + kEmitterYMachineIndex
    beq _NoForcefield
_CreateForcefield:
    ;; Reposition the forcefield platform.
    lda Ram_MachineGoalHorz_u8_arr + kEmitterXMachineIndex  ; beam col
    mul #kBlockWidthPx
    jsr Func_MovePointRightByA
    lda Ram_MachineGoalVert_u8_arr + kEmitterYMachineIndex  ; beam row
    mul #kBlockHeightPx
    jsr Func_MovePointDownByA
    ldy #kEmitterForcefieldPlatformIndex  ; param: platform index
    jsr Func_SetPlatformTopLeftToPoint
    ;; Make the forcefield platform solid.
    lda #ePlatform::Solid
    sta Ram_PlatformType_ePlatform_arr + kEmitterForcefieldPlatformIndex
    jsr FuncA_Machine_PlaySfxEmitterForcefield
    jsr FuncA_Machine_PushAvatarOutOfEmitterForcefield
    jsr FuncA_Machine_KillGooWithEmitterForcefield
    sec  ; set C to indicate that a forcefield was created
    rts
_NoForcefield:
    clc  ; clear C to indicate that no forcefield was created
    rts
.ENDPROC

;;; If the player avatar is colliding with the emitter forcefield's new
;;; position, pushes the avatar out in an appropriate direction.
.PROC FuncA_Machine_PushAvatarOutOfEmitterForcefield
    ldx #kEmitterForcefieldPlatformIndex  ; param: platform index
_MaybePushUp:
    ;; If the avatar's feet (but not center) are in the forcefield, push the
    ;; avatar up out of the forcefield.
    jsr Func_AvatarDepthIntoPlatformTop  ; preserves X, returns Z and A
    beq _Return  ; avatar is fully above the forcefield
    cmp #<-kAvatarBoundingBoxDown
    blt @doNotPushUp  ; avatar is too deep below the top of the forcefield
    sta Zp_AvatarPushDelta_i8
    jsr Func_IsAvatarInPlatformHorz  ; returns Z
    beq _Return  ; avatar is fully to the left or right of the forcefield
    jsr Func_TryPushAvatarVert
    ;; If the forcefield squashed the avatar into something else solid, kill
    ;; the avatar.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _Return
    jmp Func_KillAvatar
    @doNotPushUp:
_MaybePushLeft:
    ;; If the avatar's right side (but not center) is in the forcefield, push
    ;; the avatar to the left, out of the forcefield.
    jsr Func_AvatarDepthIntoPlatformLeft  ; preserves X, returns Z and A
    beq _Return  ; avatar is fully to the left of the forcefield
    cmp #<-kAvatarBoundingBoxRight
    blt @doNotPushLeft  ; avatar is too deep into the side of the forcefield
    sta Zp_AvatarPushDelta_i8
    ;; We already know from above that the avatar isn't fully above the
    ;; platform, so we only need to check here that it isn't fully below.
    jsr Func_AvatarDepthIntoPlatformBottom  ; returns Z
    beq _Return  ; avatar is fully below the forcefield
    jsr Func_TryPushAvatarHorz
    ;; If the forcefield squashed the avatar into something else solid, kill
    ;; the avatar.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _Return
    jmp Func_KillAvatar
    @doNotPushLeft:
_MaybePushRight:
    ;; If the avatar's left side (but not center) is in the forcefield, push
    ;; the avatar to the right, out of the forcefield.
    jsr Func_AvatarDepthIntoPlatformRight  ; preserves X, returns Z and A
    beq _Return  ; avatar is fully to the right of the forcefield
    cmp #kAvatarBoundingBoxLeft
    bge @doNotPushRight  ; avatar is too deep into the side of the forcefield
    sta Zp_AvatarPushDelta_i8
    ;; We already know from above that the avatar isn't fully above the
    ;; platform, so we only need to check here that it isn't fully below.
    jsr Func_AvatarDepthIntoPlatformBottom  ; returns Z
    beq _Return  ; avatar is fully below the forcefield
    jsr Func_TryPushAvatarHorz
    ;; If the forcefield squashed the avatar into something else solid, kill
    ;; the avatar.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _Return
    jmp Func_KillAvatar
    @doNotPushRight:
_MaybePushDown:
    ;; We already know from above that the avatar is neither fully above nor
    ;; fully to either side of the platform, so if the avatar isn't fully below
    ;; the forcefield, then it's intersecting it.
    jsr Func_AvatarDepthIntoPlatformBottom  ; returns Z and A
    beq _Return  ; avatar is fully below the forcefield
    ;; If the avatar is deep inside the platform, harm it.  Either way, push it
    ;; down and out.
    sta Zp_AvatarPushDelta_i8
    cmp #kAvatarBoundingBoxUp
    blt @noHarm
    jsr Func_HarmAvatar
    @noHarm:
    jsr Func_TryPushAvatarVert
    ;; If the forcefield squashed the avatar into something else solid, kill
    ;; the avatar.
    lda Zp_AvatarCollided_ePlatform
    .assert ePlatform::None = 0, error
    beq _Return
    jmp Func_KillAvatar
_Return:
    rts
.ENDPROC

;;; Checks if any green goo baddies are within the forcefield platform, and
;;; kills them if so.
;;; @prereq The forcefield platform is solid.
.PROC FuncA_Machine_KillGooWithEmitterForcefield
    ldx #kMaxActors - 1
    @loop:
    ;; If this actor isn't a green goo baddie, skip it.
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::BadGooGreen
    bne @continue
    ;; If the goo isn't in the forcefield platform, skip it.
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kEmitterForcefieldPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X, returns C
    bcc @continue
    ;; Kill the goo.
    jsr Func_InitActorSmokeExplosion  ; preserves X
    jsr Func_PlaySfxBaddieDeath  ; preserves X
    @continue:
    dex
    .assert kMaxActors <= $80, error
    bpl @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a forcefield emitter machine that fires a vertical beam at various
;;; X-positions.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The length of the beam, in tiles.
.EXPORT FuncA_Objects_DrawEmitterXMachine
.PROC FuncA_Objects_DrawEmitterXMachine
    sty T0  ; beam length in tiles
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    lda #kTileHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves T0+
    ldx Zp_MachineIndex_u8
    lda #9
    sub Ram_MachineGoalHorz_u8_arr, x
    mul #kBlockHeightPx
    adc #kTileWidthPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeLeftByA  ; preserves X and T0+
    lda Ram_MachineSlowdown_u8_arr, x
    beq _DrawGlow
_DrawBeam:
    jsr Func_GetRandomByte  ; preserves T0+, returns A
    ldy T0  ; beam length in tiles
    jsr Func_DivMod  ; returns remainder in A
    mul #kTileHeightPx  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    lda #kTileIdObjEmitterBeamVert  ; param: tile ID
    ldy #kPaletteObjEmitterBeam  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jmp _DrawMachineLight
_DrawGlow:
    lda #kTileIdObjEmitterGlowXFirst  ; param: base tile ID
    jsr FuncA_Objects_DrawEmitterMachineGlow
_DrawMachineLight:
    ldy #kPaletteObjMachineLight | bObj::FlipHV  ; param: object flags
    bne FuncA_Objects_DrawEmitterMachineLight  ; unconditional
.ENDPROC

;;; Draws a forcefield emitter machine that fires a horizontal beam at various
;;; Y-positions.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The length of the beam, in tiles.
.EXPORT FuncA_Objects_DrawEmitterYMachine
.PROC FuncA_Objects_DrawEmitterYMachine
    sty T0  ; beam length in tiles
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves T0+
    ldx Zp_MachineIndex_u8
    lda Ram_MachineGoalVert_u8_arr, x
    mul #kBlockHeightPx
    adc #kTileHeightPx / 2  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA  ; preserves X and T0+
    lda Ram_MachineSlowdown_u8_arr, x
    beq _DrawGlow
_DrawBeam:
    jsr Func_GetRandomByte  ; preserves T0+, returns A
    ldy T0  ; beam length in tiles
    jsr Func_DivMod  ; returns remainder in A
    mul #kTileWidthPx  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kTileIdObjEmitterBeamHorz  ; param: tile ID
    ldy #kPaletteObjEmitterBeam  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    jmp _DrawMachineLight
_DrawGlow:
    lda #kTileIdObjEmitterGlowYFirst  ; param: base tile ID
    jsr FuncA_Objects_DrawEmitterMachineGlow
_DrawMachineLight:
    ldy #kPaletteObjMachineLight | bObj::FlipH  ; param: object flags
    fall FuncA_Objects_DrawEmitterMachineLight
.ENDPROC

;;; Draws the machine light for a forcefield emitter machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param Y The object flags to use for the machine light.
.PROC FuncA_Objects_DrawEmitterMachineLight
    sty T0  ; object flags
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves T0+, returns A
    cmp #kTileIdObjMachineLightOn
    bne @done
    jsr FuncA_Objects_SetShapePosToMachineTopLeft  ; preserves T0+
    ldy T0  ; param: object flags
    lda #kTileIdObjEmitterLight  ; param: tile ID
    jmp FuncA_Objects_Draw1x1Shape
    @done:
    rts
.ENDPROC

;;; Draws the glowing light for an emitter machine's active emitter position.
;;; @param A The base tile ID for the glow.
.PROC FuncA_Objects_DrawEmitterMachineGlow
    ;; Don't draw the glow if the machine is halted.
    ldx Zp_MachineIndex_u8
    ldy Ram_MachineStatus_eMachine_arr, x
    cpy #eMachine::Halted
    beq @done  ; machine is halted
    ;; Draw the glow.
    sta T0  ; base tile ID
    lda Zp_FrameCounter_u8
    div #4
    and #$01
    add T0  ; param: tile ID
    ldy #kPaletteObjEmitterGlow  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
