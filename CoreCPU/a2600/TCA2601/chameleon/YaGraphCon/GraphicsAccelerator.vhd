-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;
use work.YaGraphConPackage.all;

entity GraphicsAccelerator is
	generic(
		ADDRESS_WIDTH: natural;
		BIT_DEPTH: natural;
		PITCH_WIDTH: natural
	);
	port(
		clock: in std_logic;
		reset:in std_logic;
		
		-- register interface
		registers: in registerSetType;
		busy: out std_logic;
		
		-- 1 to start command
		start: in std_logic;

		-- 1 to write next pixel from register into framebuffer
		framebufferWrite: in std_logic;

		-- framebuffer interface
		readAddress: out unsigned(ADDRESS_WIDTH-1 downto 0);
		writeAddress: out unsigned(ADDRESS_WIDTH-1 downto 0);
		data: out unsigned(BIT_DEPTH-1 downto 0);
		q: in unsigned(BIT_DEPTH-1 downto 0);
		writeEnable: out std_logic
	);
end entity GraphicsAccelerator;

architecture rtl of GraphicsAccelerator is

	-- statemachine
	type stateType is (
		WAIT_FOR_START,
		PIXEL,
		LINE_INIT,
		HORIZONTAL_LINE,
		VERTICAL_LINE,
		RECT,
		BLIT_DELAY1,
		BLIT_DELAY2,
		BLIT
	);
	signal state: stateType := WAIT_FOR_START;
	
	signal command: unsigned(7 downto 0);
	signal srcStart: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal srcPitch: unsigned(PITCH_WIDTH-1 downto 0);
	signal dstStart: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal dstPitch: unsigned(PITCH_WIDTH-1 downto 0);
	signal color: unsigned(BIT_DEPTH-1 downto 0);
	signal blitWidth: unsigned(15 downto 0);
	signal blitHeight: unsigned(15 downto 0);
	signal x0: unsigned(15 downto 0);
	signal y0: unsigned(15 downto 0);
	signal x1: unsigned(15 downto 0);
	signal y1: unsigned(15 downto 0);
	signal blitTransparent: boolean;
	signal status: unsigned(7 downto 0);
	signal writeFramebufferPixel: unsigned(BIT_DEPTH-1 downto 0);

	signal x: unsigned(15 downto 0);
	signal y: unsigned(15 downto 0);
	signal x2: unsigned(15 downto 0);
	signal y2: unsigned(15 downto 0);
	signal dx: unsigned(15 downto 0);
	signal dy: unsigned(15 downto 0);
	signal incx: std_logic;
	signal incy: std_logic;
	signal balance: signed(15 downto 0);

	signal framebufferAddress: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal framebufferWriteDelay: std_logic := '0';
	
