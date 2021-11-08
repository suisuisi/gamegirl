// Hybrid PWM / Sigma Delta DAC
//
// 16-bit Sigma Delta with 5-bit output, feeding a PWM.

// If rising and falling edges aren't perfectly symmetrical, a significant
// amount of noise can be introduced into a sigma-delta DAC, since the number
// of rising- and falling-edges within a given time period is either directly
// dependent upon the code, or pseudo-random.

// The PWM output stage, on the other hand, results results in a constant
// number of rising- and falling-edges in a given time period, so any edge imbalance
// will result in a DC offset rather than audible noise.

// 2nd order variant with low-pass input filter and high-pass feedback filter.
// Copyright 2021 by Alastair M. Robinson

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that they will
// be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>
//


module hybrid_pwm_sd_2ndorder #(parameter signalwidth=16, parameter filtersize=4)
(
	input clk,
	input reset_n,
	input [signalwidth-1:0] d_l,
	output q_l,
	input [signalwidth-1:0] d_r,
	output q_r
);

reg q_l_reg;
reg q_r_reg;
assign q_l=q_l_reg;
assign q_r=q_r_reg;

reg [12:0] initctr;
reg init = 1'b1;
reg initfilterena;

always @(posedge clk)
begin
	initfilterena<=1'b0;
	
	if(init)
	begin
		if(infilterena)
		begin
			initctr<=initctr+1'b1;
			if(initctr==0)
				initfilterena<=1'b1;
		end
		if(infiltered_l[signalwidth-1:3]==d_l[signalwidth-1:3])
			init<=1'b0;
	end
end

// Input filtering - a simple single-pole IIR low-pass filter.
// configurable number of bits.

wire [signalwidth-1:0] infiltered_l;
wire [signalwidth-1:0] infiltered_r;
reg infilterena;

iirfilter_stereo # (.signalwidth(signalwidth),.cbits(filtersize),.immediate(0)) inputfilter
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(init ? initfilterena : infilterena),
	.d_l(d_l),
	.d_r(d_r),
	.q_l(infiltered_l),
	.q_r(infiltered_r)
);


// Approximation of reconstruction filter,
// subtracted from the incoming signal to
// steer the first stage of the sigma delta.

// 9 bits for the coefficient (1/512)

wire [signalwidth-1:0] outfiltered_l;
wire [signalwidth-1:0] outfiltered_r;

iirfilter_stereo # (.signalwidth(signalwidth),.cbits(9),.immediate(1)) outputfilter
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(1'b1),
	.d_l(q_l_reg ? {signalwidth{1'b1}} : {signalwidth{1'b0}}),
	.d_r(q_r_reg ? {signalwidth{1'b1}} : {signalwidth{1'b0}}),
	.q_l(outfiltered_l),
	.q_r(outfiltered_r)
);

reg [6:0] pwmcounter;
wire [6:0] pwmthreshold_l;
wire [6:0] pwmthreshold_r;
reg [33:0] scaledin;
reg [signalwidth+1:0] sigma_l;
reg [signalwidth+1:0] sigma2_l;
reg [signalwidth+1:0] sigma_r;
reg [signalwidth+1:0] sigma2_r;

wire [signalwidth+1:0] sigmanext_l;
wire [signalwidth+1:0] sigmanext_r;

assign sigmanext_l = sigma_l+{2'b0,infiltered_l}-{2'b0,outfiltered_l};
assign sigmanext_r = sigma_r+{2'b0,infiltered_r}-{2'b0,outfiltered_r};

assign pwmthreshold_l = sigma2_l[signalwidth+1:signalwidth-5];
assign pwmthreshold_r = sigma2_r[signalwidth+1:signalwidth-5];


always @(posedge clk,negedge reset_n)
begin
	if(!reset_n) begin
		sigma_l<={signalwidth+2{1'b0}};
		sigma_r<={signalwidth+2{1'b0}};
		sigma2_l={signalwidth+2{1'b0}};
		sigma2_r={signalwidth+2{1'b0}};
		pwmcounter<=7'b111110;
	end else begin
		infilterena<=1'b0;

		if(pwmcounter==pwmthreshold_l)
			q_l_reg<=1'b0;

		if(pwmcounter==pwmthreshold_r)
			q_r_reg<=1'b0;

		if(pwmcounter==7'b11111) // Update threshold just before pwmcounter wraps around
		begin

			infilterena<=1'b1;

			// PWM

			sigma_l<=sigmanext_l;
			sigma2_l=sigmanext_l+{7'b0010000,sigma2_l[signalwidth-6:0]};

			sigma_r<=sigmanext_r;
			sigma2_r=sigmanext_r+{7'b0010000,sigma2_r[signalwidth-6:0]};

			if(sigma2_l[signalwidth+1]==1'b1)
				q_l_reg<=1'b0;
			else
				q_l_reg<=1'b1;

			if(sigma2_r[signalwidth+1]==1'b1)
				q_r_reg<=1'b0;
			else
				q_r_reg<=1'b1;

		end

		pwmcounter[6:5]<=2'b0;
		pwmcounter[4:0]<=pwmcounter[4:0]+5'b1;

	end
end

endmodule


module iirfilter_stereo #
(
	parameter signalwidth = 16,
	parameter cbits = 5,
	parameter immediate
)
(
	input clk,
	input reset_n,
	input ena,
	input [signalwidth-1:0] d_l,
	input [signalwidth-1:0] d_r,
	output [signalwidth-1:0] q_l,
	output [signalwidth-1:0] q_r
);

iirfilter_mono # (.signalwidth(signalwidth),.cbits(cbits),.immediate(immediate)) left
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(ena),
	.d(d_l),
	.q(q_l)
);

iirfilter_mono # (.signalwidth(signalwidth),.cbits(cbits),.immediate(immediate)) right
(
	.clk(clk),
	.reset_n(reset_n),
	.ena(ena),
	.d(d_r),
	.q(q_r)
);

endmodule



// Simplistic IIR low-pass filter.
// function is simply y += b * (x - y)
// where b=1/(1<<cbits)

module iirfilter_mono # 
(
	parameter signalwidth = 16,
	parameter cbits = 5,	// Bits for coefficient (default 1/32)
	parameter immediate = 0,
	parameter powerup = 1
)
(
	input clk,
	input reset_n,
	input ena,
	input [signalwidth-1:0] d,
	output [signalwidth-1:0] q
);

reg [signalwidth+cbits-1:0] acc = {powerup ? {signalwidth{1'b1}} : {signalwidth{1'b0}} , {cbits{1'b0}}};
wire [signalwidth+cbits-1:0] acc_new;

wire [signalwidth+cbits:0] delta = {d,{cbits{1'b0}}} - acc;

assign acc_new = acc + {{cbits{delta[signalwidth+cbits]}},delta[signalwidth+cbits-1:cbits]};

always @(posedge clk, negedge reset_n)
begin
	if(!reset_n)
	begin
		acc[signalwidth+cbits-1:0]<={powerup ? {signalwidth{1'b1}} : {signalwidth{1'b0}} , {cbits{1'b0}}};
	end
	else if(ena)
		acc <= acc_new;
end

// Based on the immediate signal, q is either combinational or registered.
assign q=immediate ? acc_new[signalwidth+cbits-1:cbits] : acc[signalwidth+cbits-1:cbits];

endmodule

