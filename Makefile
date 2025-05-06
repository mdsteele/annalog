#=============================================================================#
# Copyright 2022 Matthew D. Steele <mdsteele@alum.mit.edu>                    #
#                                                                             #
# This file is part of Annalog.                                               #
#                                                                             #
# Annalog is free software: you can redistribute it and/or modify it under    #
# the terms of the GNU General Public License as published by the Free        #
# Software Foundation, either version 3 of the License, or (at your option)   #
# any later version.                                                          #
#                                                                             #
# Annalog is distributed in the hope that it will be useful, but WITHOUT ANY  #
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS   #
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more      #
# details.                                                                    #
#                                                                             #
# You should have received a copy of the GNU General Public License along     #
# with Annalog.  If not, see <http://www.gnu.org/licenses/>.                  #
#=============================================================================#

ROMNAME = annalog

OUTDIR = out
OBJDIR = $(OUTDIR)/obj
BUILD_OUT_DIR = $(OUTDIR)/build
DATA_OUT_DIR = $(OUTDIR)/data
DM_OUT_DIR = $(OUTDIR)/samples
LIB_OUT_DIR = $(OUTDIR)/lib
MUSIC_OUT_DIR = $(OUTDIR)/music
PCM_OUT_DIR = $(OUTDIR)/pcm
ROOM_OUT_DIR = $(OUTDIR)/rooms
SIM65_OUT_DIR = $(OUTDIR)/sim65
TEXT_OUT_DIR = $(OUTDIR)/text
TILE_OUT_DIR = $(OUTDIR)/tiles
TSET_OUT_DIR = $(OUTDIR)/tilesets

AHI2CHR = $(BUILD_OUT_DIR)/ahi2chr
BG2MAP = $(BUILD_OUT_DIR)/bg2map
BG2ROOM = $(BUILD_OUT_DIR)/bg2room
BG2TSET = $(BUILD_OUT_DIR)/bg2tset
LABEL2NL = $(BUILD_OUT_DIR)/label2nl
SNG2ASM = $(BUILD_OUT_DIR)/sng2asm
WAV2DM = $(BUILD_OUT_DIR)/wav2dm
WAV2PCM = $(BUILD_OUT_DIR)/wav2pcm

INC_FILES := $(shell find src -name '*.inc' | sort)

INST_WAV_FILES := $(shell find src/samples -name 'inst_*.wav' | sort)
INST_DM_FILES := \
  $(patsubst src/samples/%.wav,$(DM_OUT_DIR)/%.dm,$(INST_WAV_FILES))
SFX_WAV_FILES := $(shell find src/samples -name 'sfx_*.wav' | sort)
SFX_DM_FILES := \
  $(patsubst src/samples/%.wav,$(DM_OUT_DIR)/%.dm,$(SFX_WAV_FILES))
PCM_WAV_FILES := $(shell find src/pcm -name '*.wav' | sort)
PCM_FILES := $(patsubst src/pcm/%.wav,$(PCM_OUT_DIR)/%.pcm,$(PCM_WAV_FILES))

MUSIC_SNG_FILES := $(shell find src/music -name '*.sng' | sort)
MUSIC_ASM_FILES := \
  $(patsubst src/music/%.sng,$(MUSIC_OUT_DIR)/%.asm,$(MUSIC_SNG_FILES))
MUSIC_OBJ_FILES := \
  $(patsubst $(MUSIC_OUT_DIR)/%.asm,$(MUSIC_OUT_DIR)/%.o,$(MUSIC_ASM_FILES))
MUSIC_LIB_FILE = $(LIB_OUT_DIR)/music.lib

ROOM_ASM_FILES := $(shell find src/rooms -name '*.asm' | sort)
ROOM_OBJ_FILES := \
  $(patsubst src/rooms/%.asm,$(OBJDIR)/rooms/%.o,$(ROOM_ASM_FILES))
