//
// sdram.v
//
// sdram controller implementation for the MiST board
// https://github.com/mist-devel/mist-board
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2019-2021 Gyorgy Szombathelyi
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

	input             romwr_req,
	output reg        romwr_ack,
	input      [23:1] romwr_a,
	input      [15:0] romwr_d,

	input             romrd_req,
	output reg        romrd_ack,
	input      [23:1] romrd_a,
	output     [15:0] romrd_q,

	input             ram68k_req,
	output reg        ram68k_ack,
	input             ram68k_we,
	input      [15:1] ram68k_a,
	input      [15:0] ram68k_d,
	output     [15:0] ram68k_q,
	input             ram68k_u_n,
	input             ram68k_l_n,

	input             sram_req,
	output reg        sram_ack,
	input             sram_we,
	input      [15:1] sram_a,
	input      [15:0] sram_d,
	output     [15:0] sram_q,
	input             sram_u_n,
	input             sram_l_n,

	input             vram_req,
	output reg        vram_ack,
	input             vram_we,
	input      [15:1] vram_a,
	input      [15:0] vram_d,
	output     [15:0] vram_q,
	input             vram_u_n,
	input             vram_l_n,

	input             vram32_req,
	output reg        vram32_ack,
	input      [15:1] vram32_a,
	output     [31:0] vram32_q,

	input             svp_ram1_req,
	output reg        svp_ram1_ack,
	input             svp_ram1_we,
	input      [16:1] svp_ram1_a,
	input      [15:0] svp_ram1_d,
	output     [15:0] svp_ram1_q,

	input             svp_ram2_req,
	output reg        svp_ram2_ack,
	input             svp_ram2_we,
	input      [16:1] svp_ram2_a,
	input      [15:0] svp_ram2_d,
	output     [15:0] svp_ram2_q,
	input             svp_ram2_u_n,
	input             svp_ram2_l_n,

	input             svp_rom_req,
	output reg        svp_rom_ack,
	input      [23:1] svp_rom_a,
	output     [15:0] svp_rom_q
);

localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 3 cycles@108MHz
localparam BURST_LENGTH   = 3'b001; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// 64ms/8192 rows = 7.8us -> 842 cycles@108MHz
localparam RFRSH_CYCLES = 11'd842;

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

/*
 SDRAM state machine for 2 bank interleaved access
 2 words burst, CL3
cmd issued  registered
 0 RAS0,DS1 cas1
 1 (DS1b)   ras0, ds1
 2          (ds1b - mask the second word, so cas0 can take over)
 3 CAS0     data1
 4 RAS1,DS0 cas0
 5 DS0b     ds0
 6
 7          data0 available (ds0 effective)
 8 CAS1     data0 available (ds0b effective)
*/

//CL2
//0 RAS0
//1
//2 RAS1
//3 CAS0 DS0
//4 CAS1 DS1
//5 DS1b
//6 DATA0
//7 DATA1
//8 DATA1

localparam STATE_RAS0      = 4'd0;   // first state in cycle
localparam STATE_RAS1      = 4'd4;   // Second ACTIVE command after RAS0 + tRRD (15ns)
localparam STATE_CAS0      = STATE_RAS0 + RASCAS_DELAY; // CAS phase - 3
localparam STATE_CAS1      = 4'd8;   //STATE_RAS1 + RASCAS_DELAY; // CAS phase - 5
localparam STATE_DS0       = STATE_CAS0 + 1'd1; // 4
localparam STATE_DS0b      = STATE_CAS0 + 4'd2; // 5
localparam STATE_READ0     = STATE_CAS0 + CAS_LATENCY + 4'd2; // 8
localparam STATE_READ0b    = 4'd0;   //STATE_CAS0 + CAS_LATENCY + 2'd3; // 0
localparam STATE_DS1       = 4'd0;   //STATE_CAS1 + 1'd1; // 0
//localparam STATE_DS1b      = STATE_CAS1 + 2'd2; // not used
localparam STATE_READ1     = 4'd4;
//localparam STATE_READ1b    = 4'd5; // not used
localparam STATE_LAST      = 4'd8;

reg [3:0] t;

