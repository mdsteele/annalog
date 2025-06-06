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
.INCLUDE "../cursor.inc"
.INCLUDE "../device.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../machine.inc"
.INCLUDE "../machines/drums.inc"
.INCLUDE "../machines/organ.inc"
.INCLUDE "../machines/shared.inc"
.INCLUDE "../machines/trombone.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../program.inc"
.INCLUDE "../room.inc"
.INCLUDE "../sample.inc"

.IMPORT DataA_Room_Hut_sTileset
.IMPORT Data_Empty_sActor_arr
.IMPORT FuncA_Machine_Error
.IMPORT FuncA_Machine_GenericTryMoveX
.IMPORT FuncA_Machine_GenericTryMoveY
.IMPORT FuncA_Machine_GetGenericMoveSpeed
.IMPORT FuncA_Machine_PlaySfxHiHat
.IMPORT FuncA_Machine_PlaySfxOrgan
.IMPORT FuncA_Machine_PlaySfxTrombone
.IMPORT FuncA_Machine_ReachedGoal
.IMPORT FuncA_Machine_StartWaiting
.IMPORT FuncA_Objects_Draw1x1Shape
.IMPORT FuncA_Objects_Draw1x2Shape
.IMPORT FuncA_Objects_Draw2x2MirroredShape
.IMPORT FuncA_Objects_DrawPumpMachine
.IMPORT FuncA_Objects_MoveShapeDownByA
.IMPORT FuncA_Objects_MoveShapeLeftOneTile
.IMPORT FuncA_Objects_MoveShapeRightByA
.IMPORT FuncA_Objects_MoveShapeUpByA
.IMPORT FuncA_Objects_SetShapePosToMachineTopLeft
.IMPORT FuncA_Objects_SetShapePosToPlatformTopLeft
.IMPORT Func_MovePlatformLeftTowardPointX
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_PlaySfxSample
.IMPORT Ppu_ChrObjSewer
.IMPORT Ram_MachineGoalHorz_u8_arr
.IMPORT Ram_MachineGoalVert_u8_arr
.IMPORT Ram_MachineSlowdown_u8_arr
.IMPORT Ram_MachineStatus_eMachine_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORTZP Zp_PointX_i16
.IMPORTZP Zp_PointY_i16

;;;=========================================================================;;;

;;; The machine indices for the machines in this room.
kTromboneMachineIndex = 0
kDrumsMachineIndex = 1
kOrganMachineIndex = 2

;;; The platform indices for the machines in this room.
kTrombonePlatformIndex = 0
kTromboneSlidePlatformIndex = 1
kDrumsPlatformIndex = 2
kDrumsHiHatPlatformIndex = 3
kOrganPlatformIndex = 4

;;;=========================================================================;;;

;;; The initial and maximum permitted horizontal goal values for the trombone.
kTromboneInitGoalX = 0
kTromboneMaxGoalX = 9

;;; How far the trombone slide moves per X register increment, in pixels.
.DEFINE kTromboneSlideStep 4

;;; The minimum and initial X-positions for the left of the trombone slide.
.LINECONT +
kTromboneSlideMinPlatformLeft = $006c
kTromboneSlideInitPlatformLeft = \
    kTromboneSlideMinPlatformLeft + kTromboneInitGoalX * kTromboneSlideStep
.LINECONT -

;;;=========================================================================;;;

;;; The initial and maximum permitted vertical goal values for the drums.
kDrumsInitGoalY = 1
kDrumsMaxGoalY = 1

;;; How far the drums hi-hat moves per Y register increment, in pixels.
.DEFINE kDrumsHiHatStep 2

;;; The maximum and initial Y-positions for the top of the drums hi-hat.
.LINECONT +
kDrumsHiHatMaxPlatformTop = $00a5
kDrumsHiHatInitPlatformTop = \
    kDrumsHiHatMaxPlatformTop - kDrumsInitGoalY * kDrumsHiHatStep
.LINECONT -

