// Composite-like horizontal blending by Kitrinx
// AMR - replaced filtering with simple IIR filter

// The coefficient parameter can be used to tune the filter
// to the clock frequency of the video chain, which will be different
// from the core's pixel clock.

// Coefficient can be 1 to 15.  A reasonable coefficient can be approximated :
// c = 32 * tan(r) / (1+tan(r))
// where r = pi * cutoff frequency / video chain frequency.
// For the PC Engine core where the video chain runs at 42MHz
// and with a target cutoff frequency of around 3MHz,
// r = pi * 3 / 42 = ~ 0.224
// c = ~ 5.86, so round up to 6.

// Suggested coefficients for 3MHz cutoff:
// Video chain clock:
//	21MHz						10
//	24MHz						9
//	42MHz						6
//	48MHz						5
//	96MHz						3

// Suggested coefficients for 2MHz cutoff for a more severe effect:
// Video chain clock:
//	21MHz						7
//	24MHz						7
//	42MHz						4
//	48MHz						4
//	96MHz						2

module cofi_ng
# (
	parameter VIDEO_DEPTH=8
)
(
    input        clk,
    input        pix_ce,
	 input        enable,
	 input  [3:0] coefficient,
	 input        scandoubler_disable,

    input        hblank,
    input        vblank,
    input        hs,
    input        vs,
    input  [VIDEO_DEPTH-1:0] red,
    input  [VIDEO_DEPTH-1:0] green,
    input  [VIDEO_DEPTH-1:0] blue,

    output reg       hblank_out,
    output reg       vblank_out,
    output reg       hs_out,
    output reg       vs_out,
    output [VIDEO_DEPTH-1:0] red_out,
    output [VIDEO_DEPTH-1:0] green_out,
    output [VIDEO_DEPTH-1:0] blue_out
);

// Run the filter on alternate clocks if the scandoubler's disabled, (aligned with hblank)
// otherwise every clock.
reg trigger;
always @(posedge clk)
	trigger <= !trigger | hblank | !scandoubler_disable;

cofi_iir #(.signalwidth(VIDEO_DEPTH)) rfilter
(
	.clk(clk),
	.reset_n(enable && !hblank),
	.coeff(coefficient),
	.ena(trigger),
	.d(red),
	.q(red_out)
);

cofi_iir #(.signalwidth(VIDEO_DEPTH)) gfilter
(
	.clk(clk),
	.reset_n(enable && !hblank),
	.coeff(coefficient),
	.ena(trigger),
	.d(green),
	.q(green_out)
);

cofi_iir #(.signalwidth(VIDEO_DEPTH)) bfilter
(
	.clk(clk),
	.reset_n(enable && !hblank),
	.coeff(coefficient),
	.ena(trigger),
	.d(blue),
	.q(blue_out)
);

always @(posedge clk)
begin
	hblank_out <= hblank;
	vblank_out <= vblank;
	vs_out     <= vs;
	hs_out     <= hs;
end

endmodule


module cofi_iir
# (
    parameter signalwidth = 6
)
(
    input clk,
    input reset_n,
	 input ena,
	 input [3:0] coeff,
    input [signalwidth-1:0] d,
    output [signalwidth-1:0] q
);

wire dsign;
reg [signalwidth+1:0] delta;
reg [signalwidth+4:0] acc;

always @(*)
begin
    delta={1'b0,d,1'b0}-{1'b0,acc[signalwidth+4:4]};
end

assign dsign = delta[signalwidth+1];

always @(posedge clk)
begin
	if(!reset_n) begin
		acc<={d,5'b00};
	end else if(ena) begin		
		acc <= acc
			+ (coeff[3] ? {delta,3'b000} : {(signalwidth+5){1'b0}})
			+ (coeff[2] ? {dsign,delta,2'b00} : {(signalwidth+5){1'b0}})
			+ (coeff[1] ? {{2{dsign}},delta,1'b0} : {(signalwidth+5){1'b0}})
			+ (coeff[0] ? {{3{dsign}},delta} : {(signalwidth+5){1'b0}});
	end
end

assign q=acc[signalwidth+4:5];

endmodule
