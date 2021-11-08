#
# Makefile
#

SRC=../src
SRCS = $(SRC)/vdp.vhd $(SRC)/DualPortRAM.vhd $(SRC)/vdp_common.vhd vdp_tb.vhd vram.vhd vram32.vhd cpu.vhd
OBJS = $(notdir $(SRCS:.vhd=.o)) vram_c.o video_c.o cpu_c.o

FLAGS=--ieee=synopsys -fexplicit 

all: vdp_tb

vdp_tb.o: vdp.o vram.o vram32.o video.o cpu.o
vdp.o: DualPortRAM.o vdp_common.o obj_cache.o
vram.o: vram_c.o
video.o: video_c.o
cpu.o: cpu_c.o

%.o: %.vhd
	ghdl -a $(FLAGS) $<

%.o: $(SRC)/%.vhd
	ghdl -a $(FLAGS) $<

work-obj93.cf: $(SRCS)
	ghdl -i $(SRCS)

run: vdp_tb Makefile
	ghdl -r $< --ieee-asserts=disable --stop-time=100ms 

view: video.png
	display video.png

# view interlaced
iview: videoi.png
	display videoi.png

video.png: vdp_tb Makefile
	ghdl -r $< --ieee-asserts=disable
	rm -f video.png
	ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb565 -s 855x262 -i video.rgb -f image2 -vcodec png video.png
	convert video.png -scale 855x524! video.png

videoi.png: vdp_tb Makefile
#       grab two frames and combine them into one de-interlaced 
	INTERLACE=1 ghdl -r $< --ieee-asserts=disable
	rm -f video?.png
	ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb565 -s 855x262 -i video1.rgb -f image2 -vcodec png video1.png
	convert video1.png -scale 855x524! video1.png
	ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb565 -s 855x262 -i video2.rgb -f image2 -vcodec png video2.png
	convert video2.png -scale 855x524! video2.png
	convert video1.png \( video2.png -alpha on -channel A -fx 'j%2' \) -composite videoi.png

vdp_tb: $(OBJS)
	ghdl -e $(FLAGS) -Wl,vram_c.o -Wl,video_c.o -Wl,cpu_c.o $@

vdp.ghw:  vdp_tb Makefile
	ghdl -r $< --ieee-asserts=disable --stop-time=50ms --read-wave-opt=waveopt --wave=$@

wave: vdp.ghw
	gtkwave vdp.sav

clean::
	rm -f work-obj93.cf *.o *~ *.lst *.ghw $(ROOT) *.out
