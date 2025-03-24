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

;;; The height of a "tall" room, in blocks.  A "short" room is
;;; kScreenHeightBlocks = 15 blocks tall, fitting vertically in the first
;;; nametable.  A "tall" room extends into the top portion of the second
;;; nametable by (kTallRoomHeightBlocks - kScreenHeightBlocks) = 9 blocks.
kTallRoomHeightBlocks = 24

kTallRoomHeightTiles = kTallRoomHeightBlocks * 2

;;; Some parts of the code assume that a room tile column fits in one byte.
;;; This puts the maximum width of a room at 8 screens, which is plenty wide.
kMaxRoomWidthTiles = $100
kMaxRoomWidthBlocks = kMaxRoomWidthTiles / 2

;;; How many bytes of RAM are reserved for room-specific state.
kRoomStateSize = 24

;;; The maximum number of passages a room can have.
kMaxPassages = 8

;;;=========================================================================;;;

;;; The list of rooms in the game.
.ENUM eRoom
    ;; @begin SORTED
    BossCity
    BossCrypt
    BossGarden
    BossLava
    BossMine
    BossShadow
    BossTemple
    CityBuilding1
    CityBuilding2
    CityBuilding3
    CityBuilding4
    CityBuilding5
    CityBuilding6
    CityBuilding7
    CityCenter
    CityDrain
    CityDump
    CityEast
    CityFlower
    CityOutskirts
    CitySinkhole
    CityWest
    CoreBoss
    CoreEast
    CoreElevator
    CoreFlower
    CoreJunction
    CoreLock
    CoreSouth
    CoreWest
    CryptCenter
    CryptChains
    CryptEast
    CryptEscape
    CryptFlower
    CryptGallery
    CryptLanding
    CryptNest
    CryptNorth
    CryptSouth
    CryptSpiral
    CryptTomb
    CryptWest
    FactoryAccess
    FactoryBridge
    FactoryCenter
    FactoryEast
    FactoryElevator
    FactoryFlower
    FactoryLock
    FactoryPass
    FactoryUpper
    FactoryVault
    FactoryWest
    GardenCrossroad
    GardenEast
    GardenFlower
    GardenHallway
    GardenLanding
    GardenShaft
    GardenShrine
    GardenTower
    GardenTunnel
    LavaCavern
    LavaCenter
    LavaEast
    LavaFlower
    LavaShaft
    LavaStation
    LavaTeleport
    LavaTunnel
    LavaVent
    LavaWest
    MermaidCellar
    MermaidEast
    MermaidElevator
    MermaidEntry
    MermaidFlower
    MermaidHut1
    MermaidHut2
    MermaidHut3
    MermaidHut4
    MermaidHut5
    MermaidHut6
    MermaidSpring
    MermaidVillage
    MineCenter
    MineCollapse
    MineDrift
    MineEast
    MineEntry
    MineFlower
    MineNorth
    MinePit
    MineSouth
    MineTunnel
    MineWest
    PrisonCell
    PrisonCrossroad
    PrisonEast
    PrisonEscape
    PrisonFlower
    PrisonLower
    PrisonUpper
    SewerAscent
    SewerBasin
    SewerEast
    SewerFaucet
    SewerFlower
    SewerNorth
    SewerPipe
    SewerPool
    SewerSouth
    SewerTrap
    SewerWest
    ShadowDepths
    ShadowDescent
    ShadowDrill
    ShadowEntry
    ShadowFlower
    ShadowGate
    ShadowHall
    ShadowHeart
    ShadowOffice
    ShadowTeleport
    ShadowTrap
    TempleAltar
    TempleApse
    TempleChevet
    TempleEntry
    TempleFlower
    TempleFoyer
    TempleNave
    TemplePit
    TempleSpire
    TempleWest
    TownHouse1
    TownHouse2
    TownHouse3
    TownHouse4
    TownHouse5
    TownHouse6
    TownOutdoors
    TownSky
    ;; @end SORTED
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; The list of areas in the game.
.ENUM eArea
    ;; @begin SORTED
    City
    Core
    Crypt
    Factory
    Garden
    Lava
    Mermaid
    Mine
    Prison
    Sewer
    Shadow
    Temple
    Town
    ;; @end SORTED
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Flag bits for a room.
.SCOPE bRoom
    ;; When set, passages and devices in this room won't be set as safe spawn
    ;; points.  This can be dynamically disabled for a room (e.g. when a boss
    ;; is defeated) by calling Func_MarkRoomSafe.
    Unsafe      = %10000000
    ;; If set, this room's terrain is kTallRoomHeightBlocks blocks tall instead
    ;; of kScreenHeightBlocks blocks tall.
    Tall        = %01000000
    ;; If set, music is played at a reduced volume in this room.
    ReduceMusic = %00100000
    ;; If two rooms both have this bit set, then Zp_RoomState will not be
    ;; zeroed by default when moving directly between those two rooms.
    ShareState  = %00010000
    ;; Bits used for storing this room's eArea value.
    AreaMask    = %00001111
