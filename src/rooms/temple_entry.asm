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
.INCLUDE "../actors/townsfolk.inc"
.INCLUDE "../avatar.inc"
.INCLUDE "../charmap.inc"
.INCLUDE "../cpu.inc"
.INCLUDE "../cutscene.inc"
.INCLUDE "../device.inc"
.INCLUDE "../dialog.inc"
.INCLUDE "../flag.inc"
.INCLUDE "../macros.inc"
.INCLUDE "../oam.inc"
.INCLUDE "../platform.inc"
.INCLUDE "../ppu.inc"
.INCLUDE "../room.inc"

.IMPORT DataA_Room_Temple_sTileset
.IMPORT FuncA_Dialog_AddQuestMarker
.IMPORT FuncC_Temple_DrawColumnPlatform
.IMPORT Func_IsPointInPlatform
.IMPORT Func_MovePlatformTopTowardPointY
.IMPORT Func_Noop
.IMPORT Func_SetFlag
.IMPORT Func_SetPointToAvatarCenter
.IMPORT Func_ShakeRoom
.IMPORT Ppu_ChrObjTemple
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Sram_ProgressFlags_arr
.IMPORTZP Zp_AvatarState_bAvatar
.IMPORTZP Zp_DialogAnsweredYes_bool
.IMPORTZP Zp_Next_eCutscene
.IMPORTZP Zp_PointY_i16
.IMPORTZP Zp_RoomState

;;;=========================================================================;;;

;;; The actor index for the mermaid guard in this room.
kGuardActorIndex = 0
;;; The talk devices indices for the mermaid guard in this room.
kGuardDeviceIndexLeft = 1
kGuardDeviceIndexRight = 0

;;; The actor index for Corra in this room.
kCorraActorIndex = 1
;;; The talk devices indices for Corra in this room.
kCorraDeviceIndexLeft = 3
kCorraDeviceIndexRight = 2

;;; The platform index for the zone where Corra asks you to wait up.
kWaitUpZonePlatformIndex = 0

;;; The platform index for the movable column in this room.
kColumnPlatformIndex = 1

;;; The minimum and maximum Y-positions for the top of the movable column
;;; platform.
kColumnPlatformMinTop = $140
kColumnPlatformMaxTop = $160

;;; How many frames it takes for the movable column to move one pixel.
kColumnPlatformSlowdown = 3

;;; How much to shake the room (each frame) when the movable column moves.
kColumnShakeFrames = 10

;;; Various OBJ tile IDs used for drawing the movable column.
kTileIdObjColumnFirst  = $9a
kTileIdObjColumnCorner = kTileIdObjColumnFirst + 0
kTileIdObjColumnSide   = kTileIdObjColumnFirst + 1

;;;=========================================================================;;;

;;; Defines room-specific state data for this particular room.
.STRUCT sState
    ;; How many more frames before the movable column can move another pixel.
    ColumnSlowdown_u8 .byte
.ENDSTRUCT
.ASSERT .sizeof(sState) <= kRoomStateSize, error

;;;=========================================================================;;;

.SEGMENT "PRGC_Temple"

.EXPORT DataC_Temple_Entry_sRoom
.PROC DataC_Temple_Entry_sRoom
    D_STRUCT sRoom
    d_byte MinScrollX_u8, $08
    d_word MaxScrollX_u16, $0008
    d_byte Flags_bRoom, bRoom::Tall | eArea::Temple
    d_byte MinimapStartRow_u8, 7
    d_byte MinimapStartCol_u8, 5
    d_addr TerrainData_ptr, _TerrainData
    d_byte NumMachines_u8, 0
    d_addr Machines_sMachine_arr_ptr, 0
    d_byte Chr18Bank_u8, <.bank(Ppu_ChrObjTemple)
    d_addr Ext_sRoomExt_ptr, _Ext_sRoomExt
    D_END
_Ext_sRoomExt:
    D_STRUCT sRoomExt
    d_addr Terrain_sTileset_ptr, DataA_Room_Temple_sTileset
    d_addr Platforms_sPlatform_arr_ptr, _Platforms_sPlatform_arr
    d_addr Actors_sActor_arr_ptr, _Actors_sActor_arr
    d_addr Devices_sDevice_arr_ptr, _Devices_sDevice_arr
    d_addr Passages_sPassage_arr_ptr, _Passages_sPassage_arr
    d_addr Enter_func_ptr, FuncA_Room_TempleEntry_EnterRoom
    d_addr FadeIn_func_ptr, Func_Noop
    d_addr Tick_func_ptr, FuncA_Room_TempleEntry_TickRoom
    d_addr Draw_func_ptr, FuncC_Temple_Entry_DrawRoom
    D_END
