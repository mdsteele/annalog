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

SRCDIR = src
OUTDIR = out
TESTDIR = tests
BINDIR = $(OUTDIR)/bin
DATADIR = $(OUTDIR)/data
GENDIR = $(OUTDIR)/gen
OBJDIR = $(OUTDIR)/obj
SIM65DIR = $(OUTDIR)/sim65

AHI2CHR = $(BINDIR)/ahi2chr
BG2MINI = $(BINDIR)/bg2mini
BG2ROOM = $(BINDIR)/bg2room
BG2TSET = $(BINDIR)/bg2tset
LABEL2NL = $(BINDIR)/label2nl

CFGFILE = $(SRCDIR)/linker.cfg
LABELFILE = $(OUTDIR)/$(ROMNAME).labels.txt
ROMFILE = $(OUTDIR)/$(ROMNAME).nes

AHIFILES := $(shell find $(SRCDIR) -name '*.ahi')
ASMFILES := $(shell find $(SRCDIR) -name '*.asm')
INCFILES := $(shell find $(SRCDIR) -name '*.inc')
ROOM_BG_FILES := $(shell find $(SRCDIR)/rooms -name '*.bg')
TSET_BG_FILES := $(shell find $(SRCDIR)/tilesets -name '*.bg')

CHRFILES := $(patsubst $(SRCDIR)/%.ahi,$(DATADIR)/%.chr,$(AHIFILES))
GENFILES := \
  $(patsubst $(SRCDIR)/tilesets/%.bg,$(GENDIR)/tilesets/%.asm,$(TSET_BG_FILES))
OBJFILES := \
  $(patsubst $(SRCDIR)/%.asm,$(OBJDIR)/%.o,$(ASMFILES)) \
  $(patsubst $(GENDIR)/%.asm,$(GENDIR)/%.o,$(GENFILES))
ROOMFILES := \
  $(patsubst $(SRCDIR)/rooms/%.bg,$(DATADIR)/%.room,$(ROOM_BG_FILES))

#=============================================================================#
# Phony targets:

.PHONY: rom
rom: $(ROMFILE)

.PHONY: run
run: $(ROMFILE) $(ROMFILE).ram.nl $(ROMFILE).3.nl
	fceux $<

.PHONY: test
test: $(SIM65DIR)/machine $(SIM65DIR)/terrain $(SIM65DIR)/window
	python tests/lint.py
	sim65 $(SIM65DIR)/machine
	sim65 $(SIM65DIR)/terrain
	sim65 $(SIM65DIR)/window
	python tests/style.py

.PHONY: clean
clean:
	rm -rf $(OUTDIR)

#=============================================================================#
# Build tools:

define compile-c
	@echo "Compiling $<"
	@mkdir -p $(@D)
	@cc -Wall -Werror -o $@ $<
endef

$(AHI2CHR): build/ahi2chr.c
	$(compile-c)

$(BG2MINI): build/bg2mini.c
	$(compile-c)

$(BG2ROOM): build/bg2room.c
	$(compile-c)

$(BG2TSET): build/bg2tset.c
	$(compile-c)

$(LABEL2NL): build/label2nl.c
	$(compile-c)

#=============================================================================#
# Generated files:

$(DATADIR)/%.chr: $(SRCDIR)/%.ahi $(AHI2CHR)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(AHI2CHR) < $< > $@

.SECONDARY: $(CHRFILES)

$(DATADIR)/minimap: $(SRCDIR)/minimap.bg $(BG2MINI)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(BG2MINI) < $< > $@

.SECONDARY: $(DATADIR)/minimap

$(DATADIR)/%.room: $(SRCDIR)/rooms/%.bg $(BG2ROOM)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(BG2ROOM) < $< > $@

.SECONDARY: $(ROOMFILES)

$(GENDIR)/tilesets/%.asm: $(SRCDIR)/tilesets/%.bg $(BG2TSET) $(AHIFILES)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@mkdir -p $(OUTDIR)/blocks
	@$(BG2TSET) $* < $< > $@

.SECONDARY: $(GENFILES)

$(ROMFILE).ram.nl: $(LABELFILE) $(LABEL2NL)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@$(LABEL2NL) 0000 07ff < $< > $@

$(ROMFILE).3.nl: $(LABELFILE) $(LABEL2NL)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@$(LABEL2NL) 8000 9fff c000 ffff < $< > $@

#=============================================================================#
# ASM tests:

define link-test
	@echo "Linking $@"
	@mkdir -p $(@D)
	@ld65 -o $@ -C $^
endef

$(SIM65DIR)/%.o: $(TESTDIR)/%.asm $(INCFILES)
	@echo "Assembling $<"
	@mkdir -p $(@D)
	@ca65 --target sim6502 -o $@ $<

$(SIM65DIR)/%: $(TESTDIR)/%.cfg $(SIM65DIR)/%.o $(OBJDIR)/%.o \
               $(SIM65DIR)/sim65.o
	$(link-test)

#=============================================================================#
# OBJ files:

define compile-asm
	@echo "Assembling $<"
	@mkdir -p $(@D)
	@ca65 --target nes -W1 --debug-info -o $@ $<
endef

$(OBJDIR)/chr.o: $(SRCDIR)/chr.asm $(INCFILES) $(CHRFILES)
	$(compile-asm)

$(OBJDIR)/pause.o: $(SRCDIR)/pause.asm $(INCFILES) $(DATADIR)/minimap
	$(compile-asm)

$(OBJDIR)/rooms/%.o: $(SRCDIR)/rooms/%.asm $(INCFILES) $(DATADIR)/%.room
	$(compile-asm)

$(OBJDIR)/%.o: $(SRCDIR)/%.asm $(INCFILES)
	$(compile-asm)

$(GENDIR)/%.o: $(GENDIR)/%.asm $(INCFILES)
	$(compile-asm)

#=============================================================================#
# Game ROM:

$(ROMFILE) $(LABELFILE): $(CFGFILE) $(OBJFILES) tests/lint.py
	python tests/lint.py
	@echo "Linking $@"
	@mkdir -p $(@D)
	@ld65 -Ln $(LABELFILE) -o $@ -C $(CFGFILE) $(OBJFILES)
$(LABELFILE): $(ROMFILE)

#=============================================================================#
