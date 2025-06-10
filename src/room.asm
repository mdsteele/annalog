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

.INCLUDE "actor.inc"
.INCLUDE "audio.inc"
.INCLUDE "boss.inc"
.INCLUDE "cpu.inc"
.INCLUDE "device.inc"
.INCLUDE "flag.inc"
.INCLUDE "macros.inc"
.INCLUDE "mmc3.inc"
.INCLUDE "music.inc"
.INCLUDE "platform.inc"
.INCLUDE "room.inc"
.INCLUDE "tileset.inc"

.IMPORT DataC_Boss_City_sRoom
.IMPORT DataC_Boss_Crypt_sRoom
.IMPORT DataC_Boss_Garden_sRoom
.IMPORT DataC_Boss_Lava_sRoom
.IMPORT DataC_Boss_Mine_sRoom
.IMPORT DataC_Boss_Shadow_sRoom
.IMPORT DataC_Boss_Temple_sRoom
.IMPORT DataC_City_Building1_sRoom
.IMPORT DataC_City_Building2_sRoom
.IMPORT DataC_City_Building3_sRoom
.IMPORT DataC_City_Building4_sRoom
.IMPORT DataC_City_Building5_sRoom
.IMPORT DataC_City_Building6_sRoom
.IMPORT DataC_City_Building7_sRoom
.IMPORT DataC_City_Center_sRoom
.IMPORT DataC_City_Drain_sRoom
.IMPORT DataC_City_Dump_sRoom
.IMPORT DataC_City_East_sRoom
.IMPORT DataC_City_Flower_sRoom
.IMPORT DataC_City_Outskirts_sRoom
.IMPORT DataC_City_Sinkhole_sRoom
.IMPORT DataC_City_West_sRoom
.IMPORT DataC_Core_Boss_sRoom
.IMPORT DataC_Core_East_sRoom
.IMPORT DataC_Core_Elevator_sRoom
.IMPORT DataC_Core_Flower_sRoom
.IMPORT DataC_Core_Junction_sRoom
.IMPORT DataC_Core_Lock_sRoom
.IMPORT DataC_Core_South_sRoom
.IMPORT DataC_Core_West_sRoom
.IMPORT DataC_Crypt_Center_sRoom
.IMPORT DataC_Crypt_Chains_sRoom
.IMPORT DataC_Crypt_East_sRoom
.IMPORT DataC_Crypt_Escape_sRoom
.IMPORT DataC_Crypt_Flower_sRoom
.IMPORT DataC_Crypt_Gallery_sRoom
.IMPORT DataC_Crypt_Landing_sRoom
.IMPORT DataC_Crypt_Nest_sRoom
.IMPORT DataC_Crypt_North_sRoom
.IMPORT DataC_Crypt_South_sRoom
.IMPORT DataC_Crypt_Spiral_sRoom
.IMPORT DataC_Crypt_Tomb_sRoom
.IMPORT DataC_Crypt_West_sRoom
.IMPORT DataC_Factory_Access_sRoom
.IMPORT DataC_Factory_Bridge_sRoom
.IMPORT DataC_Factory_Center_sRoom
.IMPORT DataC_Factory_East_sRoom
.IMPORT DataC_Factory_Elevator_sRoom
.IMPORT DataC_Factory_Flower_sRoom
.IMPORT DataC_Factory_Lock_sRoom
.IMPORT DataC_Factory_Pass_sRoom
.IMPORT DataC_Factory_Upper_sRoom
.IMPORT DataC_Factory_Vault_sRoom
.IMPORT DataC_Factory_West_sRoom
.IMPORT DataC_Garden_Crossroad_sRoom
.IMPORT DataC_Garden_East_sRoom
.IMPORT DataC_Garden_Flower_sRoom
.IMPORT DataC_Garden_Hallway_sRoom
.IMPORT DataC_Garden_Landing_sRoom
.IMPORT DataC_Garden_Shaft_sRoom
.IMPORT DataC_Garden_Shrine_sRoom
.IMPORT DataC_Garden_Tower_sRoom
.IMPORT DataC_Garden_Tunnel_sRoom
.IMPORT DataC_Lava_Cavern_sRoom
.IMPORT DataC_Lava_Center_sRoom
.IMPORT DataC_Lava_East_sRoom
.IMPORT DataC_Lava_Flower_sRoom
.IMPORT DataC_Lava_Shaft_sRoom
.IMPORT DataC_Lava_Station_sRoom
.IMPORT DataC_Lava_Teleport_sRoom
.IMPORT DataC_Lava_Tunnel_sRoom
.IMPORT DataC_Lava_Vent_sRoom
.IMPORT DataC_Lava_West_sRoom
.IMPORT DataC_Mermaid_Cellar_sRoom
.IMPORT DataC_Mermaid_East_sRoom
.IMPORT DataC_Mermaid_Elevator_sRoom
.IMPORT DataC_Mermaid_Entry_sRoom
.IMPORT DataC_Mermaid_Flower_sRoom
.IMPORT DataC_Mermaid_Hut1_sRoom
.IMPORT DataC_Mermaid_Hut2_sRoom
.IMPORT DataC_Mermaid_Hut3_sRoom
.IMPORT DataC_Mermaid_Hut4_sRoom
.IMPORT DataC_Mermaid_Hut5_sRoom
.IMPORT DataC_Mermaid_Hut6_sRoom
.IMPORT DataC_Mermaid_Spring_sRoom
.IMPORT DataC_Mermaid_Village_sRoom
.IMPORT DataC_Mine_Burrow_sRoom
.IMPORT DataC_Mine_Center_sRoom
.IMPORT DataC_Mine_Collapse_sRoom
.IMPORT DataC_Mine_Drift_sRoom
.IMPORT DataC_Mine_East_sRoom
.IMPORT DataC_Mine_Entry_sRoom
.IMPORT DataC_Mine_Flower_sRoom
.IMPORT DataC_Mine_North_sRoom
.IMPORT DataC_Mine_Pit_sRoom
.IMPORT DataC_Mine_South_sRoom
.IMPORT DataC_Mine_West_sRoom
.IMPORT DataC_Prison_Cell_sRoom
.IMPORT DataC_Prison_Crossroad_sRoom
.IMPORT DataC_Prison_East_sRoom
.IMPORT DataC_Prison_Escape_sRoom
.IMPORT DataC_Prison_Flower_sRoom
.IMPORT DataC_Prison_Lower_sRoom
.IMPORT DataC_Prison_Upper_sRoom
.IMPORT DataC_Sewer_Ascent_sRoom
.IMPORT DataC_Sewer_Basin_sRoom
.IMPORT DataC_Sewer_East_sRoom
.IMPORT DataC_Sewer_Faucet_sRoom
.IMPORT DataC_Sewer_Flower_sRoom
.IMPORT DataC_Sewer_North_sRoom
.IMPORT DataC_Sewer_Pipe_sRoom
.IMPORT DataC_Sewer_Pool_sRoom
.IMPORT DataC_Sewer_South_sRoom
.IMPORT DataC_Sewer_Trap_sRoom
.IMPORT DataC_Sewer_West_sRoom
.IMPORT DataC_Shadow_Depths_sRoom
.IMPORT DataC_Shadow_Descent_sRoom
.IMPORT DataC_Shadow_Drill_sRoom
.IMPORT DataC_Shadow_Entry_sRoom
.IMPORT DataC_Shadow_Flower_sRoom
.IMPORT DataC_Shadow_Gate_sRoom
.IMPORT DataC_Shadow_Hall_sRoom
.IMPORT DataC_Shadow_Heart_sRoom
.IMPORT DataC_Shadow_Office_sRoom
.IMPORT DataC_Shadow_Teleport_sRoom
.IMPORT DataC_Shadow_Trap_sRoom
.IMPORT DataC_Temple_Altar_sRoom
.IMPORT DataC_Temple_Apse_sRoom
.IMPORT DataC_Temple_Chevet_sRoom
.IMPORT DataC_Temple_Entry_sRoom
.IMPORT DataC_Temple_Flower_sRoom
.IMPORT DataC_Temple_Foyer_sRoom
.IMPORT DataC_Temple_Nave_sRoom
.IMPORT DataC_Temple_Pit_sRoom
.IMPORT DataC_Temple_Spire_sRoom
.IMPORT DataC_Temple_West_sRoom
.IMPORT DataC_Town_House1_sRoom
.IMPORT DataC_Town_House2_sRoom
.IMPORT DataC_Town_House3_sRoom
.IMPORT DataC_Town_House4_sRoom
.IMPORT DataC_Town_House5_sRoom
.IMPORT DataC_Town_House6_sRoom
.IMPORT DataC_Town_Outdoors_sRoom
.IMPORT DataC_Town_Sky_sRoom
.IMPORT Data_PowersOfTwo_u8_arr8
.IMPORT FuncA_Room_InitActor
.IMPORT Func_IsFlagSet
.IMPORT Func_ProcessFrame
.IMPORT Ram_ActorPosX_i16_0_arr
.IMPORT Ram_ActorPosX_i16_1_arr
.IMPORT Ram_ActorPosY_i16_0_arr
.IMPORT Ram_ActorPosY_i16_1_arr
.IMPORT Ram_ActorState1_byte_arr
.IMPORT Ram_ActorType_eActor_arr
.IMPORT Ram_DeviceAnim_u8_arr
.IMPORT Ram_DeviceBlockCol_u8_arr
.IMPORT Ram_DeviceBlockRow_u8_arr
.IMPORT Ram_DeviceTarget_byte_arr
.IMPORT Ram_DeviceType_eDevice_arr
.IMPORT Ram_PlatformBottom_i16_0_arr
.IMPORT Ram_PlatformBottom_i16_1_arr
.IMPORT Ram_PlatformLeft_i16_0_arr
.IMPORT Ram_PlatformLeft_i16_1_arr
.IMPORT Ram_PlatformRight_i16_0_arr
.IMPORT Ram_PlatformRight_i16_1_arr
.IMPORT Ram_PlatformTop_i16_0_arr
.IMPORT Ram_PlatformTop_i16_1_arr
.IMPORT Ram_PlatformType_ePlatform_arr
.IMPORT Ram_ProgressFlags_arr
.IMPORTZP Zp_AvatarExit_ePassage
.IMPORTZP Zp_AvatarPlatformIndex_u8
.IMPORTZP Zp_Camera_bScroll
.IMPORTZP Zp_ConsoleMachineIndex_u8
.IMPORTZP Zp_FloatingHud_bHud
.IMPORTZP Zp_Next_sAudioCtrl
.IMPORTZP Zp_RoomShake_u8

