#include "menu.h"
#include "keyboard.h"
#include "userio.h"
#include "spi.h"

/* Key -> gamepad mapping.  We override this to swap buttons A and B for NES. */

unsigned char joy_keymap[]=
{
	KEY_CAPSLOCK,
	KEY_LSHIFT,
	KEY_LCTRL,
	KEY_ALT,
	KEY_W,
	KEY_S,
	KEY_A,
	KEY_D,
	KEY_RSHIFT,
	KEY_SLASH,
	KEY_PERIOD,
	KEY_COMMA,
	KEY_UPARROW,
	KEY_DOWNARROW,
	KEY_LEFTARROW,
	KEY_RIGHTARROW,
};

/* Override menu_joystick to emulate analogue sticks */

int analoguesensitivity=0x80;
int analogue[4];

void Menu_Joystick(int port,int joymap)
{
	int buttons=HW_JOY(REG_JOY_EXTRA);
	int *a=&analogue[2*port];
	if(TestKey(KEY_F1) || (buttons&0x2))
		analoguesensitivity=0x80;
	if(TestKey(KEY_F2) || (buttons&0x4))
		analoguesensitivity=0x30;
	if(TestKey(KEY_F3) || (buttons&0x8))
		analoguesensitivity=0x0c;
	if(TestKey(KEY_F4) || (buttons&0x10))
		analoguesensitivity=0x08;
	user_io_digital_joystick_ext(port, joymap);
	Menu_JoystickToAnalogue(a,joymap);
	Menu_JoystickToAnalogue(a+1,joymap>>2);
	user_io_analogue_joystick(port,a);
}

__weak int rom_minsize=8192;

/* Initial ROM */
const char *bootrom_name="AUTOBOOTVEC";

extern int romtype;

char *autoboot()
{
	int i;
	romtype=-1;

	SPI(0xff);
	SPI_ENABLE(HW_SPI_CONF);
	SPI(UIO_SET_STATUS2); // Put the core in reset
	SPI(1);
	SPI_DISABLE(HW_SPI_CONF);

	i=LoadROM("VECTREX BIN");

	SPI(0xff);
	SPI_ENABLE(HW_SPI_CONF);
	SPI(UIO_SET_STATUS2); // Release the reset
	SPI(0);
	SPI_DISABLE(HW_SPI_CONF);

	if(!i)
		return("VECTREX.BIN not found!");

	romtype=0;
	i=LoadROM(bootrom_name);

	return(0);
}


