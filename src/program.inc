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

;;; The maximum number of instructions in a program.
.DEFINE kMaxProgramLength 16

;;;=========================================================================;;;

;;; Opcode values for program instructions.
.ENUM eOpcode
    Empty = $0  ; (no args)        Jumps to program start (in zero cycles).
    Copy  = $1  ; r, r/i           Sets register to value of second arg.
    Sync  = $2  ; (no args)        Pauses until all machines are at a SYNC
    Add   = $3  ; r, r/i, r/i      Sets register to sum of other args.
    Sub   = $4  ; r, r/i, r/i      Sets register to difference of other args.
    Mul   = $5  ; r, r/i, r/i      Sets register to product of other args.
    Goto  = $6  ; addr             Jumps to an absolute address (0-15).
    Skip  = $7  ; r/i              Skips next N instructions.
    If    = $8  ; oper, r/i, r/i   Skips next instruction if false.
    Til   = $9  ; oper, r/i, r/i   Jumps to prev instruction if false.
    Act   = $a  ; (no args)        Performs machine action (e.g. firing gun).
    Move  = $b  ; dir              Moves machine in the specified direction.
    Rest  = $c  ; r/i              Pauses for N * 16 frames.
    Beep  = $d  ; r/i              Plays a sound with one of ten pitches.
    End   = $e  ; (no args)        Halts the program.
    Nop   = $f  ; (no args)        Does nothing (but still takes a cycle).
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; Types of fields that can appear in written program instructions.
.ENUM eField
    Erase      ; used for the erase-program menu (not really a field type)
    Debug      ; used for the debug menu (not really a field type)
    Opcode     ; the instruction's opcode
    LValue     ; a writable register
    RValue     ; an immediate value (0-9) or readable register
    Address    ; an instruction number (for GOTO instructions)
    Compare    ; a comparison operator (for IF and TIL instructions)
    Direction  ; a cardinal direction (for MOVE instructions)
    NUM_VALUES
.ENDENUM

;;; eField values less than this represent special menus for things that aren't
;;; really instruction fields.
kFirstRealFieldType = eField::Opcode

;;; Comparison operators that can be used in IF and TIL instructions.
.ENUM eCmp
    Eq  ; equal
    Ne  ; not equal
    Lt  ; less than
    Le  ; less than or equal
    Gt  ; greater than
    Ge  ; greater than or equal
    NUM_VALUES
.ENDENUM

;;; Directions that can be used in MOVE instructions.
.ENUM eDir
    Up
    Right
    Down
    Left
    NUM_VALUES
.ENDENUM

;;; Options that can be selected on the debug menu.
.ENUM eDebug
    StartDebugger
    EraseProgram
    Cancel
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;

;;; One instruction in a program for an in-game machine.
.STRUCT sIns
    ;; The low nibble stores the second argument (if any), and the high nibble
    ;; stores the third argument (if any).
    Arg_byte .byte
    ;; The high nibble stores an eOpcode, and the low nibble stores the first
    ;; argument (if any).
    Op_byte  .byte
.ENDSTRUCT

;;; A program for an in-game machine.
.STRUCT sProgram
    ;; The instructions in the program.  The length of the program is the index
    ;; of the first eOpcode::Empty instruction if any, or kMaxProgramLength
    ;; otherwise.
    Code_sIns_arr .res .sizeof(sIns) * kMaxProgramLength
.ENDSTRUCT

;;;=========================================================================;;;

;;; The list of programs in the save file.  Each machine in the game uses one
;;; of these programs, although in a few cases, multiple machines may share the
;;; same program (e.g. jet machines).
.ENUM eProgram
    ;; @begin SORTED
    BossCityAmmoRack
    BossCityLauncher
    BossCityReloader
    BossCryptWinch
    BossGardenCannon
    BossLavaBlaster
    BossLavaBoiler
    BossMineCrane
    BossMineTrolley
    BossShadowEmitterX
    BossShadowEmitterY
    BossTempleMinigun
    CityBuilding3AmmoRack
    CityBuilding3Launcher
    CityBuilding3Reloader
    CityCenterSemaphore1
    CityCenterSemaphore2
    CityCenterSemaphore3
    CityCenterSemaphore4
    CityOutskirtsLauncher
    CitySinkholeLift
    CoreBossBlaster
    CoreBossCannon
    CoreBossLaser
    CoreBossWinch
    CoreElevatorJet
    CoreLockLift1
    CoreLockLift2
    CoreLockLift3
    CryptFlowerWinch
    CryptGalleryWinch
    CryptNorthLift
    CryptNorthWinch
    CryptSouthWinch
    CryptTombWinch
    CryptWestWinch
    FactoryAccessRotor
    FactoryFlowerLowerRotor
    FactoryFlowerUpperRotor
    FactoryLockLift
    FactoryUpperRotor
    FactoryWestCrane
    GardenCrossroadLift
    GardenEastBridge
    GardenEastCannon
    GardenHallwayLift
    GardenShaftLowerBridge
    GardenShaftUpperBridge
    GardenTowerCannon
    LavaCavernBoiler
    LavaCenterBlaster
    LavaEastBlaster
    LavaEastLowerBoiler
    LavaEastUpperBoiler
    LavaStationBoiler
    LavaTeleportField
    LavaTunnelBoiler
    LavaVentLift
    LavaWestBoiler
    MermaidElevatorJet
    MermaidHut6Drums
    MermaidHut6Organ
    MermaidHut6Trombone
    MermaidSpringPump
    MineCollapseCrane
    MineCollapseTrolley
    MineEastHoist
    MineEastLift
    MineFlowerHoistEast
    MineFlowerHoistWest
    MineNorthConveyor
    MineNorthHoist
    MinePitHoistEast
    MinePitHoistWest
    MineSouthHoist
    MineSouthTrolley
    MineWestCrane
    PrisonCellLauncher
    PrisonCellLift
    PrisonEastLift
    PrisonEscapeTrolley
    SewerBasinMultiplexer
    SewerFlowerPump
    SewerNorthMultiplexer
    SewerSouthMultiplexer
    SewerTrapLift
    SewerWestMultiplexer
    ShadowDrillLaser
    ShadowEntryLift
    ShadowFlowerLaser
    ShadowHallMinigun
    ShadowHeartEmitterX
    ShadowHeartEmitterY
    ShadowOfficeLift
    ShadowTeleportField
    ShadowTrapLaser
    TempleAltarLowerMinigun
    TempleAltarUpperMinigun
    TempleFoyerCarriage
    TempleNaveLowerCarriage
    TempleNaveUpperCarriage
    ;; @end SORTED
    NUM_VALUES
.ENDENUM

;;;=========================================================================;;;
