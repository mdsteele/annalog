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
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_MoveShapeDownOneTile
.IMPORT FuncA_Objects_MoveShapeRightOneTile
.IMPORT FuncA_Objects_MoveShapeUpOneTile
.IMPORT Ram_MachineParam1_u8_arr
.IMPORT Ram_MachineParam2_i16_0_arr
.IMPORT Ram_MachineParam2_i16_1_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORTZP Zp_MachineIndex_u8
.IMPORTZP Zp_PlatformGoal_i16
.IMPORTZP Zp_RoomScrollY_u8
.IMPORTZP Zp_ShapePosY_i16
.IMPORTZP Zp_Tmp1_byte
.IMPORTZP Zp_Tmp2_byte

;;;=========================================================================;;;

;;; The terminal velocity for a falling winch load, in pixels per frame.
.DEFINE kWinchMaxFallSpeed 5

;;; How many frames a falling winch machine must wait after hitting the ground
;;; before it can move again.
kWinchFallRecoverFrames = 60

;;; How many pixels above the bottom of the winch machine the chain must extend
;;; in order to appear to feed into the machine.
kWinchChainOverlapPx = 4

;;; Various OBJ tile IDs used for drawing winch machines.
kTileIdWinchChain         = $b7
kTileIdWinchGear1         = $bc
kTileIdWinchGear2         = $be
kTileIdWinchCornerBottom1 = $bd
kTileIdWinchCornerBottom2 = $bf
kTileIdWinchCornerTop     = $73

;;; OBJ palette numbers used for various parts of winch machines.
kWinchChainPalette = 0
kWinchGearPalette  = 0

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
    lda Ram_MachineParam1_u8_arr, y
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
    lda Ram_MachineParam2_i16_0_arr, y
    add #kAvatarGravity
    sta Ram_MachineParam2_i16_0_arr, y
    lda Ram_MachineParam2_i16_1_arr, y
    adc #0
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
;;; @param A The fall distance, in blocks.
;;; @return C Set if there was an error, cleared otherwise.
;;; @return A How many frames to wait before advancing the PC.
.EXPORT FuncA_Machine_WinchStartFalling
.PROC FuncA_Machine_WinchStartFalling
    tax  ; fall distance, in blocks
    ;; Start falling.
    ldy Zp_MachineIndex_u8
    lda #$ff
    sta Ram_MachineParam1_u8_arr, y
    lda #0
    sta Ram_MachineParam2_i16_0_arr, y
    sta Ram_MachineParam2_i16_1_arr, y
    ;; Determine how long it will take for the load to fall.
    lda DataA_Machine_WinchFallTime_u8_arr, x
    clc  ; success
    rts
.ENDPROC

;;; For a falling winch machine, this array maps from the initial fall
;;; distance, in blocks, to the number of frames before the winch can move
;;; again.
.PROC DataA_Machine_WinchFallTime_u8_arr
    .byte kWinchFallRecoverFrames
    vFallTime .set 0
    vFallVel .set 0
    vFallDist .set 0
    .repeat 68
    vFallTime .set vFallTime + 1
    vFallVel .set vFallVel + kAvatarGravity
    .if vFallVel > kWinchMaxFallSpeed * $100
    vFallVel .set kWinchMaxFallSpeed * $100
    .endif
    vFallDist .set vFallDist + vFallVel
    .if vFallDist >= $1000
    vFallDist .set vFallDist - $1000
    .byte vFallTime + kWinchFallRecoverFrames
    .endif
    .endrepeat
    .assert * - DataA_Machine_WinchFallTime_u8_arr = 18, error
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Allocates and populates OAM slots for a winch machine.
;;; @prereq Zp_MachineIndex_u8 is initialized.
;;; @prereq The shape position is set to the top-left corner of the machine.
;;; @param X The low byte of the Y-position of the end of the chain.
.EXPORT FuncA_Objects_DrawWinchMachine
.PROC FuncA_Objects_DrawWinchMachine
    jsr FuncA_Objects_MoveShapeDownOneTile   ; preserves X
    jsr FuncA_Objects_MoveShapeRightOneTile  ; preserves X
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

;;;=========================================================================;;;
