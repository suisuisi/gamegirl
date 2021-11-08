#include <stdio.h>

// registers
#define COMMAND_REGISTER 0x00
#define SRC_START_REGISTER 0x01
#define SRC_PITCH_REGISTER 0x05
#define DST_START_REGISTER 0x07
#define DST_PITCH_REGISTER 0x0b
#define COLOR_REGISTER 0x0d
#define BLIT_WIDTH_REGISTER 0x0e
#define BLIT_HEIGHT_REGISTER 0x10
#define X0_REGISTER 0x12
#define Y0_REGISTER 0x14
#define X1_REGISTER 0x16
#define Y1_REGISTER 0x18
#define FRAMEBUFFER_START_REGISTER 0x1a
#define FRAMEBUFFER_PITCH_REGISTER 0x1e
#define STATUS_REGISTER 0x20
#define WRITE_FRAMEBUFFER_REGISTER 0x21

// commands for COMMAND_REGISTER
#define RESET_COMMAND 0x00
#define SET_PIXEL 0x01
#define DRAW_LINE 0x02
#define FILL_RECT 0x03
#define BLIT_SIZE 0x04
#define BLIT_COMMAND 0x05
#define BLIT_TRANSPARENT 0x06
#define WRITE_FRAMEBUFFER 0x07

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 240
#define SCREEN_SIZE (SCREEN_WIDTH * SCREEN_HEIGHT)

typedef unsigned char uint8_t;
typedef unsigned int uint16_t;
typedef unsigned long uint32_t;

#define YGC ((uint8_t*)0xd000)

void setReg8(uint8_t reg, uint8_t value)
{
	YGC[reg] = value;
}

void setReg16(uint8_t reg, uint16_t value)
{
	YGC[reg] = value & 0xff;
	YGC[reg + 1] = value >> 8;
}

void setReg32(uint8_t reg, uint32_t value)
{
	YGC[reg] = value & 0xff;
	YGC[reg + 1] = (value >> 8) & 0xff;
	YGC[reg + 2] = (value >> 16) & 0xff;
	YGC[reg + 3] = value >> 24;
}

uint16_t g_currentX;
uint16_t g_currentY;
 
uint32_t screenAddress = 0;
uint32_t fontAddress = SCREEN_SIZE;

