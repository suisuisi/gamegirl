`timescale  1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : sdram_a_ref
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : SDRAM自动刷新模块
//
// Revision      :V1.1
// Additional Comments:
//
// 实验平台:野火FPGA开发板
// 公司    :http://www.embedfire.com
// 论坛    :http://www.firebbs.cn
// 淘宝    :https://fire-stm32.taobao.com
//////////////////////////////////////////////////////////////////////////////////

module  sdram_a_ref
(
    input   wire            sys_clk     ,   //系统时钟,频率100MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
    input   wire            init_end    ,   //初始化结束信号
    input   wire            aref_en     ,   //自动刷新使能

    output  reg             aref_req    ,   //自动刷新请求
    output  reg     [3:0]   aref_cmd    ,   //自动刷新阶段写入sdram的指令,{cs_n,ras_n,cas_n,we_n}
    output  reg     [1:0]   aref_ba     ,   //自动刷新阶段Bank地址
    output  reg     [12:0]  aref_addr   ,   //地址数据,辅助预充电操作,A12-A0,13位地址
    output  wire            aref_end        //自动刷新结束标志
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//parameter     define
parameter   CNT_REF_MAX =   10'd749     ;   //自动刷新等待时钟数(7.5us)
parameter   TRP_CLK     =   3'd2        ,   //预充电等待周期
            TRC_CLK     =   3'd7        ;   //自动刷新等待周期
parameter   P_CHARGE    =   4'b0010     ,   //预充电指令
            A_REF       =   4'b0001     ,   //自动刷新指令
            NOP         =   4'b0111     ;   //空操作指令
parameter   AREF_IDLE   =   3'b000      ,   //初始状态,等待自动刷新使能
            AREF_PCHA   =   3'b001      ,   //预充电状态
            AREF_TRP    =   3'b011      ,   //预充电等待          tRP
            AUTO_REF    =   3'b010      ,   //自动刷新状态
            AREF_TRF    =   3'b100      ,   //自动刷新等待        tRC
            AREF_END    =   3'b101      ;   //自动刷新结束

//wire  define
wire            trp_end     ;   //预充电等待结束标志
wire            trc_end     ;   //自动刷新等待结束标志
wire            aref_ack    ;   //自动刷新应答信号

//reg   define
reg     [9:0]   cnt_aref        ;   //自动刷新计数器
reg     [2:0]   aref_state      ;   //SDRAM自动刷新状态
reg     [2:0]   cnt_clk         ;   //时钟周期计数,记录自刷新阶段各状态等待时间
reg             cnt_clk_rst     ;   //时钟周期计数复位标志
reg     [1:0]   cnt_aref_aref   ;   //自动刷新次数计数器

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//cnt_ref:刷新计数器
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_aref    <=  10'd0;
    else    if(cnt_aref >= CNT_REF_MAX)
        cnt_aref    <=  10'd0;
    else    if(init_end == 1'b1)
        cnt_aref    <=  cnt_aref + 1'b1;

//aref_req:自动刷新请求
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        aref_req    <=  1'b0;
    else    if(cnt_aref == (CNT_REF_MAX - 1'b1))
        aref_req    <=  1'b1;
    else    if(aref_ack == 1'b1)
        aref_req    <=  1'b0;

//aref_ack:自动刷新应答信号
assign  aref_ack = (aref_state == AREF_PCHA ) ? 1'b1 : 1'b0;

//aref_end:自动刷新结束标志
assign  aref_end = (aref_state == AREF_END  ) ? 1'b1 : 1'b0;

//cnt_clk:时钟周期计数,记录初始化各状态等待时间
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  3'd0;
    else    if(cnt_clk_rst == 1'b1)
        cnt_clk <=  3'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

//trp_end,trc_end,tmrd_end:等待结束标志
assign  trp_end = ((aref_state == AREF_TRP)
                    && (cnt_clk == TRP_CLK )) ? 1'b1 : 1'b0;
assign  trc_end = ((aref_state == AREF_TRF)
                    && (cnt_clk == TRC_CLK )) ? 1'b1 : 1'b0;

//cnt_aref_aref:初始化过程自动刷新次数计数器
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_aref_aref   <=  2'd0;
    else    if(aref_state == AREF_IDLE)
        cnt_aref_aref   <=  2'd0;
    else    if(aref_state == AUTO_REF)
        cnt_aref_aref   <=  cnt_aref_aref + 1'b1;
    else
        cnt_aref_aref   <=  cnt_aref_aref;

//SDRAM自动刷新状态机
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        aref_state  <=  AREF_IDLE;
    else
        case(aref_state)
            AREF_IDLE:
                if((aref_en == 1'b1) && (init_end == 1'b1))
                    aref_state  <=  AREF_PCHA;
                else
                    aref_state  <=  aref_state;
            AREF_PCHA:
                aref_state  <=  AREF_TRP;
            AREF_TRP:
                if(trp_end == 1'b1)
                    aref_state  <=  AUTO_REF;
                else
                    aref_state  <=  aref_state;
            AUTO_REF:
                aref_state  <=  AREF_TRF;
            AREF_TRF:
                if(trc_end == 1'b1)
                    if(cnt_aref_aref == 2'd2)
                        aref_state  <=  AREF_END;
                    else
                        aref_state  <=  AUTO_REF;
                else
                    aref_state  <=  aref_state;
            AREF_END:
                aref_state  <=  AREF_IDLE;
            default:
                aref_state  <=  AREF_IDLE;
        endcase

//cnt_clk_rst:时钟周期计数复位标志
always@(*)
    begin
        case (aref_state)
            AREF_IDLE:  cnt_clk_rst <=  1'b1;   //时钟周期计数器清零
            AREF_TRP:   cnt_clk_rst <=  (trp_end == 1'b1) ? 1'b1 : 1'b0;
                                                //等待结束标志有效,计数器清零
            AREF_TRF:   cnt_clk_rst <=  (trc_end == 1'b1) ? 1'b1 : 1'b0;
                                                //等待结束标志有效,计数器清零
            AREF_END:   cnt_clk_rst <=  1'b1;
            default:    cnt_clk_rst <=  1'b0;
        endcase
    end

//SDRAM操作指令控制
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            aref_cmd    <=  NOP;
            aref_ba     <=  2'b11;
            aref_addr   <=  13'h1fff;
        end
    else
        case(aref_state)
            AREF_IDLE,AREF_TRP,AREF_TRF:    //执行空操作指令
                begin
                    aref_cmd    <=  NOP;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end
            AREF_PCHA:  //预充电指令
                begin
                    aref_cmd    <=  P_CHARGE;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end 
            AUTO_REF:   //自动刷新指令
                begin
                    aref_cmd    <=  A_REF;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end
            AREF_END:   //一次自动刷新完成
                begin
                    aref_cmd    <=  NOP;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end    
            default:
                begin
                    aref_cmd    <=  NOP;
                    aref_ba     <=  2'b11;
                    aref_addr   <=  13'h1fff;
                end    
        endcase

endmodule
