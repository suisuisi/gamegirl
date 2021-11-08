DEMISTIFYPATH=DeMiSTify
SUBMODULES=$(DEMISTIFYPATH)/EightThirtyTwo/Makefile
PROJECT=tgfx16
PROJECTPATH=./
PROJECTTOROOT=../
BOARD=
ROMSIZE1=16384
ROMSIZE2=8192

all: $(DEMISTIFYPATH)/site.mk firmware init compile tns mist

$(DEMISTIFYPATH)/site.mk:
	$(info ******************************************************)
	$(info Please checkout submodules using "git submodule init" )
	$(info followed by "git submodule update --recursive")
	$(info )
	$(info Then Copy the example DeMiSTify/site.template file to)
	$(info DeMiSTify/site.mk and edit the paths for the version(s))
	$(info of Quartus you have installed.)
	$(info *******************************************************)
	$(error site.mk not found.)

include $(DEMISTIFYPATH)/site.mk

$(SUBMODULES):
	git submodule update --init --recursive
	make -C $(DEMISTIFYPATH) -f bootstrap.mk

.PHONY: firmware
firmware: $(SUBMODULES)
	make -C firmware -f ../$(DEMISTIFYPATH)/Scripts/firmware.mk DEMISTIFYPATH=../$(DEMISTIFYPATH) ROMSIZE1=$(ROMSIZE1) ROMSIZE2=$(ROMSIZE2)

.PHONY: init
init:
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTTOROOT=$(PROJECTTOROOT) PROJECTPATH=$(PROJECTPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) init 

.PHONY: compile
compile: 
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTTOROOT=$(PROJECTTOROOT) PROJECTPATH=$(PROJECTPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) compile

.PHONY: clean
clean:
	make -f $(DEMISTIFYPATH)/Makefile DEMISTIFYPATH=$(DEMISTIFYPATH) PROJECTTOROOT=$(PROJECTTOROOT) PROJECTPATH=$(PROJECTPATH) PROJECTS=$(PROJECT) BOARD=$(BOARD) clean

.PHONY: tns
tns:
	@for BOARD in ${BOARDS}; do \
		echo $$BOARD; \
		grep -r Design-wide\ TNS $$BOARD/*.rpt; \
	done

.PHONY: mist
mist:
	$(Q13)/quartus_sh --flow compile mist/$(PROJECT)_mist.qpf

