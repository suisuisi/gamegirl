---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--  64k ram that needs ras/cas
--  cas inhibited when
--  -io area
--   - no response from io at d100,d500,d600 and d700
--  -rom area
--   - os
--   - basic
--   - self test
--   - cart
--  -extsel_n asserted
--  -ref_n asserted
--  ref_n also inhibits
--  - os chip select
--  - basic chip select
--  - self test chip select
--  - cart chip select (s4,s5,cctl)
--  mpd_n inhibits
--  - os rom, math pack area only
--
--
--  CI (aka CASINH) is high when io area or rom area
--  When CI is low       -> ram access
--  When CI is high      -> ram disabled + rom/io access
--  When EXTSEL_N is low -> ram disabled
--
--
-- read data from bus when: 
--   ram access and ram disabled (casinh_n and not(extsel_n)
--   io non-decoded (D1,D5,D6,D7)
--   mmu disabled - ref_n low
--   external rom (s4_n and s5_n)
-- 
-- write internal data to bus when...
--   cpu/antic reading
--   not reading from bus
--
-- write cpu data to bus when
--   cpu writing
--
-- write cpu data internally when
--   cpu writing and internal disabled
--   internal disabled:
--     ram access and ram disabled (casinh_n and not(extsel_n)
--     mmu disabled - ref_n low

ENTITY pbi6502 IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

	-- FPGA side
	ENABLE_179_EARLY : IN STD_LOGIC;

	REQUEST : IN STD_LOGIC;
	ADDR_IN : IN STD_LOGIC_VECTOR(15 downto 0);
	DATA_IN : IN STD_LOGIC_VECTOR(7 downto 0);
	WRITE_IN : IN STD_LOGIC;
	PORTB : IN STD_LOGIC_VECTOR(7 downto 0);
	DISABLE : IN STD_LOGIC;
	ANTIC_REFRESH : IN STD_LOGIC;

	SNOOP_DATA_IN : IN STD_LOGIC_VECTOR(7 downto 0);
	SNOOP_DATA_READY : IN STD_LOGIC;

	TAKEOVER : OUT STD_LOGIC; -- cut out whole cycle until we know
	RELEASE : OUT STD_LOGIC; -- not our cycle
	EXTERNAL_ACCESS : OUT STD_LOGIC;
	DATA_OUT : OUT STD_LOGIC_VECTOR(7 downto 0);
	COMPLETE : OUT STD_LOGIC;
	MPD_N : OUT STD_LOGIC;
	
	DEBUG : OUT STD_LOGIC_VECTOR(24 downto 0); -- 16 bits address(0-15), 8 bits data(16-23), 1 bit r/w(24)
	DEBUG_READY : OUT STD_LOGIC;

	-- 6502 side
	BUS_DATA_IN : IN STD_LOGIC_VECTOR(7 downto 0);
	
	BUS_PHI1 : OUT STD_LOGIC;
	BUS_PHI2 : OUT STD_LOGIC;
	BUS_ADDR_OUT : OUT STD_LOGIC_VECTOR(15 downto 0);
	BUS_ADDR_OE : OUT STD_LOGIC;
	BUS_DATA_OUT : OUT STD_LOGIC_VECTOR(7 downto 0);
	BUS_DATA_OE : OUT STD_LOGIC;
	BUS_WRITE_N : OUT STD_LOGIC;

	BUS_S4_N : OUT STD_LOGIC;
	BUS_S5_N : OUT STD_LOGIC;
	BUS_CCTL_N : OUT STD_LOGIC;
	BUS_D1XX_N : OUT STD_LOGIC;

	BUS_REFRESH_OE : OUT STD_LOGIC;
	BUS_CONTROL_OE : OUT STD_LOGIC;
	BUS_CASINH_N : OUT STD_LOGIC;
	BUS_CASINH_OE : OUT STD_LOGIC;
	BUS_CAS_N : OUT STD_LOGIC;
	BUS_RAS_N : OUT STD_LOGIC;

	BUS_RD4 : IN STD_LOGIC;
	BUS_RD5 : IN STD_LOGIC;
	PBI_MPD_N : IN STD_LOGIC;
	PBI_REF_N : IN STD_LOGIC;
	PBI_EXTSEL_N : IN STD_LOGIC
);
END pbi6502;

ARCHITECTURE vhdl OF pbi6502 IS
	signal clear_request : std_logic; -- Wipe out previous request, so in the absense of a request we do not repeat writes

	signal clear_snoop : std_logic; -- Wipe out previous 'system read data', so in the anbsense of a request we do not repeat 'read data!'

	signal mpd_n_next : std_logic;
	signal mpd_n_reg : std_logic;

	signal request_next : std_logic;
	signal request_reg : std_logic;

	signal state_next : std_logic_vector(4 downto 0);
	signal state_reg : STD_LOGIC_VECTOR(4 DOWNTO 0);

	signal addr_next : std_logic_vector(15 downto 0);
	signal addr_reg : std_logic_vector(15 downto 0);

	signal addr_oe_next : std_logic;
	signal addr_oe_reg : std_logic;

	signal data_next : std_logic_vector(7 downto 0);
	signal data_reg : std_logic_vector(7 downto 0);

	signal output_data_next : std_logic_vector(7 downto 0);
	signal output_data_reg : std_logic_vector(7 downto 0);

	signal snoop_data_next : std_logic_vector(7 downto 0);
	signal snoop_data_reg : std_logic_vector(7 downto 0);

	signal data_oe_next : std_logic;
	signal data_oe_reg : std_logic;

	signal data_read_next : std_logic_vector(7 downto 0);
	signal data_read_reg : std_logic_vector(7 downto 0);

	signal phi1_next : std_logic;
	signal phi1_reg : std_logic;

	signal phi2_next : std_logic;
	signal phi2_reg : std_logic;

	signal write_n_next : std_logic;
	signal write_n_reg : std_logic;

	signal control_oe_next : std_logic;
	signal control_oe_reg : std_logic;

	signal refresh_oe_next : std_logic;
	signal refresh_oe_reg : std_logic;

	signal refresh_next : std_logic;
	signal refresh_reg : std_logic;

	signal refresh_count_next : std_logic_vector(7 downto 0);
	signal refresh_count_reg : std_logic_vector(7 downto 0);
	signal increment_refresh_count : std_logic;
	signal antic_refresh_reg : std_logic;

	signal ras_n_next : std_logic;
	signal ras_n_reg : std_logic;

	signal cas_n_next : std_logic;
	signal cas_n_reg : std_logic;

	signal casinh_n_next : std_logic;
	signal casinh_n_reg : std_logic;

	signal casinh_oe_next : std_logic;
	signal casinh_oe_reg : std_logic;

	signal addr_stable_next : std_logic;
	signal addr_stable_reg : std_logic;

	signal external_read_next : std_logic;
	signal external_read_reg : std_logic;

	signal external_write_only_next : std_logic;
	signal external_write_only_reg : std_logic;

	signal takeover_next : std_logic;
	signal takeover_reg : std_logic;

	signal release_next : std_logic;
	signal release_reg : std_logic;

	signal complete_next : std_logic;
	signal complete_reg : std_logic;

	signal debug_next : std_logic_vector(24 downto 0); 
	signal debug_reg : std_logic_vector(24 downto 0);

	signal MMU_S4_N : std_logic;
	signal MMU_S5_N : std_logic;
	signal MMU_EXTIO : std_logic;
	signal MMU_D1XX_N : std_logic;
	signal MMU_CCTL_N : std_logic;
	signal MMU_IO : std_logic;
	signal MMU_CASINH : std_logic;
	signal MMU_BASIC : std_logic;
	signal MMU_OS : std_logic;
BEGIN
	-- regs

	process(clk, reset_n)
	begin
		if (reset_n='0') then
			mpd_n_reg <= '1';
			request_reg <= '0';
			state_reg <= (others=>'0');
			addr_reg <= (others=>'0');
			addr_oe_reg <= '0';
			data_reg <= (others=>'0');
			snoop_data_reg <= (others=>'0');
			output_data_reg <= (others=>'0');
			data_read_reg <= (others=>'0');
			data_oe_reg <= '0';
			phi1_reg <= '1';
			phi2_reg <= '0';
			write_n_reg <= '1';
			control_oe_reg <= '0';
			refresh_reg <= '0';
			refresh_oe_reg <= '0';
			refresh_count_reg <= (others=>'0');
			antic_refresh_reg <= '0';

			ras_n_reg <= '0';
			cas_n_reg <= '0';
			casinh_n_reg <= '1';
			casinh_oe_reg <= '0';

			addr_stable_reg <= '0';
			external_read_reg <= '0';
			external_write_only_reg <= '0';
			takeover_reg <= '1';
			release_reg <= '0';
			complete_reg <= '0';
			debug_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			mpd_n_reg <= mpd_n_next;
			request_reg <= request_next;
			state_reg <= state_next;
			addr_reg <= addr_next;
			addr_oe_reg <= addr_oe_next;
			data_reg <= data_next;
			snoop_data_reg <= snoop_data_next;
			output_data_reg <= output_data_next;
			data_read_reg <= data_read_next;
			data_oe_reg <= data_oe_next;
			phi1_reg <= phi1_next;
			phi2_reg <= phi2_next;
			write_n_reg <= write_n_next;
			control_oe_reg <= control_oe_next;
			refresh_reg <= refresh_next;
			refresh_oe_reg <= refresh_oe_next;
			refresh_count_reg <= refresh_count_next;
			antic_refresh_reg <= antic_refresh;

			ras_n_reg <= ras_n_next;
			cas_n_reg <= cas_n_next;
			casinh_n_reg <= casinh_n_next;
			casinh_oe_reg <= casinh_oe_next;
			
			addr_stable_reg <= addr_stable_next;
			external_read_reg <= external_read_next;
			external_write_only_reg <= external_write_only_next;
			takeover_reg <= takeover_next;
			release_reg <= release_next;
			complete_reg <= complete_next;
			debug_reg <= debug_next;
		end if;
	end process;


	-- original atari mmu logic in order to calculate casinh
	mmu1: entity work.mmu
	PORT MAP
	(
		ADDR => addr_reg(15 downto 11),
		REF_N => PBI_REF_N,
		RD4 => BUS_RD4,
		RD5 => BUS_RD5,
		MPD_N => PBI_MPD_N,
		REN => PORTB(0), 
		BE_N => PORTB(1),
		MAP_N => PORTB(7),
		S4_N => MMU_S4_N,
		S5_N => MMU_S5_N,
		BASIC => MMU_BASIC,
		IO => MMU_IO,
		OS => MMU_OS,
		CI => MMU_CASINH --Disable RAM
	);

	process(mmu_io,addr_reg)
	begin
		MMU_CCTL_N <= '1';
 		if (MMU_IO='1' and(addr_reg(10 downto 8)="101")) then
			MMU_CCTL_N <= '0';
		end if;
	end process;

	process(mmu_io,addr_reg)
	begin
		MMU_D1XX_N <= '1';
 		if (MMU_IO='1' and(addr_reg(10 downto 8)="001")) then
			MMU_D1XX_N <= '0';
		end if;
	end process;

	process(mmu_io,addr_reg)
	begin
		MMU_EXTIO <= '0';
 		if (MMU_IO='1' and(addr_reg(9 downto 8)="01" or addr_reg(10 downto 9)="11")) then -- 001,101,110,111 -> X01, 11X (D1,D5,D6,D7)
			MMU_EXTIO <= '1';
		end if;
	end process;

	-- snap the request
	process(antic_refresh,antic_refresh_reg,refresh_reg,request,clear_request,addr_in,data_in,write_in,addr_reg,data_reg,write_n_reg,request_reg,refresh_count_reg)
	begin
		addr_next <= addr_reg;
		data_next <= data_reg;
		write_n_next <= write_n_reg;
		request_next <= request_reg;
		increment_refresh_count <= '0';
		refresh_next <= refresh_reg;

		if request='1' and refresh_reg='0' then --Only needed for sim I think?
			addr_next <= addr_in;
			data_next <= data_in;
			write_n_next <= not(write_in);
			request_next <= '1';
		elsif antic_refresh='1' and antic_refresh_reg='0' then
			addr_next <= x"ff"&refresh_count_reg;
			increment_refresh_count <= '1';
			write_n_next <= '1';
			refresh_next <= '1';
		elsif clear_request='1' then
			addr_next <= (others=>'0');
			data_next <= (others=>'0');
			write_n_next <= '1';
			request_next <= '0';
			refresh_next <= '0';
		end if;

	end process;

	-- antic refresh
	process(increment_refresh_count,refresh_count_reg)
	begin
		refresh_count_next <= refresh_count_reg;
		if (increment_refresh_count='1') then
			refresh_count_next <= std_logic_vector(unsigned(refresh_count_reg)+1);
		end if;
	end process;	

	-- snap the snoop
	process(snoop_data_ready,clear_snoop,snoop_data_in,snoop_data_reg)
	begin
		snoop_data_next <= snoop_data_reg;

		if snoop_data_ready='1' then
			snoop_data_next <= snoop_data_in;
		elsif clear_snoop='1' then
			snoop_data_next <= (others=>'0');
		end if;

	end process;

	-- mux for selecting bus data output
	process(data_reg,snoop_data_reg,write_n_reg)
	begin
		output_data_next <= snoop_data_reg;
		if (write_n_reg='0') then
			output_data_next <= data_reg;
		end if;
	end process;

	-- next state
	process(enable_179_early, state_reg, phi1_reg, phi2_reg, addr_reg, addr_oe_reg, data_reg, snoop_data_reg, data_oe_reg, data_read_reg, bus_data_in, write_n_reg, control_oe_reg, addr_stable_reg, request, cas_n_reg, ras_n_reg, external_read_reg, external_write_only_reg, takeover_reg, disable, mmu_casinh, casinh_n_reg, casinh_oe_reg, pbi_extsel_n, mmu_extio, pbi_ref_n, mmu_s4_n, mmu_s5_n, request_reg, pbi_mpd_n, mpd_n_reg, debug_reg, refresh_oe_reg, refresh_reg)
		variable external_read_tmp : std_logic;
		variable external_write_only_tmp : std_logic;
	begin
		state_next <= state_reg;
		phi1_next <= phi1_reg;
		phi2_next <= phi2_reg;
		addr_oe_next <= addr_oe_reg;
		data_oe_next <= data_oe_reg;
		data_read_next <= data_read_reg;
		control_oe_next <= control_oe_reg;
		refresh_oe_next <= refresh_oe_reg;
		mpd_n_next <= mpd_n_reg;

		ras_n_next <= ras_n_reg;
		cas_n_next <= cas_n_reg;
		casinh_n_next <= casinh_n_reg;
		casinh_oe_next <= casinh_oe_reg;

		complete_next <= '0';
		release_next <= '0';
		takeover_next <= takeover_reg;

		clear_request <= '0';
		clear_snoop <= '0';

		-- for debugging
		addr_stable_next <= addr_stable_reg;
		external_read_next <= external_read_reg;
		external_write_only_next <= external_write_only_reg;
		debug_next <= debug_reg;
		debug_ready <= '0';

		state_next <= std_logic_vector(unsigned(state_reg)+1);

		if (enable_179_early = '1') then
			state_next <= (others=>'0'); -- re-sync
		end if;

		case state_reg is -- whole cycle is about 560ns, so each of our updates is about 17ns
		when '0'&x"0" =>
			ras_n_next <= '1'; -- ras high, falls from 210-305 ns (so 250ish)
			cas_n_next <= '1'; -- cas high, falls at 300-370 ns (so 340ish) (read) and >425 (write). Can fall early if inhibited. its inhibited if pbi requests cycle and its a ram cycle, or if its not a ram cycle
		when '0'&x"2" =>
			addr_oe_next <= not(disable); -- I expect to know the address by here, but really its allowed to change for the following few cycles
			refresh_oe_next <= refresh_reg;
			control_oe_next <= not(disable); --30-145ns after phi2 fall
		when '0'&x"5" => 
			takeover_next <= '0'; -- do not request requests!
			addr_stable_next <= '1'; -- also RW and REF! So now PBI devices know the address
		when '0'&x"A" => 
			-- latch casinh from MMU - since ref and mpd feed that they need to be stable by here
			casinh_n_next <= NOT(MMU_CASINH); 
			casinh_oe_next <= '1';
		when '0'&x"B" =>
			ras_n_next <= '0'; -- ras falls
			-- HERE CASINH needs to be stable for PBI so between 5 and B need to compute this
		when '0'&x"C" =>
			phi1_next <= '0';
		when '0'&x"D" =>
			phi2_next <= '1';
		when '0'&x"F" => --extsel should be stable by "B", but give it more cycles. Since its acts immediately on cas_n I suspect some hardware cheats...
			-- SO BY HERE WE KNOW IF EXTERNAL DATA IS PROVIDED, DO NOT TO DRIVE THE BUS

			external_read_tmp := write_n_reg and ((not(pbi_extsel_n) and casinh_n_reg) or mmu_extio or not(pbi_ref_n) or not(mmu_s4_n) or not(mmu_s5_n)) and not(disable);
			external_read_next <= external_read_tmp;

			external_write_only_tmp := not(write_n_reg) and ((not(pbi_extsel_n) and casinh_n_reg) or not(pbi_ref_n)) and not(disable); -- i.e. ext selected and ram access or mmu disabled
			external_write_only_next <= external_write_only_tmp;

			release_next <= not(external_read_tmp) and not(external_write_only_tmp) and request_reg;  -- carry out rest of cycle if its an internal read - or its a write
			complete_next <= external_write_only_tmp;                    -- suppress internal write if its a purely external write

			mpd_n_next <= pbi_mpd_n or disable;

		when '1'&x"0" =>
			cas_n_next <= not(write_n_reg) or not(casinh_n_reg); --drop cas on reads - unless inhibited
		when '1'&x"3" =>
			if (external_read_reg = '0' or write_n_reg = '0') then -- PBI is not driving it (snoop) or we're writing
				data_oe_next <= not(disable);
			end if;
		when '1'&x"5" =>
			cas_n_next <= not(casinh_n_reg);-- drop cas on writes
		when '1'&x"7" =>
			casinh_oe_next <= '0'; -- let casinh float...
		when '1'&x"c" =>
			complete_next <= external_read_reg;
			data_read_next <= bus_data_in;
			debug_next(15 downto 0) <= addr_reg(15 downto 0);
			debug_next(24) <= write_n_reg;
			debug_next(23 downto 16) <= bus_data_in; --should be present for read and write...
			phi2_next <= '0';
		when '1'&x"d" => 
			debug_ready <= not(disable);
			external_read_next <= '0';
			phi1_next <= '1';
			addr_oe_next <= '0';
			refresh_oe_next <= '0';
			control_oe_next <= '0';
			data_oe_next <= '0';
			mpd_n_next <= '1';
			clear_request <= '1';
			clear_snoop <= '1';
			takeover_next <= not(disable);
		when others=>

		end case;

	end process;

	-- outputs
	BUS_PHI1 <= phi1_reg;
	BUS_PHI2 <= phi2_reg;
	BUS_ADDR_OUT <= addr_reg;
	BUS_ADDR_OE <= addr_oe_reg;
	BUS_DATA_OUT <= output_data_reg;
	BUS_DATA_OE <= data_oe_reg;
	BUS_WRITE_N <= write_n_reg;
	BUS_CONTROL_OE <= control_oe_reg;
	BUS_REFRESH_OE <= refresh_oe_reg;

	BUS_S4_N <= mmu_s4_n; -- control regs directly driven off mmu - these are unregistered and can be glitchy... but not from my end, I register the inputs. So only in case of bad pbi input.
	BUS_S5_N <= mmu_s5_n; -- maybe on portb writes?
	BUS_CCTL_N <= mmu_cctl_n;
	BUS_D1XX_N <= mmu_d1xx_n;

	BUS_CAS_N <= cas_n_reg or not(pbi_extsel_n); -- extsel acts immediately, asynchronously (ref: freddie datasheet)
	BUS_RAS_N <= ras_n_reg;

	BUS_CASINH_N <= casinh_n_reg;
	BUS_CASINH_OE <= casinh_oe_reg;

	TAKEOVER <= takeover_reg;
	RELEASE <= release_reg;
	EXTERNAL_ACCESS <= external_read_reg;
	DATA_OUT <= data_read_reg;
	COMPLETE <= complete_reg;

	MPD_N <= mpd_n_reg;

	DEBUG <= debug_reg;
	
END vhdl;
