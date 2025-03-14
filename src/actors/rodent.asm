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
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../devices/mousehole.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"
.INCLUDE "rodent.inc"

.IMPORT FuncA_Actor_FindNearbyDevice
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_SetPointAboveOrBelowActor
.IMPORT FuncA_Actor_SetPointInFrontOfActor
.IMPORT FuncA_Actor_SetVelXForward
.IMPORT FuncA_Actor_SetVelYUpOrDown
.IMPORT FuncA_Actor_ZeroVelX
.IMPORT FuncA_Actor_ZeroVelY
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_GetRandomByte
.IMPORT Func_IsActorWithinDistanceOfPoint
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointHorz
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToDeviceCenter
.IMPORT Ram_ActorFlags_bObj_arr
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorState3_byte_arr
.IMPORT Ram_ActorSubX_u8_arr
.IMPORT Ram_ActorSubY_u8_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr

;;;=========================================================================;;;

;;; How many frames it takes for a rodent baddie to emerge from a mousehole.
kRodentEmergeFrames = 16
;;; How many frames a rodent baddie pauses for between fully emerging from a
;;; mousehole and when it starts running.
kRodentPauseFrames = 24
;;; How many frames a rodent baddie must run for before it can enter a
;;; mousehole again.
kRodentMinRunFrames = 16
;;; How fast a rodent baddie runs, in subpixels per frame.
kRodentRunSpeed = $250
;;; How many frames it takes for a rodent baddie to vanish into a mousehole.
kRodentVanishFrames = 16

;;; Various OBJ tile IDs for drawing rodent baddies:
kTileIdObjBadRodentEmergingFirst    = kTileIdObjBadRodentFirst + 6
kTileIdObjBadRodentRunningHorzFirst = kTileIdObjBadRodentFirst + 0
kTileIdObjBadRodentRunningVertFirst = kTileIdObjBadRodentFirst + 2
kTileIdObjBadRodentVanishingFirst   = kTileIdObjBadRodentFirst + 4

;;; The OBJ palette number used for rodent baddie actors.
kPaletteObjRodent = 0

;;;=========================================================================;;;

;;; Possible values for a rodent baddie actor's State1 byte.
.ENUM eBadRodent
    Hiding     ; hiding in the walls, absent from the room
    Emerging   ; coming out of a mousehole
    Running    ; running along the floor/wall/ceiling
    Vanishing  ; going into a mousehole
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a rodent baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickBadRodent
.PROC FuncA_Actor_TickBadRodent
    inc Ram_ActorState3_byte_arr, x  ; animation timer
    ldy Ram_ActorState1_byte_arr, x  ; eBadRodent mode
    lda _JumpTable_ptr_0_arr, y
    sta T0
    lda _JumpTable_ptr_1_arr, y
    sta T1
    jmp (T1T0)
.REPEAT 2, table
    D_TABLE_LO table, _JumpTable_ptr_0_arr
    D_TABLE_HI table, _JumpTable_ptr_1_arr
    D_TABLE .enum, eBadRodent
    d_entry table, Hiding,    FuncA_Actor_TickBadRodent_Hiding
    d_entry table, Emerging,  FuncA_Actor_TickBadRodent_Emerging
    d_entry table, Running,   FuncA_Actor_TickBadRodent_Running
    d_entry table, Vanishing, FuncA_Actor_TickBadRodent_Vanishing
    D_END
.ENDREPEAT
.ENDPROC

;;; Performs per-frame updates for a rodent baddie actor that's in Hiding mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRodent_Hiding
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    beq _TryEmerge
    dec Ram_ActorState2_byte_arr, x  ; mode timer
_StayHidden:
    rts
_TryEmerge:
    ;; Choose a random device; if it's a mousehole, the rodent will emerge from
    ;; it; otherwise, we'll try again next frame.
    jsr Func_GetRandomByte  ; preserves X, returns A
    .assert kMaxDevices = $10, error
    and #$0f
    tay  ; param: device index
    lda Ram_DeviceType_eDevice_arr, y
    cmp #eDevice::Mousehole
    bne _StayHidden
    ;; Set the point to the center of the mousehole.
    jsr Func_SetPointToDeviceCenter  ; preserves X and Y
    lda #kTileHeightPx / 2  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X and Y
    lda Ram_DeviceTarget_byte_arr, y  ; bMousehole value
    .assert bMousehole::OnRight = bProc::Negative, error
    bpl @onLeft
    @onRight:
    lda #kTileWidthPx / 2  ; param: offset
    bne @movePoint  ; unconditional
    @onLeft:
    lda #<-(kTileWidthPx / 2)  ; param: offset
    @movePoint:
    jsr Func_MovePointHorz  ; preserves X and Y
    ;; Check if any other rodents are in the way.  If so, don't emerge this
    ;; frame.
    stx T1  ; this rodent's actor index
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::BadRodent
    bne @continue
    cpx T1  ; this rodent's actor index
    beq @continue
    jsr Func_IsActorWithinDistanceOfPoint  ; preserves X and T1+, returns C
    bcc @continue
    ldx T1  ; this rodent's actor index
    rts
    @continue:
    dex
    bpl @loop
    ldx T1  ; this rodent's actor index
