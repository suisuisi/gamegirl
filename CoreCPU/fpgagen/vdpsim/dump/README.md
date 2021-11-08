# VDP memory dump for vdpsim

This directory contains the VDP state to be rendered by vdpsim. It consists
of four files:

  - [```vram.bin```](vram.bin) 64 kilobytes image of the VRAM
  - [```cram.bin```](cram.bin) 64 * 16 bit word image of the color RAM 
  - [```vsram.bin```](vsram.bin) 20 * 32 bit long word image of the VSRAM
  - [```regs.bin```](regs.bin) 24 bytes VDP registers

By default these files contain the dump of the H32 test of the SpriteMaskingTestRom.

The [blastem_io.patch](blastem_io.patch) exends the screendump function of
the blastem emulator to store aforementioned dumps with the screenshot. It's thus
possible to feed the VDP state taken from the blastem emulator into the
VDP running inside vdpsim.
