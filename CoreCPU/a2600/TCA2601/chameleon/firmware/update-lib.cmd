copy /y "C:\Program Files (x86)\cc65\lib\c64.lib" MyComputer.lib
ca65 --cpu 6502 crt0.s
ar65 a MyComputer.lib crt0.o
