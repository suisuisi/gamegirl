//
// sdram.v
//
// sdram controller implementation for the MiST board
// https://github.com/mist-devel/mist-board/wiki
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2019 Gyorgy Szombathelyi
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

module sdram (

	// interface to the MT48LC16M16 chip
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output     [12:0] SDRAM_A,    // 13 bit multiplexed address bus
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

	input      [15:0] cpu_din,
	input             cpu_port,
	output reg [15:0] cpu_port0,
	output reg [15:0] cpu_port1,
	input      [23:1] cpu_addr,
	input             cpu_req,
	output reg        cpu_req_ack,
	input       [1:0] cpu_ds,
	input             cpu_we,
	
	input      [19:0] bsram_addr,
	input       [7:0] bsram_din,
	output     [15:0] bsram_dout,
	input             bsram_req,
	output reg        bsram_req_ack,
	input             bsram_we,

	input      [19:1] bsram_io_addr,
	input      [15:0] bsram_io_din,
	output reg [15:0] bsram_io_dout,
	input             bsram_io_req,
	output reg        bsram_io_req_ack,
	input             bsram_io_we,

	input             vram1_req,
	output reg        vram1_ack,
	input      [14:0] vram1_addr,
	input       [7:0] vram1_din,
	output reg  [7:0] vram1_dout,
	input             vram1_we,

	input             vram2_req,
	output reg        vram2_ack,
	input      [14:0] vram2_addr,
	input       [7:0] vram2_din,
	output reg  [7:0] vram2_dout,
	input             vram2_we,

	input      [15:0] aram_addr,
	input       [7:0] aram_din,
	output reg [15:0] aram_dout,
	input             aram_req,
	output reg        aram_req_ack,
	input             aram_we
);

localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 3 cycles@128MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 
// 64ms/8192 rows = 7.8us -> 1000 cycles@128MHz
localparam RFRSH_CYCLES = 10'd1000;

// ---------------------------------------------------------------------
// ------------------------ sdram state machine ------------------------
// ---------------------------------------------------------------------

// SDRAM state machine for 3 bank interleaved access
//CL3
//0 RAS0                        DS2
//1           DATA1 available
//2           RAS1                                  
//3 CAS0                        DATA2 available
//4 DS0                         RAS2
//5           CAS1              
//6           DS1
//7 DATA0                       CAS2

//CL2
//0 RAS0
//1
//2 CAS0      DATA1
//3           RAS1
//4
//5 DATA0     CAS1

localparam STATE_RAS0      = 3'd0;   // first state in cycle
localparam STATE_RAS1      = 3'd2;   // Second ACTIVE command after RAS0 + tRRD (15ns)
localparam STATE_RAS2      = 3'd4;   // Third ACTIVE command after RAS0 + tRRD (15ns)
localparam STATE_CAS0      = STATE_RAS0 + RASCAS_DELAY; // CAS phase - 3
localparam STATE_CAS1      = STATE_RAS1 + RASCAS_DELAY; // CAS phase - 5
localparam STATE_CAS2      = STATE_RAS2 + RASCAS_DELAY; // CAS phase - 7
localparam STATE_DS0       = STATE_CAS0 + 1'd1;
localparam STATE_READ0     = 3'd0;//STATE_CAS0 + CAS_LATENCY + 1'd1;
localparam STATE_DS1       = STATE_CAS1 + 1'd1;
localparam STATE_READ1     = 3'd2;//3'd1;
localparam STATE_DS2       = 3'd0;
localparam STATE_READ2     = 3'd4;//3'd3;
localparam STATE_LAST      = 3'd7;  // last state in cycle

reg [2:0] t;

always @(posedge clk) begin
	reg clkref_d;
	clkref_d <= clkref;
	case (t)
		3'd0: t <= 3'd1;
		3'd1: t <= 3'd2;
		3'd2: t <= 3'd3;
		3'd3: t <= 3'd4;
		3'd4: t <= 3'd5;
		3'd5: t <= 3'd6;
		3'd6: t <= 3'd7;
		3'd7: t <= 3'd0;
	endcase

	if(~clkref_d && clkref && !oe_latch && !we_latch && !refresh && !init) t <= 3'd4;

