`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : fifo_ctrl
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : FIFO控制模块
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  fifo_ctrl
(
    input   wire            sys_clk         ,   //系统时钟
    input   wire            sys_rst_n       ,   //复位信号
//写fifo信号
    input   wire            wr_fifo_wr_clk  ,   //写FIFO写时钟
    input   wire            wr_fifo_wr_req  ,   //写FIFO写请求
    input   wire    [15:0]  wr_fifo_wr_data ,   //写FIFO写数据
    input   wire    [23:0]  sdram_wr_b_addr ,   //写SDRAM首地址
    input   wire    [23:0]  sdram_wr_e_addr ,   //写SDRAM末地址
    input   wire    [9:0]   wr_burst_len    ,   //写SDRAM数据突发长度
    input   wire            wr_rst          ,   //写复位信号
//读fifo信号
    input   wire            rd_fifo_rd_clk  ,   //读FIFO读时钟
    input   wire            rd_fifo_rd_req  ,   //读FIFO读请求
    input   wire    [23:0]  sdram_rd_b_addr ,   //读SDRAM首地址
    input   wire    [23:0]  sdram_rd_e_addr ,   //读SDRAM末地址
    input   wire    [9:0]   rd_burst_len    ,   //读SDRAM数据突发长度
    input   wire            rd_rst          ,   //读复位信号
    output  wire    [15:0]  rd_fifo_rd_data ,   //读FIFO读数据
    output  wire    [9:0]   rd_fifo_num     ,   //读fifo中的数据量

    input   wire            read_valid      ,   //SDRAM读使能
    input   wire            init_end        ,   //SDRAM初始化完成标志
//SDRAM写信号
    input   wire            sdram_wr_ack    ,   //SDRAM写响应
    output  reg             sdram_wr_req    ,   //SDRAM写请求
    output  reg     [23:0]  sdram_wr_addr   ,   //SDRAM写地址
    output  wire    [15:0]  sdram_data_in   ,   //写入SDRAM的数据
//SDRAM读信号
    input   wire            sdram_rd_ack    ,   //SDRAM读相应
    input   wire    [15:0]  sdram_data_out  ,   //读出SDRAM数据
    output  reg             sdram_rd_req    ,   //SDRAM读请求
    output  reg     [23:0]  sdram_rd_addr       //SDRAM读地址
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//wire define
wire            wr_ack_fall ;   //写响应信号下降沿
wire            rd_ack_fall ;   //读相应信号下降沿
wire    [9:0]   wr_fifo_num ;   //写fifo中的数据量

//reg define
reg        wr_ack_dly       ;   //写响应打拍
reg        rd_ack_dly       ;   //读响应打拍

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//wr_ack_dly:写响应信号打拍
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_ack_dly  <=  1'b0;
    else
        wr_ack_dly  <=  sdram_wr_ack;

//rd_ack_dly:读响应信号打拍
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_ack_dly  <=  1'b0;
    else
        rd_ack_dly <=  sdram_rd_ack;

//wr_ack_fall,rd_ack_fall:检测读写响应信号下降沿
assign  wr_ack_fall = (wr_ack_dly & ~sdram_wr_ack);
assign  rd_ack_fall = (rd_ack_dly & ~sdram_rd_ack);

//sdram_wr_addr:sdram写地址
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        sdram_wr_addr   <=  24'd0;
    else    if(wr_rst == 1'b1)
        sdram_wr_addr   <=  sdram_wr_b_addr;
    else    if(wr_ack_fall == 1'b1) //一次突发写结束,更改写地址
        begin
            if(sdram_wr_addr < (sdram_wr_e_addr - wr_burst_len))
                        //不使用乒乓操作,一次突发写结束,更改写地址,未达到末地址,写地址累加
                sdram_wr_addr   <=  sdram_wr_addr + wr_burst_len;
            else        //不使用乒乓操作,到达末地址,回到写起始地址
                sdram_wr_addr   <=  sdram_wr_b_addr;
        end

//sdram_rd_addr:sdram读地址
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        sdram_rd_addr   <=  24'd0;
    else    if(rd_rst == 1'b1)
        sdram_rd_addr   <=  sdram_rd_b_addr;
    else    if(rd_ack_fall == 1'b1) //一次突发读结束,更改读地址
        begin
            if(sdram_rd_addr < (sdram_rd_e_addr - rd_burst_len))
                    //读地址未达到末地址,读地址累加
                sdram_rd_addr   <=  sdram_rd_addr + rd_burst_len;
            else    //到达末地址,回到首地址
                sdram_rd_addr   <=  sdram_rd_b_addr;
        end

//sdram_wr_req,sdram_rd_req:读写请求信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            sdram_wr_req    <=  1'b0;
            sdram_rd_req    <=  1'b0;
        end
    else    if(init_end == 1'b1)   //初始化完成后响应读写请求
        begin   //优先执行写操作，防止写入SDRAM中的数据丢失
            if(wr_fifo_num >= wr_burst_len)
                begin   //写FIFO中的数据量达到写突发长度
                    sdram_wr_req    <=  1'b1;   //写请求有效
                    sdram_rd_req    <=  1'b0;
                end
            else    if((rd_fifo_num < rd_burst_len) && (read_valid == 1'b1))
                begin //读FIFO中的数据量小于读突发长度,且读使能信号有效
                    sdram_wr_req    <=  1'b0;
                    sdram_rd_req    <=  1'b1;   //读请求有效
                end
            else
                begin
                    sdram_wr_req    <=  1'b0;
                    sdram_rd_req    <=  1'b0;
                end
        end
    else
        begin
            sdram_wr_req    <=  1'b0;
            sdram_rd_req    <=  1'b0;
        end

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//------------- wr_fifo_data -------------
fifo_data   wr_fifo_data(
    //用户接口
    .wrclk      (wr_fifo_wr_clk ),  //写时钟
    .wrreq      (wr_fifo_wr_req ),  //写请求
    .data       (wr_fifo_wr_data),  //写数据
    //SDRAM接口
    .rdclk      (sys_clk        ),  //读时钟
    .rdreq      (sdram_wr_ack   ),  //读请求
    .q          (sdram_data_in  ),  //读数据

    .rdusedw    (wr_fifo_num    ),  //FIFO中的数据量
    .wrusedw    (               ),
    .aclr       (~sys_rst_n || wr_rst)  //清零信号
    );

//------------- rd_fifo_data -------------
fifo_data   rd_fifo_data(
    //sdram接口
    .wrclk      (sys_clk        ),  //写时钟
    .wrreq      (sdram_rd_ack   ),  //写请求
    .data       (sdram_data_out ),  //写数据
    //用户接口
    .rdclk      (rd_fifo_rd_clk ),  //读时钟
    .rdreq      (rd_fifo_rd_req ),  //读请求
    .q          (rd_fifo_rd_data),  //读数据

    .rdusedw    (               ),
    .wrusedw    (rd_fifo_num    ),  //FIFO中的数据量
    .aclr       (~sys_rst_n || rd_rst)  //清零信号
    );

endmodule
