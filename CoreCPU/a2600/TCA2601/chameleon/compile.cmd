cd firmware
cc65 -t none -O --cpu 6502 main.c
ca65 --cpu 6502 main.s
ld65 -C MyComputer.cfg -m main.map main.o MyComputer.lib
cd ..
          
java -cp bin2hex\bin bin2hex firmware\a.out YaGraphCon\cpuRAM.hex