;;;=========================================================================;;;

;;; OBJ tile IDs used for drawing various parts of the machines in this room.
kTileIdObjMachineDrumsBass           = kTileIdObjMachineDrumsFirst + 0
kTileIdObjMachineDrumsHiHat          = kTileIdObjMachineDrumsFirst + 1
kTileIdObjMachineTromboneSlideMiddle = kTileIdObjMachineTromboneFirst + 0
kTileIdObjMachineTromboneSlideEnd    = kTileIdObjMachineTromboneFirst + 1
kTileIdObjMachineTromboneBellFirst   = kTileIdObjMachineTromboneFirst + 2

;;; The OBJ palette numbers used for drawing various parts of the machines in
;;; this room.
kPaletteObjDrumsBass     = 0
kPaletteObjDrumsHiHat    = 0
kPaletteObjOrganPuff     = 0
kPaletteObjTromboneBell  = 0
kPaletteObjTromboneSlide = 0

;;;=========================================================================;;;

.SEGMENT "PRGC_Mermaid"

.EXPORT DataC_Mermaid_Hut6_sRoom
.PROC DataC_Mermaid_Hut6_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $0
    d_word MaxScrollX_u16, $0
    d_byte Flags_bRoom, eArea::Mermaid
    d_byte MinimapStartRow_u8, 10
    d_byte MinimapStartCol_u8, 16
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 3
    d_addr Machines_sMachine_arr_ptr, _Machines_sMachine_arr
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjSewer)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Hut_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, Data_Empty_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, 0
    d_addr Enter_func_ptr, Func_Noop
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, Func_Noop
    d_addr Draw_func_ptr, Func_Noop
    D_END
_TerrainData:
:   .incbin "out/rooms/mermaid_hut6.room"
    .assert * - :- = 16 * 15, error
_Machines_sMachine_arr:
:   .assert * - :- = kTromboneMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MermaidHut6Trombone
    d_byte Breaker_eFlag, eFlag::BreakerTemple
    d_byte Flags_bMachine, bMachine::MoveH | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Trombone
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $30
    d_byte RegNames_u8_arr4, 0, 0, "X", 0
    d_byte MainPlatform_u8, kTrombonePlatformIndex
    d_addr Init_func_ptr, FuncA_Room_MermaidHut6Trombone_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mermaid_Hut6Trombone_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MermaidHut6Trombone_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_MermaidHut6Trombone_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_MermaidHut6Trombone_Tick
    d_addr Draw_func_ptr, FuncC_Mermaid_Hut6Trombone_Draw
    d_addr Reset_func_ptr, FuncA_Room_MermaidHut6Trombone_InitReset
    D_END
    .assert * - :- = kDrumsMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MermaidHut6Drums
    d_byte Breaker_eFlag, eFlag::BreakerGarden
    d_byte Flags_bMachine, bMachine::MoveV | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Drums
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $30
    d_byte RegNames_u8_arr4, 0, 0, 0, "Y"
    d_byte MainPlatform_u8, kDrumsPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_MermaidHut6Drums_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mermaid_Hut6Drums_ReadReg
    d_addr WriteReg_func_ptr, Func_Noop
    d_addr TryMove_func_ptr, FuncA_Machine_MermaidHut6Drums_TryMove
    d_addr TryAct_func_ptr, FuncA_Machine_MermaidHut6Drums_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_MermaidHut6Drums_Tick
    d_addr Draw_func_ptr, FuncC_Mermaid_Hut6Drums_Draw
    d_addr Reset_func_ptr, FuncA_Room_MermaidHut6Drums_InitReset
    D_END
    .assert * - :- = kOrganMachineIndex * .sizeof(sMachine), error
    D_STRUCT sMachine
    d_byte Code_eProgram, eProgram::MermaidHut6Organ
    d_byte Breaker_eFlag, eFlag::BreakerLava
    d_byte Flags_bMachine, bMachine::WriteC | bMachine::Act
    d_byte Status_eDiagram, eDiagram::Organ
    d_word ScrollGoalX_u16, $00
    d_byte ScrollGoalY_u8, $30
    d_byte RegNames_u8_arr4, "J", 0, 0, 0
    d_byte MainPlatform_u8, kOrganPlatformIndex
    d_addr Init_func_ptr, FuncA_Room_MermaidHut6Organ_InitReset
    d_addr ReadReg_func_ptr, FuncC_Mermaid_Hut6Organ_ReadReg
    d_addr WriteReg_func_ptr, FuncA_Machine_MermaidHut6Organ_WriteReg
    d_addr TryMove_func_ptr, FuncA_Machine_Error
    d_addr TryAct_func_ptr, FuncA_Machine_MermaidHut6Organ_TryAct
    d_addr Tick_func_ptr, FuncA_Machine_ReachedGoal
    d_addr Draw_func_ptr, FuncC_Mermaid_Hut6Organ_Draw
    d_addr Reset_func_ptr, FuncA_Room_MermaidHut6Organ_InitReset
    D_END
    .assert * - :- <= kMaxMachines * .sizeof(sMachine), error
