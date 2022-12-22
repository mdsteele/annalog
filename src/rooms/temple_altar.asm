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
.INCLUDE "../cpu.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../spawn.inc"

.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncA_Machine_CarriageMoveTowardGoalHorz
.IMPORT FuncA_Machine_CarriageMoveTowardGoalVert
.IMPORT FuncA_Machine_CarriageTryMove
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_MinigunRotateBarrel
.IMPORT FuncA_Machine_MinigunTryAct
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Objects_DrawMinigunDownMachine
.IMPORT FuncA_Objects_DrawMinigunSideMachine
.IMPORT FuncA_Room_AreActorsWithinDistance
.IMPORT FuncC_Temple_DrawColumnCrackedPlatform
.IMPORT Func_InitActorProjSmoke
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToActorCenter
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Ram_RoomState
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_PointX_i16

;;;=========================================================================;;;

;;; The dialog index for the plaque sign in this room.
kPlaqueDialogIndex = 0

;;; The index of the passage at the top of the room.
kUpperPassageIndex = 0

;;; The highest actor index among the beetles in this room.
kLastBeetleActorIndex = 2

;;; The platform index for the breakable column.
kColumnPlatformIndex = 2

;;; How many bullets must hit the breakable column to destroy it.
kNumHitsToBreakColumn = 6

;;;=========================================================================;;;

;;; The machine index for the TempleAltarUpperMinigun machine.
kUpperMinigunMachineIndex = 0
;;; The platform index for the TempleAltarUpperMinigun machine.
kUpperMinigunPlatformIndex = 0

;;; The initial and maximum permitted vertical goal values for the
;;; TempleAltarUpperMinigun machine.
kUpperMinigunInitGoalX = 4
kUpperMinigunMaxGoalX  = 8

;;; The maximum and initial Y-positions for the top of the upper minigun
;;; platform.
.LINECONT +
kUpperMinigunMinPlatformLeft = $0038
kUpperMinigunInitPlatformLeft = \
    kUpperMinigunMinPlatformLeft + kUpperMinigunInitGoalX * kBlockWidthPx
.LINECONT -

;;;=========================================================================;;;

;;; The machine index for the TempleAltarLowerMinigun machine.
kLowerMinigunMachineIndex = 1
;;; The platform index for the TempleAltarLowerMinigun machine.
kLowerMinigunPlatformIndex = 1

;;; The initial and maximum permitted horizontal and vertical goal values for
;;; the TempleAltarLowerMinigun machine.
kLowerMinigunInitGoalX = 1
kLowerMinigunMaxGoalX  = 1
kLowerMinigunInitGoalY = 0
kLowerMinigunMaxGoalY  = 7

;;; The minimum and initial X-positions for the left of the lower minigun
;;; platform.
.LINECONT +
kLowerMinigunMinPlatformLeft = $0070
kLowerMinigunInitPlatformLeft = \
    kLowerMinigunMinPlatformLeft + kLowerMinigunInitGoalX * kBlockWidthPx
.LINECONT -

;;; The maximum and initial Y-positions for the top of the lower minigun
;;; platform.
.LINECONT +
kLowerMinigunMaxPlatformTop = $0130
kLowerMinigunInitPlatformTop = \
    kLowerMinigunMaxPlatformTop - kLowerMinigunInitGoalY * kBlockHeightPx
.LINECONT -

;;;=========================================================================;;;

;;; Enum for the steps of the TempleAltarLowerMinigun machine's reset sequence
;;; (listed in reverse order).
.ENUM eResetSeq
    LowerRight = 0  ; move to X=1, Y=0
    MiddleLeft      ; move to X=0, Y=3
    UpperRight      ; move to X=1
.ENDENUM

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; The current state of the room's levers.
    LeverLeft_u1           .byte
    LeverRight_u1          .byte
    ;; Which step of its reset sequence the TempleAltarLowerMinigun machine is
    ;; on.
    LowerMinigun_eResetSeq .byte
    ;; How many times the breakable column has been hit.
    BreakableColumnHits_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Altar_sRoom
.PROC DataC_Temple_Altar_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0010
    d_byte Flags_bRoom, bRoom::Tall | eArea::Temple
    d_byte MinimapStartRow_u8, 3
    d_byte MinimapStartCol_u8, 1
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Tick_func_ptr, FuncC_Temple_Altar_TickRoom
    d_addr Draw_func_ptr, FuncC_Temple_Altar_DrawRoom
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    .linecont +
    d_addr Dialogs_sDialog_ptr_arr_ptr, \
           DataA_Dialog_TempleAltar_sDialog_ptr_arr
    .linecont -
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Init_func_ptr, FuncC_Temple_Altar_InitRoom
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/temple_altar.room"
    .assert * - :- = 17 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kUpperMinigunMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::TempleAltarUpperMinigun
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Carriage  ; TODO
    d_word ScrollGoalX_u16, $0010
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, "L", "R", "X", 0
    d_byte MainPlatform_u8, kUpperMinigunPlatformIndex
    d_addr Init_func_ptr, FuncC_Temple_AltarUpperMinigun_Init
    d_addr ReadReg_func_ptr, FuncC_Temple_AltarUpperMinigun_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Temple_AltarUpperMinigun_TryMove
    d_addr TryAct_func_ptr, FuncC_Temple_AltarUpperMinigun_TryAct
    d_addr Tick_func_ptr, FuncC_Temple_AltarUpperMinigun_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawMinigunDownMachine
    d_addr Reset_func_ptr, FuncC_Temple_AltarUpperMinigun_Reset
    D_END
    .assert * - :- = kLowerMinigunMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::TempleAltarLowerMinigun
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Carriage  ; TODO
    d_word ScrollGoalX_u16, $0010
    d_byte ScrollGoalY_u8, $b0
    d_byte RegNames_u8_arr4, 0, 0, "X", "Y"
    d_byte MainPlatform_u8, kLowerMinigunPlatformIndex
    d_addr Init_func_ptr, FuncC_Temple_AltarLowerMinigun_Init
    d_addr ReadReg_func_ptr, FuncC_Temple_AltarLowerMinigun_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncC_Temple_AltarLowerMinigun_TryMove
    d_addr TryAct_func_ptr, FuncC_Temple_AltarLowerMinigun_TryAct
    d_addr Tick_func_ptr, FuncC_Temple_AltarLowerMinigun_Tick
    d_addr Draw_func_ptr, FuncA_Objects_DrawMinigunSideMachine
    d_addr Reset_func_ptr, FuncC_Temple_AltarLowerMinigun_Reset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kUpperMinigunPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16, kUpperMinigunInitPlatformLeft
    d_word Top_i16,   $0030
    D_END
    .assert * - :- = kLowerMinigunPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $20
    d_byte HeightPx_u8, $10
    d_word Left_i16, kLowerMinigunInitPlatformLeft
    d_word Top_i16,  kLowerMinigunInitPlatformTop
    D_END
    .assert * - :- = kColumnPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0058
    d_word Top_i16,   $00c0
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_byte TileRow_u8, 13
    d_byte TileCol_u8, 9
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_byte TileRow_u8, 11
    d_byte TileCol_u8, 13
    d_byte Param_byte, bObj::FlipH
    D_END
    .assert * - :- = kLastBeetleActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleVert
    d_byte TileRow_u8, 13
    d_byte TileCol_u8, 19
    d_byte Param_byte, bObj::FlipHV
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Sign
    d_byte BlockRow_u8, 9
    d_byte BlockCol_u8, 8
    d_byte Target_u8, kPlaqueDialogIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 7
    d_byte BlockCol_u8, 2
    d_byte Target_u8, kUpperMinigunMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 4
    d_byte Target_u8, sState::LeverLeft_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::LeverFloor
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 12
    d_byte Target_u8, sState::LeverRight_u1
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 15
    d_byte Target_u8, kLowerMinigunMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   .assert * - :- = kUpperPassageIndex * .sizeof(sPassage), error
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Top | 0
    d_byte Destination_eRoom, eRoom::TempleAltar  ; TODO
    d_byte SpawnBlock_u8, 8
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::TempleWest
    d_byte SpawnBlock_u8, 20
    D_END
.ENDPROC

.PROC FuncC_Temple_Altar_InitRoom
    ;; If the breakable column has already been destroyed, remove its platform.
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleAltarColumnBroken
    beq @done
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kColumnPlatformIndex
    @done:
    rts
.ENDPROC

;;; @prereq PRGA_Room is loaded.
.PROC FuncC_Temple_Altar_TickRoom
    ldx #kMaxActors - 1
    @loop:
    lda Ram_ActorType_eActor_arr, x
    cmp #eActor::ProjBullet
    bne @continue
    jsr FuncC_Temple_Altar_CheckForBulletHit  ; preserves X
    @continue:
    dex
    bpl @loop
    rts
.ENDPROC

;;; Checks if the given bullet actor has hit the breakable column or a baddie
;;; in this room; if so, handles the collision.
;;; @prereq PRGA_Room is loaded.
;;; @param X The bullet actor index.
;;; @preserves X
.PROC FuncC_Temple_Altar_CheckForBulletHit
    jsr Func_SetPointToActorCenter  ; preserves X
_CheckIfHitColumn:
    lda Ram_PlatformType_ePlatform_arr + kColumnPlatformIndex
    .assert ePlatform::None = 0, error
    beq @noHitColumn
    ldy #kColumnPlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; preserves X and Y, returns C
    bcs _HitColumn
    @noHitColumn:
_CheckIfHitBeetle:
    ldy #kLastBeetleActorIndex
    @loop:
    lda Ram_ActorType_eActor_arr, y
    cmp #eActor::BadBeetleVert
    beq @checkIfHit
    cmp #eActor::BadBeetleHorz
    bne @continue
    @checkIfHit:
    lda #6  ; param: distance
    jsr FuncA_Room_AreActorsWithinDistance  ; preserves X and Y, returns C
    bcs _HitBeetle
    @continue:
    dey
    bpl @loop
    rts
_HitColumn:
    ;; Expire the bullet.
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    ;; Hit the breakable column.
    inc Ram_RoomState + sState::BreakableColumnHits_u8
    ;; TODO: play a sound
    ;; If the column is now broken, remove it.
    lda Ram_RoomState + sState::BreakableColumnHits_u8
    cmp #kNumHitsToBreakColumn
    blt @done
    lda #ePlatform::None
    sta Ram_PlatformType_ePlatform_arr + kColumnPlatformIndex
    ldx #eFlag::TempleAltarColumnBroken  ; param: flag
    jmp Func_SetFlag
    @done:
    rts
_HitBeetle:
    ;; Expire the bullet.
    lda #eActor::None
    sta Ram_ActorType_eActor_arr, x
    txa  ; bullet actor index
    pha  ; bullet actor index
    ;; Kill the beetle.
    tya  ; beetle actor index
    tax  ; param: actor index
    jsr Func_InitActorProjSmoke
    ;; TODO: play a sound
    ;; Restore the bullet actor index (so this function can preserve X).
    pla  ; bullet actor index
    tax  ; bullet actor index
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Temple_Altar_DrawRoom
    lda Ram_PlatformType_ePlatform_arr + kColumnPlatformIndex
    .assert ePlatform::None = 0, error
    beq @columnBroken
    ldx #kColumnPlatformIndex  ; param: platform index
    lda Ram_RoomState + sState::BreakableColumnHits_u8  ; param: num hits
    jmp FuncC_Temple_DrawColumnCrackedPlatform
    @columnBroken:
    rts
.ENDPROC

.PROC FuncC_Temple_AltarUpperMinigun_Init
    .assert * = FuncC_Temple_AltarUpperMinigun_Reset, error, "fallthrough"
.ENDPROC

.PROC FuncC_Temple_AltarUpperMinigun_Reset
    lda #kUpperMinigunInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kUpperMinigunMachineIndex
    rts
.ENDPROC

.PROC FuncC_Temple_AltarUpperMinigun_ReadReg
    cmp #$e
    beq _ReadX
    cmp #$d
    beq _ReadR
_ReadL:
    lda Ram_RoomState + sState::LeverLeft_u1
    rts
_ReadR:
    lda Ram_RoomState + sState::LeverRight_u1
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kUpperMinigunPlatformIndex
    sub #kUpperMinigunMinPlatformLeft - kTileHeightPx
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Temple_AltarUpperMinigun_TryMove
    lda #kUpperMinigunMaxGoalX  ; param: max goal
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncC_Temple_AltarUpperMinigun_TryAct
    ldy #eDir::Down  ; param: bullet direction
    jmp FuncA_Machine_MinigunTryAct
.ENDPROC

