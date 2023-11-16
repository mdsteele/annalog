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
.INCLUDE "../machines/minigun.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../mmc3.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../platforms/glass.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Shadow_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_CarriageTryMove
.IMPORT FuncA_Machine_GenericMoveTowardGoalHorz
.IMPORT FuncA_Machine_GenericMoveTowardGoalVert
.IMPORT FuncA_Machine_MinigunRotateBarrel
.IMPORT FuncA_Machine_MinigunTryAct
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawMinigunRightMachine
.IMPORT FuncA_Room_RemoveAllBulletsIfConsoleOpen
.IMPORT FuncC_Shadow_DrawGlassPlatform
.IMPORT Func_IsPointInPlatform
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Sram_Programs_sProgram_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The platform indices for the breakable glass.
kGlass1PlatformIndex = 0
kGlass2PlatformIndex = 1

;;;=========================================================================;;;

;;; The machine index for the ShadowHallMinigun machine.
kMinigunMachineIndex = 0
;;; The platform index for the ShadowHallMinigun machine.
kMinigunPlatformIndex = 2

;;; The initial and maximum permitted horizontal and vertical goal values for
;;; the ShadowHallMinigun machine.
kMinigunInitGoalX = 9
kMinigunMaxGoalX  = 9
kMinigunInitGoalY = 3
kMinigunMaxGoalY  = 7

;;; The minimum and initial X-positions for the left of the minigun platform.
.LINECONT +
kMinigunMinPlatformLeft = $0080
kMinigunInitPlatformLeft = \
    kMinigunMinPlatformLeft + kMinigunInitGoalX * kBlockWidthPx
.LINECONT -

;;; The maximum and initial Y-positions for the top of the minigun platform.
.LINECONT +
kMinigunMaxPlatformTop = $00b0
kMinigunInitPlatformTop = \
    kMinigunMaxPlatformTop - kMinigunInitGoalY * kBlockHeightPx
.LINECONT -

;;;=========================================================================;;;

;;; Enum for the steps of the ShadowHallMinigun machine's reset sequence
;;; (listed in reverse order).
.ENUM eResetSeq
    MidRight = 0  ; move to X=9, Y=3
    Bottom        ; move to Y=0
    NearBottom    ; move to Y=1
.ENDENUM

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; Which step of its reset sequence the ShadowHallMinigun machine is on.
    Minigun_eResetSeq .byte
    ;; How many times each breakable glass platform has been hit, indexed by
    ;; platform index.
    BreakableGlassHits_u8_arr .res 2
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Shadow"

.EXPORT DataC_Shadow_Hall_sRoom
.PROC DataC_Shadow_Hall_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0110
    d_byte Flags_bRoom, eArea::Shadow
    d_byte MinimapStartRow_u8, 12
    d_byte MinimapStartCol_u8, 6
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 1
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Shadow_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_ShadowHall_EnterRoom
    d_addr FadeIn_func_ptr, FuncC_Shadow_Hall_FadeInRoom
    d_addr Tick_func_ptr, FuncA_Room_ShadowHall_TickRoom
    d_addr Draw_func_ptr, FuncC_Shadow_Hall_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/shadow_hall.room"
    .assert * - :- = 34 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kMinigunMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::ShadowHallMinigun
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveHV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::MinigunRight
    d_word ScrollGoalX_u16, $0060
    d_byte ScrollGoalY_u8, $28
    d_byte RegNames_u8_arr4, 0, 0, "X", "Y"
    d_byte MainPlatform_u8, kMinigunPlatformIndex
    d_addr Init_func_ptr, FuncC_Shadow_HallMinigun_Init
    d_addr ReadReg_func_ptr, FuncC_Shadow_HallMinigun_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_ShadowHallMinigun_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_ShadowHallMinigun_TryAct
    d_addr Tick_func_ptr, FuncC_Shadow_HallMinigun_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawMinigunRightMachine
    d_addr Reset_func_ptr, FuncC_Shadow_HallMinigun_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kGlass1PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kGlassPlatformWidthPx
    d_byte HeightPx_u8, kGlassPlatformHeightPx
    d_word Left_i16,  $00b8
    d_word Top_i16,   $0040
    D_END
    .assert * - :- = kGlass2PlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kGlassPlatformWidthPx
    d_byte HeightPx_u8, kGlassPlatformHeightPx
    d_word Left_i16,  $00d8
    d_word Top_i16,   $0070
    D_END
    .assert * - :- = kMinigunPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kMinigunMachineWidthPx
    d_byte HeightPx_u8, kMinigunMachineHeightPx
    d_word Left_i16, kMinigunInitPlatformLeft
    d_word Top_i16,  kMinigunInitPlatformTop
    D_END
    ;; Acid:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Kill
    d_word WidthPx_u16, $1f0
    d_byte HeightPx_u8,  $20
    d_word Left_i16,   $0020
    d_word Top_i16,    $00ca
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 8
    d_byte BlockCol_u8, 6
    d_byte Target_byte, kMinigunMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 3
    d_byte BlockCol_u8, 20
    d_byte Target_byte, kMinigunMachineIndex
    D_END
    ;; Placeholder devices for blocking minigun machine from passing pipes:
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder
    d_byte BlockRow_u8, 4
    d_byte BlockCol_u8, 10
    d_byte Target_byte, 0  ; unused
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Placeholder
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 13
    d_byte Target_byte, 0  ; unused
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::ShadowDrill
    d_byte SpawnBlock_u8, 5
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 0
    d_byte Destination_eRoom, eRoom::ShadowGate
    d_byte SpawnBlock_u8, 9
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Sets two block rows of the upper nametable to use BG palette 2.
;;; @prereq Rendering is disabled.
.PROC FuncC_Shadow_Hall_FadeInRoom
    lda #kPpuCtrlFlagsHorz
    sta Hw_PpuCtrl_wo
    ldax #Ppu_Nametable0_sName + sName::Attrs_u8_arr64 + $30
    sta Hw_PpuAddr_w2
    stx Hw_PpuAddr_w2
    lda #$aa
    ldx #8
    @loop:
    sta Hw_PpuData_rw
    dex
    bne @loop
    rts
