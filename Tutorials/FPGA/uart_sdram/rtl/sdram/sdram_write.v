`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : sdram_write
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : SDRAM写数据模块
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  sdram_write
(
    input   wire            sys_clk         ,   //系统时钟,频率100MHz
    input   wire            sys_rst_n       ,   //复位信号,低电平有效
    input   wire            init_end        ,   //初始化结束信号
    input   wire            wr_en           ,   //写使能
    input   wire    [23:0]  wr_addr         ,   //写SDRAM地址
    input   wire    [15:0]  wr_data         ,   //待写入SDRAM的数据(写FIFO传入)
    input   wire    [9:0]   wr_burst_len    ,   //写突发SDRAM字节数

    output  wire            wr_ack          ,   //写SDRAM响应信号
    output  wire            wr_end          ,   //一次突发写结束
    output  reg     [3:0]   write_cmd       ,   //写数据阶段写入sdram的指令,{cs_n,ras_n,cas_n,we_n}
    output  reg     [1:0]   write_ba        ,   //写数据阶段Bank地址
    output  reg     [12:0]  write_addr      ,   //地址数据,辅助预充电操作,行、列地址,A12-A0,13位地址
    output  reg             wr_sdram_en     ,   //数据总线输出使能
    output  wire    [15:0]  wr_sdram_data       //写入SDRAM的数据
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter     define
parameter   TRCD_CLK    =   10'd2   ,   //激活周期
            TRP_CLK     =   10'd2   ;   //预充电周期
parameter   WR_IDLE     =   4'b0000 ,   //初始状态
            WR_ACTIVE   =   4'b0001 ,   //激活
            WR_TRCD     =   4'b0011 ,   //激活等待
            WR_WRITE    =   4'b0010 ,   //写操作
            WR_DATA     =   4'b0100 ,   //写数据
            WR_PRE      =   4'b0101 ,   //预充电
            WR_TRP      =   4'b0111 ,   //预充电等待
            WR_END      =   4'b0110 ;   //一次突发写结束
parameter   NOP         =   4'b0111 ,   //空操作指令
            ACTIVE      =   4'b0011 ,   //激活指令
            WRITE       =   4'b0100 ,   //数据写指令
            B_STOP      =   4'b0110 ,   //突发停止指令
            P_CHARGE    =   4'b0010 ;   //预充电指令

//wire  define
wire            trcd_end    ;   //激活等待周期结束
wire            twrite_end  ;   //突发写结束
wire            trp_end     ;   //预充电有效周期结束

//reg   define
reg     [3:0]   write_state ;   //SDRAM写状态
reg     [9:0]   cnt_clk     ;   //时钟周期计数,记录写数据阶段各状态等待时间
reg             cnt_clk_rst ;   //时钟周期计数复位标志

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//wr_end:一次突发写结束
assign  wr_end = (write_state == WR_END) ? 1'b1 : 1'b0;

//wr_ack:写SDRAM响应信号
assign  wr_ack = ( write_state == WR_WRITE)
                || ((write_state == WR_DATA) 
                && (cnt_clk <= (wr_burst_len - 2'd2)));

//cnt_clk:时钟周期计数,记录初始化各状态等待时间
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  10'd0;
    else    if(cnt_clk_rst == 1'b1)
        cnt_clk <=  10'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

//trcd_end,twrite_end,trp_end:等待结束标志
assign  trcd_end    =   ((write_state == WR_TRCD)
                        &&(cnt_clk == TRCD_CLK        )) ? 1'b1 : 1'b0;    //激活周期结束
assign  twrite_end  =   ((write_state == WR_DATA)
                        &&(cnt_clk == wr_burst_len - 1)) ? 1'b1 : 1'b0;    //突发写结束
assign  trp_end     =   ((write_state == WR_TRP )
                        &&(cnt_clk == TRP_CLK         )) ? 1'b1 : 1'b0;    //预充电等待周期结束

//write_state:SDRAM的工作状态机
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
            write_state <=  WR_IDLE;
    else
        case(write_state)
            WR_IDLE:
                if((wr_en ==1'b1) && (init_end == 1'b1))
                        write_state <=  WR_ACTIVE;
                else
                        write_state <=  write_state;
            WR_ACTIVE:
                write_state <=  WR_TRCD;
            WR_TRCD:
                if(trcd_end == 1'b1)
                    write_state <=  WR_WRITE;
                else
                    write_state <=  write_state;
            WR_WRITE:
                write_state <=  WR_DATA;
            WR_DATA:
                if(twrite_end == 1'b1)
                    write_state <=  WR_PRE;
                else
                    write_state <=  write_state;
            WR_PRE:
                write_state <=  WR_TRP;
            WR_TRP:
                if(trp_end == 1'b1)
                    write_state <=  WR_END;
                else
                    write_state <=  write_state;

            WR_END:
                write_state <=  WR_IDLE;
            default:
                write_state <=  WR_IDLE;
        endcase

//计数器控制逻辑
always@(*)
    begin
        case(write_state)
            WR_IDLE:    cnt_clk_rst   <=  1'b1;
            WR_TRCD:    cnt_clk_rst   <=  (trcd_end == 1'b1) ? 1'b1 : 1'b0;
            WR_WRITE:   cnt_clk_rst   <=  1'b1;
            WR_DATA:    cnt_clk_rst   <=  (twrite_end == 1'b1) ? 1'b1 : 1'b0;
            WR_TRP:     cnt_clk_rst   <=  (trp_end == 1'b1) ? 1'b1 : 1'b0;
            WR_END:     cnt_clk_rst   <=  1'b1;
            default:    cnt_clk_rst   <=  1'b0;
        endcase
    end

//SDRAM操作指令控制
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            write_cmd   <=  NOP;
            write_ba    <=  2'b11;
            write_addr  <=  13'h1fff;
        end
    else
        case(write_state)
            WR_IDLE,WR_TRCD,WR_TRP:
                begin
                    write_cmd   <=  NOP;
                    write_ba    <=  2'b11;
                    write_addr  <=  13'h1fff;
                end
            WR_ACTIVE:  //激活指令
                begin
                    write_cmd   <=  ACTIVE;
                    write_ba    <=  wr_addr[23:22];
                    write_addr  <=  wr_addr[21:9];
                end
            WR_WRITE:   //写操作指令
                begin
                    write_cmd   <=  WRITE;
                    write_ba    <=  wr_addr[23:22];
                    write_addr  <=  {4'b0000,wr_addr[8:0]};
                end     
            WR_DATA:    //突发传输终止指令
                begin
                    if(twrite_end == 1'b1)
                        write_cmd <=  B_STOP;
                    else
                        begin
                            write_cmd   <=  NOP;
                            write_ba    <=  2'b11;
                            write_addr  <=  13'h1fff;
                        end
                end
            WR_PRE:     //预充电指令
                begin
                    write_cmd   <= P_CHARGE;
                    write_ba    <= wr_addr[23:22];
                    write_addr  <= 13'h0400;
                end
            WR_END:
                begin
                    write_cmd   <=  NOP;
                    write_ba    <=  2'b11;
                    write_addr  <=  13'h1fff;
                end
            default:
                begin
                    write_cmd   <=  NOP;
                    write_ba    <=  2'b11;
                    write_addr  <=  13'h1fff;
                end
        endcase

//wr_sdram_en:数据总线输出使能
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_sdram_en <=  1'b0;
    else
        wr_sdram_en <=  wr_ack;

//wr_sdram_data:写入SDRAM的数据
assign  wr_sdram_data = (wr_sdram_en == 1'b1) ? wr_data : 16'd0;

endmodule
