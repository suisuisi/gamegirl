#ifndef SPI_H
#define SPI_H

#define INTERCEPTBASE 0xFFFFFFFC
#define HW_INTERCEPT(x) *(volatile unsigned int *)(INTERCEPTBASE+x)

#define SPIBASE 0xFFFFFFD0
#define HW_SPI(x) *(volatile unsigned int *)(SPIBASE+x)

#define SPI(x) HW_SPI(HW_SPI_DATA)=(x)
#define SPI_READ(x) (HW_SPI(HW_SPI_DATA))

/* SPI registers */
#define HW_SPI_CS 0x0	/* CS bits are write-only, but bit 15 reads as the SPI busy signal */
#define HW_SPI_DATA 0x04 /* Blocks on both reads and writes, making BUSY signal redundant. */
/* #define HW_SPI_PUMP 0x08 */ /* Push 16-bits through SPI in one instruction */

#define HW_SPI_CS_SD 0
#define HW_SPI_FAST_SD 8
#define HW_SPI_FAST_INT 9
#define HW_SPI_BUSY 15

#define HW_SPI_SD 1
#define HW_SPI_FPGA 2
#define HW_SPI_OSD 3
#define HW_SPI_SNIFF 4
#define HW_SPI_CONF 5

#define SPI_CONF_READ 0x14

#define SPI_FPGA_FILE_TX 0x53
#define SPI_FPGA_FILE_TX_DAT 0x54
#define SPI_FPGA_FILE_INDEX 0x55
#define SPI_FPGA_FILE_INFO 0x56

//#define SPI_ENABLE(x) {while((HW_SPI(HW_SPI_CS)&(1<<HW_SPI_BUSY))); HW_SPI(HW_SPI_CS)=((1<<x)|1);}
//#define SPI_ENABLE_FAST(x) {while((HW_SPI(HW_SPI_CS)&(1<<HW_SPI_BUSY))); HW_SPI(HW_SPI_CS)=((1<<HW_SPI_FAST)|(1<<x)|1);}
//#define SPI_DISABLE(x) {while((HW_SPI(HW_SPI_CS)&(1<<HW_SPI_BUSY))); HW_SPI(HW_SPI_CS)=((1<<x)|0);}
#define SPI_WAIT {while(HW_SPI(HW_SPI_CS)&(1<<HW_SPI_BUSY));}
#define SPI_ENABLE(x) {HW_SPI(HW_SPI_CS)=((1<<x)|1);}
#define SPI_ENABLE_FAST_SD(x) {HW_SPI(HW_SPI_CS)=((1<<HW_SPI_FAST_SD)|(1<<x)|1);}
#define SPI_ENABLE_FAST_INT(x) {HW_SPI(HW_SPI_CS)=((1<<HW_SPI_FAST_INT)|(1<<x)|1);}
#define SPI_DISABLE(x) {HW_SPI(HW_SPI_CS)=((1<<x)|0);}

#define EnableSD() SPI_ENABLE_FAST_SD(HW_SPI_CS_SD)
#define DisableSD() SPI_DISABLE(HW_SPI_CD_SD)
#define EnableDirectSD() SPI_ENABLE_FAST_SD(HW_SPI_SNIFF)
#define DisableDirectSD() SPI_DISABLE(HW_SPI_SNIFF)
#define EnableIO() SPI_ENABLE_FAST_INT(HW_SPI_CONF)
#define DisableIO() SPI_DISABLE(HW_SPI_CONF)
#define EnableOsd() SPI_ENABLE_FAST_INT(HW_SPI_OSD)
#define DisableOsd() SPI_DISABLE(HW_SPI_OSD)
#define EnableFpga() SPI_ENABLE_FAST_INT(HW_SPI_FPGA)
#define DisableFpga() SPI_DISABLE(HW_SPI_FPGA)

#ifdef __cplusplus
extern "C" {
#endif

int spi_init();
int sd_read_sector(unsigned long lba,unsigned char *buf);
int sd_write_sector(unsigned long lba,unsigned char *buf); // FIXME - stub
int sd_get_size();

extern int spi_checksum;
extern int sd_is_sdhc;
extern int sd_size;

#ifdef __cplusplus
}
#endif

#endif