always @(posedge clk) begin
	t <= t + 1'd1;
	if (t == 4'd4 && !oe_latch[1] && !we_latch[1] && next_port[0] == PORT_NONE && !refresh && !init) t <= STATE_RAS0;
	if (t == STATE_LAST) t <= STATE_RAS0;
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

reg  [3:0] sd_cmd;   // current command sent to sd ram
reg [15:0] sd_din;
// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];

reg [24:1] addr_latch[2];
reg [24:1] addr_latch_next[2];
reg [15:0] din_latch[2];
reg [15:0] din_next[2];
reg  [1:0] oe_latch, oe_next;
reg  [1:0] we_latch, we_next;
reg  [1:0] ds[2], ds_next[2];

localparam PORT_NONE   = 4'd0;
localparam PORT_SRAM   = 4'd1;
localparam PORT_ROM    = 4'd2;
localparam PORT_RAM68K = 4'd3;
localparam PORT_VRAM   = 4'd4;
localparam PORT_VRAM32 = 4'd5;
localparam PORT_SVP1   = 4'd6;
localparam PORT_SVP2   = 4'd7;
localparam PORT_SVPROM = 4'd8;
localparam PORT_ROMWR  = 4'd9;

reg        port_state[10];
reg  [3:0] port[2];
reg  [3:0] next_port[2];

reg        refresh;
reg [10:0] refresh_cnt;
wire       need_refresh = (refresh_cnt >= RFRSH_CYCLES);

// ROM: bank 0,1
// SRAM, RAM68k, SVPRAM: bank 2
always @(*) begin
	din_next[0] = 0;
	if (refresh) begin
		next_port[0] = PORT_NONE;
		addr_latch_next[0] = addr_latch[0];
		{ oe_next[0], we_next[0] } = 0;
		ds_next[0] = 0;
	end else if (sram_req ^ port_state[PORT_SRAM]) begin
		next_port[0] = PORT_SRAM;
		addr_latch_next[0] = { 9'b101111111, sram_a };
		{ oe_next[0], we_next[0] } = { ~sram_we, sram_we };
		ds_next[0] = { ~sram_u_n, ~sram_l_n };
		din_next[0] = sram_d;
	end else if (romwr_req ^ port_state[PORT_ROMWR]) begin
		next_port[0] = PORT_ROMWR;
		addr_latch_next[0] = { 1'b0, romwr_a };
		{ oe_next[0], we_next[0] } = 2'b01;
		ds_next[0] = 2'b11;
		din_next[0] = romwr_d;
	end else if (romrd_req ^ port_state[PORT_ROM]) begin
		next_port[0] = PORT_ROM;
		addr_latch_next[0] = { 1'b0, romrd_a };
		{ oe_next[0], we_next[0] } = 2'b10;
		ds_next[0] = 2'b11;
	end else if (ram68k_req ^ port_state[PORT_RAM68K]) begin
		next_port[0] = PORT_RAM68K;
		addr_latch_next[0] = { 9'b101111110, ram68k_a };
		{ oe_next[0], we_next[0] } = { ~ram68k_we, ram68k_we };
		ds_next[0] = { ~ram68k_u_n, ~ram68k_l_n };
		din_next[0] = ram68k_d;
	end else if (svp_ram1_req ^ port_state[PORT_SVP1]) begin
		next_port[0] = PORT_SVP1;
		addr_latch_next[0] = { 8'b10111110, svp_ram1_a };
		{ oe_next[0], we_next[0] } = { ~svp_ram1_we, svp_ram1_we };
		ds_next[0] = 2'b11;
		din_next[0] = svp_ram1_d;
	end else if (svp_ram2_req ^ port_state[PORT_SVP2]) begin
		next_port[0] = PORT_SVP2;
		addr_latch_next[0] = { 8'b10111110, svp_ram2_a };
		{ oe_next[0], we_next[0] } = { ~svp_ram2_we, svp_ram2_we };
		ds_next[0] = { ~svp_ram2_u_n, ~svp_ram2_l_n };
		din_next[0] = svp_ram2_d;
	end else if (svp_rom_req ^ port_state[PORT_SVPROM]) begin
		next_port[0] = PORT_SVPROM;
		addr_latch_next[0] = { 1'b0, svp_rom_a };
		{ oe_next[0], we_next[0] } = 2'b10;
		ds_next[0] = 2'b11;
	end else begin
		next_port[0] = PORT_NONE;
		addr_latch_next[0] = addr_latch[0];
		{ oe_next[0], we_next[0] } = 0;
		ds_next[0] = 0;
	end
end

// VRAM only: bank 3
always @(*) begin
	if (vram_req ^ port_state[PORT_VRAM]) begin
		next_port[1] = PORT_VRAM;
		addr_latch_next[1] = { 9'b111111111, vram_a };
		{ oe_next[1], we_next[1] } = { ~vram_we, vram_we };
		ds_next[1] = { ~vram_u_n, ~vram_l_n };
	end else if (vram32_req ^ port_state[PORT_VRAM32]) begin
		next_port[1] = PORT_VRAM32;
		addr_latch_next[1] = { 9'b111111111, vram32_a };
		{ oe_next[1], we_next[1] } = 2'b10;
		ds_next[1] = 2'b11;
	end else begin
		next_port[1] = PORT_NONE;
		addr_latch_next[1] = addr_latch[1];
		{ oe_next[1], we_next[1] } = 0;
		ds_next[1] = 0;
	end
end

reg drive_dq;
reg [15:0] dq_out;
assign SDRAM_DQ = drive_dq ? dq_out : 16'bZZZZZZZZZZZZZZZZ;

always @(posedge clk) begin

	// permanently latch ram data to allow inferring fast input register
	sd_din <= SDRAM_DQ;
	drive_dq <= 0;
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	sd_cmd <= CMD_NOP;  // default: idle
	refresh_cnt <= refresh_cnt + 1'd1;

	if(init) begin
		// initialization takes place at the end of the reset phase
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
		// bank 0,1,2
		if(t == STATE_RAS1) begin
			port[0] <= next_port[0];
			addr_latch[0] <= addr_latch_next[0];
			{ oe_latch[0], we_latch[0] } <= { oe_next[0], we_next[0] };
			ds[0] <= ds_next[0];
			din_latch[0] <= din_next[0];
			if (next_port[0] != PORT_NONE) begin
				port_state[next_port[0]] <= ~port_state[next_port[0]];
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addr_latch_next[0][22:10];
				SDRAM_BA <= addr_latch_next[0][24:23];
			end
		end

		// bank3 - VRAM
		if(t == STATE_RAS0) begin
			refresh <= 1'b0;
			port[1] <= next_port[1];
			addr_latch[1] <= addr_latch_next[1];
			{ oe_latch[1], we_latch[1] } <= { oe_next[1], we_next[1] };
			ds[1] <= ds_next[1];
			din_latch[1] <= vram_d;
			if (next_port[1] != PORT_NONE) begin
				port_state[next_port[1]] <= ~port_state[next_port[1]];
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addr_latch_next[1][22:10];
				SDRAM_BA <= addr_latch_next[1][24:23];
			end

			if (next_port[1] == PORT_NONE && need_refresh && !we_latch[0] && !oe_latch[0]) begin
				refresh <= 1'b1;
				refresh_cnt <= 0;
				sd_cmd <= CMD_AUTO_REFRESH;
			end
		end

		// CAS phase
		if(t == STATE_CAS1 && (we_latch[0] || oe_latch[0])) begin
			sd_cmd <= we_latch[0]?CMD_WRITE:CMD_READ;
			if (we_latch[0]) begin
				drive_dq <= 1'b1;
				dq_out <= din_latch[0];
				{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[0];
				case (port[0])
					PORT_ROMWR:  romwr_ack <= romwr_req;
					PORT_SRAM:   sram_ack <= sram_req;
					PORT_RAM68K: ram68k_ack <= ram68k_req;
					PORT_SVP1:   svp_ram1_ack <= svp_ram1_req;
					PORT_SVP2:   svp_ram2_ack <= svp_ram2_req;
					default: ;
				endcase
			end
			SDRAM_A <= { 4'b0010, addr_latch[0][9:1] };  // auto precharge
			SDRAM_BA <= addr_latch[0][24:23];
		end

		// VRAM only
		if(t == STATE_CAS0 && (we_latch[1] || oe_latch[1])) begin
			sd_cmd <= we_latch[1]?CMD_WRITE:CMD_READ;
			if (we_latch[1]) begin
				drive_dq <= 1'b1;
				dq_out <= din_latch[1];
				{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[1];
				if (port[1] == PORT_VRAM) vram_ack <= vram_req;
			end
			SDRAM_A <= { 4'b0010, addr_latch[1][9:1] };  // auto precharge
			SDRAM_BA <= addr_latch[1][24:23];
		end

		// read phase
		if(t == STATE_DS1 && oe_latch[0]) { SDRAM_DQMH, SDRAM_DQML } <= ~ds[0];

		if(t == STATE_READ1 && oe_latch[0]) begin
			case (port[0])
				PORT_ROM:    begin romrd_q    <= sd_din; romrd_ack <= romrd_req;       end
				PORT_RAM68K: begin ram68k_q   <= sd_din; ram68k_ack <= ram68k_req;     end
				PORT_SRAM:   begin sram_q     <= sd_din; sram_ack <= sram_req;         end
				PORT_SVP1:   begin svp_ram1_q <= sd_din; svp_ram1_ack <= svp_ram1_req; end
				PORT_SVP2:   begin svp_ram2_q <= sd_din; svp_ram2_ack <= svp_ram2_req; end
				PORT_SVPROM: begin svp_rom_q  <= sd_din; svp_rom_ack <= svp_rom_req;   end
				default: ;
			endcase
		end

		// VRAM
		if((t == STATE_DS0 || t == STATE_DS0b) && oe_latch[1]) { SDRAM_DQMH, SDRAM_DQML } <= ~ds[1];

		if(t == STATE_READ0 && oe_latch[1]) begin
			case (port[1])
				PORT_VRAM32: vram32_q[15:0] <= sd_din;
				PORT_VRAM:   begin vram_q <= sd_din; vram_ack <= vram_req; end
				default: ;
			endcase
		end
		if(t == STATE_READ0b && oe_latch[1]) begin
			case (port[1])
				PORT_VRAM32: begin vram32_q[31:16] <= sd_din; vram32_ack <= vram32_req; end
				default: ;
			endcase
		end
	end
end

endmodule
