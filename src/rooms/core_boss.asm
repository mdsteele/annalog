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
.INCLUDE "../machines/winch.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Core_sTileset
.IMPORT FuncA_Machine_CannonTick
.IMPORT FuncA_Machine_CannonTryAct
.IMPORT FuncA_Machine_CannonTryMove
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GetWinchHorzSpeed
.IMPORT FuncA_Machine_GetWinchVertSpeed
.IMPORT FuncA_Machine_StartWorking
.IMPORT FuncA_Machine_WinchReachedGoal
.IMPORT FuncA_Machine_WinchStartFalling
.IMPORT FuncA_Objects_DrawCannonMachine
.IMPORT FuncA_Objects_DrawWinchMachineWithSpikeball
.IMPORT FuncA_Room_MachineCannonReset
.IMPORT Func_IsFlagSet
.IMPORT Func_MachineCannonReadRegY
.IMPORT Func_MovePlatformHorz
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_ResetWinchMachineState
.IMPORT Ppu_ChrObjBoss1
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_AvatarPose_eAvatar
.IMPORTZP Zp_BreakerBeingActivated_eFlag
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The machine indices for the machines in this room.
kWinchMachineIndex  = 0
kCannonMachineIndex = 1
;;; The platform indices for the machines in this room.
kWinchPlatformIndex     = 0
kSpikeballPlatformIndex = 1
kCannonPlatformIndex    = 2

;;; The initial and maximum permitted values for the winch's X and Z registers.
kWinchInitGoalX = 0
kWinchMaxGoalX  = 2
kWinchInitGoalZ = 0
kWinchMaxGoalZ  = 6

;;; The minimum and initial room pixel position for the left edge of the winch.
.LINECONT +
kWinchMinPlatformLeft = $50
kWinchInitPlatformLeft = \
    kWinchMinPlatformLeft + kBlockWidthPx * kWinchInitGoalX
.LINECONT +

;;; The minimum and initial room pixel position for the top edge of the
;;; spikeball.
.LINECONT +
kSpikeballMinPlatformTop = $22
kSpikeballInitPlatformTop = \
    kSpikeballMinPlatformTop + kBlockHeightPx * kWinchInitGoalZ
.LINECONT +

;;;=========================================================================;;;

.SEGMENT "PRGC_Core"

.EXPORT DataC_Core_Boss_sRoom
.PROC DataC_Core_Boss_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $10
    d_word MaxScrollX_u16, $0110
    d_byte Flags_bRoom, bRoom::Unsafe | bRoom::Tall | eArea::Core
    d_byte MinimapStartRow_u8, 1
    d_byte MinimapStartCol_u8, 13
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 2
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjBoss1)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Core_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, FuncC_Core_Boss_FadeInRoom
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/data/core_boss.room"
    .assert * - :- = 33 * 24, error
_Machines_sMachine_arr:
:   .assert * - :- = kWinchMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreBossWinch
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::MoveHV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Winch
    d_word ScrollGoalX_u16, $010
    d_byte ScrollGoalY_u8, $00
    d_byte RegNames_u8_arr4, 0, 0, "X", "Z"
    d_byte MainPlatform_u8, kWinchPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_CoreBossWinch_InitReset
    d_addr ReadReg_func_ptr, FuncC_Core_BossWinch_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CoreBossWinch_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CoreBossWinch_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_CoreBossWinch_Tick
    d_addr Draw_func_ptr, FuncA_Objects_CoreBossWinch_Draw
    d_addr Reset_func_ptr, FuncA_Room_CoreBossWinch_InitReset
    D_END
    .assert * - :- = kCannonMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::CoreBossCannon
    d_byte Breaker_eFlag, 0
    d_byte Flags_bMachine, bMachine::FlipH | bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::CannonLeft
    d_word ScrollGoalX_u16, $110
    d_byte ScrollGoalY_u8, $a0
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kCannonPlatformIndex
    d_addr Init_func_ptr, Func_Noop
    d_addr ReadReg_func_ptr, Func_MachineCannonReadRegY
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_CannonTryMove
    d_addr TryAct_func_ptr, FuncA_Machine_CannonTryAct
    d_addr Tick_func_ptr, FuncA_Machine_CannonTick
    d_addr Draw_func_ptr, FuncA_Objects_DrawCannonMachine
    d_addr Reset_func_ptr, FuncA_Room_MachineCannonReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWinchPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $10
    d_word Left_i16, kWinchInitPlatformLeft
    d_word Top_i16,   $0010
    D_END
    .assert * - :- = kSpikeballPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Harm
    d_word WidthPx_u16, kSpikeballWidthPx
    d_byte HeightPx_u8, kSpikeballHeightPx
    d_word Left_i16, kWinchInitPlatformLeft + 2
    d_word Top_i16, kSpikeballInitPlatformTop
    D_END
    .assert * - :- = kCannonPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, kBlockWidthPx
    d_byte HeightPx_u8, kBlockHeightPx
    d_word Left_i16, $01f0
    d_word Top_i16,  $012c
    D_END
    ;; TODO: wall to seal passage during boss fight
    ;; Top corners of reactor:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00f0
    d_word Top_i16,   $0078
    D_END
    ;; Wide radius of reactor:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $50
    d_byte HeightPx_u8, $40
    d_word Left_i16,  $00e8
    d_word Top_i16,   $00a8
    D_END
    ;; Narrow radius of reactor:
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $30
    d_byte HeightPx_u8, $a8
    d_word Left_i16,  $00f8
    d_word Top_i16,   $0070
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   ;; TODO: add Gronta actor?
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 10
    d_byte BlockCol_u8, 2
    d_byte Target_byte, kWinchMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Console
    d_byte BlockRow_u8, 20
    d_byte BlockCol_u8, 28
    d_byte Target_byte, kCannonMachineIndex
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 1
    d_byte Destination_eRoom, eRoom::CoreLock
    d_byte SpawnBlock_u8, 21
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

.PROC FuncC_Core_Boss_FadeInRoom
    ;; Only redraw circuits if the circuit activation cutscene is playing (in
    ;; this room, the player avatar will be hidden iff that's the case).
    lda Zp_AvatarPose_eAvatar
    .assert eAvatar::Hidden = 0, error
    bne _Return
_RedrawCircuits:
    ldx #kLastBreakerFlag
    @loop:
    cpx Zp_BreakerBeingActivated_eFlag
    beq @currentBreaker
    jsr Func_IsFlagSet  ; preserves X, returns Z
    bne @continue
    lda #$00  ; param: tile ID base
    beq @redraw  ; unconditional
    @currentBreaker:
    lda #$40  ; param: tile ID base
    @redraw:
    jsr FuncC_Core_Boss_RedrawCircuit  ; preserves X
    @continue:
    dex
    cpx #kFirstBreakerFlag
    bge @loop
_Return:
    rts
.ENDPROC

;;; Redraws tiles for a breaker circuit for the circuit activation cutscene.
;;; @prereq Rendering is disabled.
;;; @param A The tile ID base to use.
;;; @param X The eFlag::Breaker* value for the circuit to redraw.
;;; @preserve X
.PROC FuncC_Core_Boss_RedrawCircuit
    sta T2  ; tile ID base
    stx T3  ; eFlag::Breaker* value
_GetTransferEntries:
    txa  ; eFlag::Breaker* value
    sub #kFirstBreakerFlag
    tay  ; eBreaker value
    lda DataC_Core_Boss_BreakerTransfers_arr_ptr_0_arr, y
    sta T0  ; transfer ptr (lo)
    lda DataC_Core_Boss_BreakerTransfers_arr_ptr_1_arr, y
    sta T1  ; transfer ptr (hi)
_ReadHeader:
    ldy #0
    lda (T1T0), y  ; PPU control byte
    sta Hw_PpuCtrl_wo
    iny
    lda (T1T0), y  ; PPU destination address (lo)
    sta T4         ; PPU destination address (lo)
    iny
    lda (T1T0), y  ; PPU destination address (hi)
    iny
_WriteToPpu:
    bne @entryBegin  ; unconditional
    @entryLoop:
    iny
    ;; At this point, A holds the PPU address offset.
    add T4  ; PPU destination address (lo)
    sta T4  ; PPU destination address (lo)
    lda #0
    adc T5  ; PPU destination address (hi)
    @entryBegin:
    sta T5  ; PPU destination address (hi)
    sta Hw_PpuAddr_w2
    lda T4  ; PPU destination address (lo)
    sta Hw_PpuAddr_w2
    lda (T1T0), y  ; tile ID index
    iny
    tax  ; tile ID index
    lda (T1T0), y  ; transfer length
    iny
    sta T6  ; transfer length
    @dataLoop:
    lda DataC_Core_Boss_CircuitTiles_u8_arr, x
    ora T2  ; tile ID base
    sta Hw_PpuData_rw
    inx
    dec T6  ; transfer length
    bne @dataLoop
    lda (T1T0), y  ; PPU address offset
    bne @entryLoop
    ldx T3  ; eFlag::Breaker* value (to preserve X)
    rts
.ENDPROC

;;; Maps from eBreaker enum values to PPU transfer arrays.
.REPEAT 2, table
    D_TABLE_LO table, DataC_Core_Boss_BreakerTransfers_arr_ptr_0_arr
    D_TABLE_HI table, DataC_Core_Boss_BreakerTransfers_arr_ptr_1_arr
    D_TABLE eBreaker
    d_entry table, Garden, DataC_Core_Boss_CircuitGardenTransfer_arr
    d_entry table, Temple, DataC_Core_Boss_CircuitTempleTransfer_arr
    d_entry table, Crypt,  DataC_Core_Boss_CircuitCryptTransfer_arr
    d_entry table, Lava,   DataC_Core_Boss_CircuitLavaTransfer_arr
    d_entry table, Mine,   DataC_Core_Boss_CircuitMineTransfer_arr
    d_entry table, City,   DataC_Core_Boss_CircuitCityTransfer_arr
    d_entry table, Shadow, DataC_Core_Boss_CircuitShadowTransfer_arr
    D_END
.ENDREPEAT

.PROC DataC_Core_Boss_CircuitGardenTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $21d3              ; destination address
_Row0:
    .byte $03  ; tile ID offset
    .byte 1    ; transfer length
    .byte $20  ; address offset
_Row1:
    .byte $02  ; tile ID offset
    .byte 2    ; transfer length
    .byte $20  ; address offset
_Row2:
    .byte $01  ; tile ID offset
    .byte 3    ; transfer length
    .byte $20  ; address offset
_Row3:
    .byte $00  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row4:
    .byte $40  ; tile ID offset
    .byte 10   ; transfer length
    .byte $21  ; address offset
_Row5:
    .byte $27  ; tile ID offset
    .byte 9    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitTempleTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $2716              ; destination address
_Row0:
    .byte $20  ; tile ID offset
    .byte 7    ; transfer length
    .byte $1f  ; address offset
_Row1:
    .byte $10  ; tile ID offset
    .byte 8    ; transfer length
    .byte $1f  ; address offset
_Row2:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row3:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $20  ; address offset
_Row4:
    .byte $05  ; tile ID offset
    .byte 3    ; transfer length
    .byte $20  ; address offset
_Row5:
    .byte $06  ; tile ID offset
    .byte 2    ; transfer length
    .byte $60  ; address offset
_Row6:
    .byte $07  ; tile ID offset
    .byte 1    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitCryptTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $2c1a              ; destination address
_Row0:
    .byte $20  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row1:
    .byte $10  ; tile ID offset
    .byte 5    ; transfer length
    .byte $1f  ; address offset
_Row2:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row3:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row4:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row5:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row6:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row7:
    .byte $04  ; tile ID offset
    .byte 4    ; transfer length
    .byte $20  ; address offset
_Row8:
    .byte $05  ; tile ID offset
    .byte 3    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitLavaTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $2c06              ; destination address
_Row0:
    .byte $33  ; tile ID offset
    .byte 4    ; transfer length
    .byte $20  ; address offset
_Row1:
    .byte $1b  ; tile ID offset
    .byte 5    ; transfer length
    .byte $22  ; address offset
_Row2:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row3:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row4:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row5:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row6:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row7:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row8:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitMineTransfer_arr
    .byte kPpuCtrlFlagsHorz  ; control flags
    .addr $2707              ; destination address
_Row0:
    .byte $30  ; tile ID offset
    .byte 7    ; transfer length
    .byte $20  ; address offset
_Row1:
    .byte $18  ; tile ID offset
    .byte 8    ; transfer length
    .byte $25  ; address offset
_Row2:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row3:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row4:
    .byte $08  ; tile ID offset
    .byte 4    ; transfer length
    .byte $21  ; address offset
_Row5:
    .byte $08  ; tile ID offset
    .byte 3    ; transfer length
    .byte $61  ; address offset
_Row6:
    .byte $08  ; tile ID offset
    .byte 2    ; transfer length
    .byte $21  ; address offset
_Row7:
    .byte $08  ; tile ID offset
    .byte 1    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitCityTransfer_arr
    .byte kPpuCtrlFlagsHorz ; control flags
    .addr $21b1             ; destination address
_Row0:
    .byte $0c  ; tile ID offset
    .byte 1    ; transfer length
    .byte $1f  ; address offset
_Row1:
    .byte $0c  ; tile ID offset
    .byte 2    ; transfer length
    .byte $1f  ; address offset
_Row2:
    .byte $0c  ; tile ID offset
    .byte 3    ; transfer length
    .byte $1f  ; address offset
_Row3:
    .byte $0c  ; tile ID offset
    .byte 4    ; transfer length
    .byte $1f  ; address offset
_Row4:
    .byte $0c  ; tile ID offset
    .byte 4    ; transfer length
    .byte $19  ; address offset
_Row5:
    .byte $4a  ; tile ID offset
    .byte 10   ; transfer length
    .byte $20  ; address offset
_Row6:
    .byte $37  ; tile ID offset
    .byte 9    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitShadowTransfer_arr
    .byte kPpuCtrlFlagsVert  ; control flags
    .addr $2ca1              ; destination address
_Col0:
    .byte $54  ; tile ID offset
    .byte 4    ; transfer length
    .byte $01  ; address offset
_Col1:
    .byte $58  ; tile ID offset
    .byte 4    ; transfer length
    .byte 0    ; address offset (0 = stop)
.ENDPROC

.PROC DataC_Core_Boss_CircuitTiles_u8_arr
    ;; $00
    .byte $33, $32, $31, $30
    .byte $34, $35, $36, $37
    .byte $3b, $3a, $39, $38
    .byte $3c, $3d, $3e, $3f
    ;; $10
    .byte $34, $35, $36, $2b, $2b, $2b, $2b, $2b
    .byte $2d, $2d, $2d, $2d, $2d, $3a, $39, $38
    ;; $20
    .byte $34, $2a, $2a, $2a, $2a, $2a, $2a
    .byte $33, $2b, $2b, $2b, $2b, $2b, $2b, $2b, $2b
    ;; $30
    .byte $2c, $2c, $2c, $2c, $2c, $2c, $38
    .byte $2d, $2d, $2d, $2d, $2d, $2d, $2d, $2d, $3f
    ;; $40
    .byte $33, $32, $31, $2a, $2a, $2a, $2a, $2a, $2a, $2a
    .byte $2c, $2c, $2c, $2c, $2c, $2c, $2c, $3d, $3e, $3f
    ;; $54
    .byte $2e, $2e, $2e, $2e
    .byte $2f, $2f, $2f, $2f
.ENDPROC

.PROC FuncC_Core_BossWinch_ReadReg
    cmp #$e
    beq _ReadX
_ReadZ:
    lda Ram_PlatformTop_i16_0_arr + kSpikeballPlatformIndex
    sub #kSpikeballMinPlatformTop - kTileHeightPx
    div #kBlockHeightPx
    rts
_ReadX:
    lda Ram_PlatformLeft_i16_0_arr + kWinchPlatformIndex
    sub #kWinchMinPlatformLeft - kTileWidthPx
    div #kBlockWidthPx
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_CoreBossWinch_TryMove
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    .assert eDir::Up = 0, error
    txa
    beq _MoveUp
    cpx #eDir::Down
    beq _MoveDown
_MoveHorz:
    cpx #eDir::Left
    beq @moveLeft
    @moveRight:
    cpy #kWinchMaxGoalX
    bge _Error
    iny
    bne @checkFloor  ; unconditional
    @moveLeft:
    tya
    beq _Error
    dey
    @checkFloor:
    lda DataA_Machine_CoreBossWinchFloor_u8_arr, y
    cmp Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    blt _Error
    sty Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveUp:
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    beq _Error
    dec Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_MoveDown:
    lda DataA_Machine_CoreBossWinchFloor_u8_arr, y
    cmp Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    beq _Error
    inc Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp FuncA_Machine_StartWorking
_Error:
    jmp FuncA_Machine_Error
.ENDPROC

.PROC FuncA_Machine_CoreBossWinch_TryAct
    ldy Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda DataA_Machine_CoreBossWinchFloor_u8_arr, y  ; param: new Z-goal
    jmp FuncA_Machine_WinchStartFalling
.ENDPROC

.PROC FuncA_Machine_CoreBossWinch_Tick
_MoveVert:
    ;; Calculate the desired room-space pixel Y-position for the top edge of
    ;; the spikeball, storing it in Zp_PointY_i16.
    lda Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    mul #kBlockHeightPx
    adc #kSpikeballMinPlatformTop  ; carry is already clear
    .linecont +
    .assert kWinchMaxGoalZ * kBlockHeightPx + \
            kSpikeballMinPlatformTop < $100, error
    .linecont -
    sta Zp_PointY_i16 + 0
    lda #0
    sta Zp_PointY_i16 + 1
    ;; Determine how fast we should move toward the goal.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jsr FuncA_Machine_GetWinchVertSpeed  ; preserves X, returns Z and A
    bne @move
    rts
    @move:
    ;; Move the spikeball vertically, as necessary.
    jsr Func_MovePlatformTopTowardPointY  ; returns Z and A
    beq @reachedGoal
    rts
    @reachedGoal:
_MoveHorz:
    ;; Calculate the desired X-position for the left edge of the winch, in
    ;; room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    mul #kBlockWidthPx
    adc #<kWinchMinPlatformLeft  ; carry is already clear
    sta Zp_PointX_i16 + 0
    .linecont +
    .assert kWinchMaxGoalX * kBlockWidthPx + \
            kWinchMinPlatformLeft < $100, error
    .linecont -
    lda #0
    sta Zp_PointX_i16 + 1
    ;; Move the winch horizontally, if necessary.
    jsr FuncA_Machine_GetWinchHorzSpeed  ; returns A
    ldx #kWinchPlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z and A
    beq @reachedGoal
    ;; If the winch moved, move the spikeball platform too.
    ldx #kSpikeballPlatformIndex  ; param: platform index
    jmp Func_MovePlatformHorz
    @reachedGoal:
_Finished:
    jmp FuncA_Machine_WinchReachedGoal
.ENDPROC

.PROC DataA_Machine_CoreBossWinchFloor_u8_arr
    .byte 2, 6, 6
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_CoreBossWinch_InitReset
    lda #kWinchInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kWinchMachineIndex
    lda #kWinchInitGoalZ
    sta Ram_MachineGoalVert_u8_arr + kWinchMachineIndex
    jmp Func_ResetWinchMachineState
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Objects"

;;; Draws the CoreBossWinch machine.
.PROC FuncA_Objects_CoreBossWinch_Draw
    ldx #kSpikeballPlatformIndex  ; param: spikeball platform index
    jmp FuncA_Objects_DrawWinchMachineWithSpikeball
.ENDPROC

;;;=========================================================================;;;