_Platforms_sPlatform_arr:
:   .assert * - :- = kTrombonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0047
    d_word Top_i16,   $0072
    D_END
    .assert * - :- = kTromboneSlidePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16, kTromboneSlideInitPlatformLeft
    d_word Top_i16,   $0078
    D_END
    .assert * - :- = kDrumsPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0057
    d_word Top_i16,   $00b7
    D_END
    .assert * - :- = kDrumsHiHatPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $0f
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0051
    d_word Top_i16, kDrumsHiHatInitPlatformTop
    D_END
    .assert * - :- = kOrganPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $08
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $0091
    d_word Top_i16,   $0087
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Devices_sDevice_arr:
:   D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 4
    d_byte Target_byte, kTromboneMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 7
    d_byte Target_byte, kDrumsMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::ConsoleFloor
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 11
    d_byte Target_byte, kOrganMachineIndex
    D_END
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::Door1Open
    d_byte BlockRow_u8, 11
    d_byte BlockCol_u8, 9
    d_byte Target_byte, eRoom::MermaidEast
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
.ENDPROC

.PROC FuncC_Mermaid_Hut6Trombone_ReadReg
    lda Ram_PlatformLeft_i16_0_arr + kTromboneSlidePlatformIndex
    sub #<(kTromboneSlideMinPlatformLeft - kTromboneSlideStep / 2)
    div #kTromboneSlideStep
    rts
.ENDPROC

.PROC FuncC_Mermaid_Hut6Drums_ReadReg
    lda #<(kDrumsHiHatMaxPlatformTop + kDrumsHiHatStep / 2)
    sub Ram_PlatformTop_i16_0_arr + kDrumsHiHatPlatformIndex
    div #kDrumsHiHatStep
    rts
.ENDPROC

.PROC FuncC_Mermaid_Hut6Organ_ReadReg
    lda Ram_MachineGoalHorz_u8_arr + kOrganMachineIndex
    rts
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncC_Mermaid_Hut6Trombone_Draw
_TromboneBell:
    lda Ram_MachineSlowdown_u8_arr + kTromboneMachineIndex
    beq @done
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    lda #17  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #2  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    lda #kTileIdObjMachineTromboneBellFirst  ; param: tile ID
    ldy #kPaletteObjTromboneBell  ; param: object flags
    jsr FuncA_Objects_Draw1x2Shape
    @done:
_TromboneSlide:
    ldx #kTromboneSlidePlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    ldx #5
    lda #kTileIdObjMachineTromboneSlideEnd  ; param: tile ID
    bne @start  ; unconditional
    @loop:
    lda #kTileIdObjMachineTromboneSlideMiddle  ; param: tile ID
    @start:
    ldy #bObj::Pri | kPaletteObjTromboneSlide  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape  ; preserves X
    jsr FuncA_Objects_MoveShapeLeftOneTile
    dex
    bne @loop
