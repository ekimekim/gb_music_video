
# avoid implicit rules for clarity
.SUFFIXES: .asm .o .gb
.PHONY: bgb clean tests testroms debug

GENERATED_ASM := $(wildcard data/*.asm) data/audio.asm
ASMS := $(wildcard *.asm) $(GENERATED_ASM)
OBJS := $(ASMS:.asm=.o)
DEBUGOBJS := $(addprefix build/debug/,$(OBJS))
RELEASEOBJS := $(addprefix build/release/,$(OBJS))
INCLUDES := $(wildcard include/*.asm) include/banks.asm
TESTS := $(wildcard tests/*.py)
AUDIO := music.opus

FIXARGS := -v -C -m 0x19 

all: build/release/rom.gb tests/.uptodate

data/audio.asm: tools/process_audio tools/quantize_audio.py $(AUDIO) data
	tools/process_audio $(AUDIO)

include/banks.asm: tools/gen_data.py tools/process_image.py data
	python tools/gen_data.py

build/debug/%.o: %.asm $(INCLUDES) build/debug build/debug/data
	rgbasm -DDEBUG=1 -i include/ -v -o $@ $<

build/release/%.o: %.asm $(INCLUDES) build/release build/release/data
	rgbasm -DDEBUG=0 -i include/ -v -o $@ $<

build/debug/rom.gb: $(DEBUGOBJS)
# note padding with 0x40 = ld b, b = BGB breakpoint
	rgblink -n $(@:.gb=.sym) -o $@ -p 0x40 $^
	rgbfix -p 0x40 $(FIXARGS) $@

build/release/rom.gb: $(RELEASEOBJS)
	rgblink -n $(@:.gb=.sym) -o $@ $^
	rgbfix -p 0 $(FIXARGS) $@

build/debug build/release data build/debug/data build/release/data:
	mkdir -p $@

debug: build/debug/rom.gb
	bgb $<

bgb: build/release/rom.gb
	bgb $<

gambatte: build/release/rom.gb
	gambatte_sdl $<

copy: build/release/rom.gb
	copy-rom music-video $<

clean:
	rm -f build/*/*.o build/*/rom.sym build/*/rom.gb tests/*/*.{asm,o,sym,gb} $(GENERATED_ASM)

