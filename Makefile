
# avoid implicit rules for clarity
.SUFFIXES: .asm .o .gb
.PHONY: bgb clean tests testroms debug

GENERATED_ASM := audio_data.asm
ASMS := $(wildcard *.asm) $(GENERATED_ASM)
OBJS := $(ASMS:.asm=.o)
DEBUGOBJS := $(addprefix build/debug/,$(OBJS))
RELEASEOBJS := $(addprefix build/release/,$(OBJS))
INCLUDES := $(wildcard include/*.asm)
TESTS := $(wildcard tests/*.py)
AUDIO := music.mp3

FIXARGS := -v -C -m 0x1a 

all: build/release/rom.gb tests/.uptodate

tests/.uptodate: $(TESTS) tools/unit_test_gen.py $(DEBUGOBJS)
	python tools/unit_test_gen.py .
	touch "$@"

testroms: tests/.uptodate

tests: testroms
	./runtests

audio_data.asm: tools/process_audio tools/quantize_audio.py $(AUDIO)
	tools/process_audio $(AUDIO)

build/debug/%.o: %.asm $(INCLUDES) build/debug
	rgbasm -DDEBUG=1 -i include/ -v -o $@ $<

build/release/%.o: %.asm $(INCLUDES) build/release
	rgbasm -DDEBUG=0 -i include/ -v -o $@ $<

build/debug/rom.gb: $(DEBUGOBJS)
# note padding with 0x40 = ld b, b = BGB breakpoint
	rgblink -n $(@:.gb=.sym) -o $@ -p 0x40 $^
	rgbfix -p 0x40 $(FIXARGS) $@

build/release/rom.gb: $(RELEASEOBJS)
	rgblink -n $(@:.gb=.sym) -o $@ $^
	rgbfix -p 0 $(FIXARGS) $@

build/debug build/release:
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

