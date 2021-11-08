#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SULV_U  (0) /* Uninitialized   */
#define SULV_X  (1) /* Forcing Unknown */
#define SULV_0  (2) /* Forcing 0       */
#define SULV_1  (3) /* Forcing 1       */
#define SULV_Z  (4) /* High Impedance  */
#define SULV_W  (5) /* Weak Unknown    */
#define SULV_L  (6) /* Weak 0          */
#define SULV_H  (7) /* Weak 1          */
#define SULV__  (8) /* Don't care      */

unsigned char chr[] = { 'U','X','0','1','Z','W','L','H','-' };

unsigned char *rom = NULL;

void load_rom(void) {
  printf ("load rom\n");
  FILE *f = fopen("dump/vram.bin", "rb");
  if(!f) perror("fopen");
  rom = malloc(65536);
  fread(rom, 65536, 1, f);
  fclose(f);
}

void vram_c(char clk, char we, char din[16], char addr[15], char dout[16]) {
  static char last_clk = 0;
  static unsigned int last_addr = 0xffffffff;

  if(!rom) load_rom();

  // only do something if clock changes
  if((clk == last_clk) && (clk != SULV_0)&&(clk != SULV_L)  )
    return;

  last_clk = clk;

  unsigned int i, a = 0;
  for(i=0;i<15;i++) {
    a <<= 1;
    if((addr[i] == SULV_1)||(addr[i] == SULV_H))
      a |= 1;
  }

  unsigned int din16 = 0;
  for(i=0;i<16;i++) {
    din16 <<= 1;
    if((din[i] == SULV_1)||(din[i] == SULV_H))
      din16 |= 1;
  }

  unsigned short d16 = 256*rom[2*a] + rom[2*a+1];
  //  printf("vram(%04x) = $%04x\n", a, d16);

  if( (a != last_addr) && (((we == SULV_1) || (we == SULV_H))))
    printf("VRAM WR $%04x = $%04x (is $%04x)\n", 2*a, din16, d16);
  
  for(i=0;i<16;i++)
    dout[i] = (d16 & (0x8000>>i))?SULV_1:SULV_0;

  last_addr = a;
}

void vram32_c(char clk, char addr[15], char dout[32]) {
  static char last_clk = 0;
  static unsigned int last_addr = 0xffffffff;

//  if(!rom) load_rom();

  // only do something if clock changes
  if((clk == last_clk) && (clk != SULV_0)&&(clk != SULV_L)  )
    return;

  last_clk = clk;

  unsigned int i, a = 0;
  for(i=0;i<15;i++) {
    a <<= 1;
    if((addr[i] == SULV_1)||(addr[i] == SULV_H))
      a |= 1;
  }

  unsigned int d32 = rom[2*a]*256 + rom[2*a+1] + rom[2*a+2]*256*256*256 + rom[2*a+3]*256*256;
//  if (a != last_addr) printf("vram(%04x) = $%08x\n", 2*a, d32);

  for(i=0;i<32;i++)
    dout[i] = (d32 & (0x80000000>>i))?SULV_1:SULV_0;
  last_addr = a;
}
