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

.INCLUDE "../avatar.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "winch.inc"

.IMPORT FuncA_Objects_Alloc1x1Shape
.IMPORT FuncA_Objects_Alloc2x1Shape
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjSmoke
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_MachineParam2_i16_0_arr
.IMPORT Ram_MachineParam2_i16_1_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_MachineWait_u8_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosX_i16
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; How many frames a falling winch machine must wait after hitting the ground
;;; before it can move again.
kWinchFallRecoverFrames = 60

;;; How many pixels above the bottom of the winch machine the chain must extend
;;; in order to appear to feed into the machine.
kWinchChainOverlapPx = 4

;;; The falling speed to set after a winch breaks through a breakable floor, in
;;; pixels per frame.
kWinchBreakthroughSpeed = 1

;;; Various OBJ tile IDs used for drawing winch machines.
kTileIdCrusherUpperLeft   = kTileIdCrusherFirst + 0
kTileIdCrusherUpperRight  = kTileIdCrusherFirst + 2
kTileIdCrusherSpikes      = kTileIdCrusherFirst + 1
kTileIdSpikeballFirst     = kTileIdCrusherFirst + 4
kTileIdWinchChain         = kTileIdCrusherFirst + 3
kTileIdWinchGear1         = kTileIdWinchFirst + 0
kTileIdWinchGear2         = kTileIdWinchFirst + 2
kTileIdWinchCornerBottom1 = kTileIdWinchFirst + 1
kTileIdWinchCornerBottom2 = kTileIdWinchFirst + 3
kTileIdWinchCornerTop     = $79

;;; OBJ palette numbers used for various parts of winch machines.
kCrusherPalette    = 1
kSpikeballPalette  = 0
kWinchChainPalette = 0
kWinchGearPalette  = 0

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Resets machine params for a winch machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.EXPORT Func_ResetWinchMachineParams
.PROC Func_ResetWinchMachineParams
    ldy Zp_MachineIndex_u8
    ;; Start "falling" to false.
    lda #0
    sta Ram_MachineParam1_u8_arr, y  ; falling bool
    ;; Set fall speed to zero.
    sta Ram_MachineParam2_i16_0_arr, y
    sta Ram_MachineParam2_i16_1_arr, y
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Returns the speed that the current winch machine should use when moving
;;; horizontally this frame.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return A The max distance to move by, in pixels (0-127).
;;; @preserve X
.EXPORT FuncA_Machine_GetWinchHorzSpeed
.PROC FuncA_Machine_GetWinchHorzSpeed
    ldy Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Resetting
    bne @notResetting
    @resetting:
    .assert eMachine::Resetting <> 2, error
    lda #2
    rts
    @notResetting:
    lda #1
    rts
.ENDPROC

;;; Returns the speed that the current winch machine should use when moving
;;; vertically this frame.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @prereq Zp_PlatformGoal_i16 is set to the goal room-space pixel Y-position.
;;; @param X The platform index for the winch load.
;;; @return A The max distance to move by, in pixels (0-127).
;;; @return Z Set if the machine's max speed is zero this frame.
;;; @preserve X
.EXPORT FuncA_Machine_GetWinchVertSpeed
.PROC FuncA_Machine_GetWinchVertSpeed
    ldy Zp_MachineIndex_u8
    lda Ram_MachineStatus_eMachine_arr, y
    cmp #eMachine::Resetting
    bne _NotResetting
    lda #2
    rts
_NotResetting:
    lda Ram_MachineParam1_u8_arr, y  ; falling bool
    bne _Falling
    lda Zp_PlatformGoal_i16 + 0
    sub Ram_PlatformTop_i16_0_arr, x
    lda Zp_PlatformGoal_i16 + 1
    sbc Ram_PlatformTop_i16_1_arr, x
    bpl _MovingDown