.ENDSCOPE

;;; Assert that an eArea value will fit into the AreaMask.
.ASSERT eArea::NUM_VALUES <= bRoom::AreaMask + 1, error

;;;=========================================================================;;;

;;; Specifies which side of the room a given passage is on.
.ENUM ePassage
    None       = 0
    Top        = %01000000
    Bottom     = %01100000
    Western    = %10000000
    Eastern    = %10100000
.ENDENUM

;;; Specifies a particular passage exit from a room.  The three highest bits
;;; specify the side of the room the passage is on (as an ePassage value), and
;;; the three lowest bits specify which screen of the room the passage is on:
;;;     * For east/west passages in short rooms, the screen number is 0.
;;;     * For east/west passages in tall rooms, the screen number is 0 for the
;;;       top half of the room, or 1 for the bottom half.
;;;     * For up/down passages, the screen number is 0 for the westernmost
;;;       screen of the room, and (N - 1) for the easternmost screen of a room
;;;       that's N screens wide.
;;; When the player avatar exits a room via a passage, the game will look for a
;;; matching passage in the destination room for the avatar to enter via.
;;; Normally, the game will pick the first (presumably only) passage leading
;;; back to the room the avatar came from.  However, if the SameScreen bit is
;;; set, then the two passages must have the same screen number in order to
;;; match.  This is to allow two adjacent and vertically-aligned tall rooms to
;;; share two horizontal passages between each other.
.SCOPE bPassage
    EastWest   = %10000000  ; if set, this is an east/west passage
    UpDown     = %01000000  ; if set, this is an up/down passage
    SideMask   = %11100000  ; bits used for the ePassage value
    SameScreen = %00001000  ; if set, destination must have same screen number
    ScreenMask = %00000111  ; bits used for the screen number
.ENDSCOPE

;;; Stores attributes for a particular passage exit from a room.
.STRUCT sPassage
    ;; Where in the room the exit is (which side and which screen number).
    Exit_bPassage      .byte
    ;; The room number that this passage leads to.
    Destination_eRoom  .byte
    ;; Indicates the position of the passage along the side of the room, for
    ;; lining up connected passages in different rooms.  For east/west
    ;; passages, this must be the room block row index of the bottom-most empty
    ;; block in the passage (i.e. it's the block row that the player avatar
    ;; will spawn in).  For up/down passages, this should be the room block
    ;; column index for the center block of the passage (or right-of-center, if
    ;; the passage is an even number of blocks wide).
    SpawnBlock_u8      .byte
    ;; Specifies a position adjustment to apply to the player avatar when
    ;; spawning at this passage (but not when travelling through the passage).
    ;;     * For east/west passages, this field is ignored.
    ;;     * For up/down passages, bits 4-7 (the top four bits) are a signed
    ;;       horizontal offset, measured in tiles; and bit 3 indicates whether
    ;;       the avatar should face right (0) or left (1).
    ;;     * For top passages, bits 0-2 (the bottom three bits) are an unsigned
    ;;       downward ofset, measured in blocks; for bottom passages, those
    ;;       bits are an unsigned *upward* offset, measured in blocks.  In
    ;;       either case, if these bits are zero, the avatar will start out
    ;;       airborne; otherwise, it's assumed that the avatar is standing on
    ;;       solid ground.
    SpawnAdjust_byte   .byte
.ENDSTRUCT

;;;=========================================================================;;;