;;;=========================================================================;;;

.ZEROPAGE

;;; The room number for the previously-loaded room, or $ff if none.
.EXPORTZP Zp_Previous_eRoom
Zp_Previous_eRoom: .res 1
.ASSERT eRoom::NUM_VALUES <= $ff, error

;;; The room number for the currently-loaded room, or $ff if none.
.EXPORTZP Zp_Current_eRoom
Zp_Current_eRoom: .res 1

;;; Data for the currently-loaded room, if any.  If Zp_Current_eRoom is $ff,
;;; then all of this struct's fields should be considered invalid.
.EXPORTZP Zp_Current_sRoom
Zp_Current_sRoom: .tag sRoom

;;; The currently-loaded tileset.
.EXPORTZP Zp_Current_sTileset
Zp_Current_sTileset: .tag sTileset

;;; A chunk of memory that each room can divvy up however it wants to store
;;; state specific to that room.  These bytes are automatically zeroed just
;;; before a room is loaded, but can be further initialized by room
;;; Enter_func_ptr functions and/or machine Init_func_ptr functions.
.EXPORTZP Zp_RoomState
Zp_RoomState: .res kRoomStateSize

;;;=========================================================================;;;

;;; A bitfield that defines what music should play by default in a given room.
.SCOPE bRoomMusic
    Boss        = %10000000  ; if set, this is a boss room
    Prison      = %01000000  ; if set, this is a Prison area room
    BreakerMask = %00000111  ; bits used for the eBreaker when Boss bit is set
    MusicMask   = %00011111  ; bits used for the eMusic when Boss/Prison unset