_SetEmergeDirection:
    ;; Choose a direction for the rodent to run in (left or right).
    lda Ram_DeviceTarget_byte_arr, y  ; bMousehole value
    and #bMousehole::RunLeft | bMousehole::RunRight
    cmp #bMousehole::RunLeft
    beq @runLeft
    cmp #bMousehole::RunRight
    beq @runRight
    jsr Func_GetRandomByte  ; preserves X and Y, returns N
    bmi @runRight
    @runLeft:
    lda #bObj::FlipH
    bne @setFlags  ; unconditional
    @runRight:
    lda #0
    @setFlags:
    sta Ram_ActorFlags_bObj_arr, x
_StartEmerging:
    ;; Make the rodent start emerging from the mousehole.  At this point, the
    ;; actor's State2 byte is already zero.
    lda #eBadRodent::Emerging
    sta Ram_ActorState1_byte_arr, x  ; eBadRodent mode
    jmp Func_SetActorCenterToPoint  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a rodent baddie actor that's in Emerging
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRodent_Emerging
    inc Ram_ActorState2_byte_arr, x  ; mode timer
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kRodentEmergeFrames + kRodentPauseFrames
    blt _Done
_StartRunning:
    lda #kRodentMinRunFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    lda #eBadRodent::Running
    sta Ram_ActorState1_byte_arr, x  ; eBadRodent mode
    ldya #kRodentRunSpeed  ; param: speed
    jsr FuncA_Actor_SetVelXForward  ; preserves X
_Done:
    rts
.ENDPROC

;;; Performs per-frame updates for a rodent baddie actor that's in Running
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRodent_Running
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
_DecrementTimer:
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    beq @done
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    @done:
_CheckDirection:
    ;; Check if the rodent is running horizontally or vertically.
    lda Ram_ActorVelY_i16_1_arr, x
    .assert >kRodentRunSpeed > 0, error
    beq FuncA_Actor_TickBadRodent_RunningHorz  ; preserves X
    fall FuncA_Actor_TickBadRodent_RunningVert  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a rodent baddie actor that's in Running
;;; mode and currently running vertically up or down a wall.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRodent_RunningVert
_CheckForCorner:
    lda #kTileHeightPx / 2  ; param: offset
    jsr FuncA_Actor_SetPointAboveOrBelowActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _HitInnerCorner
    lda #<-kTileWidthPx  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc _HitOuterCorner
    rts
_HitOuterCorner:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH | bObj::FlipV
    sta Ram_ActorFlags_bObj_arr, x
    lda #kTileWidthPx / 2
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
_HitInnerCorner:
    jsr FuncA_Actor_AlignRodentY  ; preserves X
    ldya #kRodentRunSpeed  ; param: speed
    jmp FuncA_Actor_SetVelXForward  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a rodent baddie actor that's in Running
;;; mode and currently running horizontally along a floor or ceiling.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRodent_RunningHorz
_CheckForMousehole:
    ;; If the rodent recently emerged from a mousehole, don't enter one yet.
    lda Ram_ActorState2_byte_arr, x
    bne @done
    ;; Check if the rodent is near a mousehole device.
    lda Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bmi @done  ; rodent is on the ceiling, so can't be on a mousehole
    jsr FuncA_Actor_FindNearbyDevice  ; preserves X, returns N and Y
    bmi @done  ; no nearby device
    lda Ram_DeviceType_eDevice_arr, y
    cmp #eDevice::Mousehole
    bne @done  ; device is not a mousehole
    ;; Check if the rodent is on the correct side of the mousehold device.
    lda Ram_ActorPosX_i16_0_arr, x
    .assert kTileWidthPx = $08, error
    and #$08
    sta T0  ; rodent block side (zero or nonzero)
    lda Ram_DeviceTarget_byte_arr, y
    .assert bMousehole::OnRight = bProc::Negative, error
    bmi @mouseholeOnRight
    @mouseholeOnLeft:
    lda T0  ; rodent block side (zero or nonzero)
    bne @done
    beq @startVanishing  ; unconditional
    @mouseholeOnRight:
    lda T0  ; rodent block side (zero or nonzero)
    beq @done
    ;; Switch to vanishing mode.
    @startVanishing:
    jsr FuncA_Actor_AlignRodentX  ; preserves X
    lda #eBadRodent::Vanishing
    sta Ram_ActorState1_byte_arr, x  ; eBadRodent mode
    lda #kRodentVanishFrames
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    rts
    @done:
_CheckForCorner:
    lda #kTileWidthPx / 2  ; param: offset
    jsr FuncA_Actor_SetPointInFrontOfActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _HitInnerCorner
    lda #kTileHeightPx  ; param: offset
    jsr FuncA_Actor_SetPointAboveOrBelowActor  ; preserves X
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc _HitOuterCorner
    rts
_HitInnerCorner:
    lda Ram_ActorFlags_bObj_arr, x
    eor #bObj::FlipH | bObj::FlipV
    sta Ram_ActorFlags_bObj_arr, x
    jmp _AlignForCorner
_HitOuterCorner:
    lda #kTileHeightPx / 2
    jsr FuncA_Actor_SetPointAboveOrBelowActor  ; preserves X
    jsr Func_SetActorCenterToPoint  ; preserves X
_AlignForCorner:
    jsr FuncA_Actor_AlignRodentX  ; preserves X
    ldya #kRodentRunSpeed  ; param: speed
    jmp FuncA_Actor_SetVelYUpOrDown  ; preserves X
.ENDPROC

;;; Zeroes the rodent baddie's X-velocity, and aligns the rodent's X-position
;;; to be on the wall.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_AlignRodentX
    lda #0
    sta Ram_ActorSubX_u8_arr, x
    lda Ram_ActorPosX_i16_0_arr, x
    .assert kTileWidthPx = 8, error
    and #$f8
    ora #$04
    sta Ram_ActorPosX_i16_0_arr, x
    jmp FuncA_Actor_ZeroVelX  ; preserves X
.ENDPROC

;;; Zeroes the rodent baddie's Y-velocity, and aligns the rodent's Y-position
;;; to be on the floor or ceiling.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_AlignRodentY
    lda #0
    sta Ram_ActorSubY_u8_arr, x
    lda Ram_ActorPosY_i16_0_arr, x
    .assert kTileHeightPx = 8, error
    and #$f8
    ldy Ram_ActorFlags_bObj_arr, x
    .assert bObj::FlipV = bProc::Negative, error
    bmi @onCeiling
    @onFloor:
    ora #$04
    bne @setPos  ; unconditional
    @onCeiling:
    ora #$03
    @setPos:
    sta Ram_ActorPosY_i16_0_arr, x
    jmp FuncA_Actor_ZeroVelY  ; preserves X
.ENDPROC

;;; Performs per-frame updates for a rodent baddie actor that's in Vanishing
;;; mode.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_TickBadRodent_Vanishing
    dec Ram_ActorState2_byte_arr, x  ; mode timer
    bne @done
    ;; Hide inside the mousehole network for a random amount of time.
    lda #eBadRodent::Hiding
    sta Ram_ActorState1_byte_arr, x  ; eBadRodent mode
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #$3f
    sta Ram_ActorState2_byte_arr, x  ; mode timer
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a rodent baddie actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorBadRodent
.PROC FuncA_Objects_DrawActorBadRodent
    lda Ram_ActorState1_byte_arr, x  ; eBadRodent mode
    .assert eBadRodent::Hiding = 0, error
    beq _Done
    cmp #eBadRodent::Running
    beq _Running
    .assert eBadRodent::Emerging < eBadRodent::Running, error
    .assert eBadRodent::Vanishing > eBadRodent::Running, error
    blt _Emerging
_Vanishing:
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kRodentVanishFrames / 2 + 1
    blt @secondFrame
    @firstFrame:
    lda #kTileIdObjBadRodentVanishingFirst + 0
    bne _Draw  ; unconditional
    @secondFrame:
    lda #kTileIdObjBadRodentVanishingFirst + 1
    bne _Draw  ; unconditional
_Running:
    lda Ram_ActorState3_byte_arr, x  ; animation timer
    div #4
    and #$01
    ;; Check if the rodent is running horizontally or vertically.
    ldy Ram_ActorVelY_i16_1_arr, x
    .assert >kRodentRunSpeed > 0, error
    beq @horz
    @vert:
    .assert kTileIdObjBadRodentRunningVertFirst .mod 2 = 0, error
    ora #kTileIdObjBadRodentRunningVertFirst
    bne _Draw  ; unconditional
    @horz:
    .assert kTileIdObjBadRodentRunningHorzFirst .mod 2 = 0, error
    ora #kTileIdObjBadRodentRunningHorzFirst
    bne _Draw  ; unconditional
_Emerging:
    lda Ram_ActorState2_byte_arr, x  ; mode timer
    cmp #kRodentEmergeFrames
    bge @thirdFrame
    cmp #kRodentEmergeFrames / 2
    bge @secondFrame
    @firstFrame:
    lda #kTileIdObjBadRodentEmergingFirst + 0
    bne _Draw  ; unconditional
    @secondFrame:
    lda #kTileIdObjBadRodentEmergingFirst + 1
    bne _Draw  ; unconditional
    @thirdFrame:
    lda #kTileIdObjBadRodentEmergingFirst + 2
_Draw:
    ldy #kPaletteObjRodent  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;