;;; Stores basic information about a single room.
.STRUCT sRoom
    ;; The minimum permitted scroll X-coordinate, in pixels.
    ;;     * If the room has no passages on the western edge, this should be 0.
    ;;     * If the room does have a western passage, this should generally be
    ;;       either 8 or 16.
    MinScrollX_u8             .byte
    ;; The maximum permitted scroll X-coordinate, in pixels.  If the terrain
    ;; data is N blocks wide, then:
    ;;     * If the room has no passages on the eastern edge, this should be
    ;;       equal to (N - kScreenWidthBlocks) * kBlockWidthPx.
    ;;     * If the room does have an eastern passage, this should be equal to
    ;;       (N - kScreenWidthBlocks - 1) * kBlockWidthPx, so that the last
    ;;       terrain column will be hidden offscreen.
    MaxScrollX_u16            .word
    ;; Flag bits for this room.  If bRoom::Tall is set, the room is "tall"
    ;; (kTallRoomHeightBlocks blocks tall); if cleared the room is short
    ;; (kScreenHeightBlocks blocks tall).
    Flags_bRoom               .byte
    ;; The minimap row number for the room (if it's a short room) or for the
    ;; top half of the room (if it's a tall room).
    MinimapStartRow_u8        .byte
    ;; The minimap column number for the leftmost screen of the room.
    MinimapStartCol_u8        .byte
    ;; A pointer to the terrain block data for this room, which stores 1 byte
    ;; per block in column-major order.  For "short" rooms, new columns start
    ;; every 15 bytes; for "tall" rooms, new columns start every 24 bytes.
    TerrainData_ptr           .addr
    ;; The number of entries in the Machines_sMachine_arr_ptr array.  This must
    ;; be no greater than kMaxMachines.
    NumMachines_u8            .byte
    ;; A pointer to the machine data array for this room.
    Machines_sMachine_arr_ptr .addr
    ;; The default CHR18 bank number to set for this room.  The room's
    ;; Enter_func_ptr can modify this in Zp_Current_sRoom to override the
    ;; default.
    Chr18Bank_u8              .byte
    ;; Extended information about the room.
    Ext_sRoomExt_ptr          .addr
.ENDSTRUCT

;;; Extended information about a room that (compared to the information in
;;; sRoom) doesn't need to be as directly accessible from Zp_Current_sRoom.
.STRUCT sRoomExt
    ;; A pointer to the tileset used for this room's terrain.
    Terrain_sTileset_ptr        .addr
    ;; A pointer to a static array of platforms that should always be loaded
    ;; into the room upon entering, terminated by an ePlatform::None byte.  The
    ;; dynamic set of platforms can optionally be modified afterwards by the
    ;; room's Enter_func_ptr.
    Platforms_sPlatform_arr_ptr .addr
    ;; A pointer to a static array of actors that should always be loaded into
    ;; the room upon entering, terminated by an eActor::None byte.  The dynamic
    ;; set of actors can optionally be modified afterwards by the room's
    ;; Enter_func_ptr.
    Actors_sActor_arr_ptr       .addr
    ;; A pointer to a static array of devices that should always be loaded into
    ;; the room upon entering, terminated by an eDevice::None byte.  The
    ;; dynamic set of devices can optionally be modified afterwards by the
    ;; room's Enter_func_ptr.
    Devices_sDevice_arr_ptr     .addr
    ;; A pointer to the list of passage exits from this room.
    Passages_sPassage_arr_ptr   .addr
    ;; Function to initialize room-specific state (after the player avatar has
    ;; been spawned into the room, and after any machines in the room have been
    ;; initialized, but before the nametables have been populated with the
    ;; room's terrain).
    ;; @prereq PRGA_Room is loaded.
    ;; @prereq Static room data is loaded and avatar is positioned.
    ;; @param A The bSpawn value for where the avatar is entering the room.
    Enter_func_ptr              .addr
    ;; Function to update BG nametables just before fading in the room,
    ;; e.g. when first entering the room or when unpausing while in the room.
    ;; @prereq PRGA_Terrain is loaded.
    ;; @prereq Rendering is disabled.
    ;; @prereq Room is loaded and avatar is positioned.
    FadeIn_func_ptr             .addr
    ;; Function to call each frame to update room state.
    ;; @prereq PRGA_Room is loaded.
    Tick_func_ptr               .addr
    ;; Function to call each frame to draw room-specific objects that aren't
    ;; covered by machines/actors (e.g. bosses or special platforms).  This can
    ;; also set up IRQs for the room.
    ;; @prereq PRGA_Objects is loaded.
    Draw_func_ptr               .addr
.ENDSTRUCT

;;;=========================================================================;;;