.PROC FuncC_Temple_AltarUpperMinigun_Tick
    jsr FuncA_Machine_MinigunRotateBarrel
    ;; Calculate the desired X-position for the left edge of the minigun, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kUpperMinigunMachineIndex
    mul #kBlockWidthPx
    add #<kUpperMinigunMinPlatformLeft
    sta Zp_PointX_i16 + 0
    lda #0
    adc #>kUpperMinigunMinPlatformLeft
    sta Zp_PointX_i16 + 1
    ;; Determine the horizontal speed of the minigun (faster if resetting).
    ldx Ram_MachineStatus_eMachine_arr + kUpperMinigunMachineIndex
    lda #1
    cpx #eMachine::Resetting
    bne @slow
    mul #2
    @slow:
    ;; Move the minigun horizontally, as necessary.
    ldx #kUpperMinigunPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncC_Temple_AltarLowerMinigun_ReadReg
    cmp #$f
    beq _ReadY
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kLowerMinigunPlatformIndex
    sub #kLowerMinigunMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
_ReadY:
    lda #<(kLowerMinigunMaxPlatformTop + kTileHeightPx)
    sub Ram_PlatformTop_i16_0_arr + kLowerMinigunPlatformIndex
    div #kBlockWidthPx
    rts
.ENDPROC

.PROC FuncC_Temple_AltarLowerMinigun_TryMove
    lda #kLowerMinigunMaxGoalX  ; param: max goal horz
    ldy #kLowerMinigunMaxGoalY  ; param: max goal vert
    jmp FuncA_Machine_CarriageTryMove
.ENDPROC

.PROC FuncC_Temple_AltarLowerMinigun_TryAct
    ldy #eDir::Left  ; param: bullet direction
    jmp FuncA_Machine_MinigunTryAct
.ENDPROC

.PROC FuncC_Temple_AltarLowerMinigun_Tick
    jsr FuncA_Machine_MinigunRotateBarrel
_MoveVert:
    ldax #kLowerMinigunMaxPlatformTop
    jsr FuncA_Machine_CarriageMoveTowardGoalVert  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ldax #kLowerMinigunMinPlatformLeft
    jsr FuncA_Machine_CarriageMoveTowardGoalHorz  ; returns Z
    beq @reachedGoal
    rts
    @reachedGoal:
_ReachedGoal:
    lda Ram_RoomState + sState::LowerMinigun_eResetSeq
    bne FuncC_Temple_AltarLowerMinigun_Reset
    jmp FuncA_Machine_ReachedGoal
.ENDPROC

.PROC FuncC_Temple_AltarLowerMinigun_Reset
    lda Ram_MachineGoalHorz_u8_arr + kLowerMinigunMachineIndex
    bne @onRightSide
    @onLeftSide:
    lda Ram_MachineGoalVert_u8_arr + kLowerMinigunMachineIndex
    cmp #5
    bge _MoveToUpperRight
    blt _MoveToLowerRight  ; unconditional
    @onRightSide:
    lda Ram_MachineGoalVert_u8_arr + kLowerMinigunMachineIndex
    cmp #2
    blt _MoveToLowerRight
_MoveToMiddleLeft:
    lda #eResetSeq::MiddleLeft
    sta Ram_RoomState + sState::LowerMinigun_eResetSeq
    lda #0
    sta Ram_MachineGoalHorz_u8_arr + kLowerMinigunMachineIndex
    lda #3
    sta Ram_MachineGoalVert_u8_arr + kLowerMinigunMachineIndex
    rts
_MoveToUpperRight:
    lda #eResetSeq::UpperRight
    sta Ram_RoomState + sState::LowerMinigun_eResetSeq
    lda #1
    sta Ram_MachineGoalHorz_u8_arr + kLowerMinigunMachineIndex
    rts
_MoveToLowerRight:
    lda #eResetSeq::LowerRight
    sta Ram_RoomState + sState::LowerMinigun_eResetSeq
    .assert * = FuncC_Temple_AltarLowerMinigun_Init, error, "fallthrough"
.ENDPROC

.PROC FuncC_Temple_AltarLowerMinigun_Init
    lda #kLowerMinigunInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kLowerMinigunMachineIndex
    lda #kLowerMinigunInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kLowerMinigunMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

;;; Dialog data for the TempleAltar room.
.PROC DataA_Dialog_TempleAltar_sDialog_ptr_arr
:   .assert * - :- = kPlaqueDialogIndex * kSizeofAddr, error
    .addr DataA_Dialog_TempleAltar_Plaque_sDialog
.ENDPROC

.PROC DataA_Dialog_TempleAltar_Plaque_sDialog
    .word ePortrait::Sign  ; TODO
    .byte "- Temple of Peace -$"
    .byte "Built together as a$"
    .byte "Symbol of Unity by$"
    .byte "mermaids and humans.#"
    .word ePortrait::Done
.ENDPROC

;;;=========================================================================;;;
