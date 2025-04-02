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

;;; The maximum number of actors that can exist at once in a room.
kMaxActors = 16

;;;=========================================================================;;;

;;; Types of actors in a room (e.g. baddies, NPCs, projectiles, or smoke).
.ENUM eActor
    None
    ;; @begin SORTED
    BadBat           ; flies up and down or back and forth
    BadBeetleHorz    ; crawls around a platform
    BadBeetleVert    ; crawls around a platform
    BadBird          ; flies horizontally when it can hit the player avatar
    BadCrab          ; moves left/right randomly on a floor
    BadFirefly       ; flies up and down, and shoots horizontally
    BadFish          ; swims back and forth in water
    BadFlower        ; grows and shoots fireballs
    BadFlydrop       ; flies left/right randomly, and drops acid
    BadGhostMermaid  ; part of the shadow boss
    BadGhostOrc      ; part of the shadow boss
    BadGooGreen      ; squishes in place
    BadGooRed        ; squishes back and forth
    BadGronta        ; the final boss
    BadGrub          ; crawls left/right on a floor
    BadGrubFire      ; like grub, but can also shoot at you
    BadHotheadHorz   ; crawls around a platform, and can drop fire
    BadHotheadVert   ; crawls around a platform, and can drop fire
    BadJelly         ; moves in a straight line, turning when it hits a wall
    BadLavaball      ; jumps out of lava
    BadOrc           ; chases after player avatar
    BadRhino         ; walks back and forth, and charges at the player avatar
    BadRodent        ; runs in/out of mouseholes and along walls
    BadSlime         ; crawls back and forth on ceiling, and drops spikes
    BadSolifuge      ; chases avatar on floor and by jumping
    BadSpider        ; crawls randomly on ceiling, and drops down on a thread
    BadToad          ; jumps in place
    BadVinebug       ; moves vertically on a vine
    BadWasp          ; flies in a circle
    NpcAdult         ; used for human adults and for most mermaids
    NpcBlinky        ; a blinkenlight in the Core area
    NpcChild         ; used for human children
    NpcDuck          ; used for the ducks in SewerPool
    NpcOrc           ; used for orcs, and Queen Eirene when she's standing
    NpcOrcSleeping   ; used for an orc that's unconscious on the ground
    NpcQueen         ; used for Queen Eirene when she's seated
    NpcSquare        ; used for hiding part of another actor
    NpcToddler       ; used for baby Nina
    ProjAcid         ; acid dropped by a flydrop baddie
    ProjAxeBoomer    ; a boomerang axe thrown by Gronta
    ProjAxeSmash     ; a machine-smashing axe thrown by Gronta
    ProjBreakball    ; a bouncing ball shot by the temple boss
    ProjBreakbomb    ; a falling bomb shot by the city boss
    ProjBreakfire    ; sweeps out horizontally from an exploding breakball
    ProjBullet       ; shot by minigun machines
    ProjEgg          ; dropped by the lava boss; hatches into a BadSolifuge
    ProjEmber        ; fire dropped by a hothead baddie
    ProjFireball     ; shot by various bosses
    ProjFireblast    ; shot by firefly baddies and blaster machines
    ProjFlamestrike  ; shot by lava boss; comes down, then sweeps sideways
    ProjFood         ; food for the ducks
    ProjGrenade      ; shot by cannon machines
    ProjRocket       ; shot by launcher machines
    ProjSpike        ; a falling spike dropped by the garden boss
    ProjSpine        ; a spine shot by the city boss
    ProjSteamHorz    ; emitted horizontally from boiler machine pipes
    ProjSteamUp      ; emitted vertically from boiler machine pipes
    SmokeAxe         ; an axe thrown by Gronta in a cutscene
    SmokeBeam        ; a core beam in one of the finale cutscenes
    SmokeBlood       ; a glob of blood from the temple boss
    SmokeDirt        ; a clump of dirt from the mine boss
    SmokeExplosion   ; a puff of smoke for when something explodes
    SmokeFragment    ; a fragment that falls under gravity
    SmokeParticle    ; a single particle of smoke
    SmokeRaindrop    ; a falling drop of water
    SmokeSteamHorz   ; like ProjSteamHorz, but without any physics interactions
    SmokeSteamUp     ; like ProjSteamUp, but without any physics interactions
    SmokeWaterfall   ; pours out of a water pipe
    ;; @end SORTED
    NUM_VALUES
.ENDENUM

;;; eActor values less than this can be statically initialized by a room's
;;; sRoomExt::Actors_sActor_arr_ptr array.  eActor values greater than or equal
;;; to this can only be initialized dynamically, by calling some appropriate
;;; initialization function, which may well be in a different PRGA bank than
;;; PRGA_Room.
kFirstNonStaticActorType = eActor::ProjAcid

;;; eActor values greater than or equal to this are "smoke" actors; that is,
;;; they are decorative animations that don't affect game physics.
kFirstSmokeActorType = eActor::SmokeAxe

;;;=========================================================================;;;

;;; Static information about a particular actor instance in a room.  This is
;;; used for static baddies and NPCs, but not for projectiles (which are
;;; generally spawned dynamically).
.STRUCT sActor
    ;; The type of this actor.
    Type_eActor .byte
    ;; The room pixel X-position for the center of the actor.
    PosX_i16    .word
    ;; The room pixel Y-position for the center of the actor.
    PosY_i16    .word
    ;; Type-specific initialization parameter.  Refer to the documentation in
    ;; the relevant src/actors/*.inc file for how this is interpreted for a
    ;; given actor type.
    Param_byte  .byte
.ENDSTRUCT

;;;=========================================================================;;;
