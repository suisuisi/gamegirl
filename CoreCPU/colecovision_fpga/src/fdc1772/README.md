# fdc1772 verilator simulation

This is a verilator environment written to test the floppy and fdc
implementation for the Archimedes FPGA "Archie" and Atari ST "MiSTery" cores.

It includes a testbench for the fdc incl. a floppy model. This
can be run by entering ```make```:

```
obj_dir/Vfdc1772
[0.000] "motor on" at 300.000 RPM
[0.000] Full RPM reached 0.000ms after motor on
[0.000] Floppy becomes ready
[0.000] Floppy motor timeout 5
FORCED_INTERRUPT(0)
[0.001] New command d0
FORCED_INTERRUPT done
READ_ADDRESS 0
[0.012] fdc becomes busy
@28042us data: 00
@32us data: 00
@32us data: 01
@32us data: 03
@32us data: a5
@32us data: 5a
[0.040] IRQ raised
[0.040] fdc becomes not busy. command done
[0.040] Floppy motor timeout 9
[0.040] IRQ cleared
READ_ADDRESS done, status = 80
READ_SECTOR
[0.040] New command 88
[0.040] fdc becomes busy
DIO: READ SECTOR with empty fifo, starting 1k data
@79804us data(0): 00
@32us data(1023): ff
[0.153] IRQ raised
[0.153] fdc becomes not busy. command done
[0.153] IRQ cleared
READ_SECTOR done, status = 80
READ_SECTOR
[0.153] New command 88
[0.153] fdc becomes busy
DIO: READ SECTOR with empty fifo, starting 1k data
@7228us data(0): 00
@32us data(1023): ff
[0.193] IRQ raised
[0.193] fdc becomes not busy. command done
[0.193] IRQ cleared
READ_SECTOR done, status = 80
[0.193] done
```

it also contains a setup to test the floppy model itself by typing
```make -f floppy.mk```:

```
obj_dir/Vfloppy
motor on at 0.000 RPM
Index pulse len = 5.000ms
Full RPM reached 500.000ms after motor on
RPM = 295.875
Index pulse len = 5.000ms
RPM = 300.000
Index pulse len = 5.000ms
```

Both simulations write .vcd files for further inspection using e.g.
gtkwave.
