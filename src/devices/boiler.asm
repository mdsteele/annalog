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

.INCLUDE "../device.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "boiler.inc"

.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorProjSteamHorz
.IMPORT Func_InitActorProjSteamUp
.IMPORT Func_MovePointRightByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetPointToPlatformCenter

;;;=========================================================================;;;

;;; Ensure that the bBoiler  mask is wide enough to include any device.
.ASSERT bBoiler::PipeMask + 1 >= kMaxDevices, error

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Given a bBoiler value, emit steam from its pipe platform.
;;; @param A The bBoiler value.
;;; @preserve T0+
.EXPORT Func_EmitSteamFromPipe
.PROC Func_EmitSteamFromPipe
    tax  ; bBoiler value
    and #bBoiler::PipeMask
    tay  ; param: pipe platform index
    txa  ; bBoiler value
    .assert bBoiler::SteamUp = $80, error
    bmi Func_EmitSteamUpFromPipe  ; preserves T0+
    fall Func_EmitSteamRightFromPipe  ; preserves T0+
.ENDPROC

;;; Given an 8x8 pixel platform covering the end tile of a rightward-facing
;;; pipe, spawns a rightward steam actor emitting from that pipe.
;;; @param Y The platform index for the pipe.
;;; @preserve T0+
.EXPORT Func_EmitSteamRightFromPipe
.PROC Func_EmitSteamRightFromPipe
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
    bcs Func_DoNotEmitSteam  ; preserves T0+
    jsr Func_SetPointToPlatformCenter  ; preserves X and T0+
    lda #kTileWidthPx * 3 / 2  ; param: offset
    jsr Func_MovePointRightByA  ; preserves X and T0+
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    lda #0  ; param: facing dir
    jmp Func_InitActorProjSteamHorz  ; preserves T0+
.ENDPROC

;;; Given an 8x8 pixel platform covering the end tile of an upward-facing pipe,
;;; spawns an upward steam actor emitting from that pipe.
;;; @param Y The platform index for the pipe.
;;; @preserve T0+
.EXPORT Func_EmitSteamUpFromPipe
.PROC Func_EmitSteamUpFromPipe
    jsr Func_FindEmptyActorSlot  ; preserves Y and T0+, returns C and X
    bcs Func_DoNotEmitSteam  ; preserves T0+
    jsr Func_SetPointToPlatformCenter  ; preserves X and T0+
    lda #kTileHeightPx * 3 / 2  ; param: offset
    jsr Func_MovePointUpByA  ; preserves X and T0+
    jsr Func_SetActorCenterToPoint  ; preserves X and T0+
    jmp Func_InitActorProjSteamUp  ; preserves T0+
.ENDPROC

;;; No-op function for when a Func_EmitSteam* function above is unable to
;;; allocate an actor slot for the steam.
;;; @preserve T0+
.PROC Func_DoNotEmitSteam
    rts
.ENDPROC

;;;=========================================================================;;;
