`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : tb_sdram_init
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : SDRAM初始化模块仿真
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  tb_sdram_init();

//********************************************************************//
//****************** Internal Signal and Defparam ********************//
//********************************************************************//

//wire define
//clk_gen
wire            clk_50m         ;   //PLL输出50M时钟
wire            clk_100m        ;   //PLL输出100M时钟
wire            clk_100m_shift  ;   //PLL输出100M时钟,相位偏移-30deg
wire            locked          ;   //PLL时钟锁定信号
wire            rst_n           ;   //复位信号,低有效
//sdram_init
wire    [3:0]   init_cmd        ;   //初始化阶段指令
wire    [1:0]   init_ba         ;   //初始化阶段L-Bank地址
wire    [12:0]  init_addr       ;   //初始化阶段地址总线
wire            init_end        ;   //初始化完成信号

//reg define
reg             sys_clk         ;   //系统时钟
reg             sys_rst_n       ;   //复位信号

//defparam
//重定义仿真模型中的相关参数
defparam sdram_model_plus_inst.addr_bits = 13;          //地址位宽
defparam sdram_model_plus_inst.data_bits = 16;          //数据位宽
defparam sdram_model_plus_inst.col_bits  = 9;           //列地址位宽
defparam sdram_model_plus_inst.mem_sizes = 2*1024*1024; //L-Bank容量

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

//------------- sdram_init_inst -------------
sdram_init  sdram_init_inst(

    .sys_clk    (clk_100m   ),
    .sys_rst_n  (rst_n      ),

    .init_cmd   (init_cmd   ),
    .init_ba    (init_ba    ),
    .init_addr  (init_addr  ),
    .init_end   (init_end   )

);

//-------------sdram_model_plus_inst-------------
sdram_model_plus    sdram_model_plus_inst(
    .Dq     (               ),
    .Addr   (init_addr      ),
    .Ba     (init_ba        ),
    .Clk    (clk_100m_shift ),
    .Cke    (1'b1           ),
    .Cs_n   (init_cmd[3]    ),
    .Ras_n  (init_cmd[2]    ),
    .Cas_n  (init_cmd[1]    ),
    .We_n   (init_cmd[0]    ),
    .Dqm    (2'b0           ),
    .Debug  (1'b1           )

);

endmodule