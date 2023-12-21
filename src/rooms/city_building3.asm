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
.INCLUDE "../actors/rocket.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/ammorack.inc"
.INCLUDE "../machines/launcher.inc"
.INCLUDE "../machines/reloader.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Building_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Machine_AmmoRack_TryAct
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_LauncherTryAct
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Machine_WriteToLever
.IMPORT FuncA_Objects_DrawAmmoRackMachine
.IMPORT FuncA_Objects_DrawCratePlatform
.IMPORT FuncA_Objects_DrawLauncherMachineHorz
.IMPORT FuncA_Objects_DrawReloaderMachine
.IMPORT FuncA_Room_ResetLever
.IMPORT Func_FindActorWithType
.IMPORT Func_FindEmptyActorSlot
.IMPORT Func_InitActorSmokeExplosion
.IMPORT Func_IsPointInAnySolidPlatform
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_SetActorCenterToPoint
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Func_SetPointToPlatformCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjCity
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineState1_byte_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The number of crate platforms in this room.  The crates start at platform
;;; index zero, and increase in index from the bottom of the room upwards.
kNumCratePlatforms = 6

;;; The room pixel Y-position of the top of crate #3 when it's resting on top
;;; of crate #1 (after crate #2 has been destroyed).
kCrate3MaxTop = $a0

;;;=========================================================================;;;

;;; The machine indices for the machines in this room.
kLauncherMachineIndex = 0
kReloaderMachineIndex = 1
kAmmoRackMachineIndex = 2

;;; The platform indices for the machines in this room.
kLauncherPlatformIndex = 6
kReloaderPlatformIndex = 7
kAmmoRackPlatformIndex = 8

;;; The initial and maximum permitted vertical goal values for the launcher.
kLauncherInitGoalY = 5
kLauncherMaxGoalY = 6

;;; The maximum and initial Y-positions for the top of the launcher platform.
.LINECONT +
kLauncherMaxPlatformTop = $00a0
kLauncherInitPlatformTop = \
    kLauncherMaxPlatformTop - kLauncherInitGoalY * kBlockHeightPx
kLauncherMinPlatformTop = \
    kLauncherMaxPlatformTop - kLauncherMaxGoalY * kBlockHeightPx
.LINECONT -

;;; The initial and maximum permitted horizontal goal values for the reloader.
kReloaderInitGoalX = 6
kReloaderMaxGoalX = 8

;;; The maximum and initial X-positions for the left of the reloader platform.
.LINECONT +
kReloaderMinPlatformLeft = $0040
kReloaderInitPlatformLeft = \
    kReloaderMinPlatformLeft + kReloaderInitGoalX * kBlockWidthPx
.LINECONT -

;;; The device indices for the levers in this room.
kLeverLeftDeviceIndex = 0
kLeverRightDeviceIndex = 1

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current states of the room's two levers.
    LeverLeft_u8   .byte
    LeverRight_u8  .byte
    ;; The current Y subpixel position of crate #3.
    Crate3SubY_u8  .byte
    ;; The current Y-velocity of crate #3, in subpixels per frame.
    Crate3VelY_i16 .word
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_City"

