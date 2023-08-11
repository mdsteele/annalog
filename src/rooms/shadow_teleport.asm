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
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/field.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../teleport.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_FieldTick
.IMPORT FuncA_Machine_FieldTryAct
.IMPORT FuncA_Objects_DrawFieldMachine
.IMPORT FuncA_Room_MachineFieldReset
.IMPORT Func_MachineFieldReadRegT
.IMPORT Func_Noop
.IMPORT Ppu_ChrObjLava

;;;=========================================================================;;;

;;; The machine index for the ShadowTeleportField machine in this room.
kFieldMachineIndex = 0

;;; The primary platform index for the ShadowTeleportField machine.
kFieldPlatformIndex = 0

;;; The platform positions for the ShadowTeleportField machine.
.LINECONT +
kFieldPlatformTop  = $70
kFieldPlatformLeft1 = $68
kFieldPlatformLeft2 = \
    kFieldPlatformLeft1 + kFieldMachineWidth + kTeleportFieldWidth
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Teleport_sRoom
.PROC DataC_Shadow_Teleport_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, eArea::Shadow
    d_byte MinimapStartRow_u8, 13
    d_byte MinimapStartCol_u8, 10
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjLava)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncC_Shadow_Teleport_FadeInRoom
    D_END
_TerrainData:
:   .incbin "out/data/shadow_teleport.room"
    .assert * - :- = 17 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kFieldMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::ShadowTeleportField
    d_byte Breaker_eFlag, eFlag::BreakerCity
    d_byte Flags_bMachine, bMachine::Act
    d_byte Status_eDiagram, eDiagram::Field
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, "T", 0, 0, 0
    d_byte MainPlatform_u8, kFieldPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineFieldReadRegT
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_FieldTryAct
    d_addr Tick_func_ptr, FuncA_Machine_FieldTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawFieldMachine
    d_addr Reset_func_ptr, FuncA_Room_MachineFieldReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kFieldPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kFieldMachineWidth
    d_byte HeightPx_u8, kFieldMachineHeight
    d_word Left_i16, kFieldPlatformLeft1
    d_word Top_i16,  kFieldPlatformTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kFieldMachineWidth
    d_byte HeightPx_u8, kFieldMachineHeight
    d_word Left_i16, kFieldPlatformLeft2
    d_word Top_i16,  kFieldPlatformTop
    D_END
    ;; Acid:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $d0
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0030
    d_word Top_i16,   $00ba
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kTeleporterDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Teleporter
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eRoom::LavaTeleport
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kFieldMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Screen
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 5
    d_byte Target_byte, eDialog::ShadowTeleportScreen
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::ShadowEntry
    d_byte SpawnBlock_u8, 9
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Sets two block rows of the upper nametable to use BG palette 2.
;;; @prereq Rendering is disabled.
.PROC FuncC_Shadow_Teleport_FadeInRoom
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable0_sName + sName::Attrs_u8_arr64 + $28
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
_Row11:
    lda #$a0
    ldx #8
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
_Row12:
    lda #$0a
    ldx #8
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_ShadowTeleportScreen_sDialog
.PROC DataA_Dialog_ShadowTeleportScreen_sDialog
    dlg_Text Screen, DataA_Text0_ShadowTeleportScreen_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text0"

.PROC DataA_Text0_ShadowTeleportScreen_u8_arr
    .byte "Lorem ipsum.#"
.ENDPROC

;;;=========================================================================;;;
