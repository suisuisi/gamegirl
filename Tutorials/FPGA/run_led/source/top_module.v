module top_module
(
   	input CLK,
	output reg[3:0]LED_Out
);   
    
	 
////////////////////////////////////////////	 




////////////////////////////////////////////
//
//首先定义一个时间计数寄存器counter，每当达到预定的100ms时，
//计数寄存器就清零，否则的话寄存器就加1��//然后计算计数器计数的最大值。时钟频率为12MHZ��//也就是周期为1/12M ��3ns，要计数的最大值为T100MS= 100ms/83ns-1 = 120_4818��//

reg[24:0] counter;
parameter T100MS = 25'd120_4818;

always @ (posedge CLK)

if(counter==T100MS)

	counter<=25'd0;

else

	counter<=counter+1'b1;
////////////////////////////////////////////
always @ (posedge CLK )

if(counter==T100MS)

	begin

		if(LED_Out==8'b0000)      //当溢出最高位��
			LED_Out<=8'b1111;    //回到复位时的状��
		else

			LED_Out<=LED_Out<<1;     //循环左移一��
	end

//assign {LED0,LED1,LED2,LED3,LED4,LED5,LED6,LED7}=LED;

endmodule // Run_LED