begin

	command <= registers(COMMAND_REGISTER);
	srcStart <= registers(SRC_START_REGISTER + 2)(0) & registers(SRC_START_REGISTER + 1) & registers(SRC_START_REGISTER);
	srcPitch <= registers(SRC_PITCH_REGISTER + 1) & registers(SRC_PITCH_REGISTER);
	dstStart <= registers(DST_START_REGISTER + 2)(0) & registers(DST_START_REGISTER + 1) & registers(DST_START_REGISTER);
	dstPitch <= registers(DST_PITCH_REGISTER + 1) & registers(DST_PITCH_REGISTER);
	color <= registers(COLOR_REGISTER)(0 downto 0);
	blitWidth <= registers(BLIT_WIDTH_REGISTER + 1) & registers(BLIT_WIDTH_REGISTER);
	blitHeight <= registers(BLIT_HEIGHT_REGISTER + 1) & registers(BLIT_HEIGHT_REGISTER);
	x0 <= registers(X0_REGISTER + 1) & registers(X0_REGISTER);
	y0 <= registers(Y0_REGISTER + 1) & registers(Y0_REGISTER);
	x1 <= registers(X1_REGISTER + 1) & registers(X1_REGISTER);
	y1 <= registers(Y1_REGISTER + 1) & registers(Y1_REGISTER);
	writeFramebufferPixel <= registers(WRITE_FRAMEBUFFER_REGISTER)(0 downto 0);

	process(clock)
		variable dx2: unsigned(dx'high downto 0);
		variable dy2: unsigned(dy'high downto 0);
		procedure setPixel(x: unsigned(15 downto 0); y: unsigned(15 downto 0); clr: unsigned(BIT_DEPTH-1 downto 0)) is
		begin
			writeAddress <= adjustLength(dstStart + dstPitch * y + x, writeAddress'length);
			writeEnable <= '1';
			data <= clr;
		end;
		procedure nextBlitRead is
		begin
			readAddress <= adjustLength(srcStart + srcPitch * y2 + x2, readAddress'length);
			if x2 < x0 + blitWidth then
				x2 <= x2 + 1;
			else
				x2 <= x0;
				y2 <= y2 + 1;
			end if;
		end;
		procedure doIncx is
		begin
			if incx = '1' then
				x <= x + 1;
			else
				x <= x - 1;
			end if;
		end;
		procedure doIncy is
		begin
			if incy = '1' then
				y <= y + 1;
			else
				y <= y - 1;
			end if;
		end;
	begin
		if rising_edge(clock) then
			if reset = '1' then
				state <= WAIT_FOR_START;
				busy <= '0';
			else
				writeEnable <= '0';
				framebufferWriteDelay <= '0';
				case state is
					when WAIT_FOR_START =>
						busy <= '0';
						if start = '1' then
							busy <= '1';
							case command is
								when SET_PIXEL =>
									x <= x0;
									y <= y0;
									state <= PIXEL;
								when DRAW_LINE =>
									if x1 >= x0 then
										dx <= x1 - x0;
										incx <= '1';
									else
										dx <= x0 - x1;
										incx <= '0';
									end if;
									if y1 >= y0 then
										dy <= y1 - y0;
										incy <= '1';
									else
										dy <= y0 - y1;
										incy <= '0';
									end if;
									x <= x0;
									y <= y0;
									x2 <= x1;
									y2 <= y1;
									state <= LINE_INIT;
								when FILL_RECT =>
									x <= x0;
									y <= y0;
									state <= RECT;
								when BLIT_COMMAND | BLIT_TRANSPARENT =>
									x <= x1;
									y <= y1;
									x2 <= x0;
									y2 <= y0;
									blitTransparent <= command = BLIT_TRANSPARENT;
									state <= BLIT_DELAY1;
								when WRITE_FRAMEBUFFER =>
									framebufferAddress <= dstStart;
								when others => null;
							end case;
						end if;
						if framebufferWrite = '1' then
							writeAddress <= framebufferAddress;
							framebufferAddress <= framebufferAddress + 1;
							framebufferWriteDelay <= '1';
						else
							if framebufferWriteDelay = '1' then
								-- write one cycle later, because the writeFramebufferPixel value needs it to be latched
								writeEnable <= '1';
								data <= writeFramebufferPixel;
							end if;
						end if;
					when PIXEL =>
						setPixel(x, y, color);
						state <= WAIT_FOR_START;
					when LINE_INIT =>
						dx2 := dx(dx'high - 1 downto 0) & "0";
						dy2 := dy(dy'high - 1 downto 0) & "0";
						if dx >= dy then
							balance <= to_signed(to_integer(dy2) - to_integer(dx), balance'length);
							state <= HORIZONTAL_LINE;
						else
							balance <= to_signed(to_integer(dx2) - to_integer(dy), balance'length);
							state <= VERTICAL_LINE;
						end if;
						dx <= dx2;
						dy <= dy2;
					when HORIZONTAL_LINE =>
						if x /= x2 then
							setPixel(x, y, color);
							if balance >= 0 then
								doIncy;
								balance <= balance - to_integer(dx) + to_integer(dy);
							else
								balance <= balance + to_integer(dy);
							end if;
							doIncx;
						else
							setPixel(x, y, color);
							state <= WAIT_FOR_START;
						end if;
					when VERTICAL_LINE =>
						if y /= y2 then
							setPixel(x, y, color);
							if balance >= 0 then
								doIncx;
								balance <= balance - to_integer(dy) + to_integer(dx);
							else
								balance <= balance + to_integer(dx);
							end if;
							doIncy;
						else
							setPixel(x, y, color);
							state <= WAIT_FOR_START;
						end if;
					when RECT =>
						setPixel(x, y, color);
						if x < x1 then
							x <= x + 1;
						else
							x <= x0;
							if y < y1 then
								y <= y + 1;
							else
								state <= WAIT_FOR_START;
							end if;
						end if;
					when BLIT_DELAY1 =>
						nextBlitRead;
						state <= BLIT_DELAY2;
					when BLIT_DELAY2 =>
						nextBlitRead;
						state <= BLIT;
					when BLIT =>
						if blitTransparent then
							if q /= color then
								setPixel(x, y, q);
							end if;
						else
							setPixel(x, y, q);
						end if;
						if x < x1 + blitWidth then
							x <= x + 1;
						else
							x <= x1;
							if y < y1 + blitHeight then
								y <= y + 1;
							else
								state <= WAIT_FOR_START;
							end if;
						end if;
						nextBlitRead;
					when others =>
						state <= WAIT_FOR_START;
				end case;
			end if;
		end if;
	end process;

end architecture rtl;