_MovingUp:
    lda Ram_MachineSlowdown_u8_arr, y
    beq @canMove
    lda #0
    rts
    @canMove:
    lda #kWinchMoveUpSlowdown
    sta Ram_MachineSlowdown_u8_arr, y
_MovingDown:
    lda #1
    rts
_Falling:
    ;; Keep extending machine wait time until it stops falling.
    lda #kWinchFallRecoverFrames
    sta Ram_MachineWait_u8_arr, y
    ;; Apply gravity.
    lda Ram_MachineParam2_i16_0_arr, y
    add #kAvatarGravity
    sta Ram_MachineParam2_i16_0_arr, y
    lda Ram_MachineParam2_i16_1_arr, y
    adc #0
    ;; Cap speed at kWinchMaxFallSpeed.
    cmp #kWinchMaxFallSpeed
    blt @setVelHi
    lda #0
    sta Ram_MachineParam2_i16_0_arr, y
    lda #kWinchMaxFallSpeed
    @setVelHi:
    sta Ram_MachineParam2_i16_1_arr, y
    tay  ; to set/clear Z
    rts
.ENDPROC

;;; Puts the current winch machine into falling mode.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param A The new Z-goal to set.
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.EXPORT FuncA_Machine_WinchStartFalling
.PROC FuncA_Machine_WinchStartFalling
    ldy Zp_MachineIndex_u8
    sta Ram_MachineGoalVert_u8_arr, y
    ;; Start "falling" to true.
    lda #$ff
    sta Ram_MachineParam1_u8_arr, y  ; falling bool
    ;; Set fall speed to zero.
    lda #0
    sta Ram_MachineParam2_i16_0_arr, y
    sta Ram_MachineParam2_i16_1_arr, y
    ;; Return initial wait frames.  (FuncA_Machine_GetWinchVertSpeed will keep
    ;; extending the wait time as long as the winch is still falling.)
    lda #kWinchFallRecoverFrames
    clc  ; success
    rts
.ENDPROC

;;; If the current winch machine is falling, plays a sound for impact and then
;;; takes it out of falling mode.
;;; @prereq Zp_MachineIndex_u8 is initialized.
.EXPORT FuncA_Machine_WinchStopFalling
.PROC FuncA_Machine_WinchStopFalling
    ;; TODO: If currently falling, play a sound for impact.
    jmp Func_ResetWinchMachineParams
.ENDPROC

;;; Determines whether the current winch machine is falling fast enough to
;;; break a breakable floor.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @return C Set if the winch is falling at max speed, cleared otherwise.
.EXPORT FuncA_Machine_IsWinchFallingFast
.PROC FuncA_Machine_IsWinchFallingFast
    ldy Zp_MachineIndex_u8
    lda Ram_MachineParam1_u8_arr, y  ; falling bool
    beq @notFalling
    lda Ram_MachineParam2_i16_1_arr, y
    cmp #kWinchMaxFallSpeed  ; clears C if Param2 less than max speed
    rts
    @notFalling:
    clc
    rts
.ENDPROC

;;; Call this when the current winch machine hits a breakable floor.  Adds
;;; smoke and plays a sound for impact, and slows down the falling speed.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @param Y The platform index of the breakable floor.
.EXPORT FuncA_Machine_WinchHitBreakableFloor
.PROC FuncA_Machine_WinchHitBreakableFloor
_AddSmokeActor:
    jsr Func_FindEmptyActorSlot  ; preserves Y, returns C and X
    bcs @done
    ;; Set X-position:
    lda Ram_PlatformLeft_i16_0_arr, y
    add #kTileWidthPx
    sta Ram_ActorPosX_i16_0_arr, x
    lda Ram_PlatformLeft_i16_1_arr, y
    adc #0
    sta Ram_ActorPosX_i16_1_arr, x
    ;; Set Y-position:
    lda Ram_PlatformTop_i16_0_arr, y
    add #kTileHeightPx / 2
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_PlatformTop_i16_1_arr, y
    adc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Init actor:
    jsr Func_InitActorProjSmoke
    @done:
_SlowFallingSpeed:
    ;; Slow down the falling winch load, in case we're breaking through the
    ;; floor.  (If we're not breaking through the floor yet, the caller will
    ;; separately stop the winch falling entirely.)
    ldx Zp_MachineIndex_u8
    lda #kWinchBreakthroughSpeed
    sta Ram_MachineParam2_i16_1_arr, x
_PlaySound:
    ;; TODO: Play a sound.
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a winch machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The low byte of the Y-position of the end of the chain.
.EXPORT FuncA_Objects_DrawWinchMachine
.PROC FuncA_Objects_DrawWinchMachine
    pha  ; chain position
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    jsr FuncA_Objects_MoveShapeDownOneTile
    jsr FuncA_Objects_MoveShapeRightOneTile
    pla  ; chain position
    tax  ; chain position
    ;; Allocate objects.
    lda #kWinchGearPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs _Done
    lda #bObj::FlipH | bObj::FlipV | kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Flags_bObj, y
    lda #bObj::FlipH | kMachineLightPalette
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
_SetGearTileIds:
    txa  ; chain position
    and #$02
    bne @position2
    @position1:
    lda #kTileIdWinchGear1
    ldx #kTileIdWinchCornerBottom1
    bne @setTiles  ; unconditional
    @position2:
    lda #kTileIdWinchGear2
    ldx #kTileIdWinchCornerBottom2
    @setTiles:
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    txa
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
_SetLightTileId:
    jsr FuncA_Objects_GetMachineLightTileId  ; preserves Y, returns A
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
_SetCornerTileId:
    lda #kTileIdWinchCornerTop
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
_Done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for a chain that feeds into a winch
;;; machine.  When this function returns, the shape position will be set to the
;;; top-left corner of the chain.
;;; @prereq The shape position is set to the bottom-left corner of the chain.
;;; @param X The platform index for the winch machine.
.EXPORT FuncA_Objects_DrawWinchChain
.PROC FuncA_Objects_DrawWinchChain
    ;; Calculate the offset to the room-space platform bottom Y-position that
    ;; will give us the screen-space Y-position for the top of the chain.  Note
    ;; that we offset by an additional (kTileHeightPx - 1), so that when we
    ;; divide by kTileHeightPx later, it will effectively round up instead of
    ;; down.
    lda Zp_RoomScrollY_u8
    add #kWinchChainOverlapPx + (kTileHeightPx - 1)
    sta Zp_Tmp1_byte  ; offset
    ;; Calculate the screen-space Y-position of the top of the chain, storing
    ;; the lo byte in Zp_Tmp1_byte and the hi byte in Zp_Tmp2_byte.
    lda Ram_PlatformBottom_i16_0_arr, x
    sub Zp_Tmp1_byte  ; offset
    sta Zp_Tmp1_byte  ; screen-space chain top (lo)
    lda Ram_PlatformBottom_i16_1_arr, x
    sbc #0
    sta Zp_Tmp2_byte  ; screen-space chain top (hi)
    ;; Calculate the length of the chain, in pixels, storing the lo byte in
    ;; Zp_Tmp1_byte and the hi byte in A.
    lda Zp_ShapePosY_i16 + 0
    sub Zp_Tmp1_byte  ; screen-space chain top (lo)
    sta Zp_Tmp1_byte  ; chain pixel length (lo)
    lda Zp_ShapePosY_i16 + 1
    sbc Zp_Tmp2_byte  ; screen-space chain top (hi)
    ;; Divide the chain pixel length by kTileHeightPx to get the length of the
    ;; chain in tiles, storing it in X.  Because we added an additional
    ;; (kTileHeightPx - 1) to the chain length above, this division will
    ;; effectively round up instead of down.
    .assert kTileHeightPx = 8, error
    .repeat 3
    lsr a
    ror Zp_Tmp1_byte  ; chain pixel length (lo)
    .endrepeat
    ldx Zp_Tmp1_byte  ; param: chain length in tiles
    ;; Draw the chain.
    .assert * = FuncA_Objects_DrawChainWithLength, error, "fallthrough"
