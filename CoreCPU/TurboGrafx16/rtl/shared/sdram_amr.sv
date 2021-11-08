//
// sdram.v
//
// sdram controller implementation for the MiST board
// https://github.com/mist-devel/mist-board
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2019 Gyorgy Szombathelyi
// Copyright (c) 2021 Alastair M. Robinson
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

// The following macros must be defined externally to describe the SDRAM chip:
// SDRAM_ROWBITS <13 in most cases>
// SDRAM_COLBITS <9 for 32 meg chips, 10 for 64 meg chips.>
// SDRAM_CL <2 or 3>
// SDRAM_tCKminCL2 <shortest cycle time allowed for CL2>
// SDRAM_tRC <Ref/Act to Ref/Act in ps>
// SDRAM_tWR <write recovery time in cycles>
// SDRAM_tRP <precharge time in ps>
//
// SDRAM_tCK <cycle time in ps> must be supplied as a parameter
// (Because it's project-specific, not board-specific.)
// If the core has a variable clock, specify the fastest rate.

// SDRAM_RISKCONTENTION <set to 1 to leave less space between reads and subsequent writes in CL3 mode.>
`define SDRAM_RISKCONTENTION 0

module sdram_amr #(parameter SDRAM_tCK=7800 )
(
	// interface to the MT48LC16M16 chip
	inout  [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [`SDRAM_ROWBITS-1:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // two byte masks
	output reg        SDRAM_DQMH, // two byte masks
	output reg [1:0]  SDRAM_BA,   // two banks
	output            SDRAM_nCS,  // a single chip select
	output            SDRAM_nWE,  // write enable
	output            SDRAM_nRAS, // row address select
	output            SDRAM_nCAS, // columns address select

	// cpu/chipset interface
	input             init_n,     // init signal after FPGA config to initialize RAM
	input             clk,        // sdram clock
	input             clkref,
	input             sync_en,

	input      [15:0] rom_din,
	output reg [15:0] rom_dout,
	input      [21:1] rom_addr,
	input             rom_req,
	output reg        rom_req_ack,
	input             rom_we,
	
	input      [21:0] wram_addr,
	input       [7:0] wram_din,
	output reg [15:0] wram_dout,
	input             wram_req,
	output reg        wram_req_ack,
	input             wram_we,

	input             vram0_req,
	output reg        vram0_ack,
	input      [15:1] vram0_addr,
	input      [15:0] vram0_din,
	output reg [15:0] vram0_dout,
	input             vram0_we,

	input             vram1_req,
	output reg        vram1_ack,
	input      [15:1] vram1_addr,
	input      [15:0] vram1_din,
	output reg [15:0] vram1_dout,
	input             vram1_we,

	input      [16:0] aram_addr,
	input       [7:0] aram_din,
	output reg [15:0] aram_dout,
	input             aram_req,
	output reg        aram_req_ack,
	input             aram_we
);

localparam BANK_DELAY = ((`SDRAM_tRC+(SDRAM_tCK-1))/SDRAM_tCK)-2; // tRC-2 in cycles (rounded up)
localparam BANK_WRITE_DELAY = ((`SDRAM_tRP+(SDRAM_tCK-1))/SDRAM_tCK)+`SDRAM_tWR; // tWR + tRP in cycles (rounded up)
localparam REFRESH_DELAY = ((`SDRAM_tRC+(SDRAM_tCK-1))/SDRAM_tCK)-1; // tRC-1 in cycles (rounded up)

`ifdef VERILATOR
initial begin
	if(SDRAM_tCK>=`SDRAM_tCKminCL2)
		$display("CL2 is allowed (max speed is %d)",1000000/`SDRAM_tCKminCL2);
	else if(`SDRAM_CL==2) begin
		$display("CL2 not allowed at %d MHz (max speed is %d)",1000000/SDRAM_tCK,1000000/`SDRAM_tCKminCL2);
		$stop;
	end
end
`endif

// RAM configuration

localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY = 3'd`SDRAM_CL; // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 


// RAM control signals

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg  [3:0] sd_cmd;   // current command sent to sd ram
reg  [1:0] sd_dqm;
reg [15:0] sd_din;

// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];
assign SDRAM_DQMH = sd_dqm[1];
assign SDRAM_DQML = sd_dqm[0];


// We use a multi-stage access pipeline like so:

// Read cycle - CL2, burst 1:
// |     RAS     |     CAS     |     MASK    |    LATCH    |     RAS     |     CAS     | ....
// | Act  | .... | .... | Read | .... | .... | Ltch | Act  | .... | .... | Read | .... 
//                                        <chip><high z>
//                                           < din reg'd >
//                                                   <data to port>

// Read cycle - CL3, burst 1:
// |     RAS     |     CAS     |     MASK    |    LATCH    |     ...     | RAS         |     CAS     |
// | Act  | .... | .... | Read | DQMs | .... | .... | Ltch | .... | Act  | .... | .... | Read | .... 
//                                               <chip><high z>
//                                                  < din reg'd >
//                                                         <data to port>

// Because RAS happens on even cycles, and CAS happens on odd cycles, reads to different banks
// can be overlapped - they just need to be 2 cycles apart:

// CL2

// |     RAS     |     CAS     |     MASK    |    LATCH    |     RAS     |     CAS     |
// | Act  | .... | .... | Read | .... | .... | Ltch | .... | Act  | .... | .... | Read | ....

// |     ...     |     RAS     |     CAS     |     MASK    |    LATCH    |     RAS     |
// | .... | .... | Act  | .... | .... | Read | .... | .... | Ltch | .... | Act  | .... | .... 

// |     ...     |     ...     |     RAS     |     CAS     |     MASK    |    LATCH    | ....
// | .... | .... | .... | .... | Act  | .... | .... | Read | .... | .... | Ltch | .... | Act


// CL3

// |     RAS     |     CAS     |     MASK    |    LATCH    |     ...     |     RAS     |     CAS     
// | Act  | .... | .... | Read | DQMs | .... | .... | Ltch | .... | .... | Act  | .... | .... | Read 

// |     ...     |     RAS     |     CAS     |     MASK    |    LATCH    |     ...     |     RAS     
// | .... | .... | Act  | .... | .... | Read | DQMs | .... | .... | Ltch | .... | .... | Act  | .... 

// |     ...     |     ...     |     RAS     |     CAS     |     MASK    |    LATCH    |     ...     
// | .... | .... | .... | .... | Act  | .... | .... | Read | DQMs | .... | .... | Ltch | .... | ....


// Data can be transferred on alternate cycles, until all four banks have been serviced.
// Read cycles in a single bank can be serviced every 8 cycles (CL2) or 10 cycles (CL3).

// Write cycles look like this:

// |     RAS     |     CAS     |     MASK    |    LATCH    |     RAS     |     CAS     | ....
// | Act  | .... | .... | Writ | .... | .... | .... | .... | Act  | .... | .... | Writ | .... 


// Write cycles can't immediately follow read cycles; two slots must be left empty
// in CL3 mode to avoid possible contention or mask clashes.

// Read to write cycle, CL3, Burst 1:

// |     RAS     |     CAS     |     MASK    |    LATCH    |     ...     |     RAS     |     
// | Act  | .... | .... | Read | DQMs | .... | .... | Ltch | .... | .... | ACT  | .... | .... 

// |     ...     |   (EMPTY)   |   (EMPTY)   |     RAS     |     CAS     |     MASK    |   
// | .... | .... | .... | .... | .... | .... | Act  | .... | .... | Writ | .... | .... | ....


// (In CL2 mode one empty slot should be sufficient, provided we're not using bursts.)

// Read to write cycle, CL2, Burst 1:

// |     RAS     |     CAS     |     MASK    |    LATCH    |     RAS     |     CAS     |
// | Act  | .... | .... | Read | .... | .... | Ltch | .... | Act  | .... | .... | Read | ....

// |     ...     |   (EMPTY)   |   (EMPTY)   |     RAS     |     CAS     |     MASK    |   
// | .... | .... | .... | .... | .... | .... | Act  | .... | .... | Writ | .... | .... | ....



// Write cycles can be followed immediately by either a read or a write cycle.



// Refresh logic

// Refresh cycles must be carefully timed so as not to disrupt
// regular accesses.  For VRAM we synchronise to the incoming
// reference pixel clock and supply a four-cycle window beginning
// shortly after clkref drops, during which refresh may begin.

reg evencycle;
reg clkref_d;
reg [2:0] refreshwindow;

always@(posedge clk) begin
	evencycle<=!evencycle;

	clkref_d<=clkref;
	if(clkref_d && !clkref) begin
			refreshwindow<=3'b001;
			evencycle<=1'b1;
	end
	if(|refreshwindow)
		refreshwindow<=refreshwindow-1'b1;
end

wire allowrefresh_vram = |refreshwindow;


// Time refreshes for CPU-originated requests so that they
// immediately follow a ROM request...

reg [3:0] romsync_ctr;
reg rom_req_d;
reg allowrefresh_rom;

reg [3:0] aramsync_ctr;
reg aram_req_d;
reg allowrefresh_aram;

always @(posedge clk or negedge init_n) begin
	if(!init_n) begin
		allowrefresh_rom<=1'b0;
		allowrefresh_aram<=1'b0;
	end else begin
		rom_req_d<=rom_req;
		if(|romsync_ctr)
			romsync_ctr<=romsync_ctr-1'b1;
		else
			allowrefresh_rom<=1'b0;

		if(rom_req_d!=rom_req) begin
			allowrefresh_rom<=1'b1;
			romsync_ctr<=4'hf;
		end

		aram_req_d<=aram_req;
		if(|aramsync_ctr)
			aramsync_ctr<=aramsync_ctr-1'b1;
		else
			allowrefresh_aram<=1'b0;

		if(aram_req_d!=aram_req) begin
			allowrefresh_aram<=1'b1;
			aramsync_ctr<=4'hf;
		end
	end
end

wire need_refresh[4];
wire force_refresh[4];

localparam bank0_rowbits=(22-`SDRAM_COLBITS); // 21 bits for ROM, 21 bits for WRAM
localparam bank1_rowbits=(16-`SDRAM_COLBITS);
localparam bank2_rowbits=(15-`SDRAM_COLBITS);
localparam bank3_rowbits=(15-`SDRAM_COLBITS);

reg [bank0_rowbits-1:0] refresh_addr_0;
reg [bank1_rowbits-1:0] refresh_addr_1;
reg [bank2_rowbits-1:0] refresh_addr_2;
reg [bank3_rowbits-1:0] refresh_addr_3;

refresh_schedule #(.tCK(SDRAM_tCK),.rowbits(bank0_rowbits)) refresh_bank0
(
	.clk(clk),
	.reset_n(init_n),
	.refreshing(cas2_port==PORT_REFRESH && cas_ba==2'b00 ? 1'b1 : 1'b0),
	.allow(allowrefresh_rom),
	.refresh_req(need_refresh[0]),
	.refresh_force(force_refresh[0]),
	.addr(refresh_addr_0)
);

refresh_schedule #(.tCK(SDRAM_tCK),.rowbits(bank1_rowbits)) refresh_bank1
(
	.clk(clk),
	.reset_n(init_n),
	.refreshing(cas2_port==PORT_REFRESH && cas_ba==2'b01 ? 1'b1 : 1'b0),
	.allow(allowrefresh_aram),
	.refresh_req(need_refresh[1]),
	.refresh_force(force_refresh[1]),
	.addr(refresh_addr_1)
);

refresh_schedule #(.tCK(SDRAM_tCK),.rowbits(bank2_rowbits)) refresh_bank2
(
	.clk(clk),
	.reset_n(init_n),
	.refreshing(cas2_port==PORT_REFRESH && cas_ba==2'b10 ? 1'b1 : 1'b0),
	.allow(allowrefresh_vram),
	.refresh_req(need_refresh[2]),
	.refresh_force(force_refresh[2]),
	.addr(refresh_addr_2)
);

refresh_schedule #(.tCK(SDRAM_tCK),.rowbits(bank3_rowbits)) refresh_bank3
(
	.clk(clk),
	.reset_n(init_n),
	.refreshing(cas2_port==PORT_REFRESH && cas_ba==2'b11 ? 1'b1 : 1'b0),
	.allow(allowrefresh_vram),
	.refresh_req(need_refresh[3]),
	.refresh_force(force_refresh[3]),
	.addr(refresh_addr_3)
);


// Bank logic.
// We take a bank-oriented rather than port-oriented view of the requests to be serviced.

reg [3:0] bankactive;
reg [4:0] bankbusy [4];
wire [3:0] bankready;

assign bankready[0]=bankbusy[0][4];	// Aliases for convenience
assign bankready[1]=bankbusy[1][4];
assign bankready[2]=bankbusy[2][4];
assign bankready[3]=bankbusy[3][4];


// Request handling and priority encoding

localparam PORT_NONE   = 4'd0;
localparam PORT_ROM    = 4'd1;
localparam PORT_WRAM   = 4'd2;
localparam PORT_VRAM0  = 4'd3;
localparam PORT_VRAM1  = 4'd4;
localparam PORT_ARAM   = 4'd5;
localparam PORT_REFRESH = 4'd6;

reg [3:0] bankreq;
reg [3:0] bankstate;
reg [3:0] bankwr;
reg [15:0] bankwrdata[4];
reg [3:0] bankport[4];
reg [23:1] bankaddr[4];
reg [1:0] bankdqm[4];


// Bank 0 priority encoder - ROM / ARAM
always @(posedge clk) begin
	if((!force_refresh[0]) && rom_req ^ port_state[PORT_ROM]) begin
		bankreq[0]<=1'b1;
		bankstate[0]<=rom_req;
		bankport[0]<=PORT_ROM;
		bankdqm[0]<={!rom_we,!rom_we};
		bankwrdata[0]<=rom_din;
		bankaddr[0]<={2'b00,rom_addr[21:1]};
		bankwr[0]<=rom_we;
	end else if ((!force_refresh[0]) && wram_req ^ port_state[PORT_WRAM]) begin
		bankreq[0]<=evencycle;
		bankstate[0]<=wram_req;
		bankport[0]<=PORT_WRAM;
		bankdqm[0]<=wram_we ? { ~wram_addr[0], wram_addr[0] } : 2'b11;
		bankaddr[0]<={2'b01,wram_addr[21:1]};
		bankwr[0]<=wram_we;
		bankwrdata[0]<={wram_din,wram_din};
	end else begin
		// Manual refresh logic on idle cycles
		bankreq[0]<=evencycle&need_refresh[0];// &! blockrefresh;
		bankwr[0]<=1'b0;
		bankstate[0]<=1'b0;
		bankdqm[0]<=2'b11;
		bankaddr[0][`SDRAM_COLBITS:1]<=rom_addr[`SDRAM_COLBITS:1]; // Don't care bits map to another port
		bankaddr[0][23:`SDRAM_COLBITS+1]<={1'b0,refresh_addr_0};//,{`SDRAM_COLBITS{1'b0}}};
		bankwr[0]<=1'b0;
		bankwrdata[0]<={wram_din,wram_din};
		bankport[0]<=PORT_REFRESH;
	end
end


// ARAM has Bank 1 to itself
always @(posedge clk) begin
	if ((!force_refresh[1]) && aram_req ^ port_state[PORT_ARAM]) begin
		bankdqm[1]<=aram_we ? { ~aram_addr[0], aram_addr[0] } : 2'b11;
		bankwrdata[1]<={aram_din,aram_din};
		bankreq[1]<=1'b1;
		bankstate[1]<=aram_req;
		bankport[1]<=PORT_ARAM;
		bankaddr[1]<={7'b0000001,aram_addr[16:1]};
		bankwr[1]<=aram_we;
	end else begin
		// Manual refresh logic on idle cycles
		bankreq[1]<=evencycle&need_refresh[1];// &! blockrefresh;
		bankstate[1]<=1'b0;
		bankaddr[1][`SDRAM_COLBITS:1]<=wram_addr[`SDRAM_COLBITS:1]; // Don't care bits map to another port
		bankaddr[1][23:`SDRAM_COLBITS+1]<={7'b0000001,refresh_addr_1};
		bankdqm[1]<=aram_we ? { ~aram_addr[0], aram_addr[0] } : 2'b11;
		bankwrdata[1]<={aram_din,aram_din};
		bankwr[1]<=1'b0;
		bankport[1]<=PORT_REFRESH;
	end
end

// VRAM0 occupies Bank 2
always @(posedge clk) begin
	bankwrdata[2]<=vram0_din;
	bankdqm[2]<={!vram0_we,!vram0_we};
	if((!force_refresh[2]) && vram0_req ^ port_state[PORT_VRAM0]) begin
		bankreq[2]<=vram0_req ^ port_state[PORT_VRAM0];
		bankstate[2]<=vram0_req;
		bankport[2]<=PORT_VRAM0;
		bankaddr[2]<={8'h00,vram0_addr};
		bankwr[2]<=vram0_we;
	end else begin
		// Manual refresh logic on idle cycles
		bankreq[2]<=need_refresh[2];
		bankstate[2]<=1'b0;
		bankaddr[2][`SDRAM_COLBITS:1]<=vram0_addr[`SDRAM_COLBITS:1]; // Don't care bits map to another port
		bankaddr[2][23:`SDRAM_COLBITS+1]<={8'h00,refresh_addr_2};
		bankwr[2]<=1'b0;
		bankport[2]<=PORT_REFRESH;
	end
end

// VRAM1 occupies Bank 3
always @(posedge clk) begin
	bankwrdata[3]<=vram1_din;
	bankdqm[3]<={!vram1_we,!vram1_we};
	if((!force_refresh[3]) && vram1_req ^ port_state[PORT_VRAM1]) begin
		bankreq[3]<=1'b1;
		bankstate[3]<=vram1_req;
		bankport[3]<=PORT_VRAM1;
		bankaddr[3]<={8'h00,vram1_addr};
		bankwr[3]<=vram1_we;
	end else begin
		// Manual refresh logic on idle cycles
		bankreq[3]<=need_refresh[3];
		bankstate[3]<=1'b0;
		bankaddr[3][`SDRAM_COLBITS:1]<=vram1_addr[`SDRAM_COLBITS:1]; // Don't care bits map to another port
		bankaddr[3][23:`SDRAM_COLBITS+1]<={8'h00,refresh_addr_3};
		bankwr[3]<=1'b0;
		bankport[3]<=PORT_REFRESH;
	end
end


// Keep track of when a write cycle is allowed.
// We can only write if the prevous 2 RAS slots weren't reads.
// (Unless we're running CL2, or we've taken care of timings to avoid contention.)

reg [1:0] readcycles;


// If VRAM wants to write we reserve a slot;
// other ports have to wait for the bus to be idle.

wire writepending_c;
reg writepending;
reg writeblocked;
reg reservewrite;

assign writepending_c = (vram0_we & (vram0_req ^ port_state[PORT_VRAM0]))
			| (vram1_we & (vram1_req ^ port_state[PORT_VRAM1]));

always @(posedge clk) begin
	writepending <= writepending_c;
	writeblocked <= |readcycles;
	reservewrite <= writepending & (|readcycles);
end


// Track the state of each port's req signal when most recently serviced

reg port_state[10];


// RAS stage

reg [1:0] ras_ba;
reg [`SDRAM_COLBITS-1:0] ras_casaddr;
reg ras_wr;
reg [15:0] ras_wrdata;
reg [1:0] ras_dqm;
reg [3:0] ras1_port;
reg ras1_act;
reg [3:0] ras2_port;
reg ras2_act;

// Cas stage

reg [3:0] cas1_port;
reg cas1_act;
reg [3:0] cas2_port;

reg [1:0] cas_ba;
reg [`SDRAM_ROWBITS-1:0] cas_addr;
reg cas_wr;
reg [15:0] cas_wrdata;
reg [1:0] cas_dqm;

// Mask stage

reg [3:0] mask1_port;
reg [3:0] mask2_port;
reg mask_wr;

// Latch stage

reg [3:0] latch1_port;
reg [3:0] latch2_port;

integer loopvar;

reg [15:0] dq_reg;
`ifdef VERILATOR
reg drive_dq;
assign SDRAM_DQ = drive_dq ? dq_reg : 16'bzzzzzzzzzzzzzzzz;
`else
assign SDRAM_DQ = dq_reg;
`endif

reg init = 1'b1;
reg [4:0] reset;


always @(posedge clk,negedge init_n) begin

	if(!init_n) begin
		sd_cmd<=CMD_INHIBIT;
		port_state[0]<=1'b0;
		port_state[1]<=1'b0;
		port_state[2]<=1'b0;
		port_state[3]<=1'b0;
		port_state[4]<=1'b0;
		port_state[5]<=1'b0;
		port_state[6]<=1'b0;
		port_state[7]<=1'b0;
		port_state[8]<=1'b0;
		port_state[9]<=1'b0;
		bankbusy[0]<=5'h7;
		bankbusy[1]<=5'h1f;
		bankbusy[2]<=5'h1f;
		bankbusy[3]<=5'h1f;
		init<=1'b1;
		reset<=5'd31;
	end else begin

		for(loopvar=0; loopvar<4; loopvar=loopvar+1) begin
			if(!bankready[loopvar])
				bankbusy[loopvar]<=bankbusy[loopvar]-4'b1;
		end

`ifndef VERILATOR
		dq_reg<=16'bZZZZZZZZZZZZZZZZ;
`endif

		SDRAM_A <= cas_addr;
		sd_dqm<=2'b11;
		
		if(init) begin
			// initialization takes place at the end of the reset phase
			sd_cmd<=CMD_INHIBIT;
			if(bankready[0]) begin
				case(reset)
					16: cas_addr[10]<=1'b1;	// Precharge all banks - set in advance to reduce address mux
					15: sd_cmd <= CMD_PRECHARGE;
					11: sd_cmd <= CMD_AUTO_REFRESH;
					10: sd_cmd <= CMD_AUTO_REFRESH;
					9: sd_cmd <= CMD_AUTO_REFRESH;
					8: sd_cmd <= CMD_AUTO_REFRESH;
					7: sd_cmd <= CMD_AUTO_REFRESH;
					6: sd_cmd <= CMD_AUTO_REFRESH;
					5: sd_cmd <= CMD_AUTO_REFRESH;
					4: sd_cmd <= CMD_AUTO_REFRESH;
					3: cas_addr <= MODE;	// Put the mode on the address bus in advance of the command.
					2: begin
						sd_cmd <= CMD_LOAD_MODE;
						SDRAM_BA <= 2'b00;
					end
				endcase

				reset<=reset-1'b1;
				bankbusy[0]<=BANK_DELAY[4:0];
				if(reset==0)
				begin
					init<=1'b0;
					bankbusy[0]<=0;
				end
			end
		end else begin

			// Request dispatching

`ifdef VERILATOR
			drive_dq<=1'b0;
`endif
			sd_cmd<=CMD_INHIBIT;
			// RAS stage
			ras1_port<=PORT_NONE;
			ras1_act<=1'b0;
			ras2_port<=ras1_port;
			ras2_act<=ras1_act;

			if(!ras1_act && !cas1_act) begin // Pick a bank and dispatch the command
				readcycles<={1'b0,readcycles[1]};
				ras_wr<=1'b0;
				ras_dqm<=2'b11;
				
				// First check and initiate refresh cycles if necessary.

				if(!reservewrite) begin
					// VRAM ports have priority
					if(bankreq[2] && bankready[2] && (!writepending || bankwr[2]) && !(writeblocked && bankwr[2])) begin
						// We have to block two subsequent write slots,
						// unless we're operating CL2 with burst 1,
						// in which case we only need to block 1
						readcycles[(`SDRAM_RISKCONTENTION || `SDRAM_CL==2) && BURST_LENGTH==3'b000 ? 0 : 1]<=~bankwr[2];

						port_state[bankport[2]]<=bankstate[2];
						bankbusy[2]<=BANK_DELAY[4:0];
						ras_ba<=2'b10;
						ras_casaddr<=bankaddr[2][`SDRAM_COLBITS:1];
						ras_wr<=bankwr[2];
						ras_wrdata<=bankwrdata[2];
						ras_dqm<=bankdqm[2];
						ras1_port<=bankport[2];
						ras1_act<=1'b1;

						sd_cmd<=CMD_ACTIVE;
						SDRAM_A <= bankaddr[2][`SDRAM_ROWBITS+`SDRAM_COLBITS:`SDRAM_COLBITS+1];
						SDRAM_BA <= 2'b10;
					end else if(bankreq[3] && bankready[3] && (!writepending || bankwr[3]) && !(writeblocked && bankwr[3])) begin
						readcycles[(`SDRAM_RISKCONTENTION || `SDRAM_CL==2) && BURST_LENGTH==3'b000 ? 0 : 1]<=~bankwr[3];
						port_state[bankport[3]]<=bankstate[3];
						bankbusy[3]<=BANK_DELAY[4:0];
						ras_ba<=2'b11;
						ras_casaddr<=bankaddr[3][`SDRAM_COLBITS:1];
						ras_wr<=bankwr[3];
						ras_wrdata<=bankwrdata[3];
						ras_dqm<=bankdqm[3];
						ras1_port<=bankport[3];
						ras1_act<=1'b1;

						sd_cmd<=CMD_ACTIVE;
						SDRAM_A <= bankaddr[3][`SDRAM_ROWBITS+`SDRAM_COLBITS:`SDRAM_COLBITS+1];
						SDRAM_BA <= 2'b11;
					end else if(bankreq[0] && bankready[0] && (!writepending || bankwr[0]) && !(writeblocked && bankwr[0])) begin
						readcycles[(`SDRAM_RISKCONTENTION || `SDRAM_CL==2) && BURST_LENGTH==3'b000 ? 0 : 1]<=~bankwr[0];
						port_state[bankport[0]]<=bankstate[0];
						bankbusy[0]<=BANK_DELAY[4:0];
						ras_ba<=2'b00;
						ras_casaddr<=bankaddr[0][`SDRAM_COLBITS:1];
						ras_wr<=bankwr[0];
						ras_wrdata<=bankwrdata[0];
						ras_dqm<=bankdqm[0];
						ras1_port<=bankport[0];
						ras1_act<=1'b1;

						sd_cmd<=CMD_ACTIVE;
						SDRAM_A <= bankaddr[0][`SDRAM_ROWBITS+`SDRAM_COLBITS:`SDRAM_COLBITS+1];
						SDRAM_BA <= 2'b00;
					end else if(bankreq[1] && bankready[1] && (!writepending || bankwr[1]) && !(writeblocked && bankwr[1])) begin
						readcycles[(`SDRAM_RISKCONTENTION || `SDRAM_CL==2) && BURST_LENGTH==3'b000 ? 0 : 1]<=~bankwr[1];
						port_state[bankport[1]]<=bankstate[1];
						bankbusy[1]<=BANK_DELAY[4:0];
						ras_ba<=2'b01;
						ras_casaddr<=bankaddr[1][`SDRAM_COLBITS:1];
						ras_wr<=bankwr[1];
						ras_wrdata<=bankwrdata[1];
						ras_dqm<=bankdqm[1];
						ras1_port<=bankport[1];
						ras1_act<=1'b1;

						sd_cmd<=CMD_ACTIVE;
						SDRAM_A <= bankaddr[1][`SDRAM_ROWBITS+`SDRAM_COLBITS:`SDRAM_COLBITS+1];
						SDRAM_BA <= 2'b01;
					end
				end
			end

			if(ras2_port != PORT_NONE) begin 
				cas_addr<={`SDRAM_ROWBITS{1'b0}};
				cas_addr[10]<=1'b1; // Auto-precharge
				cas_addr[`SDRAM_COLBITS-1:0]<=ras_casaddr;
				cas_wr<=ras_wr;
				cas_dqm<=ras_dqm;
				cas_wrdata<=ras_wrdata;
				cas_ba<=ras_ba;
			end
			cas1_port<=ras2_port;
			cas1_act<=ras2_act;

		// CAS stage

			if(cas1_port != PORT_NONE) begin 
				// Action the CAS command, if any
				SDRAM_BA <= cas_ba;
				if(cas_wr) begin
					sd_cmd<=CMD_WRITE;
					bankbusy[cas_ba]<=BANK_WRITE_DELAY[4:0];
`ifdef VERILATOR
					drive_dq<=1'b1;
`endif
					dq_reg <= cas_wrdata;
					sd_dqm<=cas_dqm;
				end else begin
					sd_cmd<=CMD_READ;
					if(`SDRAM_CL==2)
						sd_dqm<=2'b00; // Enable DQs for first word of a read, if any
				end
			end

			cas2_port<=cas1_port;

			if(cas2_port!=PORT_NONE && !cas_wr && `SDRAM_CL==3)	// Enable DQs for reads if CL3
				sd_dqm<=2'b00;

			// Pump the pipeline.  Write cycles finish here, read cycles continue.

			if(`SDRAM_CL==2) begin
				mask2_port<=mask_wr ? PORT_NONE : cas2_port;
				mask_wr<=cas_wr;
			end else begin
				mask1_port<=cas2_port;
				mask_wr<=cas_wr;

				mask2_port<=mask_wr ? PORT_NONE : mask1_port;
			end
			// Latch stage

			latch1_port<=mask2_port;
		end
	end
end


// Acknowledge requests

reg [15:0] vram0_dout_r;
reg [15:0] vram1_dout_r;
reg [15:0] rom_dout_r;
reg [15:0] aram_dout_r;
reg [15:0] wram_dout_r;

assign vram0_dout=latch2_port == PORT_VRAM0 ? sd_din : vram0_dout_r;
assign vram1_dout=latch2_port == PORT_VRAM1 ? sd_din : vram1_dout_r;
assign rom_dout=latch2_port == PORT_ROM ? sd_din : rom_dout_r;
assign aram_dout=latch2_port == PORT_ARAM ? sd_din : aram_dout_r;
assign wram_dout=latch2_port == PORT_WRAM ? sd_din : wram_dout_r;

always @(posedge clk, negedge init_n) begin

	if(!init_n) begin
		rom_req_ack <= 1'b0;
		wram_req_ack <= 1'b0;
		vram0_ack <= 1'b0;
		vram1_ack <= 1'b0;
		aram_req_ack <= 1'b0;
	end else begin

		sd_din<=SDRAM_DQ;

		// Acknowledge writes
		// We also mirror the port inputs to outputs here.
		// (Required for some TGfx16 games)
		if(ras_wr) begin
			case (ras2_port)
				PORT_ROM: rom_req_ack <= rom_req;
				PORT_WRAM: wram_req_ack <= wram_req;
				PORT_VRAM0: vram0_ack <= vram0_req;
				PORT_VRAM1: vram1_ack <= vram1_req;
				PORT_ARAM: aram_req_ack <= aram_req;
				default: ;
			endcase
		end

		// Early ack for READs (writes acked anyway, so no need to bother filtering them out.)
		if(`SDRAM_CL==2) begin
			case (ras1_port)
				PORT_VRAM0: vram0_ack <= vram0_req;
				PORT_VRAM1: vram1_ack <= vram1_req;
				default: ;
			endcase
		end else begin
			case (ras2_port)
				PORT_VRAM0: vram0_ack <= vram0_req;
				PORT_VRAM1: vram1_ack <= vram1_req;
				default: ;
			endcase
		end
		latch2_port<=latch1_port;

		case (latch1_port)
			PORT_ROM:	rom_req_ack <= rom_req;
			PORT_ARAM:	aram_req_ack <= aram_req;
			PORT_WRAM:	wram_req_ack <= wram_req;
//			PORT_VRAM0:	vram0_ack <= vram0_req; //Ack'ed early
//			PORT_VRAM1:	vram1_ack <= vram1_req;
			default: ;
		endcase

		case (latch2_port)
			PORT_ROM:	rom_dout_r <= sd_din;
			PORT_ARAM:	aram_dout_r <= sd_din;
			PORT_WRAM:	wram_dout_r <= sd_din;
			PORT_VRAM0:	vram0_dout_r <= sd_din;
			PORT_VRAM1:	vram1_dout_r <= sd_din;
			default: ;
		endcase
	
		// Mirror input ports to output on write

		if (aram_we && (aram_req ^ port_state[PORT_ARAM])) begin
			if (aram_addr[0])
				aram_dout_r[15:8] <= aram_din;
			else
				aram_dout_r[7:0] <= aram_din;
		end

		if (wram_we && (wram_req ^ port_state[PORT_WRAM])) begin
			if (wram_addr[0])
				wram_dout_r[15:8] <= wram_din;
			else
				wram_dout_r[7:0] <= wram_din;
		end

		if (vram0_we && (vram0_req ^ port_state[PORT_VRAM0]))
			vram0_dout_r <= vram0_din;

		if (vram1_we && (vram1_req ^ port_state[PORT_VRAM1]))
			vram1_dout_r <= vram1_din;
	
	end
end

endmodule


module refresh_schedule #(parameter tCK=7813, parameter tREF=64, parameter rowbits=13)
(
	input clk,
	input reset_n,
	input refreshing,
	input allow,
	output refresh_req,
	output refresh_force,
	output [rowbits-1:0] addr
);

// Refresh timing: (2*rowbits) refreshes = tREF milliseconds
// 1 refresh = tREF/(2**rowbit) ms
// 1 ms = 10^9 / tCK cycles
// 1 refresh = (10^9*tREF)/(tCK * 2**rowbit) cycles;
localparam khz = (10**9)/tCK;
localparam ticksperrefresh = (khz*tREF)/(2**rowbits)-2;
localparam forcetime = ticksperrefresh-4;
reg [19:0] refresh_count;
reg need_refresh;
reg force_refresh;

reg [rowbits-1:0] addr_r;

assign refresh_req=(allow & need_refresh) | force_refresh;
assign refresh_force=force_refresh;

always @(posedge clk or negedge reset_n) begin
	if(!reset_n) begin
		addr_r<={rowbits{1'b0}};
		refresh_count<=20'b0;
`ifdef VERILATOR
		$display("%m : tpr %d",ticksperrefresh);
`endif
	end else begin
		refresh_count<=refresh_count+1'b1;

		if(refreshing) begin
			need_refresh<=1'b0;
			force_refresh<=1'b0;
			addr_r<=addr_r+1'b1;
		end

		if(refresh_count==ticksperrefresh) begin
			need_refresh<=1'b1;
			refresh_count<=20'b0;
		end

		if(refresh_count==forcetime) begin
			force_refresh<=need_refresh;
		end
	end
end

assign addr=addr_r;

endmodule
