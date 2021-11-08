`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : sdram_ctrl
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : SDRAM控制模块
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  sdram_ctrl
(
    input   wire            sys_clk         ,   //系统时钟
    input   wire            sys_rst_n       ,   //复位信号，低电平有效
//SDRAM写端口
    input   wire            sdram_wr_req    ,   //写SDRAM请求信号
    input   wire    [23:0]  sdram_wr_addr   ,   //SDRAM写操作的地址
    input   wire    [9:0]   wr_burst_len    ,   //写sdram时数据突发长度
    input   wire    [15:0]  sdram_data_in   ,   //写入SDRAM的数据
    output  wire            sdram_wr_ack    ,   //写SDRAM响应信号
//SDRAM读端口
    input   wire            sdram_rd_req    ,   //读SDRAM请求信号
    input   wire    [23:0]  sdram_rd_addr   ,   //SDRAM读操作的地址
    input   wire    [9:0]   rd_burst_len    ,   //读sdram时数据突发长度
    output  wire    [15:0]  sdram_data_out  ,   //从SDRAM读出的数据
    output  wire            init_end        ,   //SDRAM 初始化完成标志
    output  wire            sdram_rd_ack    ,   //读SDRAM响应信号
//FPGA与SDRAM硬件接口
    output  wire            sdram_cke       ,   // SDRAM 时钟有效信号
    output  wire            sdram_cs_n      ,   // SDRAM 片选信号
    output  wire            sdram_ras_n     ,   // SDRAM 行地址选通
    output  wire            sdram_cas_n     ,   // SDRAM 列地址选通
    output  wire            sdram_we_n      ,   // SDRAM 写使能
    output  wire    [1:0]   sdram_ba        ,   // SDRAM Bank地址
    output  wire    [12:0]  sdram_addr      ,   // SDRAM 地址总线
    inout   wire    [15:0]  sdram_dq            // SDRAM 数据总线
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//wire  define
//sdram_init
wire    [3:0]   init_cmd    ;   //初始化阶段写入sdram的指令
wire    [1:0]   init_ba     ;   //初始化阶段Bank地址
wire    [12:0]  init_addr   ;   //初始化阶段地址数据,辅助预充电操作
//sdram_a_ref
wire            aref_req    ;   //自动刷新请求
wire            aref_end    ;   //自动刷新结束标志
wire    [3:0]   aref_cmd    ;   //自动刷新阶段写入sdram的指令
wire    [1:0]   aref_ba     ;   //自动刷新阶段Bank地址
wire    [12:0]  aref_addr   ;   //地址数据,辅助预充电操作
wire            aref_en     ;   //自动刷新使能
//sdram_write
wire            wr_en       ;   //写使能
wire            wr_end      ;   //一次写结束信号
wire    [3:0]   write_cmd   ;   //写阶段命令
wire    [1:0]   write_ba    ;   //写数据阶段Bank地址
wire    [12:0]  write_addr  ;   //写阶段数据地址
wire            wr_sdram_en ;   //SDRAM写使能
wire    [15:0]  wr_sdram_data;  //写入SDRAM的数据
//sdram_read
wire            rd_en       ;   //读使能
wire            rd_end      ;   //一次突发读结束
wire    [3:0]   read_cmd    ;   //读数据阶段写入sdram的指令
wire    [1:0]   read_ba     ;   //读阶段Bank地址
wire    [12:0]  read_addr   ;   //读阶段数据地址

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------- sdram_init_inst -------------
sdram_init  sdram_init_inst
(
    .sys_clk    (sys_clk    ),  //系统时钟,频率100MHz
    .sys_rst_n  (sys_rst_n  ),  //复位信号,低电平有效

    .init_cmd   (init_cmd   ),  //初始化阶段写入sdram的指令
    .init_ba    (init_ba    ),  //初始化阶段Bank地址
    .init_addr  (init_addr  ),  //初始化阶段地址数据,辅助预充电操作
    .init_end   (init_end   )   //初始化结束信号
);

//------------- sdram_arbit_inst -------------
sdram_arbit sdram_arbit_inst
(
    .sys_clk    (sys_clk        ),  //系统时钟
    .sys_rst_n  (sys_rst_n      ),  //复位信号
//sdram_init
    .init_cmd   (init_cmd       ),  //初始化阶段命令
    .init_end   (init_end       ),  //初始化结束标志
    .init_ba    (init_ba        ),  //初始化阶段Bank地址
    .init_addr  (init_addr      ),  //初始化阶段数据地址
//sdram_auto_ref
    .aref_req   (aref_req       ),  //自刷新请求
    .aref_end   (aref_end       ),  //自刷新结束
    .aref_cmd   (aref_cmd       ),  //自刷新阶段命令
    .aref_ba    (aref_ba        ),  //自动刷新阶段Bank地址
    .aref_addr  (aref_addr      ),  //自刷新阶段数据地址
//sdram_write
    .wr_req     (sdram_wr_req   ),  //写数据请求
    .wr_end     (wr_end         ),  //一次写结束信号
    .wr_cmd     (write_cmd      ),  //写阶段命令
    .wr_ba      (write_ba       ),  //写阶段Bank地址
    .wr_addr    (write_addr     ),  //写阶段数据地址
    .wr_sdram_en(wr_sdram_en    ),  //SDRAM写使能
    .wr_data    (wr_sdram_data  ),  //写入SDRAM的数据
//sdram_read
    .rd_req     (sdram_rd_req   ),  //读数据请求
    .rd_end     (rd_end         ),  //一次读结束
    .rd_cmd     (read_cmd       ),  //读阶段命令
    .rd_addr    (read_addr      ),  //读阶段数据地址
    .rd_ba      (read_ba        ),  //读阶段Bank地址

    .aref_en    (aref_en        ),  //自刷新使能
    .wr_en      (wr_en          ),  //写数据使能
    .rd_en      (rd_en          ),  //读数据使能

    .sdram_cke  (sdram_cke      ),  //SDRAM时钟使能
    .sdram_cs_n (sdram_cs_n     ),  //SDRAM片选信号
    .sdram_ras_n(sdram_ras_n    ),  //SDRAM行地址选通
    .sdram_cas_n(sdram_cas_n    ),  //SDRAM列地址选通
    .sdram_we_n (sdram_we_n     ),  //SDRAM写使能
    .sdram_ba   (sdram_ba       ),  //SDRAM Bank地址
    .sdram_addr (sdram_addr     ),  //SDRAM地址总线
    .sdram_dq   (sdram_dq       )   //SDRAM数据总线
);

//------------- sdram_a_ref_inst -------------
sdram_a_ref sdram_a_ref_inst
(
    .sys_clk     (sys_clk   ),  //系统时钟,频率100MHz
    .sys_rst_n   (sys_rst_n ),  //复位信号,低电平有效
    .init_end    (init_end  ),  //初始化结束信号
    .aref_en     (aref_en   ),  //自动刷新使能

    .aref_req    (aref_req  ),  //自动刷新请求
    .aref_cmd    (aref_cmd  ),  //自动刷新阶段写入sdram的指令
    .aref_ba     (aref_ba   ),  //自动刷新阶段Bank地址
    .aref_addr   (aref_addr ),  //地址数据,辅助预充电操作
    .aref_end    (aref_end  )   //自动刷新结束标志
);

//------------- sdram_write_inst -------------
sdram_write sdram_write_inst
(
    .sys_clk        (sys_clk        ),  //系统时钟,频率100MHz
    .sys_rst_n      (sys_rst_n      ),  //复位信号,低电平有效
    .init_end       (init_end       ),  //初始化结束信号
    .wr_en          (wr_en          ),  //写使能

    .wr_addr        (sdram_wr_addr  ),  //写SDRAM地址
    .wr_data        (sdram_data_in  ),  //待写入SDRAM的数据(写FIFO传入)
    .wr_burst_len   (wr_burst_len   ),  //写突发SDRAM字节数

    .wr_ack         (sdram_wr_ack   ),  //写SDRAM响应信号
    .wr_end         (wr_end         ),  //一次突发写结束
    .write_cmd      (write_cmd      ),  //写数据阶段写入sdram的指令
    .write_ba       (write_ba       ),  //写数据阶段Bank地址
    .write_addr     (write_addr     ),  //地址数据,辅助预充电操作
    .wr_sdram_en    (wr_sdram_en    ),  //数据总线输出使能
    .wr_sdram_data  (wr_sdram_data  )   //写入SDRAM的数据
);

//------------- sdram_read_inst -------------
sdram_read  sdram_read_inst
(
    .sys_clk        (sys_clk        ),  //系统时钟,频率100MHz
    .sys_rst_n      (sys_rst_n      ),  //复位信号,低电平有效
    .init_end       (init_end       ),  //初始化结束信号
    .rd_en          (rd_en          ),  //读使能

    .rd_addr        (sdram_rd_addr  ),  //读SDRAM地址
    .rd_data        (sdram_dq       ),  //自SDRAM中读出的数据
    .rd_burst_len   (rd_burst_len   ),  //读突发SDRAM字节数

    .rd_ack         (sdram_rd_ack   ),  //读SDRAM响应信号
    .rd_end         (rd_end         ),  //一次突发读结束
    .read_cmd       (read_cmd       ),  //读数据阶段写入sdram的指令
    .read_ba        (read_ba        ),  //读数据阶段Bank地址
    .read_addr      (read_addr      ),  //地址数据,辅助预充电操作
    .rd_sdram_data  (sdram_data_out )   //SDRAM读出的数据
);

endmodule
