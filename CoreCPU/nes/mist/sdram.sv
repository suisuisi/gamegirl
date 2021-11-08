//
// sdram.v
//
// sdram controller implementation for the MiST board
// https://github.com/mist-devel/mist-board
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
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
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

	input [24:0]      addrA,      // 25 bit byte address
	input             weA,        // ppu requests write
	input [7:0]       dinA,       // data input from cpu
	input             oeA,        // ppu requests data
	output reg [7:0]  doutA,      // data output to cpu

	input [24:0]      addrB,      // 25 bit byte address
	input             weB,        // cpu requests write
	input [7:0]       dinB,       // data input from ppu
	input             oeB,        // cpu requests data
	output reg [7:0]  doutB,      // data output to ppu

	input [24:0]      addrC,      // 25 bit byte address
	input             oeweC,      // IO-controller any request
	input             weC,        // IO-controller requests write
	input [7:0]       dinC,       // data input from IO-controller
	output reg [7:0]  doutC       // data output to IO-controller
);

parameter  MHZ = 16'd80; // 80 MHz default clock, set it to proper value to calculate refresh rate

localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles@<100MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH};

// 64ms/8192 rows = 7.8us
localparam RFRSH_CYCLES = 16'd78*MHZ/4'd10;
// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

/*
 Simple SDRAM state machine
 1 word burst, CL2
cmd issued  registered
 0 RAS0
 1          ras0
 2 CAS0
 3          cas0
 4
 5          data0 returned
 6
*/

localparam STATE_RAS0      = 3'd0;   // first state in cycle
localparam STATE_CAS0      = STATE_RAS0 + RASCAS_DELAY; // CAS phase - 2
localparam STATE_READ0     = STATE_CAS0 + CAS_LATENCY + 2'd2; // 6
localparam STATE_LAST      = 3'd6;

reg [2:0] t;

always @(posedge clk) begin
	t <= t + 1'd1;
	if (t == STATE_LAST) t <= STATE_RAS0;
	if (t == STATE_RAS0 && !init && !reqA && !reqB && !reqC && !need_refresh) t <= STATE_RAS0;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0]  reset;
reg        init = 1'b1;
always @(posedge clk, negedge init_n) begin
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

reg [3:0]  sd_cmd;   // current command sent to sd ram

// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];

reg [24:0] addr_latch;
reg [15:0] din_latch;
reg        oe_latch;
reg        we_latch;
reg  [1:0] ds;

localparam IDLE = 2'd0;
localparam PORTA = 2'd1;
localparam PORTB = 2'd2;
localparam PORTC = 2'd3;

reg  [1:0] port;
reg [15:0] sd_data;

reg [10:0] refresh_cnt;
wire       need_refresh = (refresh_cnt >= RFRSH_CYCLES);

reg        oeA_d, weA_d;
reg        oeB_d, weB_d;
reg        oeweC_d;
wire       reqA = (~oeA_d & oeA) || (~weA_d & weA);
wire       reqB = (~oeB_d & oeB) || (~weB_d & weB);
wire       reqC = oeweC ^ oeweC_d;

always @(posedge clk) begin

	sd_data <= SDRAM_DQ;
	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	sd_cmd <= CMD_NOP;  // default: idle
	refresh_cnt <= refresh_cnt + 1'd1;

	if(init) begin
		// initialization takes place at the end of the reset phase
		refresh_cnt <= 0;
		if(t == STATE_RAS0) begin

			if(reset == 15) begin
				sd_cmd <= CMD_PRECHARGE;
				SDRAM_A[10] <= 1'b1;      // precharge all banks
			end

			if(reset == 10 || reset == 8) begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end

			if(reset == 2) begin
				sd_cmd <= CMD_LOAD_MODE;
				SDRAM_A <= MODE;
				SDRAM_BA <= 2'b00;
			end
		end
	end else begin
		// RAS phase
		if(t == STATE_RAS0) begin
			{ oe_latch, we_latch } <= 2'b00;
			port <= IDLE;

			oeA_d <= oeA_d & oeA; weA_d <= weA_d & weA;
			oeB_d <= oeB_d & oeB; weB_d <= weB_d & weB;
			oeweC_d <= oeweC;

			if (reqC) begin
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addrC[22:10];
				SDRAM_BA <= addrC[24:23];
				addr_latch <= addrC;
				{ oe_latch, we_latch } <= { ~weC, weC };
				ds <= { ~addrC[0], addrC[0] };
				din_latch <= { dinC, dinC };
				port <= PORTC;
			end else if (reqB) begin
				oeB_d <= oeB; weB_d <= weB;
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addrB[22:10];
				SDRAM_BA <= addrB[24:23];
				addr_latch <= addrB;
				{ oe_latch, we_latch } <= { oeB, weB };
				ds <= { ~addrB[0], addrB[0] };
				din_latch <= { dinB, dinB };
				port <= PORTB;
			end else if (reqA) begin
				oeA_d <= oeA; weA_d <= weA;
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addrA[22:10];
				SDRAM_BA <= addrA[24:23];
				addr_latch <= addrA;
				{ oe_latch, we_latch } <= { oeA, weA };
				ds <= { ~addrA[0], addrA[0] };
				din_latch <= { dinA, dinA };
				port <= PORTA;
			end else if (need_refresh) begin
				sd_cmd <= CMD_AUTO_REFRESH;
				refresh_cnt <= 0;
			end
		end

		// CAS phase
		if(t == STATE_CAS0 && (we_latch || oe_latch)) begin
			sd_cmd <= we_latch?CMD_WRITE:CMD_READ;
			{ SDRAM_DQMH, SDRAM_DQML } <= ~ds;
			if (we_latch) SDRAM_DQ <= din_latch;
			SDRAM_A <= { 4'b0010, addr_latch[9:1] };  // auto precharge
			SDRAM_BA <= addr_latch[24:23];
		end

		// Data returned
		if(t == STATE_READ0 && oe_latch) begin
			case(port)
			PORTA: doutA <= addr_latch[0] ? sd_data[7:0]:sd_data[15:8];
			PORTB: doutB <= addr_latch[0] ? sd_data[7:0]:sd_data[15:8];
			PORTC: doutC <= addr_latch[0] ? sd_data[7:0]:sd_data[15:8];
			default :;
			endcase
		end

	end
end

endmodule