.EXPORT DataC_City_Building3_sRoom
.PROC DataC_City_Building3_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::City
    d_byte MinimapStartRow_u8, 2
    d_byte MinimapStartCol_u8, 19
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 3
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjCity)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Building_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, FuncA_Room_CityBuilding3_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_CityBuilding3_TickRoom
    d_addr Draw_func_ptr, FuncC_City_Building3_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/city_building3.room"
    .assert * - :- = 16 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kLauncherMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CityBuilding3Launcher
    d_byte Breaker_eFlag, 0
    .linecont +
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | \
                           bMachine::Act | bMachine::WriteCD
    .linecont -
    d_byte Status_eDiagram, eDiagram::LauncherLeft
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", 0, "Y"
    d_byte MainPlatform_u8, kLauncherPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CityBuilding3Launcher_InitReset
    d_addr ReadReg_func_ptr, FuncC_City_Building3Launcher_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_CityBuilding3_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_CityBuilding3Launcher_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CityBuilding3Launcher_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CityBuilding3Launcher_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawLauncherMachineHorz
    d_addr Reset_func_ptr, FuncA_Room_CityBuilding3Launcher_InitReset
    D_END
    .assert * - :- = kReloaderMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CityBuilding3Reloader
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Trolley  ; TODO
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", "X", 0
    d_byte MainPlatform_u8, kReloaderPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CityBuilding3Reloader_InitReset
    d_addr ReadReg_func_ptr, FuncC_City_Building3Reloader_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_CityBuilding3_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_CityBuilding3Reloader_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CityBuilding3Reloader_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CityBuilding3Reloader_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawReloaderMachine
    d_addr Reset_func_ptr, FuncA_Room_CityBuilding3Reloader_InitReset
    D_END
    .assert * - :- = kAmmoRackMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CityBuilding3AmmoRack
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::Act | bMachine::WriteCD
    d_byte Status_eDiagram, eDiagram::Lift  ; TODO
    d_word ScrollGoalX_u16, $0000
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", 0, 0
    d_byte MainPlatform_u8, kAmmoRackPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, FuncC_City_Building3_ReadRegLR
    d_addr WriteReg_func_ptr, FuncA_Machine_CityBuilding3_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_AmmoRack_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncA_Objects_DrawAmmoRackMachine
    d_addr Reset_func_ptr, FuncA_Room_CityBuilding3_ResetLevers
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   ;; Crates:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0024
    d_word Top_i16,   $00c0
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0020
    d_word Top_i16,   $00b0
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0020
    d_word Top_i16,   $00a0
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0020
    d_word Top_i16,   $0090
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0028
    d_word Top_i16,   $0080
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0044
    d_word Top_i16,   $0060
    D_END
    .assert * - :- = kNumCratePlatforms * .sizeof(sPlatform), error
    ;; Machines:
    .assert * - :- = kLauncherPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kLauncherMachineWidthPx
    d_byte HeightPx_u8, kLauncherMachineHeightPx
    d_word Left_i16,  $00d0
    d_word Top_i16, kLauncherInitPlatformTop
    D_END
    .assert * - :- = kReloaderPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kReloaderMachineWidthPx
    d_byte HeightPx_u8, kReloaderMachineHeightPx
    d_word Left_i16, kReloaderInitPlatformLeft
    d_word Top_i16,   $0040
    D_END
    .assert * - :- = kAmmoRackPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kAmmoRackMachineWidthPx
    d_byte HeightPx_u8, kAmmoRackMachineHeightPx
    d_word Left_i16,  $0040
    d_word Top_i16,   $0038
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   .assert * - :- = kLeverLeftDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 8
    d_byte Target_byte, sState::LeverLeft_u8
    D_END
    .assert * - :- = kLeverRightDeviceIndex * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 9
    d_byte Target_byte, sState::LeverRight_u8
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 4
    d_byte Target_byte, kAmmoRackMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 7
    d_byte Target_byte, kReloaderMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 13
    d_byte Target_byte, kLauncherMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 2
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eRoom::CityCenter
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door2Open
    d_byte BlockRow_u8, 12
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eRoom::CityCenter
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_City_Building3_DrawRoom
    ldx #kNumCratePlatforms - 1
    @loop:
    txa
    pha
    jsr FuncA_Objects_DrawCratePlatform
    pla
    tax
    dex
    bpl @loop
    rts
.ENDPROC

.PROC FuncC_City_Building3Launcher_ReadReg
    cmp #$f
    bne FuncC_City_Building3_ReadRegLR
_RegY:
    lda #kLauncherMaxPlatformTop + kTileHeightPx
    sub Ram_PlatformTop_i16_0_arr + kLauncherPlatformIndex
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_City_Building3Reloader_ReadReg
    cmp #$e
    bne FuncC_City_Building3_ReadRegLR
_RegX:
    lda Ram_PlatformLeft_i16_0_arr + kReloaderPlatformIndex
    sub #kReloaderMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
.ENDPROC

;;; Reads the shared "L" or "R" lever register for the CityBuilding3Launcher,
;;; CityBuilding3Reloader, and CityBuilding3AmmoRack machines.
;;; @param A The register to read ($c or $d).
;;; @return A The value of the register (0-9).
.PROC FuncC_City_Building3_ReadRegLR
    cmp #$d
    beq _RegR
_RegL:
    lda Zp_RoomState + sState::LeverLeft_u8
    rts
_RegR:
    lda Zp_RoomState + sState::LeverRight_u8
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CityBuilding3_EnterRoom
    flag_bit Sram_ProgressFlags_arr, eFlag::CityBuilding3BlastedCrates
    beq @keepCrates
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + 2
    sta Ram_PlatformType_ePlatform_arr + 3
    sta Ram_PlatformType_ePlatform_arr + 4
    sta Ram_PlatformType_ePlatform_arr + 5
    @keepCrates:
    rts
.ENDPROC

.PROC FuncA_Room_CityBuilding3_TickRoom
_MakeCrate3Fall:
    ;; If crate #3 is already destroyed, or it's still resting on crate #2, do
    ;; nothing.
    .assert ePlatform::None = 0, error
    lda Ram_PlatformType_ePlatform_arr + 3
    beq @done
    lda Ram_PlatformType_ePlatform_arr + 2
    bne @done
    ;; Calculate how far crate #3 is above crate #1.  If it's resting on crate
    ;; #1, we're done.
    lda #kCrate3MaxTop
    sub Ram_PlatformTop_i16_0_arr + 3
    beq @done
    sta T0  ; crate #3 dist above crate #1
    ;; Apply gravity to crate #3.
    lda Zp_RoomState + sState::Crate3VelY_i16 + 0
    add #<kAvatarGravity
    sta Zp_RoomState + sState::Crate3VelY_i16 + 0
    lda Zp_RoomState + sState::Crate3VelY_i16 + 1
    adc #>kAvatarGravity
    sta Zp_RoomState + sState::Crate3VelY_i16 + 1
    ;; Update subpixels for crate #3, and calculate the number of whole pixels
    ;; to move, storing the latter in A.
    lda Zp_RoomState + sState::Crate3SubY_u8
    add Zp_RoomState + sState::Crate3VelY_i16 + 0
    sta Zp_RoomState + sState::Crate3SubY_u8
    lda #0
    adc Zp_RoomState + sState::Crate3VelY_i16 + 1
    ;; If the number of pixels to move this frame is >= the distance above
    ;; crate #1, then crate #3 is hitting crate #1 this frame.
    cmp T0  ; crate #3 dist above crate #1
    blt @noHit
    ;; TODO: play a sound for the crate landing
    ;; Zero crate #3's velocity, and move it to exactly hit crate #1.
    lda #0
    sta Zp_RoomState + sState::Crate3SubY_u8
    sta Zp_RoomState + sState::Crate3VelY_i16 + 0
    sta Zp_RoomState + sState::Crate3VelY_i16 + 1
    lda T0  ; crate #3 dist above crate #1
    @noHit:
    ldx #3  ; param: platform index
    jsr Func_MovePlatformVert
    @done:
_CheckForRocketImpact:
    ;; Check for a rocket (in this room, it's not possible for there to be more
    ;; than one on screen at once).
    lda #eActor::ProjRocket  ; param: actor type
    jsr Func_FindActorWithType  ; returns C and X
    bcs @done  ; no rocket found
    ;; Check if the rocket has hit a platform (other than its launcher).
    jsr Func_SetPointToActorCenter  ; preserves X
    jsr Func_IsPointInAnySolidPlatform  ; preserves X, returns C and Y
    bcc @done  ; no collision
    cpy #kLauncherPlatformIndex
    beq @done  ; still exiting launcher
    ;; If the rocket hits a crate, destroy that crate.
    cpy #kNumCratePlatforms
    bge @doneCrate
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr, y
    ;; Create a smoke explosion where the crate was.
    txa  ; rocket actor index
    pha  ; rocket actor index
    jsr Func_SetPointToPlatformCenter
    jsr Func_FindEmptyActorSlot  ; returns C and X
    bcs @doneExplosion
    jsr Func_SetActorCenterToPoint  ; preserves X
    jsr Func_InitActorSmokeExplosion
    @doneExplosion:
    pla  ; rocket actor index
    tax  ; rocket actor index
    @doneCrate:
    ;; Explode the rocket and shake the room.
    lda #kRocketShakeFrames  ; param: num frames
    jsr Func_ShakeRoom  ; preserves X
    jsr Func_InitActorSmokeExplosion
    ;; TODO: play a sound for the rocket exploding
    @done:
