`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : sdram_arbit
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : SDRAM仲裁模块
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  sdram_arbit
(
    input   wire            sys_clk     ,   //系统时钟
    input   wire            sys_rst_n   ,   //复位信号
//sdram_init
    input   wire    [3:0]   init_cmd    ,   //初始化阶段命令
    input   wire            init_end    ,   //初始化结束标志
    input   wire    [1:0]   init_ba     ,   //初始化阶段Bank地址
    input   wire    [12:0]  init_addr   ,   //初始化阶段数据地址
//sdram_auto_ref
    input   wire            aref_req    ,   //自刷新请求
    input   wire            aref_end    ,   //自刷新结束
    input   wire    [3:0]   aref_cmd    ,   //自刷新阶段命令
    input   wire    [1:0]   aref_ba     ,   //自动刷新阶段Bank地址
    input   wire    [12:0]  aref_addr   ,   //自刷新阶段数据地址
//sdram_write
    input   wire            wr_req      ,   //写数据请求
    input   wire    [1:0]   wr_ba       ,   //写阶段Bank地址
    input   wire    [15:0]  wr_data     ,   //写入SDRAM的数据
    input   wire            wr_end      ,   //一次写结束信号
    input   wire    [3:0]   wr_cmd      ,   //写阶段命令
    input   wire    [12:0]  wr_addr     ,   //写阶段数据地址
    input   wire            wr_sdram_en ,
//sdram_read
    input   wire            rd_req      ,   //读数据请求
    input   wire            rd_end      ,   //一次读结束
    input   wire    [3:0]   rd_cmd      ,   //读阶段命令
    input   wire    [12:0]  rd_addr     ,   //读阶段数据地址
    input   wire    [1:0]   rd_ba       ,   //读阶段Bank地址

    output  reg             aref_en     ,   //自刷新使能
    output  reg             wr_en       ,   //写数据使能
    output  reg             rd_en       ,   //读数据使能

    output  wire            sdram_cke   ,   //SDRAM时钟使能
    output  wire            sdram_cs_n  ,   //SDRAM片选信号
    output  wire            sdram_ras_n ,   //SDRAM行地址选通
    output  wire            sdram_cas_n ,   //SDRAM列地址选通
    output  wire            sdram_we_n  ,   //SDRAM写使能
    output  reg     [1:0]   sdram_ba    ,   //SDRAM Bank地址
    output  reg     [12:0]  sdram_addr  ,   //SDRAM地址总线
    inout   wire    [15:0]  sdram_dq        //SDRAM数据总线
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter define
parameter   IDLE    =   5'b0_0001   ,   //初始状态
            ARBIT   =   5'b0_0010   ,   //仲裁状态
            AREF    =   5'b0_0100   ,   //自动刷新状态
            WRITE   =   5'b0_1000   ,   //写状态
            READ    =   5'b1_0000   ;   //读状态
parameter   CMD_NOP =   4'b0111     ;   //空操作指令

//reg   define
reg     [3:0]   sdram_cmd   ;   //写入SDRAM命令
reg     [4:0]   state       ;   //状态机状态

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//state：状态机状态
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  IDLE;
    else    case(state)
        IDLE:   if(init_end == 1'b1)
                    state   <=  ARBIT;
                else
                    state   <=  IDLE;
        ARBIT:if(aref_req == 1'b1)
                    state   <=  AREF;
                else    if(wr_req == 1'b1)
                    state   <=  WRITE;
                else    if(rd_req == 1'b1)
                    state   <=  READ;
                else
                    state   <=  ARBIT;
        AREF:   if(aref_end == 1'b1)
                    state   <=  ARBIT;
                else
                    state   <=  AREF; 
        WRITE:  if(wr_end == 1'b1)
                    state   <=  ARBIT;
                else
                    state   <=  WRITE;
        READ:   if(rd_end == 1'b1)
                    state   <=  ARBIT;
                else
                    state   <=  READ;
        default:state   <=  IDLE;
    endcase

//aref_en：自动刷新使能
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        aref_en  <=  1'b0;
    else    if((state == ARBIT) && (aref_req == 1'b1))
        aref_en  <=  1'b1;
    else    if(aref_end == 1'b1)
        aref_en  <=  1'b0;

//wr_en：写数据使能
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_en   <=  1'b0;
    else    if((state == ARBIT) && (aref_req == 1'b0) && (wr_req == 1'b1))
        wr_en   <=  1'b1;
    else    if(wr_end == 1'b1)
        wr_en   <=  1'b0;

//rd_en：读数据使能
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_en   <=  1'b0;
    else    if((state == ARBIT) && (aref_req == 1'b0)  && (rd_req == 1'b1))
        rd_en   <=  1'b1;
    else    if(rd_end == 1'b1)
        rd_en   <=  1'b0;

//sdram_cmd:写入SDRAM命令;sdram_ba:SDRAM Bank地址;sdram_addr:SDRAM地址总线
always@(*)
    case(state) 
        IDLE: begin
            sdram_cmd   <=  init_cmd;
            sdram_ba    <=  init_ba;
            sdram_addr  <=  init_addr;
        end
        AREF: begin
            sdram_cmd   <=  aref_cmd;
            sdram_ba    <=  aref_ba;
            sdram_addr  <=  aref_addr;
        end
        WRITE: begin
            sdram_cmd   <=  wr_cmd;
            sdram_ba    <=  wr_ba;
            sdram_addr  <=  wr_addr;
        end
        READ: begin
            sdram_cmd   <=  rd_cmd;
            sdram_ba    <=  rd_ba;
            sdram_addr  <=  rd_addr;
        end
        default: begin
            sdram_cmd   <=  CMD_NOP;
            sdram_ba    <=  2'b11;
            sdram_addr  <=  13'h1fff;
        end
    endcase

//SDRAM时钟使能
assign  sdram_cke = 1'b1;
//SDRAM数据总线
assign  sdram_dq = (wr_sdram_en == 1'b1) ? wr_data : 16'bz;
//片选信号,行地址选通信号,列地址选通信号,写使能信号
assign  {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = sdram_cmd;

endmodule