_TerrainData:
:   .incbin "out/rooms/temple_entry.room"
    .assert * - :- = 18 * 24, error
_Platforms_sPlatform_arr:
:   .assert * - :- = kWaitUpZonePlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Zone
    d_word WidthPx_u16, $40
    d_byte HeightPx_u8, $10
    d_word Left_i16,  $00e0
    d_word Top_i16,   $0130
    D_END
    .assert * - :- = kColumnPlatformIndex * .sizeof(sPlatform), error
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $30
    d_word Left_i16,  $0040
    d_word Top_i16, kColumnPlatformMaxTop
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Solid
    d_word WidthPx_u16, $10
    d_byte HeightPx_u8, $08
    d_word Left_i16,  $00b0
    d_word Top_i16,   $0168
    D_END
    D_STRUCT sPlatform
    d_byte Type_ePlatform, ePlatform::Water
    d_word WidthPx_u16, $c0
    d_byte HeightPx_u8, $20
    d_word Left_i16,  $0030
    d_word Top_i16,   $0154
    D_END
    .assert * - :- <= kMaxPlatforms * .sizeof(sPlatform), error
    .byte ePlatform::None
_Actors_sActor_arr:
:   .assert * - :- = kGuardActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $0070
    d_word PosY_i16, $0158
    d_byte Param_byte, kTileIdMermaidGuardFFirst
    D_END
    .assert * - :- = kCorraActorIndex * .sizeof(sActor), error
    D_STRUCT sActor
    d_byte Type_eActor, eActor::NpcMermaid
    d_word PosX_i16, $00b0
    d_word PosY_i16, $0158
    d_byte Param_byte, kTileIdMermaidCorraFirst
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleVert
    d_word PosX_i16, $00a8
    d_word PosY_i16, $0098
    d_byte Param_byte, bObj::FlipV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadBeetleHorz
    d_word PosX_i16, $00d0
    d_word PosY_i16, $00c8
    d_byte Param_byte, bObj::FlipHV
    D_END
    D_STRUCT sActor
    d_byte Type_eActor, eActor::BadToad
    d_word PosX_i16, $0080
    d_word PosY_i16, $0100
    d_byte Param_byte, 0
    D_END
    .assert * - :- <= kMaxActors * .sizeof(sActor), error
    .byte eActor::None
_Devices_sDevice_arr:
:   .assert * - :- = kGuardDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 6
    d_byte Target_byte, eDialog::TempleEntryGuard
    D_END
    .assert * - :- = kGuardDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 7
    d_byte Target_byte, eDialog::TempleEntryGuard
    D_END
    .assert * - :- = kCorraDeviceIndexRight * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkRight
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 10
    d_byte Target_byte, eDialog::TempleEntryCorraHi
    D_END
    .assert * - :- = kCorraDeviceIndexLeft * .sizeof(sDevice), error
    D_STRUCT sDevice
    d_byte Type_eDevice, eDevice::TalkLeft
    d_byte BlockRow_u8, 21
    d_byte BlockCol_u8, 11
    d_byte Target_byte, eDialog::TempleEntryCorraHi
    D_END
    .assert * - :- <= kMaxDevices * .sizeof(sDevice), error
    .byte eDevice::None
_Passages_sPassage_arr:
:   D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Western | 0
    d_byte Destination_eRoom, eRoom::TempleFoyer
    d_byte SpawnBlock_u8, 6
    D_END
    D_STRUCT sPassage
    d_byte Exit_bPassage, ePassage::Eastern | 1
    d_byte Destination_eRoom, eRoom::GardenHallway
    d_byte SpawnBlock_u8, 19
    D_END
    .assert * - :- <= kMaxPassages * .sizeof(sPassage), error
.ENDPROC

;;; Draw function for the TempleEntry room.
;;; @prereq PRGA_Objects is loaded.
.PROC FuncC_Temple_Entry_DrawRoom
    ldx #kColumnPlatformIndex  ; param: platform index
    jmp FuncC_Temple_DrawColumnPlatform
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

.PROC FuncA_Room_TempleEntry_EnterRoom
_MaybeRemoveCorra:
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerCrypt
    beq @removeCorra
    flag_bit Sram_ProgressFlags_arr, eFlag::CityOutskirtsTalkedToAlex
    beq @keepCorra
    @removeCorra:
    lda #0
    .assert eActor::None = 0, error
    sta Ram_ActorType_eActor_arr + kCorraActorIndex
    .assert eDevice::None = 0, error
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kCorraDeviceIndexRight
    @keepCorra:
_MaybeRemoveGuard:
    ;; If the temple breaker has been activated, then remove the mermaid guard
    ;; from this room, and mark the column as raised (although normally, you
    ;; can't reach the breaker without first raising the column).
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerTemple
    beq @done
    lda #eActor::None
    sta Ram_ActorType_eActor_arr + kGuardActorIndex
    .assert eDevice::None = eActor::None, error
    sta Ram_DeviceType_eDevice_arr + kGuardDeviceIndexLeft
    sta Ram_DeviceType_eDevice_arr + kGuardDeviceIndexRight
    ldx #eFlag::TempleEntryColumnRaised  ; param: flag
    jsr Func_SetFlag
    @done:
_MaybeRaiseColumn:
    ;; If the column has been raised before, raise it.
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryColumnRaised
    beq @done
    lda #<kColumnPlatformMinTop
    sta Ram_PlatformTop_i16_0_arr + kColumnPlatformIndex
    lda #>kColumnPlatformMinTop
    sta Ram_PlatformTop_i16_1_arr + kColumnPlatformIndex
    @done:
    rts
.ENDPROC

.PROC FuncA_Room_TempleEntry_TickRoom
_StartCutscene:
    ;; If Corra isn't here, or if Anna has already talked to Corra, don't start
    ;; the cutscene.
    flag_bit Sram_ProgressFlags_arr, eFlag::BreakerCrypt
    beq @done  ; Corra isn't here yet
    flag_bit Sram_ProgressFlags_arr, eFlag::CityOutskirtsTalkedToAlex
    bne @done  ; Corra is no longer here
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryTalkedToCorra
    bne @done
    ;; If the player avatar isn't standing in the cutscene-starting zone, don't
    ;; start it yet.
    bit Zp_AvatarState_bAvatar
    .assert bAvatar::Airborne = bProc::Negative, error
    bmi @done
    jsr Func_SetPointToAvatarCenter
    ldy #kWaitUpZonePlatformIndex  ; param: platform index
    jsr Func_IsPointInPlatform  ; returns C
    bcc @done
    ;; Start the cutscene.
    lda #eCutscene::TempleEntryWaitUp
    sta Zp_Next_eCutscene
    @done:
_MoveColumn:
    ;; If the column-raised flag is set, move the column upward towards its
    ;; highest position.
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryColumnRaised
    beq @done
    ;; Move the column by one pixel every kColumnPlatformSlowdown frames.
    lda Zp_RoomState + sState::ColumnSlowdown_u8
    bne @slowdown
    lda #kColumnPlatformSlowdown
    sta Zp_RoomState + sState::ColumnSlowdown_u8
    ldax #kColumnPlatformMinTop
    stax Zp_PointY_i16
    lda #1  ; param: move speed
    ldx #kColumnPlatformIndex  ; param: platform index
    jsr Func_MovePlatformTopTowardPointY  ; returns Z
    beq @done
    lda #kColumnShakeFrames  ; param: num frames
    jmp Func_ShakeRoom
    @slowdown:
    dec Zp_RoomState + sState::ColumnSlowdown_u8
    @done:
    rts
.ENDPROC
;;;=========================================================================;;;

.SEGMENT "PRGA_Cutscene"

.EXPORT DataA_Cutscene_TempleEntryWaitUp_sCutscene
.PROC DataA_Cutscene_TempleEntryWaitUp_sCutscene
    act_SetAvatarState 0
    act_SetAvatarVelX 0
    act_SetAvatarPose eAvatar::Standing
    act_RunDialog eDialog::TempleEntryCorraWait
    act_WalkAvatar $00e6
    act_SetAvatarFlags kPaletteObjAvatarNormal | bObj::FlipH
    act_SetAvatarPose eAvatar::Standing
    act_WaitFrames 30
    act_RunDialog eDialog::TempleEntryCorraHi
    act_ContinueExploring
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Dialog"

.EXPORT DataA_Dialog_TempleEntryCorraWait_sDialog
.PROC DataA_Dialog_TempleEntryCorraWait_sDialog
    dlg_Text MermaidCorra, DataA_Text2_TempleEntryCorra_Wait_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TempleEntryCorraHi_sDialog
.PROC DataA_Dialog_TempleEntryCorraHi_sDialog
    dlg_Func @func
    @func:
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryTalkedToCorra
    bne @alexAsked
    @question:
    ldya #_Question_sDialog
    rts
    @alexAsked:
    ldya #_AlexAsked_sDialog
    rts
_Question_sDialog:
    dlg_Text MermaidCorra, DataA_Text2_TempleEntryCorra_Question_u8_arr
    dlg_Func @func
    @func:
    bit Zp_DialogAnsweredYes_bool
    bmi @yes
    @no:
    ldya #_NoAnswer_sDialog
    rts
    @yes:
    ldya #_YesAnswer_sDialog
    rts
_NoAnswer_sDialog:
    dlg_Text MermaidCorra, DataA_Text2_TempleEntryCorra_No_u8_arr
    dlg_Text MermaidCorra, DataA_Text2_TempleEntryCorra_Taught_u8_arr
    dlg_Func @func
    @func:
    ldya #_AlexAsked_sDialog
    rts
_YesAnswer_sDialog:
    dlg_Text MermaidCorra, DataA_Text2_TempleEntryCorra_Yes_u8_arr
    dlg_Text MermaidCorra, DataA_Text2_TempleEntryCorra_Whom_u8_arr
_AlexAsked_sDialog:
    dlg_Text MermaidCorra, DataA_Text2_TempleEntryCorra_AlexAsked_u8_arr
    dlg_Func @func
    @func:
    ldx #eFlag::TempleEntryTalkedToCorra  ; param: flag
    jsr FuncA_Dialog_AddQuestMarker
    ldya #_MarkMap_sDialog
    rts
_MarkMap_sDialog:
    dlg_Text MermaidCorra, DataA_Text2_TempleEntryCorra_MarkMap_u8_arr
    dlg_Done
.ENDPROC

.EXPORT DataA_Dialog_TempleEntryGuard_sDialog
.PROC DataA_Dialog_TempleEntryGuard_sDialog
    dlg_Text MermaidGuardF, DataA_Text2_TempleEntryGuard_Intro_u8_arr
    dlg_Func _CheckPermissionFunc
_CheckPermissionFunc:
    flag_bit Sram_ProgressFlags_arr, eFlag::TempleEntryPermission
    bne _RaiseColumnFunc
    ldya #_NoPermission_sDialog
    rts
_NoPermission_sDialog:
    dlg_Text MermaidGuardF, DataA_Text2_TempleEntryGuard_NoPermission_u8_arr
    dlg_Done
_RaiseColumnFunc:
    ldx #eFlag::TempleEntryColumnRaised  ; param: flag
    jsr Func_SetFlag
    ldya #_Enter_sDialog
    rts
_Enter_sDialog:
    dlg_Text MermaidGuardF, DataA_Text2_TempleEntryGuard_Enter_u8_arr
    dlg_Done
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Text2"

.PROC DataA_Text2_TempleEntryCorra_Wait_u8_arr
    .byte "Hey Anna, wait up!#"
.ENDPROC

.PROC DataA_Text2_TempleEntryCorra_Question_u8_arr
    .byte "Hi! Did you come to$"
    .byte "the temple to pray?%"
.ENDPROC

.PROC DataA_Text2_TempleEntryCorra_Yes_u8_arr
    .byte "Me too! I was taught$"
    .byte "to pray always for$"
    .byte "peace. I didn't think$"
    .byte "humans did that.#"
.ENDPROC

.PROC DataA_Text2_TempleEntryCorra_Whom_u8_arr
    .byte "I'm not sure whom I'm$"
    .byte "praying to, though.$"
    .byte "...I guess they never$"
    .byte "taught me that.#"
.ENDPROC

.PROC DataA_Text2_TempleEntryCorra_No_u8_arr
    .byte "Oh, right...humans$"
    .byte "never evolved to seek$"
    .byte "after peace, like we$"
    .byte "did...#"
.ENDPROC

.PROC DataA_Text2_TempleEntryCorra_Taught_u8_arr
    .byte "Er, at least, that's$"
    .byte "what I was taught.#"
.ENDPROC

.PROC DataA_Text2_TempleEntryCorra_AlexAsked_u8_arr
    .byte "Oh, I almost forgot!$"
    .byte "Alex asked me to tell$"
    .byte "you where to find him$"
    .byte "if I saw you.#"
.ENDPROC

.PROC DataA_Text2_TempleEntryCorra_MarkMap_u8_arr
    .byte "Here, I'll just mark$"
    .byte "it on your map.#"
.ENDPROC

.PROC DataA_Text2_TempleEntryGuard_Intro_u8_arr
    .byte "I am guarding the$"
    .byte "entrance to the temple$"
    .byte "you see above us.#"
.ENDPROC

.PROC DataA_Text2_TempleEntryGuard_NoPermission_u8_arr
    .byte "I cannot help you to$"
    .byte "enter it without the$"
    .byte "queen's permission.#"
.ENDPROC

.PROC DataA_Text2_TempleEntryGuard_Enter_u8_arr
    .byte "Our queen has sent$"
    .byte "word: I am to allow$"
    .byte "you to enter.#"
.ENDPROC

;;;=========================================================================;;;