end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0]  reset;
reg        init = 1'b1;
always @(posedge clk,negedge init_n) begin
	if(!init_n) begin
		reset <= 5'h1f;
		init <= 1'b1;
	end else begin
		if((t == STATE_LAST) && (reset != 0)) reset <= reset - 5'd1;
		init <= !(reset == 0);
	end
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

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
reg [12:0] sd_a;
reg [15:0] sd_din;

// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];
assign SDRAM_A    = sd_a;

reg [24:0] addr_latch[3];
reg [15:0] din_latch[3];
reg  [2:0] oe_latch;
reg  [2:0] we_latch;
reg  [1:0] ds[3];

localparam PORT_NONE  = 2'd0;

localparam PORT_CPU   = 2'd1;
localparam PORT_BSRAM = 2'd2;
localparam PORT_BSRAM_IO = 2'd3;

localparam PORT_ARAM  = 2'd1;

localparam PORT_VRAM  = 2'd1;
localparam PORT_VRAM1 = 2'd2;
localparam PORT_VRAM2 = 2'd3;

reg  [1:0] port[3];
reg  [1:0] next_port[3];
reg [24:0] next_addr[3];
reg [15:0] next_din[3];
reg  [1:0] next_ds[3];
reg  [2:0] next_we;
reg  [2:0] next_oe;

reg        refresh;
reg [10:0] refresh_cnt;
reg        need_refresh = 1'b0;

always @(posedge clk) begin

	if (refresh_cnt == 0)
		need_refresh <= 0;
	else if (refresh_cnt == RFRSH_CYCLES)
		need_refresh <= 1;

end

