`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/11/01
// Module Name   : hdmi_colorbar
// Project Name  : hdmi_colorbar
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : hdmi_colorbar顶层模块
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  hdmi_colorbar
(
    input   wire            sys_clk     ,   //输入工作时钟,频率50MHz
    input   wire            sys_rst_n   ,   //输入复位信号,低电平有效

    output  wire            ddc_scl     ,
    output  wire            ddc_sda     ,
    output  wire            tmds_clk_p  ,
    output  wire            tmds_clk_n  ,   //HDMI时钟差分信号
    output  wire    [2:0]   tmds_data_p ,
    output  wire    [2:0]   tmds_data_n     //HDMI图像差分信号
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//wire define
wire            vga_clk ;   //VGA工作时钟,频率25MHz
wire            clk_5x  ;
wire            locked  ;   //PLL locked信号
wire            rst_n   ;   //VGA模块复位信号
wire    [11:0]  pix_x   ;   //VGA有效显示区域X轴坐标
wire    [11:0]  pix_y   ;   //VGA有效显示区域Y轴坐标
wire    [15:0]  pix_data;   //VGA像素点色彩信息
wire            hsync   ;   //输出行同步信号
wire            vsync   ;   //输出场同步信号
wire    [15:0]  rgb     ;   //输出像素信息
wire            rgb_valid;

//rst_n:VGA模块复位信号
assign  rst_n   = (sys_rst_n & locked);
assign  ddc_scl = 1'b1;
assign  ddc_sda = 1'b1;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//------------- clk_gen_inst -------------
clk_gen clk_gen_inst
(
    .areset     (~sys_rst_n ),  //输入复位信号,高电平有效,1bit
    .inclk0     (sys_clk    ),  //输入50MHz晶振时钟,1bit

    .c0         (vga_clk    ),  //输出VGA工作时钟,频率25Mhz,1bit
    .c1         (clk_5x     ),
    .locked     (locked     )   //输出pll locked信号,1bit
);

//------------- vga_ctrl_inst -------------
vga_ctrl  vga_ctrl_inst
(
    .vga_clk    (vga_clk    ),  //输入工作时钟,频率25MHz,1bit
    .sys_rst_n  (rst_n      ),  //输入复位信号,低电平有效,1bit
    .pix_data   (pix_data   ),  //输入像素点色彩信息,16bit

    .pix_x      (pix_x      ),  //输出VGA有效显示区域像素点X轴坐标,10bit
    .pix_y      (pix_y      ),  //输出VGA有效显示区域像素点Y轴坐标,10bit
    .hsync      (hsync      ),  //输出行同步信号,1bit
    .vsync      (vsync      ),  //输出场同步信号,1bit
    .rgb_valid  (rgb_valid  ),
    .rgb        (rgb        )   //输出像素点色彩信息,16bit
);

//------------- vga_pic_inst -------------
vga_pic vga_pic_inst
(
    .vga_clk    (vga_clk    ),  //输入工作时钟,频率25MHz,1bit
    .sys_rst_n  (rst_n      ),  //输入复位信号,低电平有效,1bit
    .pix_x      (pix_x      ),  //输入VGA有效显示区域像素点X轴坐标,10bit
    .pix_y      (pix_y      ),  //输入VGA有效显示区域像素点Y轴坐标,10bit

    .pix_data   (pix_data   )   //输出像素点色彩信息,16bit

);

//------------- hdmi_ctrl_inst -------------
hdmi_ctrl   hdmi_ctrl_inst
(
    .clk_1x      (vga_clk           ),   //输入系统时钟
    .clk_5x      (clk_5x            ),   //输入5倍系统时钟
    .sys_rst_n   (rst_n             ),   //复位信号,低有效
    .rgb_blue    ({rgb[4:0],3'b0}   ),   //蓝色分量
    .rgb_green   ({rgb[10:5],2'b0}  ),   //绿色分量
    .rgb_red     ({rgb[15:11],3'b0} ),   //红色分量
    .hsync       (hsync             ),   //行同步信号
    .vsync       (vsync             ),   //场同步信号
    .de          (rgb_valid         ),   //使能信号
    .hdmi_clk_p  (tmds_clk_p        ),
    .hdmi_clk_n  (tmds_clk_n        ),   //时钟差分信号
    .hdmi_r_p    (tmds_data_p[2]    ),
    .hdmi_r_n    (tmds_data_n[2]    ),   //红色分量差分信号
    .hdmi_g_p    (tmds_data_p[1]    ),
    .hdmi_g_n    (tmds_data_n[1]    ),   //绿色分量差分信号
    .hdmi_b_p    (tmds_data_p[0]    ),
    .hdmi_b_n    (tmds_data_n[0]    )    //蓝色分量差分信号
);

endmodule