.ENDPROC

.PROC FuncC_Shadow_Hall_DrawRoom
    ldx #kGlass1PlatformIndex  ; param: platform index
    jsr _DrawGlass
    ldx #kGlass2PlatformIndex  ; param: platform index
_DrawGlass:
    lda Zp_RoomState + sState::BreakableGlassHits_u8_arr, x  ; param: num hits
    jmp FuncC_Shadow_DrawGlassPlatform
.ENDPROC

.PROC FuncC_Shadow_HallMinigun_ReadReg
    cmp #$f
    beq _ReadY
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kMinigunPlatformIndex
    sub #kMinigunMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
_ReadY:
    lda #<(kMinigunMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kMinigunPlatformIndex
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Shadow_HallMinigun_Tick
    jsr FuncA_Machine_MinigunRotateBarrel
_MoveHorz:
    ldax #kMinigunMinPlatformLeft  ; param: min platform left
    jsr FuncA_Machine_GenericMoveTowardGoalHorz  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveVert:
    ldax #kMinigunMaxPlatformTop  ; param: max platform top
    jsr FuncA_Machine_GenericMoveTowardGoalVert  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_ReachedGoal:
    lda Zp_RoomState + sState::Minigun_eResetSeq
    bne FuncC_Shadow_HallMinigun_Reset
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

.PROC FuncC_Shadow_HallMinigun_Reset
    ldy Ram_MachineGoalVert_u8_arr + kMinigunMachineIndex
    beq _MoveToMiddleRight
    ldx Ram_MachineGoalHorz_u8_arr + kMinigunMachineIndex
    cpx #7
    bge _MoveToMiddleRight
    cpx #6
    blt _MoveToBottom
    cpy #1
    beq _MoveToMiddleRight
_MoveToNearBottom:
    lda #eResetSeq::NearBottom
    sta Zp_RoomState + sState::Minigun_eResetSeq
    lda #1
    sta Ram_MachineGoalVert_u8_arr + kMinigunMachineIndex
    rts
_MoveToBottom:
    lda #eResetSeq::Bottom
    sta Zp_RoomState + sState::Minigun_eResetSeq
    lda #0
    sta Ram_MachineGoalVert_u8_arr + kMinigunMachineIndex
    rts