// ROM: bank 0,1
// WRAM, BSRAM: bank 1
always @(*) begin
	next_port[0] = PORT_NONE;
	next_addr[0] = 0;
	next_we[0] = 0;
	next_oe[0] = 0;
	next_ds[0] = 0;
	next_din[0] = 0;
	if (refresh) next_port[0] = PORT_NONE;
	else if (cpu_req ^ cpu_req_ack) begin
		next_port[0] = PORT_CPU;
		next_addr[0] = { 1'b0, cpu_addr, 1'b0 };
		next_din[0]  = cpu_din;
		next_ds[0]   = cpu_ds;
		next_we[0]   = cpu_we;
		next_oe[0]   = ~cpu_we;
	end else if (bsram_req ^ bsram_req_ack) begin
		next_port[0] = PORT_BSRAM;
		next_addr[0] = { 5'b01111, bsram_addr };
		next_din[0] = { bsram_din, bsram_din };
		next_ds[0] = {bsram_addr[0], ~bsram_addr[0]};
		next_we[0] = bsram_we;
		next_oe[0] = ~bsram_we;
	end else if (bsram_io_req ^ bsram_io_req_ack) begin
		next_port[0] = PORT_BSRAM_IO;
		next_addr[0] = { 5'b01111, bsram_io_addr, 1'b0 };
		next_we[0] = bsram_io_we;
		next_oe[0] = ~bsram_io_we;
		next_din[0] = bsram_io_din;
		next_ds[0] = 2'b11;
	end
end

// ARAM: bank 2
always @(posedge clk) begin
	next_port[1] <= PORT_NONE;
	next_addr[1] = 0;
	next_we[1] = 0;
	next_oe[1] = 0;
	next_ds[1] = 0;
	next_din[1] = 0;
	if (refresh) next_port[1] <= PORT_NONE;
	else if (aram_req ^ aram_req_ack) begin
		next_port[1] <= PORT_ARAM;
		next_addr[1] <= { 9'b101111000, aram_addr };
		next_we[1] <= aram_we;
		next_oe[1] <= ~aram_we;
		next_din[1] <= { aram_din, aram_din };
		next_ds[1] <= {aram_addr[0], ~aram_addr[0]};
	end
end

// VRAM: bank 3
always @(*) begin
	next_port[2] = PORT_NONE;
	next_addr[2] = 0;
	next_we[2] = 0;
	next_oe[2] = 0;
	next_din[2] = 0;
	next_ds[2] = 0;
	if ((vram1_req ^ vram1_ack) && (vram2_req ^ vram2_ack) && (vram1_addr == vram2_addr) && (vram1_we == vram2_we))
	begin
		// 16 bit VRAM access
		next_port[2] = PORT_VRAM;
		next_addr[2] = { 9'b111111100, vram1_addr, 1'b0 };
		next_we[2] = vram1_we;
		next_oe[2] = ~vram1_we;
		next_din[2] = { vram2_din, vram1_din };
		next_ds[2] = 2'b11;
	end else if (vram1_req ^ vram1_ack) begin
		next_port[2] = PORT_VRAM1;
		next_addr[2] = { 9'b111111100, vram1_addr, 1'b0 };
		next_we[2] = vram1_we;
		next_oe[2] = ~vram1_we;
		next_din[2] = { vram1_din, vram1_din };
		next_ds[2] = 2'b01;
	end else if (vram2_req ^ vram2_ack) begin
		next_port[2] = PORT_VRAM2;
		next_addr[2] = { 9'b111111100, vram2_addr, 1'b0 };
		next_we[2] = vram2_we;
		next_oe[2] = ~vram2_we;
		next_din[2] = { vram2_din, vram2_din };
		next_ds[2] = 2'b10;
	end
end

reg [15:0] bsram_dout_reg;
assign bsram_dout = (t == STATE_READ0 && oe_latch[0] && port[0] == PORT_BSRAM) ? sd_din : bsram_dout_reg;

always @(posedge clk) begin

	// permanently latch ram data to reduce delays
	sd_din <= SDRAM_DQ;
	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	sd_cmd <= CMD_INHIBIT;  // default: idle

	if(init) begin
		refresh <= 1'b0;
		refresh_cnt <= 0;

		// initialization takes place at the end of the reset phase
		if(t == STATE_RAS0) begin

			if(reset == 15) begin
				sd_cmd <= CMD_PRECHARGE;
				sd_a[10] <= 1'b1;      // precharge all banks
			end

			if(reset == 10 || reset == 8) begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end

			if(reset == 2) begin
				sd_cmd <= CMD_LOAD_MODE;
				sd_a <= MODE;
				SDRAM_BA <= 2'b00;
			end
		end
	end else begin

		refresh_cnt <= refresh_cnt + 1'd1;

		// RAS phase
		// bank 0,1 - ROM, WRAM
		if(t == STATE_RAS0) begin
			port[0] <= next_port[0];
			{ we_latch[0], oe_latch[0] } <= { next_we[0], next_oe[0] };
			addr_latch[0] <= next_addr[0];
			sd_a <= next_addr[0][22:10];
			SDRAM_BA <= next_addr[0][24:23];
			din_latch[0] <= next_din[0];
			ds[0] <= next_ds[0];
			if (next_port[0] != PORT_NONE) sd_cmd <= CMD_ACTIVE;
		end

		// bank 2 - ARAM
		if(t == STATE_RAS1) begin
			port[1] <= next_port[1];
			{ we_latch[1], oe_latch[1] } <= { next_we[1], next_oe[1] };
			addr_latch[1] <= next_addr[1];
			sd_a <= next_addr[1][22:10];
			SDRAM_BA <= 2'b10;
			din_latch[1] <= next_din[1];
			ds[1] <= next_ds[1];
			if (next_port[1] != PORT_NONE) sd_cmd <= CMD_ACTIVE;
		end

		// bank3 - VRAM
		if(t == STATE_RAS2) begin
			refresh <= 1'b0;

			port[2] <= next_port[2];
			{ we_latch[2], oe_latch[2] } <= { next_we[2], next_oe[2] };
			addr_latch[2] <= next_addr[2];
			sd_a <= next_addr[2][22:10];
			SDRAM_BA <= 2'b11;
			din_latch[2] <= next_din[2];
			ds[2] <= next_ds[2];
			if (next_port[2] != PORT_NONE) sd_cmd <= CMD_ACTIVE;
			else if (!we_latch[0] && !oe_latch[0] && !we_latch[1] && !oe_latch[1] && need_refresh) begin
				refresh <= 1'b1;
				refresh_cnt <= 0;
				sd_cmd <= CMD_AUTO_REFRESH;
			end
		end

		// CAS phase
		// ROM, WRAM
		if(t == STATE_CAS0 && (oe_latch[0] || we_latch[0])) begin
			sd_cmd <= we_latch[0]?CMD_WRITE:CMD_READ;
			if (we_latch[0]) begin
				SDRAM_DQ <= din_latch[0];
				{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[0];
			end
			sd_a <= { 4'b0010, addr_latch[0][9:1] };  // auto precharge
			SDRAM_BA <= addr_latch[0][24:23];
		end
		if(t == STATE_CAS0) begin
			case (port[0])
				PORT_CPU:   cpu_req_ack <= cpu_req;
				PORT_BSRAM: bsram_req_ack <= bsram_req;
				PORT_BSRAM_IO: bsram_io_req_ack <= bsram_io_req;
				default: ;
			endcase
		end

		// ARAM
		if(t == STATE_CAS1 && (oe_latch[1] || we_latch[1])) begin
			sd_cmd <= we_latch[1]?CMD_WRITE:CMD_READ;
			if (we_latch[1]) begin
				SDRAM_DQ <= din_latch[1];
				{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[1];
			end
			aram_req_ack <= aram_req;
			sd_a <= { 4'b0010, addr_latch[1][9:1] };  // auto precharge
			SDRAM_BA <= 2'b10;
		end

		// VRAM
		if(t == STATE_CAS2 && (oe_latch[2] || we_latch[2])) begin
			sd_cmd <= we_latch[2]?CMD_WRITE:CMD_READ;
			if (we_latch[2]) begin
				SDRAM_DQ <= din_latch[2];
				{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[2];
			end
			sd_a <= { 4'b0010, addr_latch[2][9:1] };  // auto precharge
			SDRAM_BA <= 2'b11;
		end
		if(t == STATE_CAS2) begin
			case (port[2])
				PORT_VRAM:   { vram1_ack, vram2_ack } <= { vram1_req, vram2_req };
				PORT_VRAM1:  vram1_ack <= vram1_req;
				PORT_VRAM2:  vram2_ack <= vram2_req;
				default: ;
			endcase
		end

		// read phase
		// ROM, WRAM, BSRAM
		if(t == STATE_DS0 && oe_latch[0]) { SDRAM_DQMH, SDRAM_DQML } <= 2'b00;
		if(t == STATE_READ0 && oe_latch[0]) begin
			case (port[0])
				PORT_CPU:   if (cpu_port) cpu_port1 <= sd_din; else cpu_port0 <= sd_din;
				PORT_BSRAM: bsram_dout_reg <= sd_din;
				PORT_BSRAM_IO: bsram_io_dout <= sd_din;
				default: ;
			endcase
		end

		// ARAM
		if(t == STATE_DS1 && oe_latch[1]) { SDRAM_DQMH, SDRAM_DQML } <= 2'b00;
		if(t == STATE_READ1 && oe_latch[1]) aram_dout <= sd_din;

		// VRAM
		if(t == STATE_DS2 && oe_latch[2]) { SDRAM_DQMH, SDRAM_DQML } <= 2'b00;
		if(t == STATE_READ2 && oe_latch[2]) begin
			case (port[2])
				PORT_VRAM: { vram2_dout, vram1_dout } <= sd_din;
				PORT_VRAM1: vram1_dout <= sd_din[7:0];
				PORT_VRAM2: vram2_dout <= sd_din[15:8];
				default: ;
			endcase
		end
		if(t == STATE_READ2 && we_latch[2]) begin
			case (port[2])
				PORT_VRAM: { vram2_dout, vram1_dout } <= din_latch[2];
				PORT_VRAM1: vram1_dout <= din_latch[2][7:0];
				PORT_VRAM2: vram2_dout <= din_latch[2][7:0];
				default: ;
			endcase
		end

	end
end

endmodule
