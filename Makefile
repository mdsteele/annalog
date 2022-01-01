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
BINDIR = $(OUTDIR)/bin
DATADIR = $(OUTDIR)/data
OBJDIR = $(OUTDIR)/obj

CFGFILE = $(SRCDIR)/linker.cfg
LABELFILE = $(OUTDIR)/$(ROMNAME).labels.txt
ROMFILE = $(OUTDIR)/$(ROMNAME).nes

ASMFILES := $(shell find $(SRCDIR) -name '*.asm')
INCFILES := $(shell find $(SRCDIR) -name '*.inc')

OBJFILES := $(patsubst $(SRCDIR)/%.asm,$(OBJDIR)/%.o,$(ASMFILES))

#=============================================================================#

.PHONY: rom
rom: $(ROMFILE)

.PHONY: run
run: $(ROMFILE)
	fceux $<

.PHONY: clean
clean:
	rm -rf $(OUTDIR)

#=============================================================================#

$(ROMFILE) $(LABELFILE): $(CFGFILE) $(OBJFILES)
	@echo "Linking $@"
	@mkdir -p $(@D)
	@ld65 -Ln $(LABELFILE) -o $@ -C $(CFGFILE) $(OBJFILES)
$(LABELFILE): $(ROMFILE)

define compile-asm
	@echo "Compiling $<"
	@mkdir -p $(@D)
	@ca65 --target nes -W1 --debug-info -o $@ $<
endef

$(OBJDIR)/%.o: $(SRCDIR)/%.asm $(INCFILES)
	$(compile-asm)

#=============================================================================#
