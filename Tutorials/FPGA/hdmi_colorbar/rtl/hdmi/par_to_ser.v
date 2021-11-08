`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/11/01
// Module Name   : par_to_ser
// Project Name  : hdmi_colorbar
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : 并行转串行、单端转差分、单沿转双沿
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module par_to_ser
(
    input   wire            clk_5x      ,   //输入系统时钟
    input   wire    [9:0]   par_data    ,   //输入并行数据

    output  wire            ser_data_p  ,   //输出串行差分数据
    output  wire            ser_data_n      //输出串行差分数据
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//wire  define
wire    [4:0]   data_rise = {par_data[8],par_data[6],
                            par_data[4],par_data[2],par_data[0]};
wire    [4:0]   data_fall = {par_data[9],par_data[7],
                            par_data[5],par_data[3],par_data[1]};

//reg   define
reg     [4:0]   data_rise_s = 0;
reg     [4:0]   data_fall_s = 0;
reg     [2:0]   cnt = 0;


always @ (posedge clk_5x)
    begin
        cnt <= (cnt[2]) ? 3'd0 : cnt + 3'd1;
        data_rise_s  <= cnt[2] ? data_rise : data_rise_s[4:1];
        data_fall_s  <= cnt[2] ? data_fall : data_fall_s[4:1];

    end

//********************************************************************//
//**************************** Instantiate ***************************//
//********************************************************************//
//------------- ddio_out_inst0 -------------
ddio_out    ddio_out_inst0
(
    .datain_h   (data_rise_s[0] ),
    .datain_l   (data_fall_s[0] ),
    .outclock   (~clk_5x        ),
    .dataout    (ser_data_p     )
);

//------------- ddio_out_inst1 -------------
ddio_out    ddio_out_inst1
(
    .datain_h   (~data_rise_s[0]),
    .datain_l   (~data_fall_s[0]),
    .outclock   (~clk_5x        ),
    .dataout    (ser_data_n     )
);

endmodule
