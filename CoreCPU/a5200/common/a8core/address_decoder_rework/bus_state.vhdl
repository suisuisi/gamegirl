
---------------------------------------------------------------------------
-- (c) 2017 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.all;


-- Purpose:
-- Maps atari devices onto FPGA devices
-- So we map atari ram access to sdram or block ram -> and offset the address appropriately
ENTITY bus_state IS
PORT 
( 
	clk : in std_logic;
	reset_n : in std_logic;

	selected_master : in std_logic_vector(1 downto 0);

	chosen_master : in std_logic_vector(1 downto 0);
);

END bus_state;

ARCHITECTURE vhdl OF bus_state IS
	constant selected_antic : std_logic_vector(1 downto 0) := "11";
	constant selected_cpu : std_logic_vector(1 downto 0) := "01";
	constant selected_dma : std_logic_vector(1 downto 0) := "10";
	constant selected_none : std_logic_vector(1 downto 0) := "00";


	signal wait_for_next : std_logic_vector(1 downto 0);
	signal wait_for_reg : std_logic_vector(1 downto 0);
	constant wait_for_antic : std_logic_vector(1 downto 0) := "00";
	constant wait_for_6502 : std_logic_vector(1 downto 0) := "01";
	constant wait_for_dma : std_logic_vector(1 downto 0) := "10";
	constant wait_for_none : std_logic_vector(1 downto 0) := "11";