ROOM_BG_FILES := $(shell find src/rooms -name '*.bg' | sort)
ROOM_ROOM_FILES := \
  $(patsubst src/rooms/%.bg,$(ROOM_OUT_DIR)/%.room,$(ROOM_BG_FILES))
ROOM_LIB_FILE = $(LIB_OUT_DIR)/rooms.lib

TEXT_TXT_FILES := $(shell find src/text -name '*.txt' | sort)
TEXT_ASM_FILES := \
  $(patsubst src/text/%.txt,$(TEXT_OUT_DIR)/%.asm,$(TEXT_TXT_FILES))
TEXT_OBJ_FILES := \
  $(patsubst $(TEXT_OUT_DIR)/%.asm,$(TEXT_OUT_DIR)/%.o,$(TEXT_ASM_FILES))
TEXT_LIB_FILE = $(LIB_OUT_DIR)/text.lib

TILE_AHI_FILES := $(shell find src/tiles -name '*.ahi' | sort)
TILE_CHR_FILES := \
  $(patsubst src/tiles/%.ahi,$(TILE_OUT_DIR)/%.chr,$(TILE_AHI_FILES))

TSET_BG_FILES := $(shell find src/tilesets -name '*.bg' | sort)
TSET_ASM_FILES := \
  $(patsubst src/tilesets/%.bg,$(TSET_OUT_DIR)/%.asm,$(TSET_BG_FILES))
TSET_OBJ_FILES := \
  $(patsubst $(TSET_OUT_DIR)/%.asm,$(TSET_OUT_DIR)/%.o,$(TSET_ASM_FILES))
TSET_LIB_FILE = $(LIB_OUT_DIR)/tilesets.lib

ROM_ASM_FILES := \
  $(shell find src -name rooms -prune -false -or -name '*.asm' | sort)
ROM_OBJ_FILES := $(patsubst src/%.asm,$(OBJDIR)/%.o,$(ROM_ASM_FILES))
ROM_CFG_FILE = src/linker.cfg
ROM_LABEL_FILE = $(OUTDIR)/$(ROMNAME).labels.txt
ROM_MAP_FILE = $(OUTDIR)/$(ROMNAME)-nes-map.txt
ROM_BIN_FILE = $(OUTDIR)/$(ROMNAME).nes

NSF_CFG_FILE = nsf/nsf.cfg
NSF_OBJ_FILES := $(OUTDIR)/nsf/nsf.o \
  $(OBJDIR)/audio.o $(OBJDIR)/inst.o $(OBJDIR)/music.o $(OBJDIR)/null.o
NSF_MAP_FILE = $(OUTDIR)/$(ROMNAME)-nsf-map.txt
NSF_BIN_FILE = $(OUTDIR)/$(ROMNAME).nsf

SIM65_ASM_FILES := $(shell find tests -name '*.asm' | sort)
SIM65_CFG_FILES := $(shell find tests -name '*.cfg' | sort)
SIM65_OBJ_FILES := \
  $(patsubst tests/%.asm,$(SIM65_OUT_DIR)/%.o,$(SIM65_ASM_FILES))
SIM65_BIN_FILES := \
  $(patsubst tests/%.cfg,$(SIM65_OUT_DIR)/%,$(SIM65_CFG_FILES))

CFLAGS = -std=c99 -pedantic -Wall -Werror

VERSION_FILE = $(OUTDIR)/version
GIT_REV := $(shell git describe 2>/dev/null || git rev-parse --short HEAD)

#=============================================================================#

define compile-asm
	@echo "Assembling $<"
	@mkdir -p $(@D)
	@ca65 --target nes -W1 --debug-info -o $@ $<
endef

define compile-c-obj
	@echo "Compiling $<"
	@mkdir -p $(@D)
	@cc $(CFLAGS) -o $@ -c $<
endef

define compile-c-bin
	@echo "Compiling $<"
	@mkdir -p $(@D)
	@cc $(CFLAGS) -o $@ $^ -lm
