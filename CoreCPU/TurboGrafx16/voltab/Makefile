all: voltab_16.mif voltab.mif voltab_small.mif

voltab: voltab.c
	gcc -o voltab voltab.c -lm

voltab_small: voltab_small.c
	gcc -o voltab_small voltab_small.c -lm

voltab.mif: voltab
	./voltab 24
	mv	voltab_out.mif voltab.mif

voltab_16.mif: voltab
	./voltab 16
	mv	voltab_out.mif voltab_16.mif

voltab_small.mif: voltab_small
	./voltab_small