_MachineLight:
    jmp FuncA_Objects_DrawPumpMachine
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncC_Mermaid_Hut6Drums_Draw
_Drum:
    lda Ram_MachineSlowdown_u8_arr + kDrumsMachineIndex
    beq @done
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    lda #16  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #1  ; param: offset
    jsr FuncA_Objects_MoveShapeDownByA
    lda #kTileIdObjMachineDrumsBass  ; param: tile ID
    ldy #kPaletteObjDrumsBass  ; param: object flags
    jsr FuncA_Objects_Draw2x2MirroredShape
    @done:
_HiHat:
    ldx #kDrumsHiHatPlatformIndex  ; param: platform index
    jsr FuncA_Objects_SetShapePosToPlatformTopLeft
    lda #kTileIdObjMachineDrumsHiHat  ; param: tile ID
    ldy #kPaletteObjDrumsHiHat  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
    lda #7  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kTileIdObjMachineDrumsHiHat  ; param: tile ID
    ldy #kPaletteObjDrumsHiHat | bObj::FlipH  ; param: object flags
    jsr FuncA_Objects_Draw1x1Shape
_MachineLight:
    jmp FuncA_Objects_DrawPumpMachine
.ENDPROC

;;; @prereq PRGA_Objects is loaded.
;;; @prereq Zp_MachineIndex_u8 and Zp_Current_sMachine_ptr are initialized.
.PROC FuncC_Mermaid_Hut6Organ_Draw
_AirPuff:
    lda Ram_MachineSlowdown_u8_arr + kOrganMachineIndex
    beq @done
    sub #1
    div #2
    add #kTileIdObjMachineOrganFirst
    pha  ; tile ID
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    lda Ram_MachineGoalHorz_u8_arr + kOrganMachineIndex  ; tone
    mul #4
    ora #2  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda Ram_MachineGoalHorz_u8_arr + kOrganMachineIndex  ; tone
    mul #2
    rsub #32  ; param: offset
    jsr FuncA_Objects_MoveShapeUpByA
    ldy #kPaletteObjOrganPuff  ; param: object flags
    pla  ; param: tile ID
    jsr FuncA_Objects_Draw1x1Shape
    @done:
_Indicator:
    lda Ram_MachineStatus_eMachine_arr + kOrganMachineIndex
    cmp #eMachine::Halted
    beq @done
    jsr FuncA_Objects_SetShapePosToMachineTopLeft
    lda Ram_MachineGoalHorz_u8_arr + kOrganMachineIndex  ; tone
    mul #4
    ora #1  ; param: offset
    jsr FuncA_Objects_MoveShapeRightByA
    lda #kTileIdObjCursorDimLeft  ; param: tile ID
    ldy #kPaletteObjMachineLight | bObj::FlipH | bObj::Pri  ; param: obj flags
    jsr FuncA_Objects_Draw1x1Shape
    @done:
_MachineLight:
    jmp FuncA_Objects_DrawPumpMachine
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_MermaidHut6Trombone_InitReset
    lda #kTromboneInitGoalX
    sta Ram_MachineGoalHorz_u8_arr + kTromboneMachineIndex
    rts
.ENDPROC

.PROC FuncA_Room_MermaidHut6Drums_InitReset
    lda #kDrumsInitGoalY
    sta Ram_MachineGoalVert_u8_arr + kDrumsMachineIndex
    rts
.ENDPROC

.PROC FuncA_Room_MermaidHut6Organ_InitReset
    lda #2
    sta Ram_MachineGoalHorz_u8_arr + kOrganMachineIndex
    rts
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Machine"

.PROC FuncA_Machine_MermaidHut6Trombone_TryMove
    lda #9  ; param: max goal horz
    jmp FuncA_Machine_GenericTryMoveX
.ENDPROC

