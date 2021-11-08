`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : fifo_read
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : SDRAM数据回传缓存模块
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  fifo_read
(
    input   wire            sys_clk     ,   //系统时钟，频率50MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
    input   wire    [9:0]   rd_fifo_num ,   //SDRAM中读fifo中数据个数
    input   wire    [7:0]   pi_data     ,   //读出数据
    input   wire    [9:0]   burst_num   ,   //一次突发数据个数

    output  reg             read_en     ,   //SDRAM中读fifo的读使能
    output  wire    [7:0]   tx_data     ,   //输出数据
    output  reg             tx_flag         //输出数据标志信号
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter define
parameter   BAUD_CNT_END        =   13'd5207        ,
            BAUD_CNT_END_HALF   =   13'd2603        ;
parameter   CNT_WAIT_MAX        =   24'd4_999_999   ;

//wire  define
wire    [9:0]   data_num    ;   //fifo中数据个数

//reg   define
reg         read_en_dly     ;
reg [12:0]  baud_cnt        ;
reg         rd_en           ;
reg         rd_flag         ;
reg [9:0]   cnt_read        ;
reg [3:0]   bit_cnt         ;
reg         bit_flag        ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//read_en:SDRAM中读fifo的读使能
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        read_en   <=  1'b0;
    else    if(rd_fifo_num == burst_num)
        read_en   <=  1'b1;
    else    if(data_num == burst_num - 2)
        read_en   <=  1'b0;

//read_en_dly:SDRAM中读fifo的读使能打拍
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        read_en_dly    <=  1'b0;
    else
        read_en_dly    <=  read_en;

//rd_flag:向tx模块发送数据使能
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_flag <=  1'b0;
    else    if(cnt_read == burst_num)
        rd_flag <=  1'b0;
    else    if(data_num == burst_num)
        rd_flag <=  1'b1;

//baud_cnt:波特率计数器计数从0计数到BAUD_CNT_END
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        baud_cnt    <=  13'd0;
    else    if(baud_cnt == BAUD_CNT_END)
        baud_cnt    <=  13'd0;
    else    if(rd_flag == 1'b1)
        baud_cnt    <=  baud_cnt + 1'b1;

//bit_flag:bit计数器计数使能
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        bit_flag    <=  1'b0;
    else    if(baud_cnt == BAUD_CNT_END_HALF)
        bit_flag    <=  1'b1;
    else
        bit_flag    <=  1'b0;

//bit_cnt:bit计数器
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        bit_cnt <=  4'b0;
    else    if((bit_cnt == 4'd9) && (bit_flag == 1'b1))
        bit_cnt <=  4'b0;
    else    if(bit_flag ==  1'b1)
        bit_cnt <=  bit_cnt +   1'b1;

//rd_en:读fifo的读使能
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_en   <=  1'b0;
    else    if(bit_cnt == 4'd9 && bit_flag == 1'b1)
        rd_en   <=  1'b1;
    else
        rd_en   <=  1'b0;

//cnt_read:读出数据计数
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_read    <=  10'd0;
    else    if(cnt_read == burst_num)
        cnt_read    <=  10'b0;
    else    if(rd_en == 1'b1)
        cnt_read    <=  cnt_read + 1'b1;
    else
        cnt_read    <=  cnt_read;

//tx_flag:读出数据标志信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        tx_flag <=  1'b0;
    else
        tx_flag <=  rd_en;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//-------------fifo_read_inst--------------
read_fifo   read_fifo_inst(
    .clock  (sys_clk        ),  //input clk
    .data   (pi_data        ),  //input [7 : 0] din
    .wrreq  (read_en_dly    ),  //input wr_en
    .rdreq  (rd_en          ),  //input rd_en

    .q      (tx_data        ),  //output [7 : 0] dout
    .usedw  (data_num       )
);

endmodule
