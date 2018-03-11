include "ioregs.asm"
include "debug.asm"


SECTION "Main methods", ROM0

Start::
	; On startup, immediately disable sound and video while we init
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	; Switch to double-speed mode
	ld A, 1
	ld [CGBSpeedSwitch], A
	stop

	; test: play square wave at volume 0. is it silent?

	; enable sound
	ld A, %10000000
	ld [SoundControl], A

	; Set channels: 3 only, to both
	ld A, %01000100
	ld [SoundMux], A

	; Turn on Ch3
	ld A, %10000000
	ld [SoundCh3OnOff], A

	; set ch3 to no shift of samples
	ld A, %00100000
	ld [SoundCh3Volume], A

	; We need to load the next sample pair every 228 cycles and update volume every 114.
	; We alternate "long" updates where we add a sample pair and "short" ones where we don't.

	ld C, LOW(SoundCh3Data) ; sample pair index
	ld HL, $4000 ; addr within bank
	ld B, 1 ; bank

	; pre-load first pair of volumes
	ld A, [HL]
	and $f0
	ld D, A
	ld A, [HL+]
	and $0f
	ld E, A
	swap A
	or E
	ld E, A
	ld A, D
	swap A
	or D
	ld D, A

	; Set freqency. We want 18396Hz so we set freq = 2^20/57. To get 57, we do 2048-57 = 1991.
	ld A, LOW(1991)
	ld [SoundCh3FreqLo], A
	ld A, HIGH(1991) | %10000000 ; flag to start playing
	; Time starts when we write to control register.
	ld [SoundCh3Control], A

Wait: MACRO
	REPT \1
	nop
	ENDR
ENDM

.loop
	ld A, D
	ld [SoundVolume], A ; next volume
	ld A, [HL+] ; next pair of samples
	ld [C], A ; write samples

	Wait 114 - 8 ; 8 from above

	; short update
	ld A, E
	ld [SoundVolume], A ; next volume

	Wait 114 - 4 - 46 ; 4 from above, 46 from below inc loop

	; wrap bounds on C by setting upper nibble to 3 (range is 30-3f)
	ld A, C
	and $0f
	or $30 ; set upper nibble to 3

	; check bounds on HL and inc bank
	ld A, H
	; check if top bit is set (ie. HL >= 8000)
	rla ; puts top bit into c
	jr nc, .no_newbank
	ld HL, $4000
	ld A, B
	inc A

	cp 198 ; final bank is 197
	jr z, .end_audio

	ld B, A
	ld [$2000], A ; switch bank
	jr .newbank_end
.no_newbank
	Wait 15
.newbank_end

	; Load new volume pair
	ld A, [HL] ; A = 0xxx0yyy where x is first entry
	and $f0
	ld D, A ; D = first entry, unprocessed
	ld A, [HL+] ; load a fresh copy
	and $0f
	ld E, A ; E = 00000yyy
	swap A
	or E
	ld E, A ; A = 0yyy0yyy
	ld A, D
	swap A
	or D
	ld D, A ; D = 0xxx0xxx

	jp .loop

.end_audio
	xor A
	ld [SoundControl], A ; turn off sound
	jp HaltForever