.PROC FuncA_Machine_MermaidHut6Trombone_TryAct
    lda #9
    sub Ram_MachineGoalHorz_u8_arr + kTromboneMachineIndex  ; param: tone
    jsr FuncA_Machine_PlaySfxTrombone
    lda #$0b
    sta Ram_MachineSlowdown_u8_arr + kTromboneMachineIndex
    lda #$10
    jmp FuncA_Machine_StartWaiting
.ENDPROC

.PROC FuncA_Machine_MermaidHut6Trombone_Tick
    ;; Calculate the desired X-position for the left edge of the slide
    ;; platform, in room-space pixels, storing it in Zp_PointX_i16.
    lda Ram_MachineGoalHorz_u8_arr + kTromboneMachineIndex
    mul #kTromboneSlideStep
    adc #<kTromboneSlideMinPlatformLeft  ; carry is already clear from mul
    sta Zp_PointX_i16 + 0
    lda #0
    adc #>kTromboneSlideMinPlatformLeft  ; carry is already clear from mul
    sta Zp_PointX_i16 + 1
    ;; Move the trombone slide horizontally, as necessary.
    jsr FuncA_Machine_GetGenericMoveSpeed  ; returns A (param: max move delta)
    ldx #kTromboneSlidePlatformIndex  ; param: platform index
    jsr Func_MovePlatformLeftTowardPointX  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncA_Machine_MermaidHut6Drums_TryMove
    lda #1  ; param: max vertical goal
    jsr FuncA_Machine_GenericTryMoveY
    ;; If trying to move resulted in an error, we're done.
    lda Ram_MachineStatus_eMachine_arr + kDrumsMachineIndex
    cmp #eMachine::Error
    beq @done
    ;; If we moved down successfully, play a hi-hat sound.
    lda Ram_MachineGoalVert_u8_arr + kDrumsMachineIndex
    bne @noHiHatSound
    jsr FuncA_Machine_PlaySfxHiHat
    @noHiHatSound:
    ;; If we moved up or down successfully, wait a bit.
    lda #$08  ; param: num frames
    jmp FuncA_Machine_StartWaiting
    @done:
    rts
.ENDPROC

.PROC FuncA_Machine_MermaidHut6Drums_TryAct
    lda #eSample::KickDrum  ; param: eSample to play
    jsr Func_PlaySfxSample
    lda #$08
    sta Ram_MachineSlowdown_u8_arr + kDrumsMachineIndex
    mul #2  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

.PROC FuncA_Machine_MermaidHut6Drums_Tick
    ;; Pick the goal position to move the hi-hat towards, and the speed at
    ;; which to move it (either up slowly, or down quickly).
    ldx #kDrumsHiHatMaxPlatformTop - kDrumsHiHatStep  ; upper position
    lda #1  ; param: move speed (slow)
    ldy Ram_MachineGoalVert_u8_arr + kDrumsMachineIndex
    bne @move
    ldx #kDrumsHiHatMaxPlatformTop                    ; lower position
    mul #2  ; param: move speed (fast)
    @move:
    ;; Move the hi-hat platform towards its goal position.
    stx Zp_PointY_i16 + 0
    ldx #0
    stx Zp_PointY_i16 + 1
    ldx #kDrumsHiHatPlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    jeq FuncA_Machine_ReachedGoal
    rts
.ENDPROC

.PROC FuncA_Machine_MermaidHut6Organ_WriteReg
    sta Ram_MachineGoalHorz_u8_arr + kOrganMachineIndex
    rts
.ENDPROC

.PROC FuncA_Machine_MermaidHut6Organ_TryAct
    lda Ram_MachineGoalHorz_u8_arr + kOrganMachineIndex  ; param: tone
    jsr FuncA_Machine_PlaySfxOrgan
    lda #$08
    sta Ram_MachineSlowdown_u8_arr + kOrganMachineIndex
    lda #$10  ; param: num frames
    jmp FuncA_Machine_StartWaiting
.ENDPROC

;;;=========================================================================;;;