.ENDPROC

;;; Allocates and populates OAM slots for a chain of the given length.  When
;;; this function returns, the shape position will be set to the top-left
;;; corner of the chain.
;;; @prereq The shape position is set to the bottom-left corner of the chain.
;;; @param X The number of tiles in the chain (nonzero).
.EXPORT FuncA_Objects_DrawChainWithLength
.PROC FuncA_Objects_DrawChainWithLength
    @loop:
    jsr FuncA_Objects_MoveShapeUpOneTile  ; preserves X
    jsr FuncA_Objects_Alloc1x1Shape  ; preserves X, returns C and Y
    bcs @continue
    lda #kTileIdWinchChain
    sta Ram_Oam_sObj_arr64 + sObj::Tile_u8, y
    lda #kWinchChainPalette
    sta Ram_Oam_sObj_arr64 + sObj::Flags_bObj, y
    @continue:
    dex
    bne @loop
    rts
.ENDPROC

;;; Populates Zp_ShapePosX_i16 and Zp_ShapePosY_i16 with the screen position of
;;; the center of the specified winch spikeball.
;;; @param X The spikeball platform index.
;;; @preserve X, Y
.EXPORT FuncA_Objects_SetShapePosToSpikeballCenter
.PROC FuncA_Objects_SetShapePosToSpikeballCenter
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X and Y
    lda Zp_ShapePosX_i16 + 0
    add #6
    sta Zp_ShapePosX_i16 + 0
    lda Zp_ShapePosX_i16 + 1
    adc #0
    sta Zp_ShapePosX_i16 + 1
    lda Zp_ShapePosY_i16 + 0
    add #6
    sta Zp_ShapePosY_i16 + 0
    lda Zp_ShapePosY_i16 + 1
    adc #0
    sta Zp_ShapePosY_i16 + 1
    rts
.ENDPROC

;;; Allocates and populates OAM slots for a winch spikeball.
;;; @prereq The shape position is set to the center of the spikeball.
;;; @preserve X
.EXPORT FuncA_Objects_DrawWinchSpikeball
.PROC FuncA_Objects_DrawWinchSpikeball
    lda #kSpikeballPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kTileIdSpikeballFirst + 0
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdSpikeballFirst + 1
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    lda #kTileIdSpikeballFirst + 2
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdSpikeballFirst + 3
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for a winch crusher.  When this returns,
;;; the shape position will be set to the center of the crusher.
;;; @param X The platform index for the upper (solid) part of the crusher.
;;; @preserve X
.EXPORT FuncA_Objects_DrawWinchCrusher
.PROC FuncA_Objects_DrawWinchCrusher
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X
    jsr FuncA_Objects_MoveShapeDownOneTile  ; preserves X
    lda #kCrusherPalette  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda #kTileIdCrusherUpperLeft
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    lda #kTileIdCrusherUpperRight
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    lda #kTileIdCrusherSpikes
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;; Allocates and populates OAM slots for a winch-breakable floor.
;;; @param A How many more hits the floor can take (1-3).
;;; @param X The platform index for the breakable floor.
;;; @preserve X
.EXPORT FuncA_Objects_DrawWinchBreakableFloor
.PROC FuncA_Objects_DrawWinchBreakableFloor
    pha  ; floor HP
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft  ; preserves X
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X
    lda #0  ; param: object flags
    jsr FuncA_Objects_Alloc2x1Shape  ; preserves X, returns C and Y
    pla  ; floor HP
    bcs @done
    mul #2
    adc #kTileIdWeakFloorFirst - 2  ; carry bit is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    adc #1  ; carry bit is already clear
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