_MoveToMiddleRight:
    lda #eResetSeq::MidRight
    sta Zp_RoomState + sState::Minigun_eResetSeq
    .assert * = FuncC_Shadow_HallMinigun_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Shadow_HallMinigun_Init
    lda #kMinigunInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kMinigunMachineIndex
    lda #kMinigunInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kMinigunMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC DataA_Room_ShadowHallMinigun_sIns_arr
    D_STRUCT sIns
    d_byte Arg_byte, $00  ; REST
    d_byte Op_byte, eOpcode::Rest << 4
    D_END
    D_STRUCT sIns
    d_byte Arg_byte, $2f  ; IF Y>2
    d_byte Op_byte, (eOpcode::If << 4) | eCmp::Gt
    D_END
    D_STRUCT sIns
    d_byte Arg_byte, $00  ; MOVE v
    d_byte Op_byte, (eOpcode::Move << 4) | eDir::Down
    D_END
    D_STRUCT sIns
    d_byte Arg_byte, $00  ; ACT
    d_byte Op_byte, eOpcode::Act << 4
    D_END
.ENDPROC

.PROC FuncA_Room_ShadowHall_EnterRoom
_InitProgram:
    ldx #eFlag::ShadowHallInitialized  ; param: flag
    jsr Func_SetFlag  ; returns C
    bcs @done
    ldx #.sizeof(DataA_Room_ShadowHallMinigun_sIns_arr) - 1
    ;; Enable writes to SRAM.
    ldy #bMmc3PrgRam::Enable
    sty Hw_Mmc3PrgRamProtect_wo
    ;; Copy the instructions.
    @loop:
    lda DataA_Room_ShadowHallMinigun_sIns_arr, x
    .linecont +
    sta Sram_Programs_sProgram_arr + \
        .sizeof(sProgram) * eProgram::ShadowHallMinigun, x
    .linecont -
    dex
    .assert .sizeof(DataA_Room_ShadowHallMinigun_sIns_arr) <= $80, error
    bpl @loop
    ;; Disable writes to SRAM.
    ldy #bMmc3PrgRam::Enable | bMmc3PrgRam::DenyWrites
    sty Hw_Mmc3PrgRamProtect_wo
    @done:
_BreakableGlass:
    ;; If the breakable glass has already been broken, remove those platforms.
    flag_bit Sram_ProgressFlags_arr, eFlag::ShadowHallGlassBroken
    beq @done
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kGlass1PlatformIndex
    sta Ram_PlatformType_ePlatform_arr + kGlass2PlatformIndex
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_ShadowHall_TickRoom
    jsr FuncA_Room_RemoveAllBulletsIfConsoleOpen
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjBullet
    bne @continue
    ldy #kGlass1PlatformIndex  ; param: glass platform index
    jsr FuncA_Room_ShadowHall_CheckForBulletHit  ; preserves X
    ldy #kGlass2PlatformIndex  ; param: glass platform index
    jsr FuncA_Room_ShadowHall_CheckForBulletHit  ; preserves X
    @continue:
    dex
    bpl @loop
    rts
.ENDPROC

;;; Checks if the given bullet actor has hit the breakable glass in this room;
;;; if so, handles the collision.
;;; @param X The bullet actor index.
;;; @param Y The glass platform index.
;;; @preserve X
.PROC FuncA_Room_ShadowHall_CheckForBulletHit
    ;; If the breakable glass is already destroyed, we're done.
    lda Ram_PlatformType_ePlatform_arr, y
    .assert ePlatform::None = 0, error
    beq @done
    ;; If this bullet isn't hitting the glass, we're done.
    jsr Func_SetPointToActorCenter  ; preserves X
    jsr Func_IsPointInPlatform  ; preserves X and Y, returns C
    bcc @done
    ;; Expire the bullet.
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    ;; TODO: play a sound
    ;; Hit the breakable glass.
    stx T0  ; bullet actor index
    ldx Zp_RoomState + sState::BreakableGlassHits_u8_arr, y
    inx
    txa
    sta Zp_RoomState + sState::BreakableGlassHits_u8_arr, y
    ;; If the glass is now broken, remove it.
    cmp #kNumHitsToBreakGlass
    blt @done
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr, y
    ;; TODO: either two separate flags, or only set flag once both are broken
    ldx #eFlag::ShadowHallGlassBroken  ; param: flag
    jsr Func_SetFlag  ; preserves T0+
    ldx T0  ; bullet actor index
    @done:
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_ShadowHallMinigun_TryMove
    lda #kMinigunMaxGoalX  ; param: max goal horz
    ldy #kMinigunMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_CarriageTryMove
.ENDPROC

.PROC FuncA_Machine_ShadowHallMinigun_TryAct
    ldy #eDir::Right  ; param: bullet direction
    jmp FuncA_Machine_MinigunTryAct
.ENDPROC

;;;=========================================================================;;;