endef

define update-archive
	@echo "Updating $@"
	@mkdir -p $(@D)
	@ar65 r $@ $?
endef

#=============================================================================#
# Phony targets:

.PHONY: all
all: $(ROM_BIN_FILE) $(NSF_BIN_FILE)

.PHONY: run
run: $(ROM_BIN_FILE) $(ROM_BIN_FILE).ram.nl $(ROM_BIN_FILE).3.nl
	fceux $< > /dev/null

.PHONY: listen
listen: $(NSF_BIN_FILE)
	open -a 'Audio Overload' $<

.PHONY: test
test: $(SIM65_BIN_FILES)
	python3 tests/lint.py
	@for BIN in $^; do echo sim65 $$BIN; sim65 $$BIN || exit 1; done
	python3 tests/scenario.py
	python3 tests/style.py

.PHONY: clean
clean:
	rm -rf $(OUTDIR)

#=============================================================================#
# Build tools:

$(BUILD_OUT_DIR)/util.o: build/util.c build/util.h
	$(compile-c-obj)

$(AHI2CHR): build/ahi2chr.c $(BUILD_OUT_DIR)/util.o
	$(compile-c-bin)

$(BG2MAP): build/bg2map.c $(BUILD_OUT_DIR)/util.o
	$(compile-c-bin)

$(BG2ROOM): build/bg2room.c $(BUILD_OUT_DIR)/util.o
	$(compile-c-bin)

$(BG2TSET): build/bg2tset.c $(BUILD_OUT_DIR)/util.o
	$(compile-c-bin)

$(LABEL2NL): build/label2nl.c
	$(compile-c-bin)

$(SNG2ASM): build/sng2asm.c $(BUILD_OUT_DIR)/util.o
	$(compile-c-bin)

$(WAV2DM): build/wav2dm.c
	$(compile-c-bin)

$(WAV2PCM): build/wav2pcm.c
	$(compile-c-bin)

#=============================================================================#
# Generated files:

$(TILE_OUT_DIR)/%.chr: src/tiles/%.ahi $(AHI2CHR)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(AHI2CHR) < $< > $@
.SECONDARY: $(TILE_CHR_FILES)

$(DATA_OUT_DIR)/minimap.map: src/minimap.bg $(BG2MAP)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(BG2MAP) < $< > $@
.SECONDARY: $(DATA_OUT_DIR)/minimap.map

$(DATA_OUT_DIR)/title.map: src/title.bg $(BG2MAP)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(BG2MAP) < $< > $@
.SECONDARY: $(DATA_OUT_DIR)/title.map

$(ROOM_OUT_DIR)/%.room: src/rooms/%.bg $(BG2ROOM)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(BG2ROOM) < $< > $@
.SECONDARY: $(ROOM_ROOM_FILES)

$(MUSIC_OUT_DIR)/%.asm: src/music/%.sng $(SNG2ASM)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@$(SNG2ASM) < $< > $@
.SECONDARY: $(MUSIC_ASM_FILES)

$(TEXT_OUT_DIR)/%.asm: src/text/%.txt build/text2asm.py
	@echo "Generating $@"
	@mkdir -p $(@D)
	@python3 build/text2asm.py $< > $@
.SECONDARY: $(TEXT_ASM_FILES)

$(TSET_OUT_DIR)/%.asm: src/tilesets/%.bg $(BG2TSET) $(TILE_AHI_FILES)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@mkdir -p $(OUTDIR)/blocks
	@$(BG2TSET) $* < $< > $@
.SECONDARY: $(TSET_ASM_FILES)

$(DM_OUT_DIR)/%.dm: src/samples/%.wav $(WAV2DM)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(WAV2DM) < $< > $@
.SECONDARY: $(INST_DM_FILES) $(SFX_DM_FILES)