.ENDSCOPE
.ASSERT bRoomMusic::BreakerMask + 1 >= eBreaker::NUM_VALUES, error
.ASSERT bRoomMusic::MusicMask + 1 >= eMusic::NUM_VALUES, error

;;;=========================================================================;;;

.SEGMENT "PRG8"

;;; Enables audio and sets the music volume according to the current room's
;;; bRoom::ReduceMusic flag.
.EXPORT Func_SetMusicVolumeForCurrentRoom
.PROC Func_SetMusicVolumeForCurrentRoom
    lda Zp_Current_sRoom + sRoom::Flags_bRoom
    and #bRoom::ReduceMusic
    .assert bRoom::ReduceMusic << 1 = bAudio::ReduceMusic, error
    asl a
    ora #bAudio::Enable
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
    rts
.ENDPROC

;;; Queues up the music for the specified room (if it's not already playing),
;;; switches PRGC banks, then loads and initializes data for the room.
;;; @prereq Rendering is disabled.
;;; @prereq Zp_Current_eRoom and Zp_Current_sRoom are initialized.
;;; @param X The eRoom value for the room to load.
.EXPORT FuncM_SwitchPrgcAndLoadRoom
.PROC FuncM_SwitchPrgcAndLoadRoom
    jsr_prga FuncA_Avatar_ChooseMusicForRoom  ; preserves X, returns Y
    fall FuncM_SwitchPrgcAndLoadRoomWithMusic
.ENDPROC

;;; Queues up the specified music (if it's not already playing), switches PRGC
;;; banks, then loads and initializes data for the specified room.
;;; @prereq Rendering is disabled.
;;; @prereq Zp_Current_eRoom and Zp_Current_sRoom are initialized.
;;; @param X The eRoom value for the room to load.
;;; @param Y The eMusic value for the music to play in the new room.
.EXPORT FuncM_SwitchPrgcAndLoadRoomWithMusic
.PROC FuncM_SwitchPrgcAndLoadRoomWithMusic
    main_prga_bank DataA_Room_Banks_u8_arr
    jsr FuncA_Room_ChangeMusicIfNeeded  ; preserves X
    main_prgc DataA_Room_Banks_u8_arr, x
    jmp FuncA_Room_Load
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Avatar"

;;; Chooses the music that should play in the specified room, based partly on
;;; the current progress flags.  The room does *not* need to be loaded already,
;;; nor its PRGC bank set.
;;; @param X The eRoom value for the room to choose music for.
;;; @return Y The eMusic value for the music to play in the specified room.
;;; @preserve X
.PROC FuncA_Avatar_ChooseMusicForRoom
    lda DataA_Avatar_Music_bRoomMusic_arr, x
    ;; If the bRoomMusic::Boss bit is set, then this is a boss room.
    .assert bRoomMusic::Boss = $80, error
    bmi _BossMusic
    .assert bRoomMusic::Prison = (1 << 6), error
    ;; If the bRoomMusic::Prison bit is set, then this is a prison room.
    bit Data_PowersOfTwo_u8_arr8 + 6
    bne _PrisonMusic
    ;; Otherwise, this room just uses a fixed music.
    and #bRoomMusic::MusicMask
    tay  ; eMusic value
    rts
_BossMusic:
    ;; Check if this boss has been defeated yet.  If not, play the boss music;
    ;; if so, play calm music.
    and #bRoomMusic::BreakerMask
    add #kFirstBossFlag
    stx T0  ; eRoom value
    tax  ; param: eFlag::Boss* value
    jsr Func_IsFlagSet  ; preserves T0+, returns Z
    bne @bossDead
    @bossAlive:
    ldy #eMusic::Boss1
    .assert eMusic::Boss1 < $80, error
    bpl @setMusic  ; unconditional
    @bossDead:
    ldy #eMusic::Calm
    @setMusic:
    ldx T0  ; eRoom value (to preserve X)
    rts
_PrisonMusic:
    ;; Play calm music in the Prison Caves until Anna first escapes; then play
    ;; the prison break music when she returns thereafter.
    ldy #eMusic::Calm
    flag_bit Ram_ProgressFlags_arr, eFlag::GardenLandingDroppedIn
    beq @done
    ldy #eMusic::Prison
    @done:
    rts
.ENDPROC

;;; Maps from eRoom values to the default eMusic to play in each room.
.PROC DataA_Avatar_Music_bRoomMusic_arr
    D_ARRAY .enum, eRoom
    d_byte BossCity,        bRoomMusic::Boss | eBreaker::City
    d_byte BossCrypt,       bRoomMusic::Boss | eBreaker::Crypt
    d_byte BossGarden,      bRoomMusic::Boss | eBreaker::Garden
    d_byte BossLava,        bRoomMusic::Boss | eBreaker::Lava
    d_byte BossMine,        bRoomMusic::Boss | eBreaker::Mine
    d_byte BossShadow,      bRoomMusic::Boss | eBreaker::Shadow
    d_byte BossTemple,      bRoomMusic::Boss | eBreaker::Temple
    d_byte CityBuilding1,   eMusic::City
    d_byte CityBuilding2,   eMusic::City
    d_byte CityBuilding3,   eMusic::City
    d_byte CityBuilding4,   eMusic::City
    d_byte CityBuilding5,   eMusic::City
    d_byte CityBuilding6,   eMusic::City
    d_byte CityBuilding7,   eMusic::City
    d_byte CityCenter,      eMusic::City
    d_byte CityDrain,       eMusic::City
    d_byte CityDump,        eMusic::City
    d_byte CityEast,        eMusic::City
    d_byte CityFlower,      eMusic::City
    d_byte CityOutskirts,   eMusic::City
    d_byte CitySinkhole,    eMusic::City
    d_byte CityWest,        eMusic::City
    d_byte CoreBoss,        eMusic::Suspense
    d_byte CoreEast,        eMusic::Core
    d_byte CoreElevator,    eMusic::Core
    d_byte CoreFlower,      eMusic::Core
    d_byte CoreJunction,    eMusic::Core
    d_byte CoreLock,        eMusic::Core
    d_byte CoreSouth,       eMusic::Core
    d_byte CoreWest,        eMusic::Core
    d_byte CryptCenter,     eMusic::Crypt
    d_byte CryptChains,     eMusic::Crypt
    d_byte CryptEast,       eMusic::Crypt
    d_byte CryptEscape,     eMusic::Crypt
    d_byte CryptFlower,     eMusic::Crypt
    d_byte CryptGallery,    eMusic::Crypt
    d_byte CryptLanding,    eMusic::Crypt
    d_byte CryptNest,       eMusic::Crypt
    d_byte CryptNorth,      eMusic::Crypt
    d_byte CryptSouth,      eMusic::Crypt
    d_byte CryptSpiral,     eMusic::Crypt
    d_byte CryptTomb,       eMusic::Crypt
    d_byte CryptWest,       eMusic::Crypt
    d_byte FactoryAccess,   eMusic::Factory
    d_byte FactoryBridge,   eMusic::Factory
    d_byte FactoryCenter,   eMusic::Factory
    d_byte FactoryEast,     eMusic::Factory
    d_byte FactoryElevator, eMusic::Factory
    d_byte FactoryFlower,   eMusic::Factory
    d_byte FactoryLock,     eMusic::Factory
    d_byte FactoryPass,     eMusic::Factory
    d_byte FactoryUpper,    eMusic::Factory
    d_byte FactoryVault,    eMusic::Suspense
    d_byte FactoryWest,     eMusic::Factory
    d_byte GardenCrossroad, eMusic::Garden
    d_byte GardenEast,      eMusic::Garden
    d_byte GardenFlower,    eMusic::Garden
    d_byte GardenHallway,   eMusic::Garden
    d_byte GardenLanding,   eMusic::Garden
    d_byte GardenShaft,     eMusic::Garden
    d_byte GardenShrine,    eMusic::Garden
    d_byte GardenTower,     eMusic::Garden
    d_byte GardenTunnel,    eMusic::Garden
    d_byte LavaCavern,      eMusic::Lava
    d_byte LavaCenter,      eMusic::Lava
    d_byte LavaEast,        eMusic::Lava
    d_byte LavaFlower,      eMusic::Lava
    d_byte LavaShaft,       eMusic::Lava
    d_byte LavaStation,     eMusic::Lava
    d_byte LavaTeleport,    eMusic::Lava
    d_byte LavaTunnel,      eMusic::Lava
    d_byte LavaVent,        eMusic::Lava
    d_byte LavaWest,        eMusic::Lava
    d_byte MermaidCellar,   eMusic::Florist
    d_byte MermaidEast,     eMusic::Mermaid
    d_byte MermaidElevator, eMusic::Mermaid
    d_byte MermaidEntry,    eMusic::Mermaid
    d_byte MermaidFlower,   eMusic::Mermaid
    d_byte MermaidHut1,     eMusic::Mermaid
    d_byte MermaidHut2,     eMusic::Mermaid
    d_byte MermaidHut3,     eMusic::Mermaid
    d_byte MermaidHut4,     eMusic::Florist
    d_byte MermaidHut5,     eMusic::Mermaid
    d_byte MermaidHut6,     eMusic::Silence
    d_byte MermaidSpring,   eMusic::Mermaid
    d_byte MermaidVillage,  eMusic::Mermaid
    d_byte MineBurrow,      eMusic::Mine
    d_byte MineCenter,      eMusic::Mine
    d_byte MineCollapse,    eMusic::Mine
    d_byte MineDrift,       eMusic::Mine
    d_byte MineEast,        eMusic::Mine
    d_byte MineEntry,       eMusic::Mine
    d_byte MineFlower,      eMusic::Mine
    d_byte MineNorth,       eMusic::Mine
    d_byte MinePit,         eMusic::Mine
    d_byte MineSouth,       eMusic::Mine
    d_byte MineWest,        eMusic::Mine
    d_byte PrisonCell,      bRoomMusic::Prison
    d_byte PrisonCrossroad, bRoomMusic::Prison
    d_byte PrisonEast,      bRoomMusic::Prison
    d_byte PrisonEscape,    bRoomMusic::Prison
    d_byte PrisonFlower,    bRoomMusic::Prison
    d_byte PrisonLower,     bRoomMusic::Prison
    d_byte PrisonUpper,     bRoomMusic::Prison
    d_byte SewerAscent,     eMusic::Sewer
    d_byte SewerBasin,      eMusic::Sewer
    d_byte SewerEast,       eMusic::Sewer
    d_byte SewerFaucet,     eMusic::Sewer
    d_byte SewerFlower,     eMusic::Sewer
    d_byte SewerNorth,      eMusic::Sewer
    d_byte SewerPipe,       eMusic::Sewer
    d_byte SewerPool,       eMusic::Sewer
    d_byte SewerSouth,      eMusic::Sewer
    d_byte SewerTrap,       eMusic::Sewer
    d_byte SewerWest,       eMusic::Sewer
    d_byte ShadowDepths,    eMusic::Shadow
    d_byte ShadowDescent,   eMusic::Shadow
    d_byte ShadowDrill,     eMusic::Shadow
    d_byte ShadowEntry,     eMusic::Shadow
    d_byte ShadowFlower,    eMusic::Shadow
    d_byte ShadowGate,      eMusic::Shadow
    d_byte ShadowHall,      eMusic::Shadow
    d_byte ShadowHeart,     eMusic::Shadow
    d_byte ShadowOffice,    eMusic::Shadow
    d_byte ShadowTeleport,  eMusic::Shadow
    d_byte ShadowTrap,      eMusic::Shadow
    d_byte TempleAltar,     eMusic::Temple
    d_byte TempleApse,      eMusic::Temple
    d_byte TempleChevet,    eMusic::Temple
    d_byte TempleEntry,     eMusic::Temple
    d_byte TempleFlower,    eMusic::Temple
    d_byte TempleFoyer,     eMusic::Temple
    d_byte TempleNave,      eMusic::Temple
    d_byte TemplePit,       eMusic::Temple
    d_byte TempleSpire,     eMusic::Temple
    d_byte TempleWest,      eMusic::Temple
    d_byte TownHouse1,      eMusic::Town
    d_byte TownHouse2,      eMusic::Town
    d_byte TownHouse3,      eMusic::Town
    d_byte TownHouse4,      eMusic::Town
    d_byte TownHouse5,      eMusic::Town
    d_byte TownHouse6,      eMusic::Town
    d_byte TownOutdoors,    eMusic::Town
    d_byte TownSky,         eMusic::Silence
    D_END
.ENDPROC

;;;=========================================================================;;;

.SEGMENT "PRGA_Room"

;;; If the specified music is different than what's currently playing, disables
;;; the audio system (processing an extra frame to do so), then sets up
;;; Zp_Next_sAudioCtrl to re-enable the audio system and play the new music
;;; next frame.
;;; @prereq Rendering is disabled.
;;; @param Y The eMusic value for the music to play in the new room.
;;; @preserve X
.PROC FuncA_Room_ChangeMusicIfNeeded
    cpy Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    beq @done
    lda #0
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
    sty T1  ; eMusic to play
    stx T0
    jsr Func_ProcessFrame  ; preserves T0+
    ldx T0
    lda #bAudio::Enable
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Next_bAudio
    lda T1  ; eMusic to play
    sta Zp_Next_sAudioCtrl + sAudioCtrl::Music_eMusic
    @done:
    rts
.ENDPROC

;;; Pointers and PRGC bank numbers for sRoom structs for all rooms in the game,
;;; indexed by eRoom values.
.REPEAT 3, table
    D_TABLE_LO table, DataA_Room_Table_sRoom_ptr_0_arr
    D_TABLE_HI table, DataA_Room_Table_sRoom_ptr_1_arr
    D_TABLE_BANK table, DataA_Room_Banks_u8_arr
    D_TABLE .enum, eRoom
    d_entry table, BossCity,        DataC_Boss_City_sRoom
    d_entry table, BossCrypt,       DataC_Boss_Crypt_sRoom
    d_entry table, BossGarden,      DataC_Boss_Garden_sRoom
    d_entry table, BossLava,        DataC_Boss_Lava_sRoom
    d_entry table, BossMine,        DataC_Boss_Mine_sRoom
    d_entry table, BossShadow,      DataC_Boss_Shadow_sRoom
    d_entry table, BossTemple,      DataC_Boss_Temple_sRoom
    d_entry table, CityBuilding1,   DataC_City_Building1_sRoom
    d_entry table, CityBuilding2,   DataC_City_Building2_sRoom
    d_entry table, CityBuilding3,   DataC_City_Building3_sRoom
    d_entry table, CityBuilding4,   DataC_City_Building4_sRoom
    d_entry table, CityBuilding5,   DataC_City_Building5_sRoom
    d_entry table, CityBuilding6,   DataC_City_Building6_sRoom
    d_entry table, CityBuilding7,   DataC_City_Building7_sRoom
    d_entry table, CityCenter,      DataC_City_Center_sRoom
    d_entry table, CityDrain,       DataC_City_Drain_sRoom
    d_entry table, CityDump,        DataC_City_Dump_sRoom
    d_entry table, CityEast,        DataC_City_East_sRoom
    d_entry table, CityFlower,      DataC_City_Flower_sRoom
    d_entry table, CityOutskirts,   DataC_City_Outskirts_sRoom
    d_entry table, CitySinkhole,    DataC_City_Sinkhole_sRoom
    d_entry table, CityWest,        DataC_City_West_sRoom
    d_entry table, CoreBoss,        DataC_Core_Boss_sRoom
    d_entry table, CoreEast,        DataC_Core_East_sRoom
    d_entry table, CoreElevator,    DataC_Core_Elevator_sRoom
    d_entry table, CoreFlower,      DataC_Core_Flower_sRoom
    d_entry table, CoreJunction,    DataC_Core_Junction_sRoom
    d_entry table, CoreLock,        DataC_Core_Lock_sRoom
    d_entry table, CoreSouth,       DataC_Core_South_sRoom
    d_entry table, CoreWest,        DataC_Core_West_sRoom
    d_entry table, CryptCenter,     DataC_Crypt_Center_sRoom
    d_entry table, CryptChains,     DataC_Crypt_Chains_sRoom
    d_entry table, CryptEast,       DataC_Crypt_East_sRoom
    d_entry table, CryptEscape,     DataC_Crypt_Escape_sRoom
    d_entry table, CryptFlower,     DataC_Crypt_Flower_sRoom
    d_entry table, CryptGallery,    DataC_Crypt_Gallery_sRoom
    d_entry table, CryptLanding,    DataC_Crypt_Landing_sRoom
    d_entry table, CryptNest,       DataC_Crypt_Nest_sRoom
    d_entry table, CryptNorth,      DataC_Crypt_North_sRoom
    d_entry table, CryptSouth,      DataC_Crypt_South_sRoom
    d_entry table, CryptSpiral,     DataC_Crypt_Spiral_sRoom
    d_entry table, CryptTomb,       DataC_Crypt_Tomb_sRoom
    d_entry table, CryptWest,       DataC_Crypt_West_sRoom
    d_entry table, FactoryAccess,   DataC_Factory_Access_sRoom
    d_entry table, FactoryBridge,   DataC_Factory_Bridge_sRoom
    d_entry table, FactoryCenter,   DataC_Factory_Center_sRoom
    d_entry table, FactoryEast,     DataC_Factory_East_sRoom
    d_entry table, FactoryElevator, DataC_Factory_Elevator_sRoom
    d_entry table, FactoryFlower,   DataC_Factory_Flower_sRoom
    d_entry table, FactoryLock,     DataC_Factory_Lock_sRoom
    d_entry table, FactoryPass,     DataC_Factory_Pass_sRoom
    d_entry table, FactoryUpper,    DataC_Factory_Upper_sRoom
    d_entry table, FactoryVault,    DataC_Factory_Vault_sRoom
    d_entry table, FactoryWest,     DataC_Factory_West_sRoom
    d_entry table, GardenCrossroad, DataC_Garden_Crossroad_sRoom
    d_entry table, GardenEast,      DataC_Garden_East_sRoom
    d_entry table, GardenFlower,    DataC_Garden_Flower_sRoom
    d_entry table, GardenHallway,   DataC_Garden_Hallway_sRoom
    d_entry table, GardenLanding,   DataC_Garden_Landing_sRoom
    d_entry table, GardenShaft,     DataC_Garden_Shaft_sRoom
    d_entry table, GardenShrine,    DataC_Garden_Shrine_sRoom
    d_entry table, GardenTower,     DataC_Garden_Tower_sRoom
    d_entry table, GardenTunnel,    DataC_Garden_Tunnel_sRoom
    d_entry table, LavaCavern,      DataC_Lava_Cavern_sRoom
    d_entry table, LavaCenter,      DataC_Lava_Center_sRoom
    d_entry table, LavaEast,        DataC_Lava_East_sRoom
    d_entry table, LavaFlower,      DataC_Lava_Flower_sRoom
    d_entry table, LavaShaft,       DataC_Lava_Shaft_sRoom
    d_entry table, LavaStation,     DataC_Lava_Station_sRoom
    d_entry table, LavaTeleport,    DataC_Lava_Teleport_sRoom
    d_entry table, LavaTunnel,      DataC_Lava_Tunnel_sRoom
    d_entry table, LavaVent,        DataC_Lava_Vent_sRoom
    d_entry table, LavaWest,        DataC_Lava_West_sRoom
    d_entry table, MermaidCellar,   DataC_Mermaid_Cellar_sRoom
    d_entry table, MermaidEast,     DataC_Mermaid_East_sRoom
    d_entry table, MermaidElevator, DataC_Mermaid_Elevator_sRoom
    d_entry table, MermaidEntry,    DataC_Mermaid_Entry_sRoom
    d_entry table, MermaidFlower,   DataC_Mermaid_Flower_sRoom
    d_entry table, MermaidHut1,     DataC_Mermaid_Hut1_sRoom
    d_entry table, MermaidHut2,     DataC_Mermaid_Hut2_sRoom
    d_entry table, MermaidHut3,     DataC_Mermaid_Hut3_sRoom
    d_entry table, MermaidHut4,     DataC_Mermaid_Hut4_sRoom
    d_entry table, MermaidHut5,     DataC_Mermaid_Hut5_sRoom
    d_entry table, MermaidHut6,     DataC_Mermaid_Hut6_sRoom
    d_entry table, MermaidSpring,   DataC_Mermaid_Spring_sRoom
    d_entry table, MermaidVillage,  DataC_Mermaid_Village_sRoom
    d_entry table, MineBurrow,      DataC_Mine_Burrow_sRoom
    d_entry table, MineCenter,      DataC_Mine_Center_sRoom
    d_entry table, MineCollapse,    DataC_Mine_Collapse_sRoom
    d_entry table, MineDrift,       DataC_Mine_Drift_sRoom
    d_entry table, MineEast,        DataC_Mine_East_sRoom
    d_entry table, MineEntry,       DataC_Mine_Entry_sRoom
    d_entry table, MineFlower,      DataC_Mine_Flower_sRoom
    d_entry table, MineNorth,       DataC_Mine_North_sRoom
    d_entry table, MinePit,         DataC_Mine_Pit_sRoom
    d_entry table, MineSouth,       DataC_Mine_South_sRoom
    d_entry table, MineWest,        DataC_Mine_West_sRoom
    d_entry table, PrisonCell,      DataC_Prison_Cell_sRoom
    d_entry table, PrisonCrossroad, DataC_Prison_Crossroad_sRoom
    d_entry table, PrisonEast,      DataC_Prison_East_sRoom
    d_entry table, PrisonEscape,    DataC_Prison_Escape_sRoom
    d_entry table, PrisonFlower,    DataC_Prison_Flower_sRoom
    d_entry table, PrisonLower,     DataC_Prison_Lower_sRoom
    d_entry table, PrisonUpper,     DataC_Prison_Upper_sRoom
    d_entry table, SewerAscent,     DataC_Sewer_Ascent_sRoom
    d_entry table, SewerBasin,      DataC_Sewer_Basin_sRoom
    d_entry table, SewerEast,       DataC_Sewer_East_sRoom
    d_entry table, SewerFaucet,     DataC_Sewer_Faucet_sRoom
    d_entry table, SewerFlower,     DataC_Sewer_Flower_sRoom
    d_entry table, SewerNorth,      DataC_Sewer_North_sRoom
    d_entry table, SewerPipe,       DataC_Sewer_Pipe_sRoom
    d_entry table, SewerPool,       DataC_Sewer_Pool_sRoom
    d_entry table, SewerSouth,      DataC_Sewer_South_sRoom
    d_entry table, SewerTrap,       DataC_Sewer_Trap_sRoom
    d_entry table, SewerWest,       DataC_Sewer_West_sRoom
    d_entry table, ShadowDepths,    DataC_Shadow_Depths_sRoom
    d_entry table, ShadowDescent,   DataC_Shadow_Descent_sRoom
    d_entry table, ShadowDrill,     DataC_Shadow_Drill_sRoom
    d_entry table, ShadowEntry,     DataC_Shadow_Entry_sRoom
    d_entry table, ShadowFlower,    DataC_Shadow_Flower_sRoom
    d_entry table, ShadowGate,      DataC_Shadow_Gate_sRoom
    d_entry table, ShadowHall,      DataC_Shadow_Hall_sRoom
    d_entry table, ShadowHeart,     DataC_Shadow_Heart_sRoom
    d_entry table, ShadowOffice,    DataC_Shadow_Office_sRoom
    d_entry table, ShadowTeleport,  DataC_Shadow_Teleport_sRoom
    d_entry table, ShadowTrap,      DataC_Shadow_Trap_sRoom
    d_entry table, TempleAltar,     DataC_Temple_Altar_sRoom
    d_entry table, TempleApse,      DataC_Temple_Apse_sRoom
    d_entry table, TempleChevet,    DataC_Temple_Chevet_sRoom
    d_entry table, TempleEntry,     DataC_Temple_Entry_sRoom
    d_entry table, TempleFlower,    DataC_Temple_Flower_sRoom
    d_entry table, TempleFoyer,     DataC_Temple_Foyer_sRoom
    d_entry table, TempleNave,      DataC_Temple_Nave_sRoom
    d_entry table, TemplePit,       DataC_Temple_Pit_sRoom
    d_entry table, TempleSpire,     DataC_Temple_Spire_sRoom
    d_entry table, TempleWest,      DataC_Temple_West_sRoom
    d_entry table, TownHouse1,      DataC_Town_House1_sRoom
    d_entry table, TownHouse2,      DataC_Town_House2_sRoom
    d_entry table, TownHouse3,      DataC_Town_House3_sRoom
    d_entry table, TownHouse4,      DataC_Town_House4_sRoom
    d_entry table, TownHouse5,      DataC_Town_House5_sRoom
    d_entry table, TownHouse6,      DataC_Town_House6_sRoom
    d_entry table, TownOutdoors,    DataC_Town_Outdoors_sRoom
    d_entry table, TownSky,         DataC_Town_Sky_sRoom
    D_END
.ENDREPEAT

;;; Loads and initializes data for the specified room.
;;; @prereq Zp_Current_eRoom and Zp_Current_sRoom are initialized.
;;; @prereq The correct PRGC bank has been set for the new room to be loaded.
;;; @param X The eRoom value for the room to load.
.PROC FuncA_Room_Load
    ldy Zp_Current_eRoom
    sty Zp_Previous_eRoom
    stx Zp_Current_eRoom
    lda #0
    cpy #$ff
    beq @setPrevRoomFlags
    lda Zp_Current_sRoom + sRoom::Flags_bRoom
    @setPrevRoomFlags:
    sta T2  ; previous room's flags
_CopyRoomStruct:
    ;; Get a pointer to the sRoom struct and store it in T1T0.
    lda DataA_Room_Table_sRoom_ptr_0_arr, x
    sta T0
    lda DataA_Room_Table_sRoom_ptr_1_arr, x
    sta T1
    ;; Copy the sRoom struct into Zp_Current_sRoom.
    ldy #.sizeof(sRoom) - 1
    @loop:
    lda (T1T0), y
    sta Zp_Current_sRoom, y
    dey
    .assert .sizeof(sRoom) <= $80, error
    bpl @loop
_CopyTilesetStruct:
    ;; Copy the current room's Terrain_sTileset_ptr into T1T0.
    ldy #sRoomExt::Terrain_sTileset_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    ;; Copy the sTileset struct into Zp_Current_sTileset.
    ldy #.sizeof(sTileset) - 1
    @loop:
    lda (T1T0), y
    sta Zp_Current_sTileset, y
    dey
    .assert .sizeof(sTileset) <= $80, error
    bpl @loop
_ClearRoomState:
    ;; If the previous room and the new room both have the ShareState flag bit
    ;; set, then don't clear Zp_RoomState between those rooms.
    lda Zp_Current_sRoom + sRoom::Flags_bRoom
    and T2  ; previous room's flags
    and #bRoom::ShareState
    bne @done
    ;; Otherwise, zero Zp_RoomState.
    lda #0
    ldx #kRoomStateSize
    @loop:
    dex
    sta Zp_RoomState, x
    bne @loop
    @done:
_LoadPlatforms:
    ;; Copy the current room's Platforms_sPlatform_arr_ptr into T1T0.
    ldy #sRoomExt::Platforms_sPlatform_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    ;; Copy room platform structs into platform RAM.
    ldx #0  ; platform index
    .assert kMaxPlatforms * .sizeof(sPlatform) < $100, error
    ldy #0  ; byte offset into Platforms_sPlatform_arr_ptr
    @copyLoop:
    .assert sPlatform::Type_ePlatform = 0, error
    lda (T1T0), y
    .assert ePlatform::None = 0, error
    beq @copyDone
    sta Ram_PlatformType_ePlatform_arr, x
    iny
    .assert sPlatform::WidthPx_u16 = 1, error
    lda (T1T0), y
    sta T2  ; platform width (lo)
    iny
    lda (T1T0), y
    sta T3  ; platform width (hi)
    iny
    .assert sPlatform::HeightPx_u8 = 3, error
    lda (T1T0), y
    sta T4  ; platform height
    iny
    .assert sPlatform::Left_i16 = 4, error
    lda (T1T0), y
    sta Ram_PlatformLeft_i16_0_arr, x
    add T2  ; platform width (lo)
    sta Ram_PlatformRight_i16_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_PlatformLeft_i16_1_arr, x
    adc T3  ; platform width (hi)
    sta Ram_PlatformRight_i16_1_arr, x
    iny
    .assert sPlatform::Top_i16 = 6, error
    lda (T1T0), y
    sta Ram_PlatformTop_i16_0_arr, x
    add T4  ; platform height
    sta Ram_PlatformBottom_i16_0_arr, x
    iny
    lda (T1T0), y
    sta Ram_PlatformTop_i16_1_arr, x
    adc #0
    sta Ram_PlatformBottom_i16_1_arr, x
    iny
    .assert .sizeof(sPlatform) = 8, error
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in platform RAM.
    @clearLoop:
    sta Ram_PlatformType_ePlatform_arr, x  ; A is already ePlatform::None
    inx
    @copyDone:
    cpx #kMaxPlatforms
    blt @clearLoop
_LoadActors:
    ;; Copy the current room's Actors_sActor_arr_ptr into T1T0.
    ldy #sRoomExt::Actors_sActor_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    ;; Copy room actor structs into actor RAM.
    ldx #0  ; actor index
    .assert kMaxActors * .sizeof(sActor) < $100, error
    ldy #0  ; byte offset into Actors_sActor_arr_ptr
    @copyLoop:
    ;; Actor type:
    .assert sActor::Type_eActor = 0, error
    lda (T1T0), y
    .assert eActor::None = 0, error
    beq @copyDone
    sta Ram_ActorType_eActor_arr, x
    iny
    ;; X-position:
    .assert sActor::PosX_i16 = 1, error
    lda (T1T0), y
    iny
    sta Ram_ActorPosX_i16_0_arr, x
    lda (T1T0), y
    iny
    sta Ram_ActorPosX_i16_1_arr, x
    ;; Y-position:
    .assert sActor::PosY_i16 = 3, error
    lda (T1T0), y
    iny
    sta Ram_ActorPosY_i16_0_arr, x
    lda (T1T0), y
    iny
    sta Ram_ActorPosY_i16_1_arr, x
    ;; Temporarily store param byte in Ram_ActorState1_byte_arr:
    .assert sActor::Param_byte = 5, error
    lda (T1T0), y
    iny
    sta Ram_ActorState1_byte_arr, x
    ;; Continue to next sActor entry.
    .assert .sizeof(sActor) = 6, error
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in actor RAM.
    @clearLoop:
    sta Ram_ActorType_eActor_arr, x  ; A is already eActor::None
    inx
    @copyDone:
    cpx #kMaxActors
    blt @clearLoop
    ;; Call all actor init functions, using the param bytes we stored in
    ;; Ram_ActorState1_byte_arr.
    dex
    @initLoop:
    lda Ram_ActorState1_byte_arr, x
    jsr FuncA_Room_InitActor  ; preserves X
    dex
    .assert kMaxActors < $80, error
    bpl @initLoop
_LoadDevices:
    ;; Copy the current room's Devices_sDevice_arr_ptr into T1T0.
    ldy #sRoomExt::Devices_sDevice_arr_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    ;; Copy room device structs into device RAM.
    ldx #0  ; device index
    .assert kMaxDevices * .sizeof(sDevice) < $100, error
    ldy #0  ; byte offset into Devices_sDevice_arr_ptr
    @copyLoop:
    .assert sDevice::Type_eDevice = 0, error
    lda (T1T0), y
    .assert eDevice::None = 0, error
    beq @copyDone
    sta Ram_DeviceType_eDevice_arr, x
    iny
    .assert sDevice::BlockRow_u8 = 1, error
    lda (T1T0), y
    sta Ram_DeviceBlockRow_u8_arr, x
    iny
    .assert sDevice::BlockCol_u8 = 2, error
    lda (T1T0), y
    sta Ram_DeviceBlockCol_u8_arr, x
    iny
    .assert sDevice::Target_byte = 3, error
    lda (T1T0), y
    sta Ram_DeviceTarget_byte_arr, x
    iny
    .assert .sizeof(sDevice) = 4, error
    lda #0
    sta Ram_DeviceAnim_u8_arr, x
    inx
    bne @copyLoop  ; unconditional
    ;; Clear remaining slots in device RAM.
    @clearLoop:
    sta Ram_DeviceType_eDevice_arr, x  ; A is already eDevice::None
    inx
    @copyDone:
    cpx #kMaxDevices
    blt @clearLoop
_SetVars:
    ldx #0
    .assert ePassage::None = 0, error
    stx Zp_AvatarExit_ePassage
    stx Zp_Camera_bScroll
    stx Zp_RoomShake_u8
    dex  ; now X is $ff
    stx Zp_AvatarPlatformIndex_u8
    stx Zp_ConsoleMachineIndex_u8
    stx Zp_FloatingHud_bHud  ; disable the floating HUD
    jmp Func_SetMusicVolumeForCurrentRoom
.ENDPROC

;;; Calls the current room's Tick_func_ptr function.
.EXPORT FuncA_Room_CallRoomTick
.PROC FuncA_Room_CallRoomTick
    ldy #sRoomExt::Tick_func_ptr
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T0
    iny
    lda (Zp_Current_sRoom + sRoom::Ext_sRoomExt_ptr), y
    sta T1
    jmp (T1T0)
.ENDPROC

;;;=========================================================================;;;
