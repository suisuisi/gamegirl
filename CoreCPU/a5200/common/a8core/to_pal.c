#include <stdio.h>

/*                process(atari_colour)
                begin
                        case atari_colour is
                                when X"00" =>
                                        R_next <= X"00";
                                        G_next <= X"00";
                                        B_next <= X"00";
                                when X"01" =>
                                        R_next <= X"11";
                                        G_next <= X"11";
                                        B_next <= X"11";*/

int main(int argc, char const ** argv)
{
//ARCHITECTURE altirra OF gtia_palette IS
//begin
	printf("ARCHITECTURE %s OF gtia_palette IS\nbegin\n",argv[2]);
	printf("\t\t--%s\n",argv[1]);
	printf("\t\tprocess(atari_colour)\n");
	printf("\t\tbegin\n");
	printf("\t\t\tcase atari_colour is\n");

	FILE * f = fopen(argv[1],"r");
	for (int col = 0; col!=256; ++col)
	{
		unsigned char r = fgetc(f);
		unsigned char g = fgetc(f);
		unsigned char b = fgetc(f);

		printf("\t\t\t\twhen X\"%02x\" =>\n", col);
		printf("\t\t\t\t\tR_next <= X\"%02x\";\n",r);
		printf("\t\t\t\t\tG_next <= X\"%02x\";\n",g);
		printf("\t\t\t\t\tB_next <= X\"%02x\";\n",b);
	}
	fclose(f);
	printf("\t\t\t\twhen others =>\n\t\t\t\t\t--nop\n");
	printf("\t\t\tend case;\n");
	printf("\t\tend process;\n");
	printf("end %s;\n",argv[2]);
//end laoo;

	return 0;
}


