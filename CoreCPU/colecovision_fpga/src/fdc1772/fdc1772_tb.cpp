#include "Vfdc1772.h"
#include "Vfdc1772_fdc1772.h"
#include "Vfdc1772__Syms.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#define DUMP 1

#define STEPTEST 0
#define READTEST 1

Vfdc1772* top = NULL;
#if DUMP
VerilatedVcdC* tfp = NULL;
#endif

double time_ns = 0;
int dump_enable = 0;

#define MHZ2NS(a)  (1000000000.0/(a))
#define CLK        (32000000.0)

#define FLOPPY0    (top->fdc1772->fdd__BRA__0__KET____DOT__floppy)

void hexdump(void *data, int size) {
  int i, b2c, n=0;
  char *ptr = (char*)data;

  if(!size) return;

  while(size>0) {
    printf("  %04x: ", n);
    b2c = (size>16)?16:size;
    for(i=0;i<b2c;i++)      printf("%02x ", 0xff&ptr[i]);
    printf("  ");
    for(i=0;i<(16-b2c);i++) printf("   ");
    for(i=0;i<b2c;i++)      printf("%c", isprint(ptr[i])?ptr[i]:'.');
    printf("\n");
    ptr  += b2c;
    size -= b2c;
    n    += b2c;
  }
}

void eval(void) {
  // evaluate recent changes
  top->eval();
#if DUMP
  if(dump_enable) { 
    static int dump_cnt = 0;
    dump_cnt++;
    if(dump_cnt >= DUMP) {
      tfp->dump(time_ns);
      dump_cnt = 0;
    }
  }
#endif
}

char cpu_write_reg = -1;
unsigned char cpu_write_data;
char cpu_read_reg = -1;
unsigned char cpu_read_data;

