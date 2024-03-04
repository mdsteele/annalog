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
.INCLUDE "../actors/firefly.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/lift.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_LiftTick
.IMPORT FuncA_Machine_LiftTryMove
.IMPORT FuncA_Objects_DrawLiftMachine
.IMPORT Func_Noop
.IMPORT Func_WriteToLowerAttributeTable
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr

;;;=========================================================================;;;

;;; The machine index for the ShadowEntryLift machine in this room.
kLiftMachineIndex = 0

;;; The primary platform index for the ShadowEntryLift machine.
kLiftPlatformIndex = 0

;;; The initial and maximum permitted vertical goal values for the lift.
kLiftInitGoalY = 0
kLiftMaxGoalY = 19

;;; The maximum and initial Y-positions for the top of the lift platform.
kLiftMaxPlatformTop = $0150
kLiftMinPlatformTop = kLiftMaxPlatformTop - kLiftMaxGoalY * kBlockHeightPx
kLiftInitPlatformTop = kLiftMaxPlatformTop - kLiftInitGoalY * kBlockHeightPx

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Entry_sRoom
.PROC DataC_Shadow_Entry_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Shadow
    d_byte MinimapStartRow_u8, 12
    d_byte MinimapStartCol_u8, 9
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncA_Terrain_ShadowEntry_FadeInRoom
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_entry.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLiftMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::ShadowEntryLift
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveV
    d_byte Status_eDiagram, eDiagram::Lift
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $d0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLiftPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_ShadowEntryLift_InitReset
    d_addr ReadReg_func_ptr, FuncC_Shadow_EntryLift_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_ShadowEntryLift_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_Error
    d_addr Tick_func_ptr, FuncA_Machine_ShadowEntryLift_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLiftMachine
    d_addr Reset_func_ptr, FuncA_Room_ShadowEntryLift_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLiftPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLiftMachineWidthPx
    d_byte HeightPx_u8, kLiftMachineHeightPx
    d_word Left_i16, $0080
    d_word Top_i16, kLiftInitPlatformTop
    D_END
    ;; Acid:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0020
    d_word Top_i16,   $015a
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0080
    d_word Top_i16,   $016a
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $00b0
    d_word Top_i16,   $015a
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadFirefly
    d_word PosX_i16, $00d0
    d_word PosY_i16, $00b8
    d_byte Param_byte, (bBadFirefly::ThetaMask & $80) | bBadFirefly::FlipH
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadFirefly
    d_word PosX_i16, $0030
    d_word PosY_i16, $0118
    d_byte Param_byte, bBadFirefly::ThetaMask & $40
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 19
    d_byte BlockCol_u8, 3
    d_byte Target_byte, kLiftMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Paper
    d_byte BlockRow_u8, 6
    d_byte BlockCol_u8, 3
    d_byte Target_byte, eFlag::PaperJerome01
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::ShadowGate
    d_byte SpawnBlock_u8, 6
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::ShadowTeleport
    d_byte SpawnBlock_u8, 18
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Shadow_EntryLift_ReadReg
    lda #<(kLiftMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kLiftPlatformIndex
    sta T0
    lda #>(kLiftMaxPlatformTop + kTileHeightPx)
    sbc Ram_PlatformTop_i16_1_arr + kLiftPlatformIndex
    .assert kBlockHeightPx = 1 << 4, error
    .repeat 4
    lsr a
    lsr T0
    .endrepeat
    lda T0
    cmp #10
    blt @done
    lda #9
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_ShadowEntryLift_InitReset
    lda #kLiftInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLiftMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_ShadowEntryLift_TryMove
    lda #kLiftMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_LiftTryMove
.ENDPROC

.PROC FuncA_Machine_ShadowEntryLift_Tick
    ldax #kLiftMaxPlatformTop  ; param: max platform top
    jmp FuncA_Machine_LiftTick
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Sets two block rows of the lower nametable to use BG palette 2.
;;; @prereq Rendering is disabled.
.PROC FuncA_Terrain_ShadowEntry_FadeInRoom
    ldx #7    ; param: num bytes to write
    ldy #$aa  ; param: attribute value
    lda #$19  ; param: initial byte offset
    jmp Func_WriteToLowerAttributeTable
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_PaperJerome01_sDialog
.PROC DataA_Dialog_PaperJerome01_sDialog
    dlg_Text Paper, DataA_Text0_PaperJerome01_Page1_u8_arr
    dlg_Text Paper, DataA_Text0_PaperJerome01_Page2_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_PaperJerome01_Page1_u8_arr
    .byte "Day 1: My name is$"
    .byte "Jerome. It was I who$"
    .byte "created the orcs.#"
.ENDPROC

.PROC DataA_Text0_PaperJerome01_Page2_u8_arr
    .byte "And now, I feel that I$"
    .byte "must speak out.#"
.ENDPROC

;;;=========================================================================;;;
