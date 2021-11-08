PROJECT=floppy
NOWARN = -Wno-UNOPTFLAT -Wno-WIDTH # --report-unoptflat # -Wno-UNOPTFLAT
SRC = $(PROJECT).v $(PROJECT)_tb.cpp

all: $(PROJECT).vcd

obj_dir/stamp: $(SRC)
	verilator $(NOWARN) --cc --trace --exe $(PROJECT).v $(PROJECT)_tb.cpp
	touch obj_dir/stamp

obj_dir/V$(PROJECT): obj_dir/stamp
	make -j -C obj_dir/ -f V$(PROJECT).mk V$(PROJECT)

$(PROJECT).vcd: obj_dir/V$(PROJECT)
	obj_dir/V$(PROJECT)

clean:
	rm -rf obj_dir
	rm -f  $(PROJECT).vcd
	rm -f *~ 

run: obj_dir/V$(PROJECT)
	obj_dir/V$(PROJECT)

view: $(PROJECT).vcd
	gtkwave $< $(PROJECT).sav &
