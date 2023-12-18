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
    BadBat           ; flies up and down or back and forth
    BadBeetleHorz    ; crawls around a platform
    BadBeetleVert    ; crawls around a platform
    BadBird          ; flies horizontally when it can hit the player avatar
    BadCrab          ; moves left/right randomly on a floor
    BadFirefly       ; flies up and down, and shoots horizontally
    BadFish          ; swims back and forth in water
    BadFlydrop       ; flies left/right randomly, and drops acid
    BadGrub          ; crawls left/right on a floor
    BadHotheadHorz   ; crawls around a platform, and can drop fire
    BadHotheadVert   ; crawls around a platform, and can drop fire
    BadJelly         ; moves in a straight line, turning when it hits a wall
    BadLavaball      ; jumps out of lava
    BadOrc           ; chases after player avatar
    BadRhino         ; walks back and forth, and charges at the player avatar
    BadRodent        ; runs in/out of mouseholes and along walls
    BadSpider        ; crawls randomly on ceiling, and drops down on a thread
    BadToad          ; jumps in place
    BadVinebug       ; moves vertically on a vine
    BadWasp          ; flies in a circle
    NpcAdult
    NpcChild
    NpcMermaid
    NpcMermaidQueen
    NpcOrc
    NpcToddler
    ProjAcid         ; acid dropped by a flydrop baddie
    ProjBreakball    ; a bouncing ball shot by the temple boss
    ProjBreakbomb    ; a falling bomb shot by the city boss
    ProjBreakfire    ; sweeps out horizontally from an exploding breakball
    ProjBullet       ; shot by minigun machines
    ProjEmber        ; fire dropped by a hothead baddie
    ProjFireball     ; shot by various bosses
    ProjFireblast    ; shot by firefly baddies and blaster machines
    ProjFlamestrike  ; shot by lava boss; comes down, then sweeps sideways
    ProjGrenade      ; shot by cannon machines
    ProjRocket       ; shot by launcher machines
    ProjSpike        ; a falling spike dropped by the garden boss
    ProjSpine        ; a spine shot by the city boss
    ProjSteamHorz    ; emitted horizontally from boiler machine pipes
    ProjSteamUp      ; emitted vertically from boiler machine pipes
    SmokeExplosion   ; a puff of smoke for when something explodes
    SmokeFragment    ; a fragment that falls under gravity
    SmokeParticle    ; a single particle of smoke
    NUM_VALUES
.ENDENUM

;;; eActor values greater than or equal to this are "smoke" actors; that is,
;;; they are decorative animations that don't affect game physics.
kFirstSmokeActorType = eActor::SmokeExplosion

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
    ;; Type-specific initialization parameter.
    ;;   * For BadBeetle*, this is the actor flip flags to set.
    ;;   * For BadBird, this is a bBadBird value.
    ;;   * For BadHothead*, this is the actor flip flags to set.
    ;;   * For NpcAdult, this is the first tile ID (of six).
    ;;   * For NpcChild, this is a bNpcChild value.
    ;;   * For NpcMermaid, this is the first tile ID (of six).
    ;;   * For NpcToddler, this is a bNpcToddler value.
    ;;   * For all other baddies and NPCs, this is ignored.
    Param_byte  .byte
.ENDSTRUCT

;;;=========================================================================;;;
