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
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/crane.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Mine_sTileset
.IMPORT FuncA_Machine_GenericTryMoveZ
.IMPORT FuncA_Machine_HoistMoveTowardGoal
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_DrawCraneMachine
.IMPORT FuncA_Objects_DrawGirderPlatform
.IMPORT Func_MovePlatformVert
.IMPORT Func_Noop
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjMine
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_RoomState
.IMPORTZP Zp_Tmp1_byte

;;;=========================================================================;;;

;;; The machine index for the MineWestCrane machine in this room.
kCraneMachineIndex = 0

;;; The platform index for the MineWestCrane machine.
kCranePlatformIndex = 0

;;; The initial and maximum permitted values for the crane's Z-goal.
kCraneInitGoalZ = 0
kCraneMaxGoalZ = 9

;;; The minimum and initial Y-positions for the top of the crane platform.
kCraneMinPlatformTop = $0038
kCraneInitPlatformTop = kCraneMinPlatformTop + kCraneInitGoalZ * kBlockHeightPx

;;;=========================================================================;;;

;;; The platform indices for the ceiling/floor of the cage.
kCageUpperPlatformIndex = 1
kCageLowerPlatformIndex = 2

;;; The width and height for each platform that makes up the cage.
kCagePlatformWidth = kTileWidthPx * 3
kCagePlatformHeight = kTileHeightPx

;;; The vertical distance, in pixels, between the bottom of the upper cage
;;; platform and the top of the lower cage platform.
kCageInteriorHeight = $20

;;; The room pixel X-position of the left side of the cage.
kCagePlatformLeft = $84

;;; The room pixel Y-position of the bottom and top of the cage when it's
;;; resting on the floor.
kCageMaxBottom = $110
kCageMaxTop = kCageMaxBottom - (kCagePlatformHeight * 2 + kCageInteriorHeight)

;;; How many frames the room shakes for when the cage hits the ground.
kCageShakeFrames = 15

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; True ($ff) if the crane is currently grasping the cage, false ($00)
    ;; otherwise.
    CageIsGrasped_bool .byte
    ;; The current Y subpixel position of the cage.
    CageSubY_u8        .byte
    ;; The current Y-velocity of the cage, in subpixels per frame.
    CageVelY_i16       .word
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Mine"

.EXPORT DataC_Mine_West_sRoom
.PROC DataC_Mine_West_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $10
    d_byte Flags_bRoom, bRoom::Tall | eArea::Mine
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 20
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjMine)
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, FuncA_Objects_MineWest_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Mine_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/mine_west.room"
    .assert * - :- = 18 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kCraneMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MineWestCrane
    d_byte Breaker_eFlag, eFlag::BreakerLava
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Crane
    d_word ScrollGoalX_u16, $10
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "D", 0, 0, "Z"
    d_byte MainPlatform_u8, kCranePlatformIndex
    d_addr Init_func_ptr, FuncC_Mine_WestCrane_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mine_WestCrane_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Mine_WestCrane_TryMove
    d_addr TryAct_func_ptr, FuncC_Mine_WestCrane_TryAct
    d_addr Tick_func_ptr, FuncC_Mine_WestCrane_Tick
    d_addr Draw_func_ptr, FuncA_Objects_MineWestCrypt_Draw
    d_addr Reset_func_ptr, FuncC_Mine_WestCrane_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kCranePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $0088
    d_word Top_i16, kCraneInitPlatformTop
    D_END
    .assert * - :- = kCageUpperPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kCagePlatformWidth
    d_byte HeightPx_u8, kCagePlatformHeight
    d_word Left_i16, kCagePlatformLeft
    d_word Top_i16, kCageMaxTop
    D_END
    .assert * - :- = kCageLowerPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kCagePlatformWidth
    d_byte HeightPx_u8, kCagePlatformHeight
    d_word Left_i16, kCagePlatformLeft
    d_word Top_i16, kCageMaxBottom - kCagePlatformHeight
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0050
    d_word Top_i16,   $0144
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
    ;; TODO: add some baddies
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 18
    d_byte BlockCol_u8, 4
    d_byte Target_u8, kCraneMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::MineWest  ; TODO MineFlower
    d_byte SpawnBlock_u8, 4
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::MineWest  ; TODO MineNorth
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::MineSouth
    d_byte SpawnBlock_u8, 20
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Mine_WestCrane_InitReset
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    sta Zp_RoomState + sState::CageIsGrasped_bool
    .assert kCraneInitGoalZ = 0, error
    sta Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    rts
.ENDPROC

.PROC FuncC_Mine_WestCrane_ReadReg
    cmp #$f
    beq _ReadZ
_ReadD:
    lda Ram_PlatformTop_i16_0_arr + kCageUpperPlatformIndex
    sub Ram_PlatformBottom_i16_0_arr + kCranePlatformIndex
    div #kBlockHeightPx
    rts
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kCranePlatformIndex
    sub #kCraneMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
