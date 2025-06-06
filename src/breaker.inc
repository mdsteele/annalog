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

;;; The total duration, in frames, of the circuit-tracing mode.
kCircuitTraceFrames = 248

;;; The duration, in frames, of the "slow" part of circuit-tracing mode, before
;;; things speed up at the end.
kCircuitTraceSlowFrames = 160

;;; OBJ tile IDs for drawing energy waves during circuit-tracing mode.
kTileIdObjCircuitWaveFirst = $a0

;;; BG tile IDs for drawing animated circuit conduit terrain.
kTileIdBgAnimCircuitFirst = $5a

;;;=========================================================================;;;
