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

.INCLUDE "../macros.inc"
.INCLUDE "pump.inc"
.INCLUDE "shared.inc"

.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_GetMachineLightTileId
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws a pump machine.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.EXPORT FuncA_Objects_DrawPumpMachine
.PROC FuncA_Objects_DrawPumpMachine
    jsr FuncA_Objects_GetMachineLightTileId  ; returns A
    cmp #kTileIdObjMachineLightOn
    bne @done
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    lda #kTileIdObjPumpLight  ; param: tile ID
    ldy #kPaletteObjMachineLight  ; param: object flags
    jmp FuncA_Objects_Draw1x1Shape
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;
