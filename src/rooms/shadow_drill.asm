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
.INCLUDE "../machine.inc"
.INCLUDE "../machines/laser.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_LaserTryAct
.IMPORT FuncA_Machine_LaserWriteReg
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawLaserMachine
.IMPORT FuncA_Room_HarmAvatarIfWithinLaserBeam
.IMPORT FuncA_Room_KillGooWithLaserBeam
.IMPORT FuncA_Room_MachineLaserReset
.IMPORT Func_MachineLaserReadRegC
.IMPORT Func_Noop
.IMPORT Func_SetMachineIndex
.IMPORT Func_WriteToLowerAttributeTable
.IMPORT Ppu_ChrObjShadow
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORTZP Zp_AvatarFlags_bObj
.IMPORTZP Zp_AvatarPosY_i16

;;;=========================================================================;;;

;;; The index of the upper passage (which leads to the ShadowHall room).
kUpperPassageIndex = 0

;;; The room pixel Y-position of the center of the upper passage.
kUpperPassageCenterY = $0050

;;; The room pixel Y-position of the center of the lower passages.
kLowerPassageCenterY = $0150

;;;=========================================================================;;;

;;; The machine index for the ShadowDrillLaser machine in this room.
kLaserMachineIndex = 0

;;; The primary platform index for the ShadowDrillLaser machine.
kLaserPlatformIndex = 0

;;; The initial and maximum permitted horizontal goal values for the laser.
kLaserInitGoalX = 6
kLaserMaxGoalX = 9

;;; The maximum and initial X-positions for the left of the laser platform.
.LINECONT +
kLaserMinPlatformLeft = $0040
kLaserInitPlatformLeft = \
    kLaserMinPlatformLeft + kLaserInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Drill_sRoom
.PROC DataC_Shadow_Drill_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Shadow
    d_byte MinimapStartRow_u8, 12
    d_byte MinimapStartCol_u8, 5
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjShadow)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_ShadowDrill_EnterRoom
    d_addr FadeIn_func_ptr, FuncA_Terrain_ShadowDrill_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_ShadowDrill_TickRoom
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_drill.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kLaserMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::ShadowDrillLaser
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteC
    d_byte Status_eDiagram, eDiagram::Laser
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $0
    d_byte RegNames_u8_arr4, "C", 0, "X", 0
    d_byte MainPlatform_u8, kLaserPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_ShadowDrillLaser_InitReset
    d_addr ReadReg_func_ptr, FuncC_Shadow_DrillLaser_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_LaserWriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_ShadowDrillLaser_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_ShadowDrillLaser_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ShadowDrillLaser_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLaserMachine
    d_addr Reset_func_ptr, FuncA_Room_ShadowDrillLaser_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLaserPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLaserMachineWidthPx
    d_byte HeightPx_u8, kLaserMachineHeightPx
    d_word Left_i16, kLaserInitPlatformLeft
    d_word Top_i16,   $0020
    D_END
    ;; Acid:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $c0
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0030
    d_word Top_i16,   $016a
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $0088
    d_word PosY_i16, $0078
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $00b8
    d_word PosY_i16, $0098
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooRed
    d_word PosX_i16, $0078
    d_word PosY_i16, $00b8
    d_byte Param_byte, 0
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooRed
    d_word PosX_i16, $0058
    d_word PosY_i16, $00d8
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooGreen
    d_word PosX_i16, $0098
    d_word PosY_i16, $00d8
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadGooRed
    d_word PosX_i16, $0078
    d_word PosY_i16, $00f8
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console  ; TODO: ConsoleCeiling
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 3
    d_byte Target_byte, kLaserMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console  ; TODO: ConsoleCeiling
    d_byte BlockRow_u8, 17
    d_byte BlockCol_u8, 12
    d_byte Target_byte, kLaserMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   .assert * - :- = kUpperPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::ShadowHall
    d_byte SpawnBlock_u8, 5
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::ShadowDescent
    d_byte SpawnBlock_u8, 21
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::ShadowTrap
    d_byte SpawnBlock_u8, 21
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Shadow_DrillLaser_ReadReg
    cmp #$e
    beq _ReadX
_ReadC:
    jmp Func_MachineLaserReadRegC
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kLaserPlatformIndex
    sub #kLaserMinPlatformLeft - kTileHeightPx
    div #kBlockWidthPx
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; @param A The bSpawn value for where the avatar is entering the room.
.PROC FuncA_Room_ShadowDrill_EnterRoom
    cmp #bSpawn::Passage | kUpperPassageIndex
    beq @upperPassage
    and #bSpawn::Passage
    beq @done  ; not spawning from a passage
    @lowerPassage:
    ldya #kLowerPassageCenterY * 2
    bpl @invertPositionY  ; unconditional
    @upperPassage:
    ldya #kUpperPassageCenterY * 2
    @invertPositionY:
    sub Zp_AvatarPosY_i16 + 0
    sta Zp_AvatarPosY_i16 + 0
    tya
    sbc Zp_AvatarPosY_i16 + 1
    sta Zp_AvatarPosY_i16 + 1
    @done:
_SetGravityReversed:
    lda Zp_AvatarFlags_bObj
    ora #bObj::FlipV
    sta Zp_AvatarFlags_bObj
    rts
.ENDPROC

.PROC FuncA_Room_ShadowDrill_TickRoom
    ;; TODO: Once all goos are dead, set a flag to make them not reappear.
    ldx #kLaserMachineIndex
    jsr Func_SetMachineIndex
    jsr FuncA_Room_HarmAvatarIfWithinLaserBeam
    jmp FuncA_Room_KillGooWithLaserBeam
.ENDPROC

.PROC FuncA_Room_ShadowDrillLaser_InitReset
    lda #kLaserInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLaserMachineIndex
    jmp FuncA_Room_MachineLaserReset
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_ShadowDrillLaser_TryMove
    lda #kLaserMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_ShadowDrillLaser_TryAct
    ldx Ram_MachineGoalHorz_u8_arr + kLaserMachineIndex
    lda _LaserBottom_i16_0_arr, x  ; param: laser bottom (lo)
    ldy _LaserBottom_i16_1_arr, x  ; param: laser bottom (hi)
    jmp FuncA_Machine_LaserTryAct
_LaserBottom_i16_0_arr:
:   .byte $00, $40, $60, $c0, $80, $e0, $60, $00, $80, $80
    .assert * - :- = kLaserMaxGoalX + 1, error
_LaserBottom_i16_1_arr:
:   .byte $01, $00, $00, $00, $00, $00, $00, $01, $00, $00
    .assert * - :- = kLaserMaxGoalX + 1, error
.ENDPROC

.PROC FuncA_Machine_ShadowDrillLaser_Tick
    ldax #kLaserMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Terrain"

;;; Sets one block row of the lower nametable to use BG palette 2.
;;; @prereq Rendering is disabled.
.PROC FuncA_Terrain_ShadowDrill_FadeInRoom
    ldx #7    ; param: num bytes to write
    ldy #$a0  ; param: attribute value
    lda #$19  ; param: initial byte offset
    jmp Func_WriteToLowerAttributeTable
.ENDPROC

;;;=========================================================================;;;
