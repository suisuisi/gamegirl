`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/11/01
// Module Name   : hdmi_ctrl
// Project Name  : hdmi_colorbar
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : HDMI控制模块
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////


module  hdmi_ctrl
(
    input   wire            clk_1x      ,   //输入系统时钟
    input   wire            clk_5x      ,   //输入5倍系统时钟
    input   wire            sys_rst_n   ,   //复位信号,低有效
    input   wire    [7:0]   rgb_blue    ,   //蓝色分量
    input   wire    [7:0]   rgb_green   ,   //绿色分量
    input   wire    [7:0]   rgb_red     ,   //红色分量
    input   wire            hsync       ,   //行同步信号
    input   wire            vsync       ,   //场同步信号
    input   wire            de          ,   //使能信号

    output  wire            hdmi_clk_p  ,
    output  wire            hdmi_clk_n  ,   //时钟差分信号
    output  wire            hdmi_r_p    ,
    output  wire            hdmi_r_n    ,   //红色分量差分信号
    output  wire            hdmi_g_p    ,
    output  wire            hdmi_g_n    ,   //绿色分量差分信号
    output  wire            hdmi_b_p    ,
    output  wire            hdmi_b_n        //蓝色分量差分信号
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
wire    [9:0]   red     ;   //8b转10b后的红色分量
wire    [9:0]   green   ;   //8b转10b后的绿色分量
wire    [9:0]   blue    ;   //8b转10b后的蓝色分量

//********************************************************************//
//**************************** Instantiate ***************************//
//********************************************************************//
//------------- encode_inst0 -------------
encode  encode_inst0
(
    .sys_clk    (clk_1x     ),
    .sys_rst_n  (sys_rst_n  ),
    .data_in    (rgb_blue   ),
    .c0         (hsync      ),
    .c1         (vsync      ),
    .de         (de         ),
    .data_out   (blue       )
);

//------------- encode_inst1 -------------
encode  encode_inst1
(
    .sys_clk    (clk_1x     ),
    .sys_rst_n  (sys_rst_n  ),
    .data_in    (rgb_green  ),
    .c0         (hsync      ),
    .c1         (vsync      ),
    .de         (de         ),
    .data_out   (green      )
);

//------------- encode_inst2 -------------
encode  encode_inst2
(
    .sys_clk    (clk_1x     ),
    .sys_rst_n  (sys_rst_n  ),
    .data_in    (rgb_red    ),
    .c0         (hsync      ),
    .c1         (vsync      ),
    .de         (de         ),
    .data_out   (red        )
);

//------------- par_to_ser_inst0 -------------
par_to_ser  par_to_ser_inst0
(
    .clk_5x      (clk_5x    ),
    .par_data    (blue      ),

    .ser_data_p  (hdmi_b_p  ),
    .ser_data_n  (hdmi_b_n  )
);

//------------- par_to_ser_inst1 -------------
par_to_ser  par_to_ser_inst1
(
    .clk_5x      (clk_5x    ),
    .par_data    (green     ),

    .ser_data_p  (hdmi_g_p  ),
    .ser_data_n  (hdmi_g_n  )
);

//------------- par_to_ser_inst2 -------------
par_to_ser  par_to_ser_inst2
(
    .clk_5x      (clk_5x    ),
    .par_data    (red       ),

    .ser_data_p  (hdmi_r_p  ),
    .ser_data_n  (hdmi_r_n  )
);

//------------- par_to_ser_inst3 -------------
par_to_ser  par_to_ser_inst3
(
    .clk_5x      (clk_5x        ),
    .par_data    (10'b1111100000),

    .ser_data_p  (hdmi_clk_p    ),
    .ser_data_n  (hdmi_clk_n    )
);

endmodule