BEGIN

	-- concept
	-- bus master sends request - antic or cpu
	-- antic has priority
	-- cpu may be idle
	-- once request complete MEMORY_READY is set
	-- if request interrupted then results are LOST - memory ready not set until priority request satisfied
	
	-- so
	-- memory_ready <= device_ready;
	
	-- problem
	-- request -> device access -> interrupt -> device finishes -> ignored? -> device access
	
	-- state machine
	
	-- state machine impl
	fetch_priority <= ANTIC_FETCH&DMA_FETCH&CPU_FETCH;
	process(fetch_wait_reg, state_reg, addr_reg, data_write_reg, width_8bit_reg, width_16bit_reg, width_32bit_reg, master_write_enable, pbi_write_enable_reg, write_enable_reg, fetch_priority, antic_addr, DMA_addr, cpu_addr, request_complete, DMA_8bit_write_enable,DMA_16bit_write_enable,DMA_32bit_write_enable,DMA_read_enable, cpu_write_n, CPU_WRITE_DATA, DMA_WRITE_DATA, antic_fetch_real_reg, cpu_fetch_real_reg, addr_pbi_elligible, pbi_disable, pbi_takeover, pbi_release, pbi_cycle_reg,  wait_for_reg)
	begin
		start_request <= '0';
		pbi_request <= '0';
		state_next <= state_reg;
		fetch_wait_next <= std_logic_vector(unsigned(fetch_wait_reg) + to_unsigned(1,9));
		pbi_cycle_next <= pbi_cycle_reg;

		addr_next <= addr_reg;
		data_WRITE_next <= data_WRITE_reg;
		width_8bit_next <= width_8bit_reg;		
		width_16bit_next <= width_16bit_reg;		
		width_32bit_next <= width_32bit_reg;		
		write_enable_next <= write_enable_reg;
		pbi_write_enable_next <= pbi_write_enable_reg;
		master_write_enable <= '0';
		
		antic_fetch_real_next <= antic_fetch_real_reg;
		cpu_fetch_real_next <= cpu_fetch_real_reg;
		wait_for_next <= wait_for_reg;

		-- idle -> when not selected_none,... start request
		--if (or_reduce(addr_next(23 downto 18)) = '0' ) then -- bit 16,17 left out on purpose, so the Atari 64k is available as 64k-128k for zpu. The zpu has rom at 0-64k...
		--
		--addr_pbi_elligible <= not(addr_next(17)); -- Disable for frozen reg copy area
		--if (freezer_enable = '1' and freezer_disable_atari) then
		-- 
		-- turbo freezer + 1 cycle latency? different path?
		
		
		case state_reg is
			when state_idle =>
				fetch_wait_next <= (others=>'0');
				write_enable_next <= '0';
				width_8bit_next <= '0';
				width_16bit_next <= '0';
				width_32bit_next <= '0';	
				data_WRITE_next <= (others => '0');
				addr_next <= DMA_ADDR(23 downto 16)&cpu_ADDR(15 downto 0);				


				if ((addr_pbi_elligible and not(pbi_disable))='1') then
					state_next <= state_pbi_request;
					pbi_write_enable_next <= master_write_enable;
				else
					start_request <= '1';
					write_enable_next <= master_write_enable;
					if (request_complete = '0') then
						state_next <= state_wait_done;
					end if;
				end if;
				
				case fetch_priority is
				when "100"|"101"|"110"|"111" => -- antic wins
					addr_next <= "00000000"&antic_ADDR;
					width_8bit_next <= '1';					
					antic_fetch_real_next <= '1';
					cpu_fetch_real_next <= '0';
					wait_for_next <= wait_for_antic;
				when "010"|"011" => -- DMA wins (DMA usually accesses own ROM memory - this is NOT a DMA_fetch)
					-- TODO, lower priority than 6502, except on first request in block...
					addr_next <= DMA_ADDR;
					data_WRITE_next <= DMA_WRITE_DATA;

					width_8bit_next <= DMA_8BIT_WRITE_ENABLE or (DMA_READ_ENABLE and (DMA_addr(0) or DMA_addr(1)));
					width_16bit_next <= DMA_16BIT_WRITE_ENABLE;
					width_32bit_next <= DMA_32BIT_WRITE_ENABLE or (DMA_READ_ENABLE and not(DMA_addr(0) or DMA_addr(1))); -- narrower devices just return 8 bits on read
					
					master_write_enable <= not(DMA_READ_ENABLE);
					cpu_fetch_real_next <= '1';
					antic_fetch_real_next <= '0';
					wait_for_next <= wait_for_dma;
				when "001" => -- 6502 wins
					addr_next <= "00000000"&cpu_ADDR;
					data_WRITE_next(7 downto 0) <= cpu_WRITE_DATA;
					width_8bit_next <= '1';
					master_write_enable <= not(cpu_WRITE_N); 
					cpu_fetch_real_next <= '1';
					antic_fetch_real_next <= '0';
					wait_for_next <= wait_for_6502;
				when others =>
					-- no requests/nop
					start_request <= '0';
					state_next <= state_idle;
					wait_for_next <= wait_for_none;
				end case;

			when state_pbi_request =>
				if (pbi_takeover='1') then
					pbi_request <= '1';
					pbi_cycle_next <= '1';
					state_next <= state_wait_done;
				end if;

			when state_pbi_released =>
				start_request <= '1';
				write_enable_next <= pbi_write_enable_reg;
				state_next <= state_idle;
				if (request_complete = '0') then
					state_next <= state_wait_done;
				end if;

			when state_wait_done =>
				if (pbi_release = '1') then
					state_next <= state_pbi_released;
					pbi_cycle_next <= '0';
				end if;

				if (request_complete = '1') then
					state_next <= state_idle;
					pbi_cycle_next <= '0';
				end if;

			when others =>
				-- NOP
		end case;
	end process;

	process(wait_for_next,request_complete)
	begin
		notify_antic <= '0';
		notify_cpu <= '0';
		notify_DMA <= '0';

		case wait_for_next is
		when wait_for_dma =>
			notify_DMA <= request_complete;
		when wait_for_antic =>
			notify_antic <= request_complete;
		when wait_for_6502 =>
			notify_cpu <= request_complete;
		when others =>
			-- notify no-one!
		end case;
	end process;
	
	-- output
	MEMORY_READY_ANTIC <= notify_antic;
	MEMORY_READY_DMA <= notify_DMA;
	MEMORY_READY_CPU <= notify_cpu;
	
	RAM_REQUEST <= ram_chip_select;
		
	SDRAM_REQUEST <= sdram_chip_select;
	--SDRAM_REQUEST <= sdram_request_next;
	SDRAM_READ_EN <= not(write_enable_next);
	SDRAM_WRITE_EN <= write_enable_next;
	
	WIDTH_8bit_ACCESS <= width_8bit_next;
	WIDTH_16bit_ACCESS <= width_16bit_next;
	WIDTH_32bit_ACCESS <= width_32bit_next;	
	
	WRITE_DATA <= DATA_WRITE_next;

END VHDL;

