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
OBJDIR = $(OUTDIR)/obj
SIM65DIR = $(OUTDIR)/sim65

AHI2CHR = $(BINDIR)/ahi2chr
BG2ROOM = $(BINDIR)/bg2room
LABEL2NL = $(BINDIR)/label2nl

CFGFILE = $(SRCDIR)/linker.cfg
LABELFILE = $(OUTDIR)/$(ROMNAME).labels.txt
ROMFILE = $(OUTDIR)/$(ROMNAME).nes

AHIFILES := $(shell find $(SRCDIR) -name '*.ahi')
ASMFILES := $(shell find $(SRCDIR) -name '*.asm')
BGFILES := $(shell find $(SRCDIR) -name '*.bg')
INCFILES := $(shell find $(SRCDIR) -name '*.inc')

CHRFILES := $(patsubst $(SRCDIR)/%.ahi,$(DATADIR)/%.chr,$(AHIFILES))
OBJFILES := $(patsubst $(SRCDIR)/%.asm,$(OBJDIR)/%.o,$(ASMFILES))
ROOMFILES := $(patsubst $(SRCDIR)/%.bg,$(DATADIR)/%.room,$(BGFILES))

#=============================================================================#

.PHONY: rom
rom: $(ROMFILE)

.PHONY: run
run: $(ROMFILE) $(ROMFILE).ram.nl $(ROMFILE).3.nl
	fceux $<

.PHONY: test
test: $(SIM65DIR)/terrain
	python tests/lint.py
	sim65 $(SIM65DIR)/terrain
	python tests/style.py

.PHONY: clean
clean:
	rm -rf $(OUTDIR)

#=============================================================================#

define compile-c
	@echo "Compiling $<"
	@mkdir -p $(@D)
	@cc -Wall -Werror -o $@ $<
endef

$(AHI2CHR): build/ahi2chr.c
	$(compile-c)

$(DATADIR)/%.chr: $(SRCDIR)/%.ahi $(AHI2CHR)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(AHI2CHR) < $< > $@

$(BG2ROOM): build/bg2room.c
	$(compile-c)

$(DATADIR)/%.room: $(SRCDIR)/%.bg $(BG2ROOM)
	@echo "Converting $<"
	@mkdir -p $(@D)
	@$(BG2ROOM) < $< > $@

$(LABEL2NL): build/label2nl.c
	$(compile-c)

$(ROMFILE).ram.nl: $(LABELFILE) $(LABEL2NL)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@$(LABEL2NL) 0000 07ff < $< > $@

$(ROMFILE).3.nl: $(LABELFILE) $(LABEL2NL)
	@echo "Generating $@"
	@mkdir -p $(@D)
	@$(LABEL2NL) 8000 9fff c000 ffff < $< > $@

#=============================================================================#

define link-test
	@echo "Linking $@"
	@mkdir -p $(@D)
	@ld65 -o $@ -C $^
endef

$(SIM65DIR)/terrain: $(TESTDIR)/terrain.cfg $(SIM65DIR)/terrain.o \
                     $(OBJDIR)/terrain.o $(SIM65DIR)/sim65.o
	$(link-test)

$(SIM65DIR)/%.o: $(TESTDIR)/%.asm $(INCFILES)
	@echo "Assembling $<"
	@mkdir -p $(@D)
	@ca65 --target sim6502 -o $@ $<

#=============================================================================#

$(ROMFILE) $(LABELFILE): $(CFGFILE) $(OBJFILES)
	@echo "Linking $@"
	@mkdir -p $(@D)
	@ld65 -Ln $(LABELFILE) -o $@ -C $(CFGFILE) $(OBJFILES)
$(LABELFILE): $(ROMFILE)

define compile-asm
	@echo "Assembling $<"
	@mkdir -p $(@D)
	@ca65 --target nes -W1 --debug-info -o $@ $<
endef

$(OBJDIR)/chr.o: $(SRCDIR)/chr.asm $(INCFILES) $(CHRFILES)
	$(compile-asm)

$(OBJDIR)/room.o: $(SRCDIR)/room.asm $(INCFILES) $(ROOMFILES)
	$(compile-asm)

$(OBJDIR)/%.o: $(SRCDIR)/%.asm $(INCFILES)
	$(compile-asm)

#=============================================================================#
