# Makefile for toolchain and tests

all: 832a/832a 832emu/832e 832ocd/832ocd vbcc/supp.h lib832/lib832.a hello test

832a/832a: force
	-make -C 832a

832emu/832e: force
	-make -C 832emu

832ocd/832ocd: force
	-make -C 832ocd

lib832/lib832.a: 832a/832a 832a/832l vbcc/bin/vbcc832 force
	-make -C lib832

hello: 832emu/832e 832a/832a
	-832emu/832e 832a/hello

vbcc0_9g.tar.gz:
	wget http://phoenix.owl.de/tags/vbcc0_9g.tar.gz

vbcc/bin/vbcc832: vbcc/bin vbcc0_9g.tar.gz
	tar -xzf vbcc0_9g.tar.gz
	cd vbcc; \
	patch -i ../vbcc_09g_volatilefix.patch
	make -C vbcc TARGET=832

vbcc/supp.h:
	$(info )
	$(info Type make vbcc to unpack, patch and build vbcc 0.9g automatically.)
	$(info When configuring VBCC, if you're building on a typical Linux system)
	$(info you can just accept the defaults.)
	$(info )
	$(info NB: Take note of the terms of the VBCC license if you intend to distribute)
	$(info a product which incorporates code compiled for 832.)
	$(error vbcc needs to be built.)

vbcc/bin:
	mkdir vbcc/bin

.PHONY vbcc:
vbcc: vbcc/bin/vbcc832

.PHONY test:
test:
	-make -C vbcc/test emu

force:

