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
.INCLUDE "../actors/child.inc"
.INCLUDE "../actors/particle.inc"
.INCLUDE "../actors/rocket.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/launcher.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_City_sTileset
.IMPORT DataA_Text1_CityOutskirtsAlex_Part1_u8_arr
.IMPORT DataA_Text1_CityOutskirtsAlex_Part2_u8_arr
.IMPORT DataA_Text1_CityOutskirtsAlex_Part3_u8_arr
.IMPORT DataA_Text1_CityOutskirtsAlex_Part4_u8_arr
.IMPORT DataA_Text1_CityOutskirtsAlex_Part5_u8_arr
.IMPORT DataA_Text1_CityOutskirtsAlex_Part6_u8_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_LauncherTryAct
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_AnimateCircuitIfBreakerActive
.IMPORT FuncA_Objects_DrawLauncherMachineHorz
.IMPORT FuncA_Objects_DrawRocksPlatformVert
.IMPORT FuncA_Room_SpawnParticleAtPoint
.IMPORT Func_DivAByBlockSizeAndClampTo9
.IMPORT Func_FindActorWithType
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePointDownByA
.IMPORT Func_MovePointUpByA
.IMPORT Func_Noop
.IMPORT Func_PlaySfxExplodeFracture
.IMPORT Func_PlaySfxSecretUnlocked
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjCity
.IMPORT Ram_ActorState2_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr

;;;=========================================================================;;;

;;; The actor index for Alex in this room.
kAlexActorIndex = 0
;;; The talk device indices for Alex in this room.
kAlexDeviceIndexRight = 0
kAlexDeviceIndexLeft  = 1

;;; The actor index for the rhino baddie in this room.
kRhinoActorIndex = 1

;;;=========================================================================;;;

;;; The machine index for the CityOutskirtsLauncher machine.
kLauncherMachineIndex = 0

;;; The platform index for the CityOutskirtsLauncher machine.
kLauncherPlatformIndex = 0
;;; The platform index for the rocks that can be blasted away by the
;;; CityOutskirtsLauncher machine.
kRockWallPlatformIndex = 1

;;; The initial and maximum permitted vertical goal values for the launcher.
kLauncherInitGoalY = 2
kLauncherMaxGoalY = 2

;;; The maximum and initial Y-positions for the top of the launcher platform.
.LINECONT +
kLauncherMaxPlatformTop = $0070
kLauncherInitPlatformTop = \
    kLauncherMaxPlatformTop - kLauncherInitGoalY * kBlockHeightPx
.LINECONT -

;;;=========================================================================;;;

.SEGMENT "PRGC_City"

.EXPORT DataC_City_Outskirts_sRoom
.PROC DataC_City_Outskirts_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $110
    d_byte Flags_bRoom, eArea::City
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 16
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCity)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_City_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_CityOutskirts_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_CityOutskirts_TickRoom
    d_addr Draw_func_ptr, FuncC_City_Outskirts_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/city_outskirts.room"
    .assert * - :- = 34 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kLauncherMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CityOutskirtsLauncher
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::LauncherLeft
    d_word ScrollGoalX_u16, $00a0
    d_byte ScrollGoalY_u8, $20
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kLauncherPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CityOutskirtsLauncher_InitReset
    d_addr ReadReg_func_ptr, FuncC_City_OutskirtsLauncher_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CityOutskirtsLauncher_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CityOutskirtsLauncher_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CityOutskirtsLauncher_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLauncherMachineHorz
    d_addr Reset_func_ptr, FuncA_Room_CityOutskirtsLauncher_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kLauncherPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLauncherMachineWidthPx
    d_byte HeightPx_u8, kLauncherMachineHeightPx
    d_word Left_i16,  $0150
    d_word Top_i16, kLauncherInitPlatformTop
    D_END
    .assert * - :- = kRockWallPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $00d0
    d_word Top_i16,   $0060
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kAlexActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcChild
    d_word PosX_i16, $00c0
    d_word PosY_i16, $0088
    d_byte Param_byte, eNpcChild::AlexStanding
    D_END
    .assert * - :- = kRhinoActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadRhino
    d_word PosX_i16, $01b8
    d_word PosY_i16, $00c8
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kAlexDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eDialog::CityOutskirtsAlex1
    D_END
    .assert * - :- = kAlexDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 12
    d_byte Target_byte, eDialog::CityOutskirtsAlex1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 23
    d_byte Target_byte, kLauncherMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 25
    d_byte Target_byte, eRoom::CityBuilding1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door2Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 23
    d_byte Target_byte, eRoom::CityBuilding1
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::CoreEast
    d_byte SpawnBlock_u8, 11
    d_byte SpawnAdjust_byte, 0
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::CityWest
    d_byte SpawnBlock_u8, 7
    d_byte SpawnAdjust_byte, 0
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_City_Outskirts_DrawRoom
_BgAnimation:
    ldx #eFlag::BreakerCity  ; param: breaker flag
    jsr FuncA_Objects_AnimateCircuitIfBreakerActive
_RockWall:
    ldx #kRockWallPlatformIndex  ; param: platform index
    jmp FuncA_Objects_DrawRocksPlatformVert
.ENDPROC

.PROC FuncC_City_OutskirtsLauncher_ReadReg
    lda #kLauncherMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLauncherPlatformIndex  ; param: distance
    jmp Func_DivAByBlockSizeAndClampTo9  ; returns A
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CityOutskirts_EnterRoom
_Alex:
    ;; If Alex isn't here yet, or he's done being here, remove him.
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerCrypt
    beq @removeAlex
    flag_bit Sram_ProgressFlags_arr, eFlag::CityOutskirtsTalkedToAlex
    beq @keepAlex
    @removeAlex:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kAlexActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kAlexDeviceIndexRight
    @keepAlex:
_Rhino:
    ;; The rhino baddie doesn't appear until after the lava breaker cutscene.
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerLava
    bne @keepRhino
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kRhinoActorIndex
    @keepRhino:
_Rocks:
    flag_bit Sram_ProgressFlags_arr, eFlag::CityOutskirtsBlastedRocks
    bne @removeRocks
    @loadRocketLauncher:
    inc Ram_MachineState1_byte_arr + kLauncherMachineIndex  ; ammo count
    rts
    @removeRocks:
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kRockWallPlatformIndex
    rts
.ENDPROC

.PROC FuncA_Room_CityOutskirts_TickRoom
    ;; Find the rocket (if any).  If there isn't one, we're done.
    lda #eActor::ProjRocket  ; param: actor type to find
    jsr Func_FindActorWithType  ; returns C and X
    bcs @done
    ;; Check if the rocket has hit the breakable wall; if not, we're done.
    ;; (Note that no rocket can exist in this room if the breakable wall is
    ;; already gone.)
    jsr Func_SetPointToActorCenter  ; preserves X
    ldy #kRockWallPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X and Y, returns C
    bcc @done
    ;; Explode the rocket.
    jsr Func_SetPointToPlatformCenter  ; preserves X
    jsr Func_InitActorSmokeExplosion
    ;; Add particles for the breaking wall.
    lda #kTileHeightPx * 3 + kTileHeightPx / 2  ; param: offset
    jsr Func_MovePointUpByA
    ldy #6 - 1
    @loop:
    lda #kTileHeightPx  ; param: offset
    jsr Func_MovePointDownByA  ; preserves Y
    tya
    mul #$10  ; also clears C for the ADC below
    adc #$58  ; param: angle
    jsr FuncA_Room_SpawnParticleAtPoint  ; preserves Y
    dey
    bpl @loop
    ;; Shake the room and remove the wall.
    lda #kRocketShakeFrames  ; param: shake frames
    jsr Func_ShakeRoom
    jsr Func_PlaySfxExplodeFracture
    jsr Func_PlaySfxSecretUnlocked
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kRockWallPlatformIndex
    ldx #eFlag::CityOutskirtsBlastedRocks
    jmp Func_SetFlag
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_CityOutskirtsLauncher_InitReset
    lda #kLauncherInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLauncherMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_CityOutskirtsLauncher_TryMove
    lda #kLauncherMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncA_Machine_CityOutskirtsLauncher_TryAct
    ;; If the launcher is blocked, fail.
    lda Ram_MachineGoalVert_u8_arr + kLauncherMachineIndex
    jne FuncA_Machine_Error
    ;; Otherwise, try to fire a rocket.
    lda #eDir::Left  ; param: rocket direction
    jmp FuncA_Machine_LauncherTryAct
.ENDPROC

.PROC FuncA_Machine_CityOutskirtsLauncher_Tick
    ldax #kLauncherMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_CityOutskirtsLook_sCutscene
.PROC DataA_Cutscene_CityOutskirtsLook_sCutscene
    act_SetActorState2 kAlexActorIndex, $ff
    act_SetActorFlags kAlexActorIndex, 0
    act_ForkStart 1, _Look_sCutscene
    act_ScrollSlowX $0090
    act_WaitFrames 30
    act_RunDialog eDialog::CityOutskirtsAlex2
    act_ContinueExploring
_Look_sCutscene:
    act_WaitFrames 20
    act_SetAvatarFlags 0 | kPaletteObjAvatarNormal
    act_ForkStop $ff
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_CityOutskirtsAlex1_sDialog
.PROC DataA_Dialog_CityOutskirtsAlex1_sDialog
    .linecont +
    dlg_IfSet CityOutskirtsTalkedToAlex, \
              DataA_Dialog_CityOutskirtsMeetAtHotSpring_sDialog
    .linecont -
_YouMadeIt_sDialog:
    dlg_Text ChildAlex, DataA_Text1_CityOutskirtsAlex_Part1_u8_arr
    dlg_Text ChildAlex, DataA_Text1_CityOutskirtsAlex_Part2_u8_arr
    dlg_Cutscene eCutscene::CityOutskirtsLook
.ENDPROC

.EXPORT DataA_Dialog_CityOutskirtsAlex2_sDialog
.PROC DataA_Dialog_CityOutskirtsAlex2_sDialog
    dlg_Text ChildAlex, DataA_Text1_CityOutskirtsAlex_Part3_u8_arr
    dlg_Text ChildAlex, DataA_Text1_CityOutskirtsAlex_Part4_u8_arr
    dlg_Text ChildAlex, DataA_Text1_CityOutskirtsAlex_Part5_u8_arr
    dlg_Call _MakeAlexFaceAnna
    dlg_Quest CityOutskirtsTalkedToAlex
    dlg_Goto DataA_Dialog_CityOutskirtsMeetAtHotSpring_sDialog
_MakeAlexFaceAnna:
    lda #$00
    sta Ram_ActorState2_byte_arr + kAlexActorIndex
    rts
.ENDPROC

.PROC DataA_Dialog_CityOutskirtsMeetAtHotSpring_sDialog
    dlg_Text ChildAlex, DataA_Text1_CityOutskirtsAlex_Part6_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;
