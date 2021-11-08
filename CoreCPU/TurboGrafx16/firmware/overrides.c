#include "keyboard.h"

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
	KEY_ENTER,
	KEY_RSHIFT,
	KEY_RCTRL,
	KEY_ALTGR,
	KEY_UPARROW,
	KEY_DOWNARROW,
	KEY_LEFTARROW,
	KEY_RIGHTARROW,
};

/* Initial ROM */
const char *bootrom_name="AUTOBOOTSGX";
extern unsigned char romtype;
extern unsigned char cfgidx;
char *autoboot()
{
	char *result=0;
	romtype=1;
	cfgidx=1;
	LoadROM(bootrom_name);
	return(result);
}

