#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define BRAM_WIDTH 24
#define ITABLE_SHIFT 5

#define HIST_SIZE 65

int main(int argc, char **argv)
{	
	FILE *fp;
	int i, j;
	int hist[HIST_SIZE];
	int maxerror=0;

	for(i=0;i<HIST_SIZE;++i)
		hist[i]=0;
	
	//long voltab[32][32*3];
	long voltab[32][128];
	long attab[128];

	double range=(double)((1<<24)-1) / ( 62 * 6 );
//	printf("\nRange: %lf\n",range);
	
	for(i = 0; i < 32; i++) {
		// long sample = (i - 16)<<(21-5);
		
		// double step = (double)((1<<21)-1) / (double)31;
		double step = (double)((1<<24)-1) / (double)31 / (double)6;
		long sample = (long)( (double)(i - 15.5) * step ); 
		int sample_i = (i*2)-31;
//		printf("\nSAMPLE %02X : %d %d %06X\n", i, sample, (long)((double)sample_i * range), sample & ((1<<24)-1) );
	
		for(j = 0; j < 32*3; j++) {
			int err;
			//double att = pow( (double)10, (double)( j ) * -(double)0.15 );
			double att = pow( (double)10, (double)( j ) * -(double)0.07 );
			long att_i = (long)(att * range * (1<<ITABLE_SHIFT));
			long final = (long)( (double)sample * att );
			long final_i = (long)( sample_i * att_i + (1<<(ITABLE_SHIFT-1)))>>ITABLE_SHIFT;
			err=final_i-final;
			if(err<0)
				err=-err;
			if(err>maxerror)
				maxerror=err;
			if(err<HIST_SIZE)
				++hist[err];
//			printf("%d %06X  ", final, final & ((1<<24)-1));
//			printf("%06X (%06X) \n",final_i & ((1<<24)-1), att_i);
			voltab[i][j] = final;
			attab[j]=att_i;
		}
		for(j = 32*3; j<128; j++) {
			voltab[i][j] = 0;
			attab[j]=0;
		}
	}
	printf("itable_shift: %d, max error from integer calcs: %d\n",ITABLE_SHIFT,maxerror);

	j=0;
	for(i=0;i<=maxerror;++i)
	{
		if(i>0)
			j+=hist[i];
		printf("Error size: %d, count: %d\n",i,hist[i]);
	}
	printf("A total of %d codes lost precision\n",j);

	int a = 0;
	fp = fopen("voltab_small.mif","wb");
	fprintf(fp, "WIDTH = %d;\n", BRAM_WIDTH/2);
	fprintf(fp, "DEPTH = 256;\n");
	fprintf(fp, "ADDRESS_RADIX = HEX;\n");
	fprintf(fp, "DATA_RADIX = HEX;\n");
	fprintf(fp, "CONTENT\n");
	fprintf(fp, "BEGIN\n");

	// We split the table in half, emitting the upper half of each entry first, then the lower half
	// which should allow the ROM to be implemented as a dual port RAM in a single M9K.
	for(j = 0; j < /*32*3*/ 128; j++) {
		fprintf(fp,"%04X : %04X;\n", a++, (attab[j]>>(BRAM_WIDTH/2))&((1<<(BRAM_WIDTH/2))-1)); // Upper half first
	}
	for(j = 0; j < /*32*3*/ 128; j++) {
		fprintf(fp,"%04X : %04X;\n", a++, attab[j]&((1<<(BRAM_WIDTH/2))-1)); // Now lower half
	}
	fprintf(fp, "END;\n");
	fclose(fp);

	return 0;
}
