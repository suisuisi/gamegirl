#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>

#define SULV_U  (0) /* Uninitialized   */
#define SULV_X  (1) /* Forcing Unknown */
#define SULV_0  (2) /* Forcing 0       */
#define SULV_1  (3) /* Forcing 1       */
#define SULV_Z  (4) /* High Impedance  */
#define SULV_W  (5) /* Weak Unknown    */
#define SULV_L  (6) /* Weak 0          */
#define SULV_H  (7) /* Weak 1          */
#define SULV__  (8) /* Don't care      */

unsigned short vsram_prepare[][2] = {
  { 4, 0x4000}, // prepare vsram access
  { 4, 0x0010}
};

unsigned short cram_prepare[][2] = {
  { 4, 0xc000}, // prepare cram access
  { 4, 0x0000}
};

unsigned short vram_prepare[][2] = {
  { 4, 0x4000}, // prepare vram access
  { 4, 0x0000}
};

unsigned short *cram = NULL;
int cram_entries = 0;

unsigned short *vsram = NULL;
int vsram_entries = 0;

unsigned char *regs = NULL;
int reg_entries = 0;

unsigned short *vram = NULL;

void cpu_c(char clk, char rst_n, char sel[1], char dtack_n, char rnw[1], char ds[2], char a[5], char d[16]) {
  static char last_clk = -1;
  static int state = -1;
  static int wait = 0;
  static int cnt = 0;

  // internal signal states
  static int sel_i = 0;
  static int rnw_i = 1;
  static int ds_i  = 3;
  static int a_i   = 0;
  static int d_i   = 0;

  static int sprite_table = -1;
  
  if(!cram) {
    FILE *f=fopen("dump/cram.bin", "rb");
    if(!f) { perror("cram"); exit(-1); }
    fseek(f, 0, SEEK_END);
    int len = ftell(f);
    fseek(f, 0, SEEK_SET);

    cram = malloc(len);
    fread(cram, 1, len, f);

    for(int i=0;i<len/2;i++)
      cram[i] = htons(cram[i]);
    
    cram_entries = len/2;
      
    fclose(f);
  }
  
  if(!vram) {
    FILE *f=fopen("dump/vram.bin", "rb");
    if(!f) { perror("cram"); exit(-1); }
    fseek(f, 0, SEEK_END);
    int len = ftell(f);
    fseek(f, 0, SEEK_SET);

    vram = malloc(len);
    fread(vram, 1, len, f);

    fclose(f);
  }

  if(!vsram) {
    FILE *f=fopen("dump/vsram.bin", "rb");
    if(!f) { perror("vsram"); exit(-1); }
    fseek(f, 0, SEEK_END);
    int len = ftell(f);
    fseek(f, 0, SEEK_SET);

    vsram = malloc(len);
    fread(vsram, 1, len, f);

    for(int i=0;i<len/2;i++)
      vsram[i] = htons(vsram[i]);
    
    vsram_entries = len/2;
      
    fclose(f);
  }
  
  if(!regs) {
    FILE *f=fopen("dump/regs.bin", "rb");
    if(!f) { perror("regs"); exit(-1); }
    fseek(f, 0, SEEK_END);
    reg_entries = ftell(f);
    fseek(f, 0, SEEK_SET);

    regs = malloc(reg_entries);
    fread(regs, 1, reg_entries, f);

    fclose(f);
  }
  
  if((rst_n != SULV_1)&&(rst_n != SULV_H)) {
    state = 0;
    wait = 2;
    cnt = 0;
    sel_i = 0;
  } else {
  
    // only work on rising clock edge
    if((clk != last_clk) && (clk == SULV_0) || (clk == SULV_L)) {
      // just waiting
      if(wait || sel_i) {
	int ack = (dtack_n == SULV_0)||(dtack_n == SULV_L);

	if(sel_i) {
	  if(ack) sel_i = 0;
	} else     wait--;
      } else {
	
	// state 0: writing regs
	if(state == 0) {
	  while(!regs[cnt] && (cnt < reg_entries))
	    cnt++;
	    
	  if(cnt < reg_entries) {	    
	    sel_i = 1;
	    ds_i = 0;
	    rnw_i = 0;
	    a_i = 4;
	    d_i = ((0x80 + cnt)<<8) + regs[cnt];
	    printf("REG %04x\n", d_i);

	    // dump some extra info
	    switch(cnt) {
	    case 0:
	      printf("  left 8 pixels: %s\n", (regs[0]&0x20)?"hidden":"visible");
	      printf("  display enable: %s\n", (regs[0]&0x01)?"overlay":"normal");
	      break;
	    case 1:
	      printf("  vram size: %s\n", (regs[1]&0x80)?"128k":"64k");
	      printf("  display: %s\n", (regs[1]&0x40)?"enabled":"disabled");
	      printf("  image height: %s\n", (regs[1]&0x04)?"V30 (30 cells, 240 pixels)":"V28 (28 cells, 224 pixels)");
	      printf("  master system mode 4: %s\n", (regs[1]&0x02)?"enaled":"disabled");
	      break;
	    case 2:
	      printf("  plane a nametable: $%04x\n", (regs[2] & 0x78)<<10 );
	      break;
	    case 3:
	      printf("  window nametable: $%04x\n", (regs[3] & 0x7e)<<10 );
	      if(regs[3] & 0x40) printf("  WARNING: window plane addresses second 64k!!!\n");  
	      break;
	    case 4:
	      printf("  plane b nametable: $%04x\n", (regs[4] & 0x0f)<<13 );
	      break;
	    case 5:
	      printf("  sprite table location: $%04x\n", regs[5]<<9 );
	      // we need to save this as we have to write this via the CPU to fill the
	      // VDP sprite cache
	      sprite_table = regs[5]<<9;
	      break;
	    case 10:
	      printf("  hint counter: %d\n", regs[10]);
	      break;
	    case 11: {
	      char *hsmode[]={"once", "forbidden", "8 pix per long", "one line per long" };
	      printf("  vscroll: %s\n", (regs[11]&4)?"2 cells per VSRAM entry":"entire screen from VSRAM(0)");
	      printf("  hscroll: %s\n", hsmode[regs[11]&3] );
	      } break;
	    case 12:
	      printf("  H40 R0: %s\n", (regs[12]&0x80)?"40 cells, 320 pixel":"32 cells, 256 pixel");
	      printf("  H40 R1: %s\n", (regs[12]&0x01)?"40 cells, 320 pixel":"32 cells, 256 pixel");
	      break;
	    case 13:
	      printf("  hscroll data: $%04x\n", (regs[13]&0x7f)<<10);
	      break;
	    case 15:
	      printf("  auto increment: $%02x\n", regs[15]);
	      break;
	    case 16: {
	      char *size[]={"32", "64", "forbidden", "128" };
	      printf("  vertical plane size: %s\n", size[(regs[16]>>4)&3]);
	      printf("  horizontal plane size: %s\n", size[regs[16]&3]);
	      } break;
	    }
	    
	    cnt++;
	    wait = 0;
	  }
	    
	  // all registers written?
	  if(cnt == reg_entries) {
	    state = 1;  // next-> prepare cram
	    wait = 2;
	    cnt = 0;
	  }	  
	}
	  
	// state 1: prepare vsram access
	else if(state == 1) {
	  sel_i = 1;
	  ds_i = 0;
	  rnw_i = 0;
	  a_i = vsram_prepare[cnt][0];
	  d_i = vsram_prepare[cnt++][1];
	  wait = 0;

	  // all registers written?
	  if(cnt == sizeof(vsram_prepare)/(2*sizeof(unsigned short))) {
	    state = 2;  // next-> write vsram
	    wait = 2;
	    cnt = 0;
	  }
	}

	// state 2: load vsram
	else if(state == 2) {
	  sel_i = 1;
	  rnw_i = 0;
	  ds_i = 0;
	  a_i = 0;
	  d_i = vsram[cnt];
	  printf("VSRAM[%d] %04x\n", cnt, d_i);
	  cnt++;
	  wait = 0;

	  // all vsram entries written?
	  if(cnt == vsram_entries) {
	    state = 3;
	    cnt = 0;
	  }
	}

	// state 3: prepare cram access
	else if(state == 3) {
	  sel_i = 1;
	  ds_i = 0;
	  rnw_i = 0;
	  a_i = cram_prepare[cnt][0];
	  d_i = cram_prepare[cnt++][1];
	  wait = 0;

	  // all registers written?
	  if(cnt == sizeof(cram_prepare)/(2*sizeof(unsigned short))) {
	    state = 4;  // next-> write cram
	    wait = 2;
	    cnt = 0;
	  }
	}

	// state 4: load cram
	else if(state == 4) {
	  sel_i = 1;
	  rnw_i = 0;
	  ds_i = 0;
	  a_i = 0;
	  d_i = cram[cnt];
	  printf("COLOR[%d] %04x\n", cnt, d_i);
	  cnt++;
	  wait = 0;

	  // all cram entries written?
	  if(cnt == cram_entries) {
	    printf("VRAM prepare for %04x\n", sprite_table);

	    // xyz
	    vram_prepare[0][1] |= sprite_table & 0x3fff;
	    vram_prepare[1][1] |= (sprite_table>>14) & 0x3;
	      
	    state = 5;
	    cnt = 0;
	  }
	}

	// state 5: prepare vram access
	else if(state == 5) {
	  sel_i = 1;
	  ds_i = 0;
	  rnw_i = 0;
	  a_i = vram_prepare[cnt][0];
	  d_i = vram_prepare[cnt++][1];
	  wait = 0;

	  // all registers written?
	  if(cnt == sizeof(vram_prepare)/(2*sizeof(unsigned short))) {
	    state = 6;  // next-> write vram
	    wait = 2;
	    cnt = 0;
	  }
	}

	// state 6: load vram
	else if(state == 6) {
	  //	  printf("XXX %d\n", cnt+sprite_table/2);
	  
	  sel_i = 1;
	  rnw_i = 0;
	  ds_i = 0;
	  a_i = 0;
	  d_i = htons(vram[cnt+sprite_table/2]);
	  cnt++;
	  wait = 0;

	  // all vram sprite table entries written?
	  if(cnt == 80*4) {
	    printf("VRAM sprite table upload done\n");
	    state = 7;
	    cnt = 0;
	  }
	}
      }
    }
  }

  last_clk = clk;
    
  // drive all signals
  for(int i=0;i<16;i++)
    d[i] = (d_i&(0x8000>>i))?SULV_1:SULV_0;
  for(int i=0;i<5;i++)
    a[i] = (a_i&(0x10>>i))?SULV_1:SULV_0;
  for(int i=0;i<2;i++)
    ds[i] = (ds_i&(2>>i))?SULV_1:SULV_0;

  sel[0] = sel_i?SULV_1:SULV_0;
  rnw[0] = rnw_i?SULV_1:SULV_0;
}