// advance time and create valid 32 Mhz clock and signals
// derived from it 
void wait_ns(double n) {
  static double clk_time = 0;

  eval();

  // check if next clk event is within waiting period
  while(clk_time <= n) {
    time_ns += clk_time;    // advance time to next clk event
    n -= clk_time;          // reduce remainung waiting time

    // process change on clk 
    top->clkcpu = !top->clkcpu;

    // generate 8mhz clock
    static int clkdiv = 0;
    if(top->clkcpu) {
      clkdiv++;
      if(clkdiv == 4) {
	top->clk8m_en = 1;
	clkdiv = 0;
      } else
	top->clk8m_en = 0;
    }

    { static int cmd_rx = 0;
      if(top->fdc1772->cmd_rx && !cmd_rx)
	printf("[%.3f] New command %x\n", time_ns/1000000000, top->fdc1772->cmd);
      cmd_rx = top->fdc1772->cmd_rx;
    }

    { static int motor_on=0;
      static int rate=0;
      static double motor_on_time = 0;
      static double motor_off_time = 0;
      if(!motor_on && top->fdc1772->motor_on) {
	printf("[%.3f] \"motor on\" at %.3f RPM\n", time_ns/1000000000, 
	       300.0*FLOPPY0->rate/250000.0);
	motor_on_time = time_ns;
      }
      
      if(motor_on && !top->fdc1772->motor_on) {
	printf("[%.3f] \"motor off\" at %.3f RPM\n",  time_ns/1000000000, 
	       300.0*FLOPPY0->rate/250000.0);
	motor_off_time = time_ns;
      }
      
      motor_on = top->fdc1772->motor_on;
      
      if((FLOPPY0->rate == 250000)&&(rate != 250000)) {
	printf("[%.3f] Full RPM reached %.3fms after motor on\n",  time_ns/1000000000, 
	       (time_ns-motor_on_time)/1000000);
      }
      
      if((FLOPPY0->rate == 0)&&(rate != 0)) {
	printf("[%.3f] Disk stopped %.3fms after motor off\n",  time_ns/1000000000, 
	       (time_ns-motor_off_time)/1000000);
      }
      
      rate = FLOPPY0->rate;
      
#if 0
      { static int step_busy = 0;
	if(FLOPPY0->step_busy != step_busy) {
	  printf("[%.3f] Step busy now %d\n",  time_ns/1000000000,
		 FLOPPY0->step_busy);
	  step_busy = FLOPPY0->step_busy;
	}
      }
#endif
      
      static int ready=0;
      int top_ready = 
	(FLOPPY0->rate == 250000) && (FLOPPY0->step_busy == 0);
      if(top_ready != ready) {
	printf("[%.3f] Floppy becomes %sready\n",  time_ns/1000000000, 
	       top_ready?"":"not ");
	ready = top_ready;
      }

      static int firq=0;
      if(top->irq != firq) {
	printf("[%.3f] IRQ %s\n",  time_ns/1000000000, 
	       top->irq?"raised":"cleared");

	firq = top->irq;
      }

#if 0
      static int drq=0;
      if(top->drq != drq) {
	printf("[%.3f] DRQ %s\n",  time_ns/1000000000, 
	       top->drq?"raised":"cleared");

	drq = top->drq;
      }
#endif

#if 0
      static int step_in=0;
      if(top->fdc1772__DOT__step_in != step_in) {
	printf("[%.3f] step in %d\n",  time_ns/1000000000, 
	       top->fdc1772__DOT__step_in);
	step_in = top->fdc1772__DOT__step_in;
      }
#endif

      static int busy=0;
      if(top->fdc1772->busy != busy) {
	printf("[%.3f] fdc becomes %sbusy%s\n",  time_ns/1000000000, 
	       top->fdc1772->busy?"":"not ", 
	       top->fdc1772->busy?"":". command done");
	busy = top->fdc1772->busy;
      }
      
      static int motor_timeout_index = 0;
      if(top->fdc1772->motor_timeout_index != motor_timeout_index) {
        printf("[%.3f] Floppy motor timeout %d\n",  time_ns/1000000000, 
	top->fdc1772->motor_timeout_index);
      
	motor_timeout_index = top->fdc1772->motor_timeout_index;
      }
      
      static int track = 0;
      if(FLOPPY0->current_track != track) {
	printf("[%.3f] Track changed to %d\n",  time_ns/1000000000, 
	       FLOPPY0->current_track);
	track = FLOPPY0->current_track;
      }

      static int motor_spin_up_sequence = 0;
      if(top->fdc1772->motor_spin_up_sequence != motor_spin_up_sequence) {
 	printf("[%.3f] Motor spinup %d\n",  time_ns/1000000000, 
	       top->fdc1772->motor_spin_up_sequence);

        motor_spin_up_sequence = top->fdc1772->motor_spin_up_sequence;
      }
   }

    // things supposed to happen on rising clock edge
    if(!top->clkcpu) {
      if(top->cpu_sel && top->cpu_rw)
	cpu_read_data = top->cpu_dout;
    }

    if(top->clkcpu && clkdiv == 0) {
      // check for status 
      static unsigned long status = 0;
      static bool io_rd = false;
      static long data_tx_counter = 0;
      static int data_tx_state = 0;
      if(top->fdc1772->sd_rd != io_rd) {
	io_rd = top->fdc1772->sd_rd;
	
	printf("DIO: sd_rd changed to: %d\n", top->fdc1772->sd_rd);
	if(top->fdc1772->sd_rd) {
	      printf("DIO: READ SECTOR with empty fifo, starting 1k data\n");
	      data_tx_counter = 1024;
	      data_tx_state = 0;
	      top->sd_ack = 1;
	      top->sd_buff_addr = 0;
	}
      }
      
      // write something into the fifo
      if(data_tx_counter) {
	if(data_tx_state == 0) {
	  top->sd_dout = 1024 - data_tx_counter;
	  data_tx_state = 1;
	} else if(data_tx_state == 1) {
	  top->sd_dout_strobe = 1;
	  data_tx_state = 2;
	} else if(data_tx_state == 2) {
	  top->sd_dout_strobe = 0;
	  top->sd_buff_addr++;
	  data_tx_state = 3;
	  data_tx_counter--;
	  if(data_tx_counter == 0) top->sd_ack = 0;
	} else {
	  data_tx_state++;
	  if(data_tx_state == 10)
	    data_tx_state=0;
	}
      }
    }

    // handle cpu io    
    if(!top->clkcpu) {
      if(cpu_write_reg >= 0) {
	top->cpu_addr = cpu_write_reg;
	top->cpu_sel = 1;
	top->cpu_din = cpu_write_data;
	top->cpu_rw = 0;
	cpu_write_reg = -5;
      } else if(cpu_read_reg >= 0) {
	top->cpu_addr = cpu_read_reg;
	top->cpu_sel = 1;
	top->cpu_rw = 1;
	cpu_read_reg = -5;
      } else {
	if(cpu_read_reg < -1)
	  cpu_read_reg = cpu_read_reg + 1;
	else if(cpu_write_reg < -1)
	  cpu_write_reg = cpu_write_reg + 1;
	else {
	  top->cpu_sel = 0;
	  top->cpu_rw = 1;
	}
      }
    }

    eval();

    clk_time = MHZ2NS(CLK)/2.0; // next clk change in 62.5ns
  }

  // next event is when done waiting
  time_ns += n; // advance time
  clk_time -= n;
}

void wait_us(double n) {
  wait_ns(n * 1000.0);
}

void wait_ms(double n) {
  wait_us(n * 1000.0);
}

void cpu_write(char reg, unsigned char data) {
  cpu_write_reg = reg;
  cpu_write_data = data;
  wait_us(1);
}

unsigned char cpu_read(char reg) {
  cpu_read_reg = reg;
  wait_us(1);
  return cpu_read_data;
}

void track_expect(int t) {
  if((FLOPPY0->current_track != t)||
     (top->fdc1772->track != t)) {
    printf("Unexpected track position FLOPPY %d/FDC %d, expected %d \n",
	   FLOPPY0->current_track, top->fdc1772->track, t);
    exit(1);
  }
}	   

