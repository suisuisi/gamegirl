`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/08/25
// Module Name   : tb_uart_sdram
// Project Name  : uart_sdram
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : uart_sdram模块仿真文件
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  tb_uart_sdram();

//********************************************************************//
//****************** Internal Signal and Defparam ********************//
//********************************************************************//

//wire define
wire            tx          ;
wire            sdram_clk   ;
wire            sdram_cke   ;
wire            sdram_cs_n  ;
wire            sdram_cas_n ;
wire            sdram_ras_n ;
wire            sdram_we_n  ;
wire    [1:0]   sdram_ba    ;
wire    [12:0]  sdram_addr  ;
wire    [1:0]   sdram_dqm   ;
wire    [15:0]  sdram_dq    ;

//reg define
reg           sys_clk   ;
reg           sys_rst_n ;
reg           rx    ;
reg   [7:0]   data_mem [9:0] ;  //data_mem是一个存储器，相当于一个ram

//********************************************************************//
//**************************** Clk And Rst ***************************//
//********************************************************************//

//读取sim文件夹下面的data.txt文件，并把读出的数据定义为data_mem
initial
  $readmemh("E:/sources/sdram_test/uart_sdram/sim/test_data.txt",data_mem);

//时钟、复位信号
initial
  begin
    sys_clk     =   1'b1  ;
    sys_rst_n   <=  1'b0  ;
    #200
    sys_rst_n   <=  1'b1  ;
  end

always  #10 sys_clk = ~sys_clk;


initial
  begin
    rx  <=  1'b1;
    #200
    rx_byte();
  end

task  rx_byte();
  integer j;
  for(j=0;j<10;j=j+1)
    rx_bit(data_mem[j]);
endtask

task  rx_bit(input[7:0] data);  //data是data_mem[j]的值。
  integer i;
    for(i=0;i<10;i=i+1)
      begin
        case(i)
          0:  rx  <=  1'b0   ;  //起始位
          1:  rx  <=  data[0];
          2:  rx  <=  data[1];
          3:  rx  <=  data[2];
          4:  rx  <=  data[3];
          5:  rx  <=  data[4];
          6:  rx  <=  data[5];
          7:  rx  <=  data[6];
          8:  rx  <=  data[7];  //上面8个发送的是数据位
          9:  rx  <=  1'b1   ;  //停止位
        endcase
        #1040;                  //一个波特时间=ssys_clk周期*波特计数器
      end
endtask

//重定义defparam,用于修改参数,缩短仿真时间
defparam uart_sdram_inst.uart_rx_inst.BAUD_CNT_END      = 52;
defparam uart_sdram_inst.uart_rx_inst.BAUD_CNT_END_HALF = 26;
defparam uart_sdram_inst.uart_tx_inst.BAUD_CNT_END      = 52;
defparam uart_sdram_inst.fifo_read_inst.BAUD_CNT_END_HALF = 26;
defparam uart_sdram_inst.fifo_read_inst.BAUD_CNT_END      = 52;
defparam sdram_model_plus_inst.addr_bits = 13;
defparam sdram_model_plus_inst.data_bits = 16;
defparam sdram_model_plus_inst.col_bits  = 9;
defparam sdram_model_plus_inst.mem_sizes = 2*1024*1024;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//-------------uart_sdram_inst-------------
uart_sdram  uart_sdram_inst(

    .sys_clk     (sys_clk     ),
    .sys_rst_n   (sys_rst_n   ),
    .rx          (rx          ),

    .tx          (tx          ),

    .sdram_clk   (sdram_clk   ),
    .sdram_cke   (sdram_cke   ),
    .sdram_cs_n  (sdram_cs_n  ),
    .sdram_cas_n (sdram_cas_n ),
    .sdram_ras_n (sdram_ras_n ),
    .sdram_we_n  (sdram_we_n  ),
    .sdram_ba    (sdram_ba    ),
    .sdram_addr  (sdram_addr  ),
    .sdram_dqm   (sdram_dqm   ),
    .sdram_dq    (sdram_dq    )

);

//-------------sdram_model_plus_inst-------------
sdram_model_plus    sdram_model_plus_inst(
    .Dq     (sdram_dq       ),
    .Addr   (sdram_addr     ),
    .Ba     (sdram_ba       ),
    .Clk    (sdram_clk      ),
    .Cke    (sdram_cke      ),
    .Cs_n   (sdram_cs_n     ),
    .Ras_n  (sdram_ras_n    ),
    .Cas_n  (sdram_cas_n    ),
    .We_n   (sdram_we_n     ),
    .Dqm    (sdram_dqm      ),
    .Debug  (1'b1           )
);

endmodule