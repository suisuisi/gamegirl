`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : tb_sdram_ctrl
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : SDRAM控制模块仿真
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  tb_sdram_ctrl();

//********************************************************************//
//****************** Internal Signal and Defparam ********************//
//********************************************************************//

//wire define
//clk_gen
wire            clk_50m         ;   //PLL输出50M时钟
wire            clk_100m        ;   //PLL输出100M时钟
wire            clk_100m_shift  ;   //PLL输出100M时钟,相位偏移-75deg
wire            locked          ;   //PLL时钟锁定信号
wire            rst_n           ;   //复位信号,低有效
//sdram
wire            sdram_cke       ;   //SDRAM时钟使能信号
wire            sdram_cs_n      ;   //SDRAM片选信号
wire            sdram_ras_n     ;   //SDRAM行选通信号
wire            sdram_cas_n     ;   //SDRAM列选题信号
wire            sdram_we_n      ;   //SDRAM写使能信号
wire    [1:0]   sdram_ba        ;   //SDRAM L-Bank地址
wire    [12:0]  sdram_addr      ;   //SDRAM地址总线
wire    [15:0]  sdram_dq        ;   //SDRAM数据总线
//sdram_ctrl
wire            init_end        ;   //初始化完成信号
wire            sdram_wr_ack    ;   //数据写阶段写响应
wire            sdram_rd_ack    ;   //数据读阶段响应

//reg define
reg             sys_clk         ;   //系统时钟
reg             sys_rst_n       ;   //复位信号
reg             wr_en           ;   //写使能
reg     [15:0]  wr_data_in      ;   //写数据
reg             rd_en           ;   //读使能

//defparam
//重定义仿真模型中的相关参数
defparam sdram_model_plus_inst.addr_bits = 13;          //地址位宽
defparam sdram_model_plus_inst.data_bits = 16;          //数据位宽
defparam sdram_model_plus_inst.col_bits  = 9;           //列地址位宽
defparam sdram_model_plus_inst.mem_sizes = 2*1024*1024; //L-Bank容量

//重定义自动刷新模块自动刷新间隔时间计数最大值
defparam sdram_ctrl_inst.sdram_a_ref_inst.CNT_REF_MAX = 39;

//********************************************************************//
//**************************** Clk And Rst ***************************//
//********************************************************************//

//时钟、复位信号
initial
  begin
    sys_clk     =   1'b1  ;
    sys_rst_n   <=  1'b0  ;
    #200
    sys_rst_n   <=  1'b1  ;
  end

always  #10 sys_clk = ~sys_clk;

//rst_n:复位信号
assign  rst_n = sys_rst_n & locked;

//wr_en：写数据使能
always@(posedge clk_100m or negedge rst_n)
    if(rst_n == 1'b0)
        wr_en   <=  1'b1;
    else    if(wr_data_in == 10'd10)
        wr_en   <=  1'b0;
    else
        wr_en   <=  wr_en;

//wr_data_in:写数据
always@(posedge clk_100m or negedge rst_n)
    if(rst_n == 1'b0)
        wr_data_in  <=  16'd0;
    else    if(wr_data_in == 16'd10)
        wr_data_in  <=  16'd0;
    else    if(sdram_wr_ack == 1'b1)
        wr_data_in  <=  wr_data_in + 1'b1;
    else
        wr_data_in  <=  wr_data_in;

//rd_en:读数据使能
always@(posedge clk_100m or negedge rst_n)
    if(rst_n == 1'b0)
        rd_en   <=  1'b0;
    else    if(wr_en == 1'b0)
        rd_en   <=  1'b1;
    else
        rd_en   <=  rd_en;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//------------- clk_gen_inst -------------
clk_gen clk_gen_inst (
    .inclk0     (sys_clk        ),
    .areset     (~sys_rst_n     ),
    .c0         (clk_50m        ),
    .c1         (clk_100m       ),
    .c2         (clk_100m_shift ),

    .locked     (locked         )
);

//------------- sdram_ctrl_inst -------------
sdram_ctrl  sdram_ctrl_inst(

    .sys_clk        (clk_100m       ),   //系统时钟
    .sys_rst_n      (rst_n          ),   //复位信号，低电平有效
//SDRAM 控制器写端口
    .sdram_wr_req   (wr_en          ),   //写SDRAM请求信号
    .sdram_wr_addr  (24'h000_000    ),   //SDRAM写操作的地址
    .wr_burst_len   (10'd10         ),   //写sdram时数据突发长度
    .sdram_data_in  (wr_data_in     ),   //写入SDRAM的数据
    .sdram_wr_ack   (sdram_wr_ack   ),   //写SDRAM响应信号
//SDRAM 控制器读端口
    .sdram_rd_req   (rd_en          ),  //读SDRAM请求信号
    .sdram_rd_addr  (24'h000_000    ),  //SDRAM写操作的地址
    .rd_burst_len   (10'd10         ),  //读sdram时数据突发长度
    .sdram_data_out (sdram_data_out ),  //从SDRAM读出的数据
    .init_end       (init_end       ),  //SDRAM 初始化完成标志
    .sdram_rd_ack   (sdram_rd_ack   ),  //读SDRAM响应信号
//FPGA与SDRAM硬件接口
    .sdram_cke      (sdram_cke      ),  // SDRAM 时钟有效信号
    .sdram_cs_n     (sdram_cs_n     ),  // SDRAM 片选信号
    .sdram_ras_n    (sdram_ras_n    ),  // SDRAM 行地址选通脉冲
    .sdram_cas_n    (sdram_cas_n    ),  // SDRAM 列地址选通脉冲
    .sdram_we_n     (sdram_we_n     ),  // SDRAM 写允许位
    .sdram_ba       (sdram_ba       ),  // SDRAM L-Bank地址线
    .sdram_addr     (sdram_addr     ),  // SDRAM 地址总线
    .sdram_dq       (sdram_dq       )   // SDRAM 数据总线

);

//-------------sdram_model_plus_inst-------------
sdram_model_plus    sdram_model_plus_inst(
    .Dq     (sdram_dq       ),
    .Addr   (sdram_addr     ),
    .Ba     (sdram_ba       ),
    .Clk    (clk_100m_shift ),
    .Cke    (sdram_cke      ),
    .Cs_n   (sdram_cs_n     ),
    .Ras_n  (sdram_ras_n    ),
    .Cas_n  (sdram_cas_n    ),
    .We_n   (sdram_we_n     ),
    .Dqm    (2'b0           ),
    .Debug  (1'b1           )

);

endmodule