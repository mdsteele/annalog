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
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "egg.inc"
.INCLUDE "solifuge.inc"

.IMPORT FuncA_Actor_ApplyGravityWithTerminalVelocity
.IMPORT FuncA_Actor_HarmAvatarIfCollision
.IMPORT FuncA_Actor_IsInRoomBounds
.IMPORT FuncA_Actor_SetPointAboveOrBelowActor
.IMPORT FuncA_Objects_Draw1x1Actor
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorBadSolifuge
.IMPORT Func_InitActorDefault
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInAnySolidPlatform
.IMPORT Func_PlaySfxPoof
.IMPORT Func_PointHitsTerrain
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToActorCenter
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The terminal velocity for a falling egg, in pixels per frame.
kProjEggTerminalVelocity = 4

;;; The OBJ palette number used for solifuge egg projectile actors.
kPaletteObjEgg = 1

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; Initializes the specified actor as a solifuge egg projectile.
;;; @prereq The actor's pixel position has already been initialized.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Room_InitActorProjEgg
.PROC FuncA_Room_InitActorProjEgg
    ldy #eActor::ProjEgg  ; param: actor type
    jmp Func_InitActorDefault  ; preserves X
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Actor"

;;; Performs per-frame updates for a solifuge egg projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Actor_TickProjEgg
.PROC FuncA_Actor_TickProjEgg
    jsr FuncA_Actor_HarmAvatarIfCollision  ; preserves X
    ;; Remove the egg if it somehow falls out of the room without hitting a
    ;; solid platform or terrain.
    jsr FuncA_Actor_IsInRoomBounds  ; preserves X, returns C
    bcc _Remove
    ;; We want to hatch the egg while its center is still in the empty terrain
    ;; block above the solid terrain that it hits, so check far enough below
    ;; the center of the egg to ensure that the center of the egg won't be
    ;; inside the solid terrain next frame.
    lda #kProjEggTerminalVelocity
    jsr FuncA_Actor_SetPointAboveOrBelowActor  ; preserves X
    ;; If the egg lands on a solid platform or terrain, it will hatch or break.
    jsr Func_IsPointInAnySolidPlatform  ; preserves X, returns C and Y
    bcs _HitSolidPlatform
    jsr Func_PointHitsTerrain  ; preserves X, returns C
    bcs _Hatch
    ;; Otherwise, keep falling.
    lda #kProjEggTerminalVelocity  ; param: terminal velocity
    jmp FuncA_Actor_ApplyGravityWithTerminalVelocity  ; preserves X
_HitSolidPlatform:
    ;; If the egg hits a Harm or Kill platform, just destroy the egg.
    ;; Otherwise, hatch the egg.
    lda Ram_PlatformType_ePlatform_arr, y
    cmp #kFirstHarmfulPlatformType
    bge _Break
_Hatch:
    jsr Func_SetPointToActorCenter  ; preserves X
    ;; Align the point to kBadSolifugeBoundingBoxDown pixels above this block.
    lda Zp_PointY_i16 + 0
    and #$f0
    ora #$10 - kBadSolifugeBoundingBoxDown
    sta Zp_PointY_i16 + 0
    ;; Spawn a solifuge baddie actor at the point position.
    stx T0  ; egg actor index
    jsr Func_FindEmptyActorSlot  ; preserves T0+, returns C and X
    bcs @noSpawn
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_InitActorBadSolifuge
    @noSpawn:
    ldx T0  ; egg actor index
_Break:
    jsr Func_PlaySfxPoof  ; preserves X
    jmp Func_InitActorSmokeExplosion  ; preserves X
_Remove:
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a solifuge egg projectile actor.
;;; @param X The actor index.
;;; @preserve X
.EXPORT FuncA_Objects_DrawActorProjEgg
.PROC FuncA_Objects_DrawActorProjEgg
    lda #kTileIdObjProjEgg  ; param: tile ID
    ldy #kPaletteObjEgg  ; param: palette
    jmp FuncA_Objects_Draw1x1Actor  ; preserves X
.ENDPROC

;;;=========================================================================;;;
