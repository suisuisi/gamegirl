// A video pipeline for MiST. Just insert between the core video output and the VGA pins
// Provides an optional scandoubler, a rotateable OSD and (optional) RGb->YPbPr conversion

// Adjustments by AMR to reduce block RAM usage and simplify the logic.
// TODO: take in a blanking signal
// TODO: delay sync pulses the same amount as the data.

module mist_video
(
	// master clock
	// it should be 4x (or 2x) pixel clock for the scandoubler
	input        clk_sys,

	// OSD SPI interface
	input        SPI_SCK,
	input        SPI_SS3,
	input        SPI_DI,

	// scanlines (00-none 01-25% 10-50% 11-75%)
	input  [1:0] scanlines,

	// non-scandoubled pixel clock divider 0 - clk_sys/2, 1 - clk_sys/3, 2 - clk_sys/4, etc.
	input  [2:0] ce_divider,

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	input        scandoubler_disable,
	// disable csync without scandoubler
	input        no_csync,
	// YPbPr always uses composite sync
	input        ypbpr,
	// Rotate OSD [0] - rotate [1] - left or right
	input  [1:0] rotate,
	// composite-like blending
	input        blend,
	input  [3:0] blend_coeff,

	// video in
	input  [COLOR_DEPTH-1:0] R,
	input  [COLOR_DEPTH-1:0] G,
	input  [COLOR_DEPTH-1:0] B,

	input        HSync,
	input        VSync,

	// MiST video output signals
	output reg [5:0] VGA_R,
	output reg [5:0] VGA_G,
	output reg [5:0] VGA_B,
	output reg      VGA_VS,
	output reg      VGA_HS
);

parameter OSD_COLOR    = 3'd4;
parameter OSD_X_OFFSET = 10'd0;
parameter OSD_Y_OFFSET = 10'd0;
parameter SD_HCNT_WIDTH = 9;
parameter SD_SCNT_WIDTH = 12;
parameter COLOR_DEPTH = 6; // 1-6
parameter OSD_AUTO_CE = 1'b1;
parameter SYNC_AND = 1'b0; // 0 - XOR, 1 - AND

// Scandouble the incoming signal. Scandoubler is bypassed if scandouble_disable is set.

wire [5:0] SD_R_O;
wire [5:0] SD_G_O;
wire [5:0] SD_B_O;
wire       SD_HS_O;
wire       SD_VS_O;

wire pixel_ena;

scandoubler #(
	.HCNT_WIDTH(SD_HCNT_WIDTH),
	.HSCNT_WIDTH(SD_SCNT_WIDTH),
	.COLOR_DEPTH(COLOR_DEPTH))
scandoubler (
	.clk_sys    ( clk_sys    ),
	.scanlines  ( scanlines  ),
	.bypass     ( scandoubler_disable ),
	.pixel_ena  ( pixel_ena  ),
	.ce_divider ( ce_divider ),
	.hs_in      ( HSync      ),
	.vs_in      ( VSync      ),
	.r_in       ( R          ),
	.g_in       ( G          ),
	.b_in       ( B          ),
	.hs_out     ( SD_HS_O    ),
	.vs_out     ( SD_VS_O    ),
	.r_out      ( SD_R_O     ),
	.g_out      ( SD_G_O     ),
	.b_out      ( SD_B_O     )
);


// Overlay the on-screen display
// FIXME - should output delayed Sync pulses

wire [5:0] osd_r_o;
wire [5:0] osd_g_o;
wire [5:0] osd_b_o;

osd #(OSD_X_OFFSET, OSD_Y_OFFSET, OSD_COLOR, OSD_AUTO_CE) osd
(
	.clk_sys ( clk_sys ),
	.rotate  ( rotate  ),
	.ce      ( pixel_ena ),
	.SPI_DI  ( SPI_DI  ),
	.SPI_SCK ( SPI_SCK ),
	.SPI_SS3 ( SPI_SS3 ),
	.R_in    ( SD_R_O ),
	.G_in    ( SD_G_O ),
	.B_in    ( SD_B_O ),
	.HSync   ( SD_HS_O ),
	.VSync   ( SD_VS_O ),
	.R_out   ( osd_r_o ),
	.G_out   ( osd_g_o ),
	.B_out   ( osd_b_o )
);


// Apply composite video simulation filter, bypassed if blend is low

wire [5:0] cofi_r, cofi_g, cofi_b;
wire       cofi_hs, cofi_vs;

cofi_ng #(.VIDEO_DEPTH(6)) cofi (
	.clk     ( clk_sys ),
	.pix_ce  ( pixel_ena ),
	.scandoubler_disable ( scandoubler_disable ),
	.enable  ( blend ),
	.coefficient ( blend_coeff   ),
	.hblank  ( ~SD_HS_O ),
	.hs      ( SD_HS_O ),
	.vs      ( SD_VS_O ),
	.red     ( osd_r_o ),
	.green   ( osd_g_o ),
	.blue    ( osd_b_o ),
	.hs_out  ( cofi_hs ),
	.vs_out  ( cofi_vs ),
	.red_out ( cofi_r  ),
	.green_out( cofi_g ),
	.blue_out( cofi_b  )
);


// Finally convert to YPbPr, bypassed is ypbpr is low

wire [5:0] r_final, g_final, b_final;
wire hs_final,vs_final,cs_final;

RGBtoYPbPr #(.WIDTH(6)) rgb2ypbpr
(
	.clk      ( clk_sys ),
	.ena      ( ypbpr   ),
	.red_in   ( cofi_r ),
	.green_in ( cofi_g ),
	.blue_in  ( cofi_b ),
	.hs_in    ( cofi_hs ),
	.vs_in    ( cofi_vs ),
	.cs_in    ( SYNC_AND ? (cofi_hs & cofi_vs) : ~(cofi_hs ^ cofi_vs) ),
	.red_out  ( r_final ),
	.green_out( g_final ),
	.blue_out ( b_final ),
	.hs_out   ( hs_final),
	.vs_out   ( vs_final),
	.cs_out   ( cs_final)
);

// Register final video signal to avoid hold violations
always @(posedge clk_sys)
begin
	VGA_R <= r_final[5:0];
	VGA_G <= g_final[5:0];
	VGA_B <= b_final[5:0];

// a minimig vga->scart cable expects a composite sync signal on the VGA_HS output.
// and VCC on VGA_VS (to switch into rgb mode)
	VGA_HS <= ((~no_csync & scandoubler_disable) || ypbpr)? cs_final : hs_final;
	VGA_VS <= ((~no_csync & scandoubler_disable) || ypbpr)? 1'b1 : vs_final;
end

endmodule