void read_sector(int track, int sector) {
  int i = 0;

  // read sector
  printf("READ_SECTOR\n");
  cpu_write(1, track);   // track 0
  cpu_write(2, sector);  // sector 0
  cpu_write(3, 0x00);  // data 0 ?
  cpu_write(0, 0x88);  // read sector, spinup

  // now DIO will be requested

  double start = time_ns;
    
  // reading the address should generate 6 drq's until a irq is generated
  while(!top->irq) {
    wait_ns(100);
    if(top->drq) {
      int data = cpu_read(3);
      
      if(data != (i&0xff))
	printf("data(%d) failed: is %02x, expected %02x\n", i, data, (i&0xff));

      if((i == 0)||(i == 1023))
	printf("@%.0fus data(%d): %02x\n", 
	       (time_ns - start)/1000, i, data);

      i++;
      start = time_ns;
    }
  }
  
  // read status to clear interrupt
  printf("READ_SECTOR done, status = %x\n", cpu_read(0));
}

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);
  // init top verilog instance
  top = new Vfdc1772;
  int i;

#if DUMP
  // init trace dump
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  top->trace (tfp, 99);
  tfp->open ("fdc1772.vcd");
#endif

  // initialize system inputs
  top->clkcpu = 1;

  // no cpu access
  top->cpu_sel = 0;

  // Select FD0
  top->floppy_drive = 0xe;
  top->floppy_side = 0;
  top->floppy_reset = 0;
  wait_ns(100);
  top->floppy_reset = 1;

  // mount an image in FD0
  top->img_mounted = 1;
  top->img_size = 100000;
  wait_ns(100);
  top->img_mounted = 0;

#if STEPTEST
  printf("============= STEP TESTS ==============\n");

  // start at track 10
  FLOPPY0->current_track = 10;

  wait_ns(100);

  printf("RESTORE\n");
  cpu_write(0, 0x0b);  // Restore, Motor on, 6ms
  // wait for end of command
  while(cpu_read(0) & 0x01)
    wait_ms(1);
  printf("RESTORE done\n");
  track_expect(0);

  wait_ms(500);

  printf("SEEK(5)\n");
  cpu_write(3, 5);     // Track 5
  cpu_write(0, 0x19);  // Seek, Motor on, 3ms
  // wait for end of command
  while(cpu_read(0) & 0x01)
    wait_ms(1);
  printf("SEEK(5) done\n");
  track_expect(5);

  wait_ms(500);

  printf("STEP_IN\n");
  cpu_write(0, 0x59);  // step_in, udpate track, Motor on, 3ms
  // wait for end of command
  while(cpu_read(0) & 0x01)
    wait_ms(1);
  printf("STEP_IN done\n");
  track_expect(6);

  wait_ms(500);

  printf("STEP\n");
  cpu_write(0, 0x39);  // step, udpate track, Motor on, 3ms
  // wait for end of command
  while(cpu_read(0) & 0x01)
    wait_ms(1);
  printf("STEP done\n");
  track_expect(7);

  wait_ms(500);

  printf("STEP_OUT\n");
  cpu_write(0, 0x79);  // step_out, udpate track, Motor on, 3ms
  // wait for end of command
  while(cpu_read(0) & 0x01)
    wait_ms(1);
  printf("STEP_OUT done\n");
  track_expect(6);

  wait_ms(3000);
#endif

#if READTEST

  // force disk to spin at full speed
  FLOPPY0->rate = 250000;
  FLOPPY0->current_track = 0;
  top->fdc1772->motor_on = 1;
  top->fdc1772->motor_spin_up_sequence = 0;
  top->fdc1772->motor_timeout_index = 5;

  dump_enable = 1;

  wait_ms(1);
  printf("FORCED_INTERRUPT(0)\n");
  cpu_write(0, 0xd0);
  wait_ms(1);
  printf("FORCED_INTERRUPT done\n");

  dump_enable = 0;

  wait_ms(10);

  for(i=0;i<1;i++) {
    printf("READ_ADDRESS %d\n", i);
    cpu_write(1, 0x00);  // track 0
    cpu_write(2, 0x00);  // sector 0
    cpu_write(3, 0x00);  // data 0 ?
    cpu_write(0, 0xcc);  // read address, spinup, 30ms settling delay
    
    double start = time_ns;
    
    // reading the address should generate 6 drq's until a irq is generated
    while(!top->irq) {
      wait_ns(100);
      if(top->drq) {
	printf("@%.0fus data: %02x\n", 
	       (time_ns - start)/1000, cpu_read(3));
	start = time_ns;
      }
    }

    // read status to clear interrupt
    printf("READ_ADDRESS done, status = %x\n", cpu_read(0));
  }

  read_sector(0,3);
  read_sector(0,4);
#endif

  printf("[%.3f] done\n",  time_ns/1000000000);

#if DUMP
  tfp->close();
#endif

  exit(0);
 }