$(PCM_OUT_DIR)/%.pcm: src/pcm/%.wav $(WAV2PCM)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(WAV2PCM) < $< > $@
.SECONDARY: $(PCM_FILES)

$(ROM_BIN_FILE).ram.nl: $(ROM_LABEL_FILE) $(LABEL2NL)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@$(LABEL2NL) 0000 07ff < $< > $@

$(ROM_BIN_FILE).3.nl: $(ROM_LABEL_FILE) $(LABEL2NL)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@$(LABEL2NL) 8000 9fff c000 ffff < $< > $@

FORCE:
$(VERSION_FILE): FORCE
	@mkdir -p $(@D)
	@touch -a $@
	@(printf '.byte "%s"\n' "$(GIT_REV)" | diff $@ - >/dev/null) || \
	    (echo "Updating $@" && printf '.byte "%s"\n' "$(GIT_REV)" > $@)

#=============================================================================#
# ASM tests:

$(SIM65_OUT_DIR)/%.o: tests/%.asm $(INC_FILES)
	@echo "Assembling $<"
	@mkdir -p $(@D)
	@ca65 --target sim6502 -o $@ $<
.SECONDARY: $(SIM65_OBJ_FILES)

$(SIM65_OUT_DIR)/%: \
  tests/%.cfg $(SIM65_OUT_DIR)/%.o $(OBJDIR)/%.o \
  $(SIM65_OUT_DIR)/sim65.o $(OBJDIR)/null.o
	@echo "Linking $@"
	@mkdir -p $(@D)
	@ld65 -o $@ -C $^

#=============================================================================#
# OBJ files:

$(OBJDIR)/chr.o: src/chr.asm $(INC_FILES) $(TILE_CHR_FILES)
	$(compile-asm)

$(OBJDIR)/credits.o: src/credits.asm $(INC_FILES) $(VERSION_FILE)
	$(compile-asm)

$(OBJDIR)/inst.o: src/inst.asm $(INC_FILES) $(INST_DM_FILES)
	$(compile-asm)

$(OBJDIR)/minimap.o: src/minimap.asm $(INC_FILES) $(DATA_OUT_DIR)/minimap.map
	$(compile-asm)

$(OBJDIR)/pcm.o: src/pcm.asm $(INC_FILES) $(PCM_FILES)
	$(compile-asm)

$(OBJDIR)/sample.o: src/sample.asm $(INC_FILES) $(SFX_DM_FILES)
	$(compile-asm)

$(OBJDIR)/title.o: src/title.asm $(INC_FILES) $(DATA_OUT_DIR)/title.map
	$(compile-asm)

$(OBJDIR)/rooms/city_building1.o: \
  src/rooms/city_building1.asm $(INC_FILES) \
  $(ROOM_OUT_DIR)/city_building1.room $(ROOM_OUT_DIR)/city_building2.room \
  $(ROOM_OUT_DIR)/city_building3.room $(ROOM_OUT_DIR)/city_building4.room \
  $(ROOM_OUT_DIR)/city_building5.room $(ROOM_OUT_DIR)/city_building6.room \
  $(ROOM_OUT_DIR)/city_building7.room
	$(compile-asm)

$(OBJDIR)/rooms/city_center.o: \
  src/rooms/city_center.asm $(INC_FILES) \
  $(ROOM_OUT_DIR)/city_center1.room $(ROOM_OUT_DIR)/city_center2.room
	$(compile-asm)

$(OBJDIR)/rooms/garden_hallway.o: \
  src/rooms/garden_hallway.asm $(INC_FILES) \
  $(ROOM_OUT_DIR)/garden_hallway1.room $(ROOM_OUT_DIR)/garden_hallway2.room
	$(compile-asm)

$(OBJDIR)/rooms/mermaid_village.o: \
  src/rooms/mermaid_village.asm $(INC_FILES) \
  $(ROOM_OUT_DIR)/mermaid_village1.room $(ROOM_OUT_DIR)/mermaid_village2.room
	$(compile-asm)

