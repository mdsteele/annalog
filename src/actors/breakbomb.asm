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
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "breakbomb.inc"

.IMPORT FuncA_Actor_ApplyGravity
.IMPORT FuncA_Actor_CenterHitsTerrain
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_InitActorProjBreakfire
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_GetRandomByte
.IMPORT Func_InitActorDefault
.IMPORT Func_PlaySfxExplodeBig
.IMPORT Func_RemoveActor
.IMPORT Func_ShakeRoom
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorVelX_i16_0_arr
.IMPORT Ram_ActorVelX_i16_1_arr
.IMPORT Ram_ActorVelY_i16_0_arr
.IMPORT Ram_ActorVelY_i16_1_arr
.IMPORTZP Zp_FrameCounter_u8

;;;=========================================================================;;;

;;; The initial horizontal speed (unsigned) for a breakbomb projectile, in
;;; subpixels/frame.
kBreakBombInitSpeedX = 140

;;; The initial vertical velocity (signed) for a breakbomb projectile, in
;;; subpixels/frame.
kBreakBombInitVelY = $ffff & -600

;;; How many frames the room shakes for when a breakbomb hits the ground.
kBreakbombShakeFrames = 4

;;; The OBJ palette number used for breakbomb projectile actors.
kPaletteObjProjBreakbomb = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a breakbomb projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param A Zero if the breakbomb should move right, or bObj::FlipH for left.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorProjBreakbomb
.PROC FuncA_Room_InitActorProjBreakbomb
    pha  ; flags
    ldy #eActor::ProjBreakbomb  ; param: actor type
    jsr Func_InitActorDefault  ; preserves X
_InitVelY:
    lda #<kBreakBombInitVelY
    sta Ram_ActorVelY_i16_0_arr, x
    lda #>kBreakBombInitVelY
    sta Ram_ActorVelY_i16_1_arr, x
_InitVelX:
    pla  ; flags
    beq @right
    @left:
    ldya #$ffff & -kBreakBombInitSpeedX
    bmi @finish  ; unconditional
    @right:
    ldya #kBreakBombInitSpeedX
    @finish:
    sta Ram_ActorVelX_i16_0_arr, x
    tya
    sta Ram_ActorVelX_i16_1_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a breakbomb projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjBreakbomb
.PROC FuncA_Actor_TickProjBreakbomb
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    jsr FuncA_Actor_ApplyGravity  ; preserves X
_ExpireIfTooOld:
    inc Ram_ActorState1_byte_arr, x
    bne @done
    jmp Func_RemoveActor  ; preserves X
    @done:
_ExplodeIfHitsTerrain:
    jsr FuncA_Actor_CenterHitsTerrain  ; preserves X, returns C
    bcc @done
    ;; Adjust the breakbomb's position to 8 pixels above the floor it just hit.
    lda Ram_ActorPosY_i16_0_arr, x
    sub #kBlockHeightPx
    .assert kBlockHeightPx = $10, error
    and #$f0
    ora #$08
    sta Ram_ActorPosY_i16_0_arr, x
    lda Ram_ActorPosY_i16_1_arr, x
    sbc #0
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Explode into breakfire.
    lda #kBreakbombShakeFrames  ; param: num frames
    jsr Func_ShakeRoom  ; preserves X
    jsr Func_PlaySfxExplodeBig  ; preserves X
    jsr Func_GetRandomByte  ; preserves X, returns A
    and #bObj::FlipH  ; param: flags
    jmp FuncA_Actor_InitActorProjBreakfire  ; preserves X
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a breakbomb projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjBreakbomb
.PROC FuncA_Objects_DrawActorProjBreakbomb
    lda Zp_FrameCounter_u8
    div #2
    and #$01
    .assert kTileIdObjProjBreakbombFirst .mod 2 = 0, error
    ora #kTileIdObjProjBreakbombFirst  ; param: tile ID
    ldy #kPaletteObjProjBreakbomb  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
