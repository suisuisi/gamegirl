module TI994A_keyboard
(
	input        clk_sys,
	input        key_strobe,
  input        key_pressed,
	input  [7:0] key_code,

	input        joy_swap,
	input [15:0] joy0,
	input [15:0] joy1,

	input  [8:0] keyboardSignals_i,
	output [7:0] keyboardSignals_o
);

wire       pressed = key_pressed;

always @(posedge clk_sys) begin
	
	if(key_strobe) begin
		casex(key_code)
			'hX16: btn_1     <= pressed; // 1
			'hX1E: btn_2     <= pressed; // 2
			'hX26: btn_3     <= pressed; // 3
			'hX25: btn_4     <= pressed; // 4
			'hX2E: btn_5     <= pressed; // 5
			'hX36: btn_6     <= pressed; // 6
			'hX3D: btn_7     <= pressed; // 7
			'hX3E: btn_8     <= pressed; // 8
			'hX46: btn_9     <= pressed; // 9
			'hX45: btn_0     <= pressed; // 0
			'hX4E: btn_eq    <= pressed; // - => =
			'hX55: btn_eq    <= pressed; // =
			'hX5D: btn_eq    <= pressed; // \ => =

			'hX15: btn_q     <= pressed; // q
			'hX1D: btn_w     <= pressed; // w
			'hX24: btn_e     <= pressed; // e
			'hX2D: btn_r     <= pressed; // r
			'hX2C: btn_t     <= pressed; // t
			'hX35: btn_y     <= pressed; // y
			'hX3C: btn_u     <= pressed; // u
			'hX43: btn_i     <= pressed; // i
			'hX44: btn_o     <= pressed; // o
			'hX4D: btn_p     <= pressed; // p
			'hX54: btn_fs    <= pressed; // [ => /
			
			'hX1C: btn_a     <= pressed; // a
			'hX1B: btn_s     <= pressed; // s
			'hX23: btn_d     <= pressed; // d
			'hX2B: btn_f     <= pressed; // f
			'hX34: btn_g     <= pressed; // g
			'hX33: btn_h     <= pressed; // h
			'hX3B: btn_j     <= pressed; // j
			'hX42: btn_k     <= pressed; // k
			'hX4B: btn_l     <= pressed; // l
			'hX4C: btn_se    <= pressed; // ;
			'hX5A: btn_en    <= pressed; // enter
			
			'hX12: btn_sh    <= pressed; // lshift
			'hX1A: btn_z     <= pressed; // z
			'hX22: btn_x     <= pressed; // x
			'hX21: btn_c     <= pressed; // c
			'hX2A: btn_v     <= pressed; // v
			'hX32: btn_b     <= pressed; // b
			'hX31: btn_n     <= pressed; // n
			'hX3A: btn_m     <= pressed; // m
			'hX41: btn_co    <= pressed; // ,
			'hX49: btn_pe    <= pressed; // .
			'hX59: btn_sh    <= pressed; // rshift

			'hX58: btn_al    <= (~btn_al & pressed) | (btn_al & ~pressed); // caps => alpha lock
			'hX14: btn_ct    <= pressed; // lctrl
			'hX29: btn_sp    <= pressed; // space
			'hX11: btn_fn    <= pressed; // lalt => fn
			//'hX14: btn_fn    <= pressed; // rctrl => fn

			'hX75: begin // up
				btn_fn <= pressed;
				btn_e <= pressed;
			end
			'hX6b: begin // left
				btn_fn <= pressed;
				btn_s <= pressed;
			end
			'hX72: begin // down
				btn_fn <= pressed;
				btn_x <= pressed;
			end
			'hX74: begin // right
				btn_fn <= pressed;
				btn_d <= pressed;
			end
			'hX71: begin // del
				btn_fn <= pressed;
				btn_1 <= pressed;
			end
			'hX70: begin // ins
				btn_fn <= pressed;
				btn_2 <= pressed;
			end
			'hX76: begin // esc (back)
				btn_fn <= pressed;
				btn_9 <= pressed;
			end

		endcase
	end
end

reg btn_1 = 0;
reg btn_2 = 0;
reg btn_3 = 0;
reg btn_4 = 0;
reg btn_5 = 0;
reg btn_6 = 0;
reg btn_7 = 0;
reg btn_8 = 0;
reg btn_9 = 0;
reg btn_0 = 0;
reg btn_eq = 0;

reg btn_q = 0;
reg btn_w = 0;
reg btn_e = 0;
reg btn_r = 0;
reg btn_t = 0;
reg btn_y = 0;
reg btn_u = 0;
reg btn_i = 0;
reg btn_o = 0;
reg btn_p = 0;
reg btn_fs = 0;

reg btn_a = 0;
reg btn_s = 0;
reg btn_d = 0;
reg btn_f = 0;
reg btn_g = 0;
reg btn_h = 0;
reg btn_j = 0;
reg btn_k = 0;
reg btn_l = 0;
reg btn_se = 0;
reg btn_en = 0;

reg btn_sh = 0;
reg btn_z = 0;
reg btn_x = 0;
reg btn_c = 0;
reg btn_v = 0;
reg btn_b = 0;
reg btn_n = 0;
reg btn_m = 0;
reg btn_co = 0;
reg btn_pe = 0;

reg btn_al = 0;
reg btn_ct = 0;
reg btn_sp = 0;
reg btn_fn = 0;

wire m_right2  = joy_swap ? joy0[0] : joy1[0];
wire m_left2   = joy_swap ? joy0[1] : joy1[1];
wire m_down2   = joy_swap ? joy0[2] : joy1[2];
wire m_up2     = joy_swap ? joy0[3] : joy1[3];
wire m_fire2   = joy_swap ? joy0[4] | joy1[5] : joy1[4] | joy0[5]; // Fire 2 = fire button on second controller joy[5]
wire m_right  = (joy_swap ? joy1[0] : joy0[0]);
wire m_left   = (joy_swap ? joy1[1] : joy0[1]);
wire m_down   = (joy_swap ? joy1[2] : joy0[2]);
wire m_up     = (joy_swap ? joy1[3] : joy0[3]);
wire m_fire   = (joy_swap ? joy1[4] | joy0[5] : joy0[4] | joy1[5]);
//wire m_arm    = btn_arm   | joy0[5];
//wire m_1      = btn_1     | joy0[9];
//wire m_2      = btn_2     | joy0[10];
//wire m_3      = btn_3     | joy0[11];
//wire m_s      = btn_s     | joy0[6];
//wire m_0      = btn_0     | joy0[8];
//wire m_p      = btn_p     | joy0[7];
//wire m_pt     = btn_pt    | joy0[12];
//wire m_bt     = btn_bt    | joy0[13];
//Parsec uses keys 1,2,3: Make these joystick buttons for convenience
//Also can be used to select menu on boot
wire m_1  = btn_1 | joy0[6] | joy1[6];
wire m_2  = btn_2 | joy0[7] | joy1[7];
wire m_3  = btn_3 | joy0[8] | joy1[8];
wire m_en = btn_en | joy0[9] | joy1[9];
wire m_8  = btn_8 | joy0[10] | joy1[10];
wire m_9  = btn_9 | joy0[11] | joy1[11];
wire m_fn = btn_fn | joy0[10] | joy1[10] | joy0[11] | joy1[11];

wire [7:0] keys0 = {btn_eq, btn_pe, btn_co, btn_m,  btn_n,  btn_fs, m_fire,  m_fire2};        // last=fire2
wire [7:0] keys1 = {btn_sp, btn_l,  btn_k,  btn_j,  btn_h,  btn_se, m_left,  m_left2};        // last=left2
wire [7:0] keys2 = {m_en,   btn_o,  btn_i,  btn_u,  btn_y,  btn_p,  m_right, m_right2};       // last=right2
wire [7:0] keys3 = {1'b0,   m_9,    m_8,    btn_7,  btn_6,  btn_0,  m_down,  m_down2};        // last=down2
wire [7:0] keys4 = {m_fn,   m_2,    m_3,    btn_4,  btn_5,  m_1,    m_up,    m_up2};          // last=up2/al
wire [7:0] keys5 = {btn_sh, btn_s,  btn_d,  btn_f,  btn_g,  btn_a,  1'b0,      1'b0};         // last=
wire [7:0] keys6 = {btn_ct, btn_w,  btn_e,  btn_r,  btn_t,  btn_q,  1'b0,      1'b0};         // last=
wire [7:0] keys7 = {1'b0,   btn_x,  btn_c,  btn_v,  btn_b,  btn_z,  1'b0,      1'b0};         // last=
wire [7:0] keyboardSelect = '{~keyboardSignals_i[4],
                              ~keyboardSignals_i[5],
                              ~keyboardSignals_i[6],
                              ~keyboardSignals_i[7],
                              ~keyboardSignals_i[3],
                              ~keyboardSignals_i[2],
                              ~keyboardSignals_i[1],
                              ~keyboardSignals_i[0]};
wire [7:0] keys = '{~|(keys7 & keyboardSelect[7:0]),
                    ~|(keys6 & keyboardSelect[7:0]),
                    ~|(keys5 & keyboardSelect[7:0]),
                    ~(|(keys4 & keyboardSelect[7:0]) | (btn_al & ~keyboardSignals_i[8])),
                    ~|(keys3 & keyboardSelect[7:0]),
                    ~|(keys2 & keyboardSelect[7:0]),
                    ~|(keys1 & keyboardSelect[7:0]),
                    ~|(keys0 & keyboardSelect[7:0])
                    };

assign keyboardSignals_o[7:0] = keys[7:0];

endmodule
