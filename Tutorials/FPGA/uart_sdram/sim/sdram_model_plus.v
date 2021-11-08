/***************************************************************************************
作者：	李晟
2003-08-27	V0.1	李晟 
 
 添加内存模块倒空功能，在外部需要创建事件：sdram_r ,本SDRAM的内容将会按Bank 顺序damp out 至文件
 sdram_data.txt 中
×××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××××*/
//2004-03-04	陈乃奎	修改原程序中将BANK的数据转存入TXT文件的格式
//2004-03-16	陈乃奎	修改SDRAM 的初始化数据
//2004/04/06	陈乃奎	将SDRAM的操作命令以字符形式表示，以便用MODELSIM监视
//2004/04/19	陈乃奎	修改参数 parameter tAC  =   8;
//2010/09/17	罗瑶	修改sdram的大小，数据位宽，dqm宽度;
/****************************************************************************************
*
*    File Name:  sdram_model.V  
*      Version:  0.0f
*         Date:  July 8th, 1999
*        Model:  BUS Functional
*    Simulator:  Model Technology (PC version 5.2e PE)
*
* Dependencies:  None
*
*       Author:  Son P. Huynh
*        Email:  sphuynh@micron.com
*        Phone:  (208) 368-3825
*      Company:  Micron Technology, Inc.
*        Model:  sdram_model (1Meg x 16 x 4 Banks)
*
*  Description:  64Mb SDRAM Verilog model
*
*   Limitation:  - Doesn't check for 4096 cycle refresh
*
*         Note:  - Set simulator resolution to "ps" accuracy
*                - Set Debug = 0 to disable $display messages
*
*   Disclaimer:  THESE DESIGNS ARE PROVIDED "AS IS" WITH NO WARRANTY 
*                WHATSOEVER AND MICRON SPECIFICALLY DISCLAIMS ANY 
*                IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
*                A PARTICULAR PURPOSE, OR AGAINST INFRINGEMENT.
*
*                Copyright ?1998 Micron Semiconductor Products, Inc.
*                All rights researved
*
* Rev   Author          Phone         Date        Changes
* ----  ----------------------------  ----------  ---------------------------------------
* 0.0f  Son Huynh       208-368-3825  07/08/1999  - Fix tWR = 1 Clk + 7.5 ns (Auto)
*       Micron Technology Inc.                    - Fix tWR = 15 ns (Manual)
*                                                 - Fix tRP (Autoprecharge to AutoRefresh)
*
* 0.0a  Son Huynh       208-368-3825  05/13/1998  - First Release (from 64Mb rev 0.0e)
*       Micron Technology Inc.
****************************************************************************************/