_SetFlagIfCratesDestroyed:
    ;; Once crates 2-5 have all been destroyed, set the flag.
    .assert ePlatform::None = 0, error
    lda Ram_PlatformType_ePlatform_arr + 2
    ora Ram_PlatformType_ePlatform_arr + 3
    ora Ram_PlatformType_ePlatform_arr + 4
    ora Ram_PlatformType_ePlatform_arr + 5
    bne @done
    ldx #eFlag::CityBuilding3BlastedCrates  ; param: flag
    jmp Func_SetFlag
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_CityBuilding3Launcher_InitReset
    lda #kLauncherInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLauncherMachineIndex
    .assert kLauncherInitGoalY < $80, error
    bpl FuncA_Room_CityBuilding3_ResetLevers  ; unconditional
.ENDPROC

.PROC FuncA_Room_CityBuilding3Reloader_InitReset
    lda #kReloaderInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kReloaderMachineIndex
    .assert * = FuncA_Room_CityBuilding3_ResetLevers, error, "fallthrough"
.ENDPROC

.PROC FuncA_Room_CityBuilding3_ResetLevers
    ;; TODO: Also reset crates if puzzle not solved?
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jsr FuncA_Room_ResetLever
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Room_ResetLever
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

;;; Shared WriteReg implementation for the CityBuilding3Launcher,
;;; CityBuilding3Reloader, and CityBuilding3AmmoRack machines.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
;;; @param A The value to write (0-9).
;;; @param X The register to write to ($c-$f).
.PROC FuncA_Machine_CityBuilding3_WriteReg
    cpx #$d
    beq _WriteR
_WriteL:
    ldx #kLeverLeftDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
_WriteR:
    ldx #kLeverRightDeviceIndex  ; param: device index
    jmp FuncA_Machine_WriteToLever
.ENDPROC

.PROC FuncA_Machine_CityBuilding3Launcher_TryMove
    lda #kLauncherMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveY
.ENDPROC

.PROC FuncA_Machine_CityBuilding3Reloader_TryMove
    lda #kReloaderMaxGoalX  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_CityBuilding3Launcher_TryAct
    lda #eDir::Left  ; param: rocket direction
    jmp FuncA_Machine_LauncherTryAct
.ENDPROC

.PROC FuncA_Machine_CityBuilding3Reloader_TryAct
    ldx Ram_MachineGoalHorz_u8_arr + kReloaderMachineIndex
    lda Ram_MachineState1_byte_arr + kReloaderMachineIndex  ; ammo count
    beq _TryPickUpAmmo
_TryDropOffAmmo:
    ;; Error unless the reloader and launcher machines are lined up.
    cpx #kReloaderMaxGoalX
    blt _Error
    lda Ram_PlatformTop_i16_0_arr + kLauncherPlatformIndex
    cmp #<kLauncherMinPlatformTop
    bne _Error
    ;; Error if the launcher machine already has a rocket loaded.
    lda Ram_MachineState1_byte_arr + kLauncherMachineIndex  ; ammo count
    bne _Error
    ;; TODO: play a sound
    dec Ram_MachineState1_byte_arr + kReloaderMachineIndex  ; ammo count
    inc Ram_MachineState1_byte_arr + kLauncherMachineIndex  ; ammo count
    bne _StartWaiting  ; unconditional
_TryPickUpAmmo:
    cpx #kNumAmmoRackSlots
    bge _Error
    lda Data_PowersOfTwo_u8_arr8, x
    bit Ram_MachineState1_byte_arr + kAmmoRackMachineIndex  ; ammo slot bits
    beq _Error
    eor #$ff
    and Ram_MachineState1_byte_arr + kAmmoRackMachineIndex  ; ammo slot bits
    sta Ram_MachineState1_byte_arr + kAmmoRackMachineIndex  ; ammo slot bits
    inc Ram_MachineState1_byte_arr + kReloaderMachineIndex  ; ammo count
    ;; TODO: play a sound
_StartWaiting:
    lda #kReloaderActCountdown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncA_Machine_CityBuilding3Launcher_Tick
    ldax #kLauncherMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncA_Machine_CityBuilding3Reloader_Tick
    ldax #kReloaderMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

;;;=========================================================================;;;
