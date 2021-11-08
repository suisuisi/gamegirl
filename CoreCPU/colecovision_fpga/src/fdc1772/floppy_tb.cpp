#include "Vfloppy.h"
#include "Vfloppy_floppy.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#define SPINTEST 1   // test disk spinning up and down
#define STEPTEST 0   // test head stepping

#if SPINTEST
#define DUMP 10
#else
#define DUMP 1
#endif

Vfloppy* top = NULL;
#if DUMP
VerilatedVcdC* tfp = NULL;
#endif

double time_ns = 0;
int dump_enable = 0;

#define MHZ2NS(a)  (1000000000.0/(a))
#define CLK        (8000000.0)

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
  static int last_clk = 0;

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

  // eval on negedge of clk
  if(!top->clk && last_clk) {

    // ...
  }
  last_clk = top->clk;
}

// advance time and create valid 8 Mhz clock and signals
// derived from it 
void wait_ns(double n) {
  static double clk_time = 0;

  eval();

  // check if next clk event is within waiting period
  while(clk_time <= n) {
    time_ns += clk_time;    // advance time to next clk event
    n -= clk_time;          // reduce remainung waiting time

    // process change on clk 
    top->clk = !top->clk;

    // check if floppy index changed
    { static int last_index = 0;
      static double last_index_time = 0;
      if(top->index != last_index) {
	if(last_index_time > 0.001) {
	  double ev_time = (time_ns - last_index_time)/1000000;
	  if(!top->index) printf("RPM = %.3f\n", 60000/ev_time);
	  else            printf("Index pulse len = %.3fms\n", ev_time);
	}

	// index starts on falling edge
	if(!top->index) last_index_time = time_ns;

	last_index = top->index;
      }
    }

    { static int motor_on=0;
      static int rate=0;
      static double motor_on_time = 0;
      static double motor_off_time = 0;
      if(!motor_on && top->motor_on) {
	printf("motor on at %.3f RPM\n", 
	       300.0*top->floppy->rate/250000.0);
	motor_on_time = time_ns;
      }

      if(motor_on && !top->motor_on) {
	printf("motor off at %.3f RPM\n", 
	       300.0*top->floppy->rate/250000.0);
	motor_off_time = time_ns;
      }

      motor_on = top->motor_on;

      if((top->floppy->rate == 250000)&&(rate != 250000)) {
	printf("Full RPM reached %.3fms after motor on\n", 
	       (time_ns-motor_on_time)/1000000);
      }

      if((top->floppy->rate == 0)&&(rate != 0)) {
	printf("Disk stopped %.3fms after motor off\n", 
	       (time_ns-motor_off_time)/1000000);
      }

      rate = top->floppy->rate;
    }

    // things supposed to happen on rising clock edge
    if(top->clk) {
      

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

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);
  // init top verilog instance
  top = new Vfloppy;
  int i;

#if DUMP
  // init trace dump
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  top->trace (tfp, 99);
  tfp->open ("floppy.vcd");
#endif

  // initialize system inputs
  top->clk = 1;
  top->motor_on = 0;
  top->step_in = 0;
  top->step_out = 0;
  top->select = 0;
  top->clk8m_en = 1;

#if SPINTEST
  dump_enable = 1;

  // select after 1 ms
  wait_ms(1);
  top->select = 1;

  // start motor after 5 ms
  wait_ms(5);
  top->motor_on = 1;

  wait_ms(5*250);

  top->motor_on = 0;
  wait_ms(100);

  top->motor_on = 1;
  wait_ms(300);

  top->motor_on = 0;
  wait_ms(400);
#elif STEPTEST
  // start disk quietly
  top->motor_on = 1;
  top->select = 1;
  wait_ms(795);

  dump_enable = 1;

  wait_ms(10);
  for(i=0;i<5;i++) {
    // step signal 
    top->step_out = 1;
    wait_ms(1);
    top->step_out = 0;
    wait_ms(2);
  }

  wait_ms(215);

  //  wait_ms(215);
#else

#endif

#if DUMP
  tfp->close();
#endif

  exit(0);
 }