`timescale 1ns / 100ps

module sdram_model_plus (Dq, Addr, Ba, Clk, Cke, Cs_n, Ras_n, Cas_n, We_n, Dqm,Debug);

    parameter addr_bits =	11;
    parameter data_bits = 	32;
    parameter col_bits  =	8;
    parameter mem_sizes =	1048576*2-1;//1 Meg 

    inout     [data_bits - 1 : 0] Dq;
    input     [addr_bits - 1 : 0] Addr;
    input                 [1 : 0] Ba;
    input                         Clk;
    input                         Cke;
    input                         Cs_n;
    input                         Ras_n;
    input                         Cas_n;
    input                         We_n;
    input                 [3 : 0] Dqm;          //高低各8bit
    //added by xzli
    input			  Debug;

    reg       [data_bits - 1 : 0] Bank0 [0 : mem_sizes];//存储器类型数据
    reg       [data_bits - 1 : 0] Bank1 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank2 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank3 [0 : mem_sizes];

    reg                   [1 : 0] Bank_addr [0 : 3];                // Bank Address Pipeline
    reg        [col_bits - 1 : 0] Col_addr [0 : 3];                 // Column Address Pipeline
    reg                   [3 : 0] Command [0 : 3];                  // Command Operation Pipeline
    reg                   [3 : 0] Dqm_reg0, Dqm_reg1;               // DQM Operation Pipeline
    reg       [addr_bits - 1 : 0] B0_row_addr, B1_row_addr, B2_row_addr, B3_row_addr;

    reg       [addr_bits - 1 : 0] Mode_reg;
    reg       [data_bits - 1 : 0] Dq_reg, Dq_dqm;
    reg       [col_bits - 1 : 0] Col_temp, Burst_counter;

    reg                           Act_b0, Act_b1, Act_b2, Act_b3;   // Bank Activate
    reg                           Pc_b0, Pc_b1, Pc_b2, Pc_b3;       // Bank Precharge

    reg                   [1 : 0] Bank_precharge     [0 : 3];       // Precharge Command
    reg                           A10_precharge      [0 : 3];       // Addr[10] = 1 (All banks)
    reg                           Auto_precharge     [0 : 3];       // RW AutoPrecharge (Bank)
    reg                           Read_precharge     [0 : 3];       // R  AutoPrecharge
    reg                           Write_precharge    [0 : 3];       //  W AutoPrecharge
    integer                       Count_precharge    [0 : 3];       // RW AutoPrecharge (Counter)
    reg                           RW_interrupt_read  [0 : 3];       // RW Interrupt Read with Auto Precharge
    reg                           RW_interrupt_write [0 : 3];       // RW Interrupt Write with Auto Precharge

    reg                           Data_in_enable;
    reg                           Data_out_enable;

    reg                   [1 : 0] Bank, Previous_bank;
    reg       [addr_bits - 1 : 0] Row;
    reg        [col_bits - 1 : 0] Col, Col_brst;

    // Internal system clock
    reg                           CkeZ, Sys_clk;

    reg	[21:0]	dd;
    
    // Commands Decode
    wire      Active_enable    = ~Cs_n & ~Ras_n &  Cas_n &  We_n;
    wire      Aref_enable      = ~Cs_n & ~Ras_n & ~Cas_n &  We_n;
    wire      Burst_term       = ~Cs_n &  Ras_n &  Cas_n & ~We_n;
    wire      Mode_reg_enable  = ~Cs_n & ~Ras_n & ~Cas_n & ~We_n;
    wire      Prech_enable     = ~Cs_n & ~Ras_n &  Cas_n & ~We_n;
    wire      Read_enable      = ~Cs_n &  Ras_n & ~Cas_n &  We_n;
    wire      Write_enable     = ~Cs_n &  Ras_n & ~Cas_n & ~We_n;

    // Burst Length Decode
    wire      Burst_length_1   = ~Mode_reg[2] & ~Mode_reg[1] & ~Mode_reg[0];
    wire      Burst_length_2   = ~Mode_reg[2] & ~Mode_reg[1] &  Mode_reg[0];
    wire      Burst_length_4   = ~Mode_reg[2] &  Mode_reg[1] & ~Mode_reg[0];
    wire      Burst_length_8   = ~Mode_reg[2] &  Mode_reg[1] &  Mode_reg[0];

    // CAS Latency Decode
    wire      Cas_latency_2    = ~Mode_reg[6] &  Mode_reg[5] & ~Mode_reg[4];
    wire      Cas_latency_3    = ~Mode_reg[6] &  Mode_reg[5] &  Mode_reg[4];

    // Write Burst Mode
    wire      Write_burst_mode = Mode_reg[9];

    wire      Debug;		// Debug messages : 1 = On; 0 = Off
    wire      Dq_chk           = Sys_clk & Data_in_enable;      // Check setup/hold time for DQ

    reg		[31:0]	mem_d;
    
    event	sdram_r,sdram_w,compare;
    
    
   
   
    assign    Dq               = Dq_reg;                        // DQ buffer

    // Commands Operation
    `define   ACT       0
    `define   NOP       1
    `define   READ      2
    `define   READ_A    3
    `define   WRITE     4
    `define   WRITE_A   5
    `define   PRECH     6
    `define   A_REF     7
    `define   BST       8
    `define   LMR       9

//    // Timing Parameters for -75 (PC133) and CAS Latency = 2
//    parameter tAC  =   8;	//test 6.5
//    parameter tHZ  =   7.0;
//    parameter tOH  =   2.7;
//    parameter tMRD =   2.0;     // 2 Clk Cycles
//    parameter tRAS =  44.0;
//    parameter tRC  =  66.0;
//    parameter tRCD =  20.0;
//    parameter tRP  =  20.0;
//    parameter tRRD =  15.0;
//    parameter tWRa =   7.5;     // A2 Version - Auto precharge mode only (1 Clk + 7.5 ns)
//    parameter tWRp =  0.0;     // A2 Version - Precharge mode only (15 ns)

    // Timing Parameters for -7 (PC143) and CAS Latency = 3
    parameter tAC  =   6.5;	//test 6.5
    parameter tHZ  =   5.5;
    parameter tOH  =   2;
    parameter tMRD =   2.0;     // 2 Clk Cycles
    parameter tRAS =  48.0;
    parameter tRC  =  70.0;
    parameter tRCD =  20.0;
    parameter tRP  =  20.0;
    parameter tRRD =  14.0;
    parameter tWRa =   7.5;     // A2 Version - Auto precharge mode only (1 Clk + 7.5 ns)
    parameter tWRp =  0.0;     // A2 Version - Precharge mode only (15 ns)
    
    // Timing Check variable
    integer   MRD_chk;
    integer   WR_counter [0 : 3];
    time      WR_chk [0 : 3];
    time      RC_chk, RRD_chk;
    time      RAS_chk0, RAS_chk1, RAS_chk2, RAS_chk3;
    time      RCD_chk0, RCD_chk1, RCD_chk2, RCD_chk3;
    time      RP_chk0, RP_chk1, RP_chk2, RP_chk3;

    integer	test_file;
    
    //*****display the command of the sdram**************************************
    
    parameter	Mode_Reg_Set	=4'b0000;
    parameter	Auto_Refresh	=4'b0001;
    parameter	Row_Active	=4'b0011;
    parameter	Pre_Charge	=4'b0010;
    parameter	PreCharge_All	=4'b0010;
    parameter	Write		=4'b0100;
    parameter	Write_Pre	=4'b0100;
    parameter	Read		=4'b0101;
    parameter	Read_Pre	=4'b0101;
    parameter	Burst_Stop	=4'b0110;
    parameter	Nop		=4'b0111;
    parameter	Dsel		=4'b1111;

    wire	[3:0]	sdram_control;
    reg			cke_temp;
    reg		[8*13:1]	sdram_command;
   
    always@(posedge Clk)
	cke_temp<=Cke;

    assign	sdram_control={Cs_n,Ras_n,Cas_n,We_n};

    always@(sdram_control or cke_temp)
	begin
		case(sdram_control)
			Mode_Reg_Set:	sdram_command<="Mode_Reg_Set";
			Auto_Refresh:	sdram_command<="Auto_Refresh";
			Row_Active:	sdram_command<="Row_Active";
			Pre_Charge:	sdram_command<="Pre_Charge";
			Burst_Stop:	sdram_command<="Burst_Stop";
			Dsel:		sdram_command<="Dsel";

			Write:		if(cke_temp==1)
						sdram_command<="Write";
					else
						sdram_command<="Write_suspend";
						
			Read:		if(cke_temp==1)
						sdram_command<="Read";
					else
						sdram_command<="Read_suspend";
						
			Nop:		if(cke_temp==1)
						sdram_command<="Nop";
					else
						sdram_command<="Self_refresh";
						
			default:	sdram_command<="Power_down";
		endcase
	end

    //*****************************************************
    
    initial 
    	begin
		//test_file=$fopen("test_file.txt");
	end

    initial 
    	begin
        Dq_reg = {data_bits{1'bz}};
        {Data_in_enable, Data_out_enable} = 0;
        {Act_b0, Act_b1, Act_b2, Act_b3} = 4'b0000;
        {Pc_b0, Pc_b1, Pc_b2, Pc_b3} = 4'b0000;
        {WR_chk[0], WR_chk[1], WR_chk[2], WR_chk[3]} = 0;
        {WR_counter[0], WR_counter[1], WR_counter[2], WR_counter[3]} = 0;
        {RW_interrupt_read[0], RW_interrupt_read[1], RW_interrupt_read[2], RW_interrupt_read[3]} = 0;
        {RW_interrupt_write[0], RW_interrupt_write[1], RW_interrupt_write[2], RW_interrupt_write[3]} = 0;
        {MRD_chk, RC_chk, RRD_chk} = 0;
        {RAS_chk0, RAS_chk1, RAS_chk2, RAS_chk3} = 0;
        {RCD_chk0, RCD_chk1, RCD_chk2, RCD_chk3} = 0;
        {RP_chk0, RP_chk1, RP_chk2, RP_chk3} = 0;
        $timeformat (-9, 0, " ns", 12);
        //$readmemh("bank0.txt", Bank0);
        //$readmemh("bank1.txt", Bank1);
        //$readmemh("bank2.txt", Bank2);
        //$readmemh("bank3.txt", Bank3);
/*  	
  	 for(dd=0;dd<=mem_sizes;dd=dd+1)
        	begin
        		Bank0[dd]=dd[data_bits - 1 : 0];
        		Bank1[dd]=dd[data_bits - 1 : 0]+1;
        		Bank2[dd]=dd[data_bits - 1 : 0]+2;
        		Bank3[dd]=dd[data_bits - 1 : 0]+3;
        	end
*/        	
  	initial_sdram(0);
  	end
 
        task	initial_sdram; 
 
 		input		data_sign;
 		reg	[3:0]	data_sign;
 	     
       		for(dd=0;dd<=mem_sizes;dd=dd+1)
        	begin
        		mem_d = {data_sign,data_sign,data_sign,data_sign,data_sign,data_sign,data_sign,data_sign};
        		if(data_bits==16)
        			begin
        				Bank0[dd]=mem_d[15:0];
        				Bank1[dd]=mem_d[15:0];
        				Bank2[dd]=mem_d[15:0];
        				Bank3[dd]=mem_d[15:0];
        			end
        		else if(data_bits==32)
        			begin
        				Bank0[dd]=mem_d[31:0];
        				Bank1[dd]=mem_d[31:0];
        				Bank2[dd]=mem_d[31:0];
        				Bank3[dd]=mem_d[31:0];
        			end
        	end	
      	
       		endtask

    // System clock generator
    always
    	begin
       		@(posedge Clk)
       			begin
            			Sys_clk = CkeZ;
            			CkeZ = Cke;
        		end
        	@(negedge Clk) 
        		begin
            			Sys_clk = 1'b0;
        		end
    	end

    always @ (posedge Sys_clk) begin
        // Internal Commamd Pipelined
        Command[0] = Command[1];
        Command[1] = Command[2];
        Command[2] = Command[3];
        Command[3] = `NOP;

        Col_addr[0] = Col_addr[1];
        Col_addr[1] = Col_addr[2];
        Col_addr[2] = Col_addr[3];
        Col_addr[3] = {col_bits{1'b0}};

        Bank_addr[0] = Bank_addr[1];
        Bank_addr[1] = Bank_addr[2];
        Bank_addr[2] = Bank_addr[3];
        Bank_addr[3] = 2'b0;

        Bank_precharge[0] = Bank_precharge[1];
        Bank_precharge[1] = Bank_precharge[2];
        Bank_precharge[2] = Bank_precharge[3];
        Bank_precharge[3] = 2'b0;

        A10_precharge[0] = A10_precharge[1];
        A10_precharge[1] = A10_precharge[2];
        A10_precharge[2] = A10_precharge[3];
        A10_precharge[3] = 1'b0;

        // Dqm pipeline for Read
        Dqm_reg0 = Dqm_reg1;
        Dqm_reg1 = Dqm;

        // Read or Write with Auto Precharge Counter
        if (Auto_precharge[0] == 1'b1) begin
            Count_precharge[0] = Count_precharge[0] + 1;
        end
        if (Auto_precharge[1] == 1'b1) begin
            Count_precharge[1] = Count_precharge[1] + 1;
        end
        if (Auto_precharge[2] == 1'b1) begin
            Count_precharge[2] = Count_precharge[2] + 1;
        end
        if (Auto_precharge[3] == 1'b1) begin
            Count_precharge[3] = Count_precharge[3] + 1;
        end

        // tMRD Counter
        MRD_chk = MRD_chk + 1;

        // tWR Counter for Write
        WR_counter[0] = WR_counter[0] + 1;
        WR_counter[1] = WR_counter[1] + 1;
        WR_counter[2] = WR_counter[2] + 1;
        WR_counter[3] = WR_counter[3] + 1;

        // Auto Refresh
        if (Aref_enable == 1'b1) begin
            if (Debug) $display ("at time %t AREF : Auto Refresh", $time);
            // Auto Refresh to Auto Refresh
            if (($time - RC_chk < tRC)&&Debug) begin
                $display ("at time %t ERROR: tRC violation during Auto Refresh", $time);
            end
            // Precharge to Auto Refresh
            if (($time - RP_chk0 < tRP || $time - RP_chk1 < tRP || $time - RP_chk2 < tRP || $time - RP_chk3 < tRP)&&Debug) begin
                $display ("at time %t ERROR: tRP violation during Auto Refresh", $time);
            end
            // Precharge to Refresh
            if (Pc_b0 == 1'b0 || Pc_b1 == 1'b0 || Pc_b2 == 1'b0 || Pc_b3 == 1'b0) begin
                $display ("at time %t ERROR: All banks must be Precharge before Auto Refresh", $time);
            end
            // Record Current tRC time
            RC_chk = $time;
        end
        
        // Load Mode Register
        if (Mode_reg_enable == 1'b1) begin
            // Decode CAS Latency, Burst Length, Burst Type, and Write Burst Mode
            if (Pc_b0 == 1'b1 && Pc_b1 == 1'b1 && Pc_b2 == 1'b1 && Pc_b3 == 1'b1) begin
                Mode_reg = Addr;
                if (Debug) begin
                    $display ("at time %t LMR  : Load Mode Register", $time);
                    // CAS Latency
                    if (Addr[6 : 4] == 3'b010)
                        $display ("                            CAS Latency      = 2");
                    else if (Addr[6 : 4] == 3'b011)
                        $display ("                            CAS Latency      = 3");
                    else
                        $display ("                            CAS Latency      = Reserved");
                    // Burst Length
                    if (Addr[2 : 0] == 3'b000)
                        $display ("                            Burst Length     = 1");
                    else if (Addr[2 : 0] == 3'b001)
                        $display ("                            Burst Length     = 2");
                    else if (Addr[2 : 0] == 3'b010)
                        $display ("                            Burst Length     = 4");
                    else if (Addr[2 : 0] == 3'b011)
                        $display ("                            Burst Length     = 8");
                    else if (Addr[3 : 0] == 4'b0111)
                        $display ("                            Burst Length     = Full");
                    else
                        $display ("                            Burst Length     = Reserved");
                    // Burst Type
                    if (Addr[3] == 1'b0)
                        $display ("                            Burst Type       = Sequential");
                    else if (Addr[3] == 1'b1)
                        $display ("                            Burst Type       = Interleaved");
                    else
                        $display ("                            Burst Type       = Reserved");
                    // Write Burst Mode
                    if (Addr[9] == 1'b0)
                        $display ("                            Write Burst Mode = Programmed Burst Length");
                    else if (Addr[9] == 1'b1)
                        $display ("                            Write Burst Mode = Single Location Access");
                    else
                        $display ("                            Write Burst Mode = Reserved");
                end
            end else begin
                $display ("at time %t ERROR: all banks must be Precharge before Load Mode Register", $time);
            end
            // REF to LMR
            if ($time - RC_chk < tRC) begin
                $display ("at time %t ERROR: tRC violation during Load Mode Register", $time);
            end
            // LMR to LMR
            if (MRD_chk < tMRD) begin
                $display ("at time %t ERROR: tMRD violation during Load Mode Register", $time);
            end
            MRD_chk = 0;
        end
        
        // Active Block (Latch Bank Address and Row Address)
        if (Active_enable == 1'b1) begin
            if (Ba == 2'b00 && Pc_b0 == 1'b1) begin
                {Act_b0, Pc_b0} = 2'b10;
                B0_row_addr = Addr [addr_bits - 1 : 0];
                RCD_chk0 = $time;
                RAS_chk0 = $time;
                if (Debug) $display ("at time %t ACT  : Bank = 0 Row = %d", $time, Addr);
                // Precharge to Activate Bank 0
                if ($time - RP_chk0 < tRP) begin
                    $display ("at time %t ERROR: tRP violation during Activate bank 0", $time);
                end
            end else if (Ba == 2'b01 && Pc_b1 == 1'b1) begin
                {Act_b1, Pc_b1} = 2'b10;
                B1_row_addr = Addr [addr_bits - 1 : 0];
                RCD_chk1 = $time;
                RAS_chk1 = $time;
                if (Debug) $display ("at time %t ACT  : Bank = 1 Row = %d", $time, Addr);
                // Precharge to Activate Bank 1
                if ($time - RP_chk1 < tRP) begin
                    $display ("at time %t ERROR: tRP violation during Activate bank 1", $time);
                end
            end else if (Ba == 2'b10 && Pc_b2 == 1'b1) begin
                {Act_b2, Pc_b2} = 2'b10;
                B2_row_addr = Addr [addr_bits - 1 : 0];
                RCD_chk2 = $time;
                RAS_chk2 = $time;
                if (Debug) $display ("at time %t ACT  : Bank = 2 Row = %d", $time, Addr);
                // Precharge to Activate Bank 2
                if ($time - RP_chk2 < tRP) begin
                    $display ("at time %t ERROR: tRP violation during Activate bank 2", $time);
                end
            end else if (Ba == 2'b11 && Pc_b3 == 1'b1) begin
                {Act_b3, Pc_b3} = 2'b10;
                B3_row_addr = Addr [addr_bits - 1 : 0];
                RCD_chk3 = $time;
                RAS_chk3 = $time;
                if (Debug) $display ("at time %t ACT  : Bank = 3 Row = %d", $time, Addr);
                // Precharge to Activate Bank 3
                if ($time - RP_chk3 < tRP) begin
                    $display ("at time %t ERROR: tRP violation during Activate bank 3", $time);
                end
            end else if (Ba == 2'b00 && Pc_b0 == 1'b0) begin
                $display ("at time %t ERROR: Bank 0 is not Precharged.", $time);
            end else if (Ba == 2'b01 && Pc_b1 == 1'b0) begin
                $display ("at time %t ERROR: Bank 1 is not Precharged.", $time);
            end else if (Ba == 2'b10 && Pc_b2 == 1'b0) begin
                $display ("at time %t ERROR: Bank 2 is not Precharged.", $time);
            end else if (Ba == 2'b11 && Pc_b3 == 1'b0) begin
                $display ("at time %t ERROR: Bank 3 is not Precharged.", $time);
            end
            // Active Bank A to Active Bank B
            if ((Previous_bank != Ba) && ($time - RRD_chk < tRRD)) begin
                $display ("at time %t ERROR: tRRD violation during Activate bank = %d", $time, Ba);
            end
            // Load Mode Register to Active
            if (MRD_chk < tMRD ) begin
                $display ("at time %t ERROR: tMRD violation during Activate bank = %d", $time, Ba);
            end
            // Auto Refresh to Activate
            if (($time - RC_chk < tRC)&&Debug) begin
                $display ("at time %t ERROR: tRC violation during Activate bank = %d", $time, Ba);
            end
            // Record variables for checking violation
            RRD_chk = $time;
            Previous_bank = Ba;
        end
        
        // Precharge Block
        if (Prech_enable == 1'b1) begin
            if (Addr[10] == 1'b1) begin
                {Pc_b0, Pc_b1, Pc_b2, Pc_b3} = 4'b1111;
                {Act_b0, Act_b1, Act_b2, Act_b3} = 4'b0000;
                RP_chk0 = $time;
                RP_chk1 = $time;
                RP_chk2 = $time;
                RP_chk3 = $time;
                if (Debug) $display ("at time %t PRE  : Bank = ALL",$time);
                // Activate to Precharge all banks
                if (($time - RAS_chk0 < tRAS) || ($time - RAS_chk1 < tRAS) ||
                    ($time - RAS_chk2 < tRAS) || ($time - RAS_chk3 < tRAS)) begin
                    $display ("at time %t ERROR: tRAS violation during Precharge all bank", $time);
                end
                // tWR violation check for write
                if (($time - WR_chk[0] < tWRp) || ($time - WR_chk[1] < tWRp) ||
                    ($time - WR_chk[2] < tWRp) || ($time - WR_chk[3] < tWRp)) begin
                    $display ("at time %t ERROR: tWR violation during Precharge all bank", $time);
                end
            end else if (Addr[10] == 1'b0) begin
                if (Ba == 2'b00) begin
                    {Pc_b0, Act_b0} = 2'b10;
                    RP_chk0 = $time;
                    if (Debug) $display ("at time %t PRE  : Bank = 0",$time);
                    // Activate to Precharge Bank 0
                    if ($time - RAS_chk0 < tRAS) begin
                        $display ("at time %t ERROR: tRAS violation during Precharge bank 0", $time);
                    end
                end else if (Ba == 2'b01) begin
                    {Pc_b1, Act_b1} = 2'b10;
                    RP_chk1 = $time;
                    if (Debug) $display ("at time %t PRE  : Bank = 1",$time);
                    // Activate to Precharge Bank 1
                    if ($time - RAS_chk1 < tRAS) begin
                        $display ("at time %t ERROR: tRAS violation during Precharge bank 1", $time);
                    end
                end else if (Ba == 2'b10) begin
                    {Pc_b2, Act_b2} = 2'b10;
                    RP_chk2 = $time;
                    if (Debug) $display ("at time %t PRE  : Bank = 2",$time);
                    // Activate to Precharge Bank 2
                    if ($time - RAS_chk2 < tRAS) begin
                        $display ("at time %t ERROR: tRAS violation during Precharge bank 2", $time);
                    end
                end else if (Ba == 2'b11) begin
                    {Pc_b3, Act_b3} = 2'b10;
                    RP_chk3 = $time;
                    if (Debug) $display ("at time %t PRE  : Bank = 3",$time);
                    // Activate to Precharge Bank 3
                    if ($time - RAS_chk3 < tRAS) begin
                        $display ("at time %t ERROR: tRAS violation during Precharge bank 3", $time);
                    end
                end
                // tWR violation check for write
                if ($time - WR_chk[Ba] < tWRp) begin
                    $display ("at time %t ERROR: tWR violation during Precharge bank %d", $time, Ba);
                end
            end
            // Terminate a Write Immediately (if same bank or all banks)
            if (Data_in_enable == 1'b1 && (Bank == Ba || Addr[10] == 1'b1)) begin
                Data_in_enable = 1'b0;
            end
            // Precharge Command Pipeline for Read
            if (Cas_latency_3 == 1'b1) begin
                Command[2] = `PRECH;
                Bank_precharge[2] = Ba;
                A10_precharge[2] = Addr[10];
            end else if (Cas_latency_2 == 1'b1) begin
                Command[1] = `PRECH;
                Bank_precharge[1] = Ba;
                A10_precharge[1] = Addr[10];
            end
        end
        
        // Burst terminate
        if (Burst_term == 1'b1) begin
            // Terminate a Write Immediately
            if (Data_in_enable == 1'b1) begin
                Data_in_enable = 1'b0;
            end
            // Terminate a Read Depend on CAS Latency
            if (Cas_latency_3 == 1'b1) begin
                Command[2] = `BST;
            end else if (Cas_latency_2 == 1'b1) begin
                Command[1] = `BST;
            end
            if (Debug) $display ("at time %t BST  : Burst Terminate",$time);
        end
        
        // Read, Write, Column Latch
        if (Read_enable == 1'b1 || Write_enable == 1'b1) begin
            // Check to see if bank is open (ACT)
            if ((Ba == 2'b00 && Pc_b0 == 1'b1) || (Ba == 2'b01 && Pc_b1 == 1'b1) ||
                (Ba == 2'b10 && Pc_b2 == 1'b1) || (Ba == 2'b11 && Pc_b3 == 1'b1)) begin
                $display("at time %t ERROR: Cannot Read or Write - Bank %d is not Activated", $time, Ba);
            end
            // Activate to Read or Write
            if ((Ba == 2'b00) && ($time - RCD_chk0 < tRCD))
                $display("at time %t ERROR: tRCD violation during Read or Write to Bank 0", $time);
            if ((Ba == 2'b01) && ($time - RCD_chk1 < tRCD))
                $display("at time %t ERROR: tRCD violation during Read or Write to Bank 1", $time);
            if ((Ba == 2'b10) && ($time - RCD_chk2 < tRCD))
                $display("at time %t ERROR: tRCD violation during Read or Write to Bank 2", $time);
            if ((Ba == 2'b11) && ($time - RCD_chk3 < tRCD))
                $display("at time %t ERROR: tRCD violation during Read or Write to Bank 3", $time);
            // Read Command
            if (Read_enable == 1'b1) begin
                // CAS Latency pipeline
                if (Cas_latency_3 == 1'b1) begin
                    if (Addr[10] == 1'b1) begin
                        Command[2] = `READ_A;
                    end else begin
                        Command[2] = `READ;
                    end
                    Col_addr[2] = Addr;
                    Bank_addr[2] = Ba;
                end else if (Cas_latency_2 == 1'b1) begin
                    if (Addr[10] == 1'b1) begin
                        Command[1] = `READ_A;
                    end else begin
                        Command[1] = `READ;
                    end
                    Col_addr[1] = Addr;
                    Bank_addr[1] = Ba;
                end

                // Read interrupt Write (terminate Write immediately)
                if (Data_in_enable == 1'b1) begin
                    Data_in_enable = 1'b0;
                end

            // Write Command
            end else if (Write_enable == 1'b1) begin
                if (Addr[10] == 1'b1) begin
                    Command[0] = `WRITE_A;
                end else begin
                    Command[0] = `WRITE;
                end
                Col_addr[0] = Addr;
                Bank_addr[0] = Ba;

                // Write interrupt Write (terminate Write immediately)
                if (Data_in_enable == 1'b1) begin
                    Data_in_enable = 1'b0;
                end

                // Write interrupt Read (terminate Read immediately)
                if (Data_out_enable == 1'b1) begin
                    Data_out_enable = 1'b0;
                end
            end

            // Interrupting a Write with Autoprecharge
            if (Auto_precharge[Bank] == 1'b1 && Write_precharge[Bank] == 1'b1) begin
                RW_interrupt_write[Bank] = 1'b1;
                if (Debug) $display ("at time %t NOTE : Read/Write Bank %d interrupt Write Bank %d with Autoprecharge", $time, Ba, Bank);
            end

            // Interrupting a Read with Autoprecharge
            if (Auto_precharge[Bank] == 1'b1 && Read_precharge[Bank] == 1'b1) begin
                RW_interrupt_read[Bank] = 1'b1;
                if (Debug) $display ("at time %t NOTE : Read/Write Bank %d interrupt Read Bank %d with Autoprecharge", $time, Ba, Bank);
            end

            // Read or Write with Auto Precharge
            if (Addr[10] == 1'b1) begin
                Auto_precharge[Ba] = 1'b1;
                Count_precharge[Ba] = 0;
                if (Read_enable == 1'b1) begin
                    Read_precharge[Ba] = 1'b1;
                end else if (Write_enable == 1'b1) begin
                    Write_precharge[Ba] = 1'b1;
                end
            end
        end

        //  Read with Auto Precharge Calculation
        //      The device start internal precharge:
        //          1.  CAS Latency - 1 cycles before last burst
        //      and 2.  Meet minimum tRAS requirement
        //       or 3.  Interrupt by a Read or Write (with or without AutoPrecharge)
        if ((Auto_precharge[0] == 1'b1) && (Read_precharge[0] == 1'b1)) begin
            if ((($time - RAS_chk0 >= tRAS) &&                                                      // Case 2
                ((Burst_length_1 == 1'b1 && Count_precharge[0] >= 1) ||                             // Case 1
                 (Burst_length_2 == 1'b1 && Count_precharge[0] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[0] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[0] >= 8))) ||
                 (RW_interrupt_read[0] == 1'b1)) begin                                              // Case 3
                    Pc_b0 = 1'b1;
                    Act_b0 = 1'b0;
                    RP_chk0 = $time;
                    Auto_precharge[0] = 1'b0;
                    Read_precharge[0] = 1'b0;
                    RW_interrupt_read[0] = 1'b0;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 0", $time);
            end
        end
        if ((Auto_precharge[1] == 1'b1) && (Read_precharge[1] == 1'b1)) begin
            if ((($time - RAS_chk1 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[1] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[1] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[1] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[1] >= 8))) ||
                 (RW_interrupt_read[1] == 1'b1)) begin
                    Pc_b1 = 1'b1;
                    Act_b1 = 1'b0;
                    RP_chk1 = $time;
                    Auto_precharge[1] = 1'b0;
                    Read_precharge[1] = 1'b0;
                    RW_interrupt_read[1] = 1'b0;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 1", $time);
            end
        end
        if ((Auto_precharge[2] == 1'b1) && (Read_precharge[2] == 1'b1)) begin
            if ((($time - RAS_chk2 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[2] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[2] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[2] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[2] >= 8))) ||
                 (RW_interrupt_read[2] == 1'b1)) begin
                    Pc_b2 = 1'b1;
                    Act_b2 = 1'b0;
                    RP_chk2 = $time;
                    Auto_precharge[2] = 1'b0;
                    Read_precharge[2] = 1'b0;
                    RW_interrupt_read[2] = 1'b0;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 2", $time);
            end
        end
        if ((Auto_precharge[3] == 1'b1) && (Read_precharge[3] == 1'b1)) begin
            if ((($time - RAS_chk3 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[3] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[3] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[3] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[3] >= 8))) ||
                 (RW_interrupt_read[3] == 1'b1)) begin
                    Pc_b3 = 1'b1;
                    Act_b3 = 1'b0;
                    RP_chk3 = $time;
                    Auto_precharge[3] = 1'b0;
                    Read_precharge[3] = 1'b0;
                    RW_interrupt_read[3] = 1'b0;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 3", $time);
            end
        end

        // Internal Precharge or Bst
        if (Command[0] == `PRECH) begin                         // Precharge terminate a read with same bank or all banks
            if (Bank_precharge[0] == Bank || A10_precharge[0] == 1'b1) begin
                if (Data_out_enable == 1'b1) begin
                    Data_out_enable = 1'b0;
                end
            end
        end else if (Command[0] == `BST) begin                  // BST terminate a read to current bank
            if (Data_out_enable == 1'b1) begin
                Data_out_enable = 1'b0;
            end
        end

        if (Data_out_enable == 1'b0) begin
            Dq_reg <= #tOH {data_bits{1'bz}};
        end

        // Detect Read or Write command
        if (Command[0] == `READ || Command[0] == `READ_A) begin
            Bank = Bank_addr[0];
            Col = Col_addr[0];
            Col_brst = Col_addr[0];
            if (Bank_addr[0] == 2'b00) begin
                Row = B0_row_addr;
            end else if (Bank_addr[0] == 2'b01) begin
                Row = B1_row_addr;
            end else if (Bank_addr[0] == 2'b10) begin
                Row = B2_row_addr;
            end else if (Bank_addr[0] == 2'b11) begin
                Row = B3_row_addr;
            end
            Burst_counter = 0;
            Data_in_enable = 1'b0;
            Data_out_enable = 1'b1;
        end else if (Command[0] == `WRITE || Command[0] == `WRITE_A) begin
            Bank = Bank_addr[0];
            Col = Col_addr[0];
            Col_brst = Col_addr[0];
            if (Bank_addr[0] == 2'b00) begin
                Row = B0_row_addr;
            end else if (Bank_addr[0] == 2'b01) begin
                Row = B1_row_addr;
            end else if (Bank_addr[0] == 2'b10) begin
                Row = B2_row_addr;
            end else if (Bank_addr[0] == 2'b11) begin
                Row = B3_row_addr;
            end
            Burst_counter = 0;
            Data_in_enable = 1'b1;
            Data_out_enable = 1'b0;
        end

        // DQ buffer (Driver/Receiver)
        if (Data_in_enable == 1'b1) begin                                   // Writing Data to Memory
            // Array buffer
            if (Bank == 2'b00) Dq_dqm [data_bits - 1  : 0] = Bank0 [{Row, Col}];
            if (Bank == 2'b01) Dq_dqm [data_bits - 1  : 0] = Bank1 [{Row, Col}];
            if (Bank == 2'b10) Dq_dqm [data_bits - 1  : 0] = Bank2 [{Row, Col}];
            if (Bank == 2'b11) Dq_dqm [data_bits - 1  : 0] = Bank3 [{Row, Col}];
            // Dqm operation
            if (Dqm[0] == 1'b0) Dq_dqm [ 7 : 0] = Dq [ 7 : 0];
            if (Dqm[1] == 1'b0) Dq_dqm [15 : 8] = Dq [15 : 8];
            //if (Dqm[2] == 1'b0) Dq_dqm [23 : 16] = Dq [23 : 16];
           // if (Dqm[3] == 1'b0) Dq_dqm [31 : 24] = Dq [31 : 24];
            // Write to memory
            if (Bank == 2'b00) Bank0 [{Row, Col}] = Dq_dqm [data_bits - 1  : 0];
            if (Bank == 2'b01) Bank1 [{Row, Col}] = Dq_dqm [data_bits - 1  : 0];
            if (Bank == 2'b10) Bank2 [{Row, Col}] = Dq_dqm [data_bits - 1  : 0];
            if (Bank == 2'b11) Bank3 [{Row, Col}] = Dq_dqm [data_bits - 1  : 0];
            if (Bank == 2'b11 && Row==10'h3 && Col[7:4]==4'h4)
            	$display("at time %t WRITE: Bank = %d Row = %d, Col = %d, Data = Hi-Z due to DQM", $time, Bank, Row, Col);
            //$fdisplay(test_file,"bank:%h	row:%h	col:%h	write:%h",Bank,Row,Col,Dq_dqm);
            // Output result
            if (Dqm == 4'b1111) begin
                if (Debug) $display("at time %t WRITE: Bank = %d Row = %d, Col = %d, Data = Hi-Z due to DQM", $time, Bank, Row, Col);
            end else begin
                if (Debug) $display("at time %t WRITE: Bank = %d Row = %d, Col = %d, Data = %d, Dqm = %b", $time, Bank, Row, Col, Dq_dqm, Dqm);
                // Record tWR time and reset counter
                WR_chk [Bank] = $time;
                WR_counter [Bank] = 0;
            end
            // Advance burst counter subroutine
            #tHZ Burst;
        end else if (Data_out_enable == 1'b1) begin                         // Reading Data from Memory
        	//$display("%h	,	%h,	%h",Bank0,Row,Col);
            // Array buffer
            if (Bank == 2'b00) Dq_dqm [data_bits - 1  : 0] = Bank0 [{Row, Col}];
            if (Bank == 2'b01) Dq_dqm [data_bits - 1  : 0] = Bank1 [{Row, Col}];
            if (Bank == 2'b10) Dq_dqm [data_bits - 1  : 0] = Bank2 [{Row, Col}];
            if (Bank == 2'b11) Dq_dqm [data_bits - 1  : 0] = Bank3 [{Row, Col}];
            	
            // Dqm operation
            if (Dqm_reg0[0] == 1'b1) Dq_dqm [ 7 : 0] = 8'bz;
            if (Dqm_reg0[1] == 1'b1) Dq_dqm [15 : 8] = 8'bz;
            if (Dqm_reg0[2] == 1'b1) Dq_dqm [23 : 16] = 8'bz;
            if (Dqm_reg0[3] == 1'b1) Dq_dqm [31 : 24] = 8'bz;
            // Display result
            Dq_reg [data_bits - 1  : 0] = #tAC Dq_dqm [data_bits - 1  : 0];
            if (Dqm_reg0 == 4'b1111) begin
                if (Debug) $display("at time %t READ : Bank = %d Row = %d, Col = %d, Data = Hi-Z due to DQM", $time, Bank, Row, Col);
            end else begin
                if (Debug) $display("at time %t READ : Bank = %d Row = %d, Col = %d, Data = %d, Dqm = %b", $time, Bank, Row, Col, Dq_reg, Dqm_reg0);
            end
            // Advance burst counter subroutine
            Burst;
        end
    end

    //  Write with Auto Precharge Calculation
    //      The device start internal precharge:
    //          1.  tWR Clock after last burst
    //      and 2.  Meet minimum tRAS requirement
    //       or 3.  Interrupt by a Read or Write (with or without AutoPrecharge)
    always @ (WR_counter[0]) begin
        if ((Auto_precharge[0] == 1'b1) && (Write_precharge[0] == 1'b1)) begin
            if ((($time - RAS_chk0 >= tRAS) &&                                                          // Case 2
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [0] >= 1) ||   // Case 1
                 (Burst_length_2 == 1'b1 && Count_precharge [0] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge [0] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge [0] >= 8))) ||
                 (RW_interrupt_write[0] == 1'b1 && WR_counter[0] >= 2)) begin                           // Case 3 (stop count when interrupt)
                    Auto_precharge[0] = 1'b0;
                    Write_precharge[0] = 1'b0;
                    RW_interrupt_write[0] = 1'b0;
                    #tWRa;                          // Wait for tWR
                    Pc_b0 = 1'b1;
                    Act_b0 = 1'b0;
                    RP_chk0 = $time;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 0", $time);
            end
        end
    end
    always @ (WR_counter[1]) begin
        if ((Auto_precharge[1] == 1'b1) && (Write_precharge[1] == 1'b1)) begin
            if ((($time - RAS_chk1 >= tRAS) &&
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [1] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge [1] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge [1] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge [1] >= 8))) ||
                 (RW_interrupt_write[1] == 1'b1 && WR_counter[1] >= 2)) begin
                    Auto_precharge[1] = 1'b0;
                    Write_precharge[1] = 1'b0;
                    RW_interrupt_write[1] = 1'b0;
                    #tWRa;                          // Wait for tWR
                    Pc_b1 = 1'b1;
                    Act_b1 = 1'b0;
                    RP_chk1 = $time;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 1", $time);
            end
        end
    end
    always @ (WR_counter[2]) begin
        if ((Auto_precharge[2] == 1'b1) && (Write_precharge[2] == 1'b1)) begin
            if ((($time - RAS_chk2 >= tRAS) &&
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [2] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge [2] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge [2] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge [2] >= 8))) ||
                 (RW_interrupt_write[2] == 1'b1 && WR_counter[2] >= 2)) begin
                    Auto_precharge[2] = 1'b0;
                    Write_precharge[2] = 1'b0;
                    RW_interrupt_write[2] = 1'b0;
                    #tWRa;                          // Wait for tWR
                    Pc_b2 = 1'b1;
                    Act_b2 = 1'b0;
                    RP_chk2 = $time;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 2", $time);
            end
        end
    end
    always @ (WR_counter[3]) begin
        if ((Auto_precharge[3] == 1'b1) && (Write_precharge[3] == 1'b1)) begin
            if ((($time - RAS_chk3 >= tRAS) &&
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [3] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge [3] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge [3] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge [3] >= 8))) ||
                 (RW_interrupt_write[3] == 1'b1 && WR_counter[3] >= 2)) begin
                    Auto_precharge[3] = 1'b0;
                    Write_precharge[3] = 1'b0;
                    RW_interrupt_write[3] = 1'b0;
                    #tWRa;                          // Wait for tWR
                    Pc_b3 = 1'b1;
                    Act_b3 = 1'b0;
                    RP_chk3 = $time;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 3", $time);
            end
        end
    end

    task Burst;
        begin
            // Advance Burst Counter
            Burst_counter = Burst_counter + 1;

            // Burst Type
            if (Mode_reg[3] == 1'b0) begin                                  // Sequential Burst
                Col_temp = Col + 1;
            end else if (Mode_reg[3] == 1'b1) begin                         // Interleaved Burst
                Col_temp[2] =  Burst_counter[2] ^  Col_brst[2];
                Col_temp[1] =  Burst_counter[1] ^  Col_brst[1];
                Col_temp[0] =  Burst_counter[0] ^  Col_brst[0];
            end

            // Burst Length
            if (Burst_length_2) begin                                       // Burst Length = 2
                Col [0] = Col_temp [0];
            end else if (Burst_length_4) begin                              // Burst Length = 4
                Col [1 : 0] = Col_temp [1 : 0];
            end else if (Burst_length_8) begin                              // Burst Length = 8
                Col [2 : 0] = Col_temp [2 : 0];
            end else begin                                                  // Burst Length = FULL
                Col = Col_temp;
            end

            // Burst Read Single Write            
            if (Write_burst_mode == 1'b1) begin
                Data_in_enable = 1'b0;
            end

            // Data Counter
            if (Burst_length_1 == 1'b1) begin
                if (Burst_counter >= 1) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_2 == 1'b1) begin
                if (Burst_counter >= 2) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_4 == 1'b1) begin
                if (Burst_counter >= 4) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_8 == 1'b1) begin
                if (Burst_counter >= 8) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end
        end
    endtask
    
    //**********************将SDRAM内的数据直接输出到外部文件*******************************//

/*    
   integer	sdram_data,ind;


    always@(sdram_r)
	begin
		   sdram_data=$fopen("sdram_data.txt");
		   $display("Sdram dampout begin ",sdram_data);
//		   $fdisplay(sdram_data,"Bank0：");
		   for(ind=0;ind<=mem_sizes;ind=ind+1)
		            $fdisplay(sdram_data,"%h	%b",ind,Bank0[ind]);
//		   $fdisplay(sdram_data,"Bank1：");
		   for(ind=0;ind<=mem_sizes;ind=ind+1)
		            $fdisplay(sdram_data,"%h	%b",ind,Bank1[ind]);
//		   $fdisplay(sdram_data,"Bank2：");
		   for(ind=0;ind<=mem_sizes;ind=ind+1)
		            $fdisplay(sdram_data,"%h	%b",ind,Bank2[ind]);
//	           $fdisplay(sdram_data,"Bank3：");
		   for(ind=0;ind<=mem_sizes;ind=ind+1)
		            $fdisplay(sdram_data,"%h	%b",ind,Bank3[ind]);
		  		    	    	    
		  $fclose("sdram_data.txt");        
	  //->compare;
	  end        
*/
    integer	sdram_data,sdram_mem;
    reg	[23:0]	aa,cc;
    reg	[18:0]	bb,ee;
    
    always@(sdram_r)
	begin
		   $display("Sdram dampout begin ",$realtime);
		   sdram_data=$fopen("sdram_data.txt");
		   for(aa=0;aa<4*(mem_sizes+1);aa=aa+1)
		   	begin
		   	bb=aa[18:0];
			if(aa<=mem_sizes)
				$fdisplay(sdram_data,"%0d	%0h",aa,Bank0[bb]);
			else if(aa<=2*mem_sizes+1)
		            	$fdisplay(sdram_data,"%0d	%0h",aa,Bank1[bb]);
			else if(aa<=3*mem_sizes+2)
				$fdisplay(sdram_data,"%0d	%0h",aa,Bank2[bb]);
			else
				$fdisplay(sdram_data,"%0d	%0h",aa,Bank3[bb]);
		  	end	    	    	    
		  $fclose("sdram_data.txt"); 
		  
		  sdram_mem=$fopen("sdram_mem.txt");
		  for(cc=0;cc<4*(mem_sizes+1);cc=cc+1)
		  	begin
		   	ee=cc[18:0];
			if(cc<=mem_sizes)
				$fdisplay(sdram_mem,"%0h",Bank0[ee]);
			else if(cc<=2*mem_sizes+1)
		            	$fdisplay(sdram_mem,"%0h",Bank1[ee]);
			else if(cc<=3*mem_sizes+2)
				$fdisplay(sdram_mem,"%0h",Bank2[ee]);
			else
				$fdisplay(sdram_mem,"%0h",Bank3[ee]);
		  	end	    	    	    
		  $fclose("sdram_mem.txt");        
	 
	  end        



//    // Timing Parameters for -75 (PC133) and CAS Latency = 2
//    specify
//        specparam
////                    tAH  =  0.8,                                        // Addr, Ba Hold Time
////                    tAS  =  1.5,                                        // Addr, Ba Setup Time
////                    tCH  =  2.5,                                        // Clock High-Level Width
////                    tCL  =  2.5,                                        // Clock Low-Level Width
//////                    tCK  = 10.0,                                       // Clock Cycle Time  100mhz
//////                    tCK  = 7.5,    					// Clock Cycle Time  133mhz
////                    tCK  =  7,                				// Clock Cycle Time  143mhz
////                    tDH  =  0.8,                                        // Data-in Hold Time
////                    tDS  =  1.5,                                        // Data-in Setup Time
////                    tCKH =  0.8,                                        // CKE Hold  Time
////                    tCKS =  1.5,                                        // CKE Setup Time
////                    tCMH =  0.8,                                        // CS#, RAS#, CAS#, WE#, DQM# Hold  Time
////                    tCMS =  1.5;                                        // CS#, RAS#, CAS#, WE#, DQM# Setup Time
//                    tAH  =  1,                                        // Addr, Ba Hold Time
//                    tAS  =  1.5,                                        // Addr, Ba Setup Time
//                    tCH  =  1,                                        // Clock High-Level Width
//                    tCL  =  3,                                        // Clock Low-Level Width
////                    tCK  = 10.0,                                       // Clock Cycle Time  100mhz
////                    tCK  = 7.5,    					// Clock Cycle Time  133mhz
//                    tCK  =  7,                				// Clock Cycle Time  143mhz
//                    tDH  =  1,                                        // Data-in Hold Time
//                    tDS  =  2,                                        // Data-in Setup Time
//                    tCKH =  1,                                        // CKE Hold  Time
//                    tCKS =  2,                                        // CKE Setup Time
//                    tCMH =  0.8,                                        // CS#, RAS#, CAS#, WE#, DQM# Hold  Time
//                    tCMS =  1.5;                                        // CS#, RAS#, CAS#, WE#, DQM# Setup Time
//        $width    (posedge Clk,           tCH);
//        $width    (negedge Clk,           tCL);
//        $period   (negedge Clk,           tCK);
//        $period   (posedge Clk,           tCK);
//        $setuphold(posedge Clk,    Cke,   tCKS, tCKH);
//        $setuphold(posedge Clk,    Cs_n,  tCMS, tCMH);
//        $setuphold(posedge Clk,    Cas_n, tCMS, tCMH);
//        $setuphold(posedge Clk,    Ras_n, tCMS, tCMH);
//        $setuphold(posedge Clk,    We_n,  tCMS, tCMH);
//        $setuphold(posedge Clk,    Addr,  tAS,  tAH);
//        $setuphold(posedge Clk,    Ba,    tAS,  tAH);
//        $setuphold(posedge Clk,    Dqm,   tCMS, tCMH);
//        $setuphold(posedge Dq_chk, Dq,    tDS,  tDH);
//    endspecify

endmodule

