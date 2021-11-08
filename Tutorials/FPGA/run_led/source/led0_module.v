module led0_module
(
    CLK, RSTn, LED_Out
);

    input CLK;
    input RSTn;
    output LED_Out;
    
    /*************************************/
    
    parameter T100MS = 23'd5_000_000;//DB4CE15开发板使用的晶振为50MHz，50M*0.01=5_000_000
    
    /*************************************/
    
    reg [22:0]Count1;
    
    always @ ( posedge CLK or negedge RSTn )
	    if( !RSTn )	
	        Count1 <= 23'd0;
	    else if( Count1 == T100MS )
	        Count1 <= 23'd0;
	    else
	        Count1 <= Count1 + 1'b1;
	        
	/*************************************/
	
	reg rLED_Out;
	
	always @ ( posedge CLK or negedge RSTn )
        if( !RSTn ) 
            rLED_Out <= 1'b0;
        else if( Count1 >= 23'd0 && Count1 < 23'd1_250_000 )//100ms的第一个四分之一，具体请看教程11页的图2.1C
            rLED_Out <= 1'b1;
        else 
            rLED_Out <= 1'b0;
            
     /***************************************/
     
     assign LED_Out = rLED_Out;
     
     /***************************************/
              
    
endmodule
