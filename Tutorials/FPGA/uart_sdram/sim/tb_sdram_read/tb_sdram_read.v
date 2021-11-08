`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : tb_sdram_read
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : SDRAM数据读模块仿真
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  tb_sdram_read();

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
//sdram_write
wire    [12:0]  write_addr      ;   //数据写阶段地址总线
wire    [1:0]   write_ba        ;   //数据写阶段L-Bank地址
wire    [3:0]   write_cmd       ;   //数据写阶段指令
wire    [15:0]  wr_sdram_data   ;   //数据写阶段写入SDRAM数据
wire            wr_sdram_en     ;   //数据写阶段写数据有效使能信号
wire            wr_end          ;   //数据写阶段一次突发写结束
//sdram_read
wire    [12:0]  read_addr       ;   //数据读阶段地址总线
wire    [1:0]   read_ba         ;   //数据读阶段L-Bank地址
wire    [3:0]   read_cmd        ;   //数据读阶段指令
wire    [15:0]  sdram_data_out  ;   //数据读阶段写入SDRAM数据
wire            rd_end          ;   //数据读阶段一次突发写结束
wire            sdram_wr_ack    ;   //数据写阶段写响应
//sdram_addr
wire    [12:0]  sdram_addr      ;   //SDRAM地址总线
wire    [1:0]   sdram_ba        ;   //SDRAML-Bank地址
wire    [3:0]   sdram_cmd       ;   //SDRAM指令
wire    [15:0]  sdram_dq        ;   //SDRAM数据总线

wire    [12:0]  w_r_addr        ;   //数据读阶段地址总线
wire    [1:0]   w_r_ba          ;   //数据读阶段L-Bank地址
wire    [3:0]   w_r_cmd         ;   //数据读阶段指令

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
    else    if(wr_end == 1'b1)
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
    else    if(rd_end == 1'b1)
        rd_en   <=  1'b0;
    else    if(wr_en == 1'b0)
        rd_en   <=  1'b1;
    else
        rd_en   <=  rd_en;

//sdram_cmd,sdram_ba,sdram_addr
assign  sdram_cmd = (init_end == 1'b1) ? w_r_cmd : init_cmd;
assign  sdram_ba = (init_end == 1'b1) ? w_r_ba : init_ba;
assign  sdram_addr = (init_end == 1'b1) ? w_r_addr : init_addr;

//w_r_cmd,w_r_ba,w_r_addr
assign  w_r_cmd = (wr_en == 1'b1) ? write_cmd : read_cmd;
assign  w_r_ba = (wr_en == 1'b1) ? write_ba : read_ba;
assign  w_r_addr = (wr_en == 1'b1) ? write_addr : read_addr;

//wr_sdram_data
assign  sdram_dq = (wr_sdram_en == 1'b1) ? wr_sdram_data : 16'hz;

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

//------------- sdram_write_inst -------------
sdram_write sdram_write_inst(

    .sys_clk        (clk_100m       ),
    .sys_rst_n      (rst_n          ),
    .init_end       (init_end       ),
    .wr_en          (wr_en          ),

    .wr_addr        (24'h000_000    ),
    .wr_data        (wr_data_in     ),
    .wr_burst_len   (10'd10         ),

    .wr_ack         (sdram_wr_ack   ),
    .wr_end         (wr_end         ),
    .write_cmd      (write_cmd      ),
    .write_ba       (write_ba       ),
    .write_addr     (write_addr     ),
    .wr_sdram_en    (wr_sdram_en    ),
    .wr_sdram_data  (wr_sdram_data  )

);

//------------- sdram_read_inst -------------
sdram_read  sdram_read_inst(

    .sys_clk        (clk_100m       ),
    .sys_rst_n      (rst_n          ),
    .init_end       (init_end       ),
    .rd_en          (rd_en          ),

    .rd_addr        (24'h000_000    ),
    .rd_data        (sdram_dq       ),
    .rd_burst_len   (10'd10         ),

    .rd_ack         (               ),
    .rd_end         (rd_end         ),
    .read_cmd       (read_cmd       ),
    .read_ba        (read_ba        ),
    .read_addr      (read_addr      ),
    .rd_sdram_data  (sdram_data_out )

);

//-------------sdram_model_plus_inst-------------
sdram_model_plus    sdram_model_plus_inst(
    .Dq     (sdram_dq       ),
    .Addr   (sdram_addr     ),
    .Ba     (sdram_ba       ),
    .Clk    (clk_100m_shift ),
    .Cke    (1'b1           ),
    .Cs_n   (sdram_cmd[3]   ),
    .Ras_n  (sdram_cmd[2]   ),
    .Cas_n  (sdram_cmd[1]   ),
    .We_n   (sdram_cmd[0]   ),
    .Dqm    (2'b0           ),
    .Debug  (1'b1           )

);

endmodule