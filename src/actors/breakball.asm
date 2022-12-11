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
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../terrain.inc"
.INCLUDE "breakball.inc"

.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_NegateVelX
.IMPORT FuncA_Actor_NegateVelY
.IMPORT FuncA_Actor_SetActorCenterToPoint
.IMPORT FuncA_Objects_Alloc2x2Shape
.IMPORT FuncA_Objects_SetShapePosToActorCenter
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorDefault
.IMPORT Func_InitActorProjFlamewave
.IMPORT Func_IsPointInAnySolidPlatform
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointLeftByA
.IMPORT Func_MovePointRightByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORT Ram_Oam_sObj_arr64
.IMPORTZP Zp_FrameCounter_u8
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The OBJ palette number used for breakball projectile actors.
kPaletteObjBreakball = 1

;;; How many VBlank frames between breakball animation frames.
.DEFINE kProjBreakballAnimSlowdown 4

;;; How fast the breakball moves horizontally/vertically, in subpixels/frame.
kProjBreakballSpeed = $c0

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a breakball projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A Zero if the breakball should move right, or bObj::FlipH for left.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorProjBreakball
.PROC FuncA_Room_InitActorProjBreakball
    sta Zp_Tmp1_byte  ; horz flag
    ldy #eActor::ProjBreakball  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X and Zp_Tmp*
_InitVelY:
    lda #kProjBreakballSpeed
    ldy #0
    sta Ram_ActorVelY_i16_0_arr, x
    tya
    sta Ram_ActorVelY_i16_1_arr, x
_InitVelX:
    bit Zp_Tmp1_byte  ; horz flag
    .assert bObj::FlipH = bProc::Overflow, error
    bvs @left
    @right:
    lda #kProjBreakballSpeed
    bne @setXVel  ; unconditional
    @left:
    dey  ; now Y is $ff
    lda #<-kProjBreakballSpeed
    @setXVel:
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a breakball projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjBreakball
.PROC FuncA_Actor_TickProjBreakball
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    jsr FuncA_Actor_ProjBreakball_CheckForCollisionHorz  ; preserves X
    ;; TODO: bounce off platform sides?
    jsr FuncA_Actor_ProjBreakball_CheckForCollisionVert  ; preserves X
    rts
.ENDPROC

;;; If the breakball is hitting the side of a terrain wall, bounce it
;;; horizontally.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_ProjBreakball_CheckForCollisionHorz
    jsr Func_SetPointToActorCenter  ; preserves X
    lda Ram_ActorVelX_i16_1_arr, x
    bpl @movingRight
    @movingLeft:
    lda #kProjBreakballRadius  ; param: offset
    jsr Func_MovePointLeftByA  ; preserves X
    jmp _CheckForCollision
    @movingRight:
    lda #kProjBreakballRadius  ; param: offset
    jsr Func_MovePointRightByA  ; preserves X
_CheckForCollision:
    ;; If the bottom of the breakball hits terrain, bounce off of it.
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _Bounce
    ;; If the bottom of the breakball hits a platform, bounce off of it.
    jsr Func_IsPointInAnySolidPlatform  ; preserves X, returns C
    bcs _Bounce
    rts
_Bounce:
    jmp FuncA_Actor_NegateVelX  ; preserves X
.ENDPROC

;;; If the breakball is hitting the top of a terrain floor, explode it into
;;; flame waves.
;;; @param X The actor index.
;;; @preserve X
.PROC FuncA_Actor_ProjBreakball_CheckForCollisionVert
    jsr Func_SetPointToActorCenter  ; preserves X
    ;; The breakball can only hit the floor if it's moving downwards.
    lda Ram_ActorVelY_i16_1_arr, x
    bpl _MovingDown
_MovingUp:
    ;; Set the point to the top of the breakball.
    lda #kProjBreakballRadius  ; param: offset
    jsr Func_MovePointUpByA  ; preserves X
    ;; If the terrain is solid, expire the breakball.
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcc @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    @done:
    rts
_MovingDown:
    ;; Set the point to the bottom of the breakball.
    lda #kProjBreakballRadius  ; param: offset
    jsr Func_MovePointDownByA  ; preserves X
    ;; If the bottom of the breakball hits terrain, explode the breakball.
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _Explode
    ;; If the bottom of the breakball hits a platform, bounce off of it.
    jsr Func_IsPointInAnySolidPlatform  ; preserves X, returns C
    bcc @noBounce
    jmp FuncA_Actor_NegateVelY  ; preserves X
    @noBounce:
    rts
_Explode:
    ;; Adjust the breakball's position to 8 pixels above the floor.
    lda Ram_ActorPosY_i16_0_arr, x
    .assert kBlockHeightPx = $10, error
    and #$f0
    ora #$08
    sta Ram_ActorPosY_i16_0_arr, x
    ;; Turn the breakball into two flamewave projetiles moving in opposite
    ;; directions.
    txa  ; breakball actor index
    pha  ; breakball actor index
    jsr Func_SetPointToActorCenter  ; preserves X
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @doneFirstFlamewave
    jsr FuncA_Actor_SetActorCenterToPoint  ; preserves X
    lda #0  ; param: direction (0 = right)
    jsr Func_InitActorProjFlamewave
    @doneFirstFlamewave:
    pla  ; breakball actor index
    tax  ; param: actor index
    lda #bObj::FlipH  ; param: direction (FlipH = left)
    jmp Func_InitActorProjFlamewave  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a breakball projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjBreakball
.PROC FuncA_Objects_DrawActorProjBreakball
    jsr FuncA_Objects_SetShapePosToActorCenter  ; preserves X
    lda #kPaletteObjBreakball  ; param: object flags
    jsr FuncA_Objects_Alloc2x2Shape  ; preserves X, returns C and Y
    bcs @done
    lda Zp_FrameCounter_u8
    div #kProjBreakballAnimSlowdown
    and #$01
    add #kTileIdObjBreakballFirst
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 0 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Tile_u8, y
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Tile_u8, y
    lda #kPaletteObjBreakball | bObj::FlipV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 1 + sObj::Flags_bObj, y
    lda #kPaletteObjBreakball | bObj::FlipH
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 2 + sObj::Flags_bObj, y
    lda #kPaletteObjBreakball | bObj::FlipHV
    sta Ram_Oam_sObj_arr64 + .sizeof(sObj) * 3 + sObj::Flags_bObj, y
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
