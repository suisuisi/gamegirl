DEMISTIFYPATH=../../DeMiSTify
PROJECT=vectrex
BOARD=
include $(DEMISTIFYPATH)/site.mk

all: submodules vbcc firmware init build_id compile

submodules: $(DEMISTIFYPATH)/Makefile

.PHONY: vbcc
vbcc:
	make -C $(DEMISTIFYPATH)/EightThirtyTwo/ vbcc

$(DEMISTIFYPATH)/DeMiSTify/Makefile:
	git submodule update --init --recursive

.PHONY: firmware
firmware: submodules
	make -C firmware -f ../$(DEMISTIFYPATH)/Scripts/firmware.mk DEMISTIFYPATH=../$(DEMISTIFYPATH)

.PHONY: build_id
build_id:
	@$(Q13)/quartus_sh >build_id.log -t rtl/build_id.tcl

.PHONY: init
init:
	@make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) init 

.PHONY: compile
compile:
	@make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) compile

.PHONY: clean
clean:
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) clean