.ENDPROC

.PROC FuncC_Mine_WestCrane_TryMove
    lda #kCraneMaxGoalZ  ; param: max goal vert
    jmp FuncA_Machine_GenericTryMoveZ
.ENDPROC

.PROC FuncC_Mine_WestCrane_TryAct
    lda Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    eor #$ff
    sta Ram_MachineGoalHorz_u8_arr + kCraneMachineIndex  ; is closed
    bne _TryGrasp
    sta Zp_RoomState + sState::CageIsGrasped_bool
    beq _Finish  ; unconditional
_TryGrasp:
    lda Ram_MachineGoalVert_u8_arr + kCraneMachineIndex
    cmp #kCraneMaxGoalZ
    blt _Finish
    lda #$ff
    sta Zp_RoomState + sState::CageIsGrasped_bool
_Finish:
    lda #kCraneActCooldown  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

.PROC FuncC_Mine_WestCrane_Tick
    jsr FuncC_Mine_West_TickCage
    ;; Move the crane itself.
    ldx #kCranePlatformIndex  ; param: platform index
    ldya #kCraneMinPlatformTop  ; param: min platform top
    jsr FuncA_Machine_HoistMoveTowardGoal  ; returns Z and A
    jeq FuncA_Machine_ReachedGoal
    ;; If the crane moved, and it's grasping the cage, then move the cage along
    ;; with it.
    bit Zp_RoomState + sState::CageIsGrasped_bool
    bpl @notGrasped
    pha  ; param: move delta
    ldx #kCageUpperPlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    pla  ; param: move delta
    ldx #kCageLowerPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
    @notGrasped:
    rts
.ENDPROC

.PROC FuncC_Mine_West_TickCage
    ;; If the crane is grasping the cage, we're done.
    bit Zp_RoomState + sState::CageIsGrasped_bool
    bmi _Done
    ;; Calculate how far above the floor the cage is.  If it's resting on the
    ;; floor, we're done.
    lda #<kCageMaxTop
    sub Ram_PlatformTop_i16_0_arr + kCageUpperPlatformIndex
    beq _Done
    sta Zp_Tmp1_byte  ; cage dist above floor
_ApplyGravity:
    lda Zp_RoomState + sState::CageVelY_i16 + 0
    add #<kAvatarGravity
    sta Zp_RoomState + sState::CageVelY_i16 + 0
    lda Zp_RoomState + sState::CageVelY_i16 + 1
    adc #>kAvatarGravity
    sta Zp_RoomState + sState::CageVelY_i16 + 1
_ApplyVelocity:
    ;; Update subpixels, and calculate the number of whole pixels to move,
    ;; storing the latter in A.
    lda Zp_RoomState + sState::CageSubY_u8
    add Zp_RoomState + sState::CageVelY_i16 + 0
    sta Zp_RoomState + sState::CageSubY_u8
    lda #0
    adc Zp_RoomState + sState::CageVelY_i16 + 1
_MaybeHitFloor:
    ;; If the number of pixels to move this frame is >= the distance above the
    ;; floor, then the cage is hitting the floor this frame.
    cmp Zp_Tmp1_byte  ; cage dist above floor
    blt @done
    ;; TODO: play a sound for the cage hitting the floor
    lda #kCageShakeFrames  ; param: shake frames
    jsr Func_ShakeRoom  ; preserves Zp_Tmp*
    ;; Zero the cage's velocity, and move it to exactly hit the floor.
    lda #0
    sta Zp_RoomState + sState::CageSubY_u8
    sta Zp_RoomState + sState::CageVelY_i16 + 0
    sta Zp_RoomState + sState::CageVelY_i16 + 1
    lda Zp_Tmp1_byte  ; cage dist above floor
    @done:
_MoveCagePlatforms:
    pha  ; param: move delta
    ldx #kCageUpperPlatformIndex  ; param: platform index
    jsr Func_MovePlatformVert
    pla  ; param: move delta
    ldx #kCageLowerPlatformIndex  ; param: platform index
    jmp Func_MovePlatformVert
_Done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

.PROC FuncA_Objects_MineWest_DrawRoom
    ;; TODO: draw handle that crane grasps
    ;; TODO: draw connectors between the girders
    ldx #kCageUpperPlatformIndex
    jsr FuncA_Objects_DrawGirderPlatform
    ldx #kCageLowerPlatformIndex
    jmp FuncA_Objects_DrawGirderPlatform
.ENDPROC

;;; Draws the BossCryptWinch machine.
.PROC FuncA_Objects_MineWestCrypt_Draw
    jsr FuncA_Objects_DrawCraneMachine
    ;; TODO: draw pulley and rope
    rts
.ENDPROC

;;;=========================================================================;;;