$(OBJDIR)/rooms/prison_upper.o: \
  src/rooms/prison_upper.asm $(INC_FILES) \
  $(ROOM_OUT_DIR)/prison_upper1.room $(ROOM_OUT_DIR)/prison_upper2.room
	$(compile-asm)

$(OBJDIR)/rooms/shadow_depths.o: \
  src/rooms/shadow_depths.asm $(INC_FILES) \
  $(ROOM_OUT_DIR)/shadow_depths1.room $(ROOM_OUT_DIR)/shadow_depths2.room \
  $(ROOM_OUT_DIR)/shadow_depths3.room
	$(compile-asm)

$(OBJDIR)/rooms/town_outdoors.o: \
  src/rooms/town_outdoors.asm $(INC_FILES) \
  $(ROOM_OUT_DIR)/town_outdoors1.room $(ROOM_OUT_DIR)/town_outdoors2.room \
  $(ROOM_OUT_DIR)/town_outdoors3.room
	$(compile-asm)

$(OBJDIR)/rooms/%.o: src/rooms/%.asm $(INC_FILES) $(ROOM_OUT_DIR)/%.room
	$(compile-asm)

$(OBJDIR)/%.o: src/%.asm $(INC_FILES)
	$(compile-asm)

$(MUSIC_OUT_DIR)/%.o: $(MUSIC_OUT_DIR)/%.asm $(INC_FILES)
	$(compile-asm)
.SECONDARY: $(MUSIC_OBJ_FILES)

$(TEXT_OUT_DIR)/%.o: $(TEXT_OUT_DIR)/%.asm $(INC_FILES)
	$(compile-asm)
.SECONDARY: $(TEXT_OBJ_FILES)

$(TSET_OUT_DIR)/%.o: $(TSET_OUT_DIR)/%.asm $(INC_FILES)
	$(compile-asm)
.SECONDARY: $(TSET_OBJ_FILES)

$(OUTDIR)/nsf/nsf.o: nsf/nsf.asm $(INC_FILES)
	$(compile-asm)

#=============================================================================#
# Libraries:

$(MUSIC_LIB_FILE): $(MUSIC_OBJ_FILES)
	$(update-archive)

$(ROOM_LIB_FILE): $(ROOM_OBJ_FILES)
	$(update-archive)

$(TEXT_LIB_FILE): $(TEXT_OBJ_FILES)
	$(update-archive)

$(TSET_LIB_FILE): $(TSET_OBJ_FILES)
	$(update-archive)

#=============================================================================#
# Game ROM:

$(ROM_BIN_FILE) $(ROM_LABEL_FILE): \
  tests/lint.py $(ROM_CFG_FILE) $(ROM_OBJ_FILES) \
  $(MUSIC_LIB_FILE) $(ROOM_LIB_FILE) $(TEXT_LIB_FILE) $(TSET_LIB_FILE)
	python3 tests/lint.py
	@echo "Linking $@"
	@mkdir -p $(@D)
	@ld65 -Ln $(ROM_LABEL_FILE) -m $(ROM_MAP_FILE) -o $@ \
	      -C $(ROM_CFG_FILE) $(ROM_OBJ_FILES) \
	      $(MUSIC_LIB_FILE) $(ROOM_LIB_FILE) $(TEXT_LIB_FILE) \
	      $(TSET_LIB_FILE)
$(ROM_LABEL_FILE): $(ROM_BIN_FILE)

#=============================================================================#
# NSF file:

$(NSF_BIN_FILE): $(NSF_CFG_FILE) $(NSF_OBJ_FILES) $(MUSIC_LIB_FILE)
	@echo "Linking $@"
	@mkdir -p $(@D)
	@ld65 -m $(NSF_MAP_FILE) -o $@ \
	      -C $(NSF_CFG_FILE) $(NSF_OBJ_FILES) $(MUSIC_LIB_FILE)

#=============================================================================#