uint32_t font[] =
{
	0x00000180, 0x018003c0, 0x03c003c0, 0x06e004e0, 0x0c700870, 0x08701ff8, 0x1038301c, 0x201c701e,
	0x00007fc0, 0x38703838, 0x38183838, 0x38703fc0, 0x38703838, 0x381c381c, 0x381c3838, 0x38707fc0,
	0x000007e4, 0x1f3c3c0c, 0x38047800, 0x70007000, 0x70007000, 0x70007000, 0x3804380c, 0x1c3807e0,
	0x00007fc0, 0x38f03838, 0x3838381c, 0x381c381c, 0x381c381c, 0x381c381c, 0x38383838, 0x38f07fc0,
	0x00007ffc, 0x380c3804, 0x38003800, 0x38203860, 0x3fe03860, 0x38203800, 0x38003804, 0x380c7ffc,
	0x00007ffc, 0x380c3804, 0x38003800, 0x38203860, 0x3fe03860, 0x38203800, 0x38003800, 0x38007c00,
	0x000007e4, 0x1f3c3c0c, 0x38047800, 0x70007000, 0x7000703e, 0x701c701c, 0x381c381c, 0x1c3807e0,
	0x00007c3e, 0x381c381c, 0x381c381c, 0x381c381c, 0x3ffc381c, 0x381c381c, 0x381c381c, 0x381c7c3e,
	0x000007c0, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x038007c0,
	0x0000003e, 0x001c001c, 0x001c001c, 0x001c001c, 0x001c001c, 0x181c3c1c, 0x3c381838, 0x0c7003c0,
	0x00007c38, 0x38303860, 0x38c03980, 0x3b003e00, 0x3f003f80, 0x3bc039e0, 0x38f03878, 0x383c7c1e,
	0x00007c00, 0x38003800, 0x38003800, 0x38003800, 0x38003800, 0x38003800, 0x3804380c, 0x381c7ffc,
	0x0000781e, 0x381c3c3c, 0x3c3c3c3c, 0x3e7c2e5c, 0x2e5c2fdc, 0x279c279c, 0x279c231c, 0x231c733e,
	0x0000600e, 0x30043804, 0x3c043e04, 0x2f042784, 0x23c421e4, 0x20f4207c, 0x203c201c, 0x200c7004,
	0x000007e0, 0x1c38381c, 0x381c781e, 0x700e700e, 0x700e700e, 0x700e781e, 0x381c381c, 0x1c3807e0,
	0x00007fc0, 0x38f03838, 0x381c381c, 0x381c3838, 0x38f03fc0, 0x38003800, 0x38003800, 0x38007c00,
	0x000007e0, 0x1c38381c, 0x381c781e, 0x700e700e, 0x700e700e, 0x73ee78fe, 0x387c383c, 0x1c3e07ef,
	0x00007fc0, 0x38f03838, 0x381c381c, 0x381c3838, 0x38f03fc0, 0x39e038f0, 0x3878383c, 0x381e7c0f,
	0x00000fc8, 0x38786018, 0x60087000, 0x7c003f80, 0x0fe003f8, 0x007c001c, 0x400c600c, 0x78384fe0,
	0x00007ffc, 0x638c4384, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x038007c0,
	0x00007c0e, 0x38043804, 0x38043804, 0x38043804, 0x38043804, 0x38043804, 0x1c0c1c08, 0x0f3803e0,
	0x0000780e, 0x3804380c, 0x1c081c18, 0x0e100e10, 0x0e300720, 0x076003c0, 0x03c003c0, 0x01800180,
	0x0000fbe7, 0x71c271c2, 0x38e638e4, 0x39e439e4, 0x1d7c1d78, 0x1f781e78, 0x0e380e30, 0x0c300c30,
	0x0000fc1e, 0x780c3c18, 0x1e300e60, 0x0fc00780, 0x038003c0, 0x07e00ce0, 0x18f03078, 0x603cf07e,
	0x0000780c, 0x38081c18, 0x1e300e20, 0x076007c0, 0x03800380, 0x03800380, 0x03800380, 0x038007c0,
	0x00007ffc, 0x60384078, 0x00f000e0, 0x01e003c0, 0x03800780, 0x0f000e00, 0x1e003c04, 0x380c7ffc,
	0x000003c0, 0x0e701c38, 0x1c383c3c, 0x381c381c, 0x381c381c, 0x381c3c3c, 0x1c381c38, 0x0e7003c0,
	0x00000380, 0x0f800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800fe0,
	0x000003c0, 0x0c701838, 0x3c3c3c1c, 0x181c0038, 0x007800f0, 0x01e003c0, 0x07800f04, 0x1e0c3ffc,
	0x00003ffc, 0x30382070, 0x00e001c0, 0x03f00078, 0x0038003c, 0x181c3c1c, 0x3c3c1838, 0x0c7003c0,
	0x00000e00, 0x0e000e00, 0x0e000e00, 0x1c001c70, 0x1c703870, 0x38703ffc, 0x00700070, 0x007001fc,
	0x00003ffc, 0x380c3804, 0x38003800, 0x3fc00070, 0x0038003c, 0x181c3c1c, 0x3c3c1838, 0x0c7003c0,
	0x000003f0, 0x0f001c00, 0x1c003800, 0x3fc03c70, 0x38383838, 0x381c381c, 0x1c381c38, 0x0e7003c0,
	0x00003ffc, 0x301c2038, 0x007000f0, 0x00e001e0, 0x01c001c0, 0x03c00380, 0x03800380, 0x03800380,
	0x000007e0, 0x1c38381c, 0x380c3c0c, 0x1e180fb0, 0x07e00df0, 0x1878303c, 0x301c381c, 0x1c7807e0,
	0x000003c0, 0x0e701c38, 0x1c38381c, 0x381c1c1c, 0x1c1c0e3c, 0x03fc001c, 0x00380038, 0x00f00fc0,
	0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000800, 0x1c000800,
	0x000003c0, 0x0e701818, 0x33ac2664, 0x6c264c02, 0x4c024c02, 0x6c262664, 0x33cc1818, 0x0e7003c0,
	0x00000780, 0x06c00c40, 0x0c400c80, 0x07000e00, 0x1e1c3718, 0x731073a0, 0x71c039e4, 0x1f380000,
};

void waitForOk()
{
	while (YGC[STATUS_REGISTER] & 1) {}
}




// graphics commands

void executeCommandAndWait(uint8_t command)
{
	setReg8(COMMAND_REGISTER, command);
	waitForOk();
}

void reset()
{
	executeCommandAndWait(RESET_COMMAND);
}

void setFramebufferStart(uint32_t address)
{
	setReg32(FRAMEBUFFER_START_REGISTER, address);
}

void setFramebufferPitch(uint32_t pitch)
{
	setReg16(FRAMEBUFFER_PITCH_REGISTER, pitch);
}

void setDestinationStart(uint32_t address)
{
	setReg32(DST_START_REGISTER, address);
}

void setDestinationPitch(uint16_t pitch)
{
	setReg16(DST_PITCH_REGISTER, pitch);
}

void setSourceStart(uint32_t address)
{
	setReg32(SRC_START_REGISTER, address);
}

void setSourcePitch(uint16_t pitch)
{
	setReg16(SRC_PITCH_REGISTER, pitch);
}

void setColor(uint8_t color)
{
	setReg8(COLOR_REGISTER, color);
}

void setX0Y0(uint16_t x, uint16_t y)
{
	setReg16(X0_REGISTER, x);
	setReg16(Y0_REGISTER, y);
}

void setX1Y1(uint16_t x, uint16_t y)
{
	setReg16(X1_REGISTER, x);
	setReg16(Y1_REGISTER, y);
}

void setPixel(uint16_t x, uint16_t y)
{
	setX0Y0(x, y);
	executeCommandAndWait(SET_PIXEL);
}

void moveTo(uint16_t x, uint16_t y)
{
	g_currentX = x;
	g_currentY = y;
}

void lineTo(uint16_t x, uint16_t y)
{
	setX0Y0(g_currentX, g_currentY);
	setX1Y1(x, y);
	g_currentX = x;
	g_currentY = y;
	executeCommandAndWait(DRAW_LINE);
}

void fillRect(uint16_t x, uint16_t y, uint16_t width, uint16_t height)
{
	setX0Y0(x, y);
	setX1Y1(x + width, y + height);
	executeCommandAndWait(FILL_RECT);
}

void blitSize(uint16_t width, uint16_t height)
{
	setReg16(BLIT_WIDTH_REGISTER, width);
	setReg16(BLIT_HEIGHT_REGISTER, height);
}

void blit(int srcX, int srcY, int dstX, int dstY)
{
	setX0Y0(srcX, srcY);
	setX1Y1(dstX, dstY);
	executeCommandAndWait(BLIT_COMMAND);
}

void blitTransparent(int srcX, int srcY, int dstX, int dstY)
{
	setX0Y0(srcX, srcY);
	setX1Y1(dstX, dstY);
	executeCommandAndWait(BLIT_TRANSPARENT);
}

void writeFramebuffer(uint32_t address, uint32_t size, uint32_t* data)
{
	uint32_t i;
	setDestinationStart(address);
	executeCommandAndWait(WRITE_FRAMEBUFFER);
	for (i = 0; i < size; i++) {
		uint8_t j;
		uint32_t d = data[i];
		for (j = 0; j < 32; j++) {
			YGC[WRITE_FRAMEBUFFER_REGISTER] = (d & 0x80000000) ? 1 : 0;
			d <<= 1;
		}
	}
}


// higher level functions

void drawChar(uint16_t x, uint16_t y, uint8_t c)
{
	uint16_t srcX = 0;
	uint16_t srcY = 16*c;
	uint16_t dstX = x;
	uint16_t dstY = y;
	blit(srcX, srcY, dstX, dstY);
}

void drawText(uint16_t x, uint16_t y, char* text)
{
	setSourceStart(fontAddress);
	setSourcePitch(16);
	setDestinationStart(screenAddress);
	blitSize(16, 16);
	while (*text) {
		char c = *text;
		if (c != 32) drawChar(x, y, c - 'a');
		x += 16;
		text++;
	}
}

void initHardware()
{
	reset();
	setFramebufferPitch(SCREEN_WIDTH);
	setDestinationPitch(SCREEN_WIDTH);
	setSourcePitch(SCREEN_WIDTH);
}

int main()
{
	// initialize hardware
	initHardware();

	// clear background
	setColor(0);
	fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

	// set pixels in corners
	setColor(1);
	setPixel(0, 0);
	setPixel(SCREEN_WIDTH - 1, 0);
	setPixel(SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1);
	setPixel(0, SCREEN_HEIGHT - 1);

	// draw frame
	moveTo(2, 0);
	lineTo(SCREEN_WIDTH - 3, 0);
	moveTo(SCREEN_WIDTH - 1, 2);
	lineTo(SCREEN_WIDTH - 1, SCREEN_HEIGHT - 3);
	moveTo(SCREEN_WIDTH - 3, SCREEN_HEIGHT - 1);
	lineTo(2, SCREEN_HEIGHT - 1);
	moveTo(0, SCREEN_HEIGHT - 3);
	lineTo(0, 2);

	// draw some lines
	{
		int width = 20;
		int steps = 10;
		int x0 = 10;
		int y0 = 20;
		int i;
		for (i = 0; i < steps; i++) {
			moveTo(x0 + i * width, y0);
			lineTo(x0 + steps * width, y0 + i * width);
			lineTo(x0 + steps * width - i * width, y0 + steps * width);
			lineTo(x0, y0 + steps * width - i * width);
			lineTo(x0 + i * width, y0);
		}
	}

	// upload font
	writeFramebuffer(fontAddress, sizeof(font) / sizeof(int), font);

	// text test
	drawText(27, 110, "hello world");

	// blit test
	drawText(27, 2, "opaque blit");
	setSourcePitch(SCREEN_WIDTH);
	setSourceStart(0);
	blitSize(176, 16);
	blit(27, 2, 27, 52);

	// transaprent blit test
	setColor(0);  // transparent background color
	drawText(27, 222, "transparent");
	setSourcePitch(SCREEN_WIDTH);
	setSourceStart(0);
	blitSize(176, 16);
	blitTransparent(27, 222, 27, 172);

	// draw some rectangles
	drawText(240, 180, "fill");
	drawText(240, 196, "rect");
	setColor(1);
	fillRect(270, 30, 40, 120);
	fillRect(230, 70, 70, 20);
	fillRect(250, 120, 30, 50);

	while (1) {}
	
	return 0;
}
