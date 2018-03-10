include "ioregs.asm"


SECTION "Main methods", ROM0

Start::
	; On startup, immediately disable sound and video while we init
	xor A
	ld [SoundControl], A
	ld [LCDControl], A


	; test: play square wave at volume 0. is it silent?

	; enable sound
	ld A, %10000000
	ld [SoundControl], A

	; Set volume to 7 both channels
	ld A, $77
	ld [SoundVolume], A

	; Set channels: 3 only, to both
	ld A, %01000100
	ld [SoundMux], A

	; Turn on Ch3
	ld A, %10000000
	ld [SoundCh3OnOff], A

	; Set wave data to square wave
	ld HL, SoundCh3Data
	REPT 8
	xor A
	ld [HL+], A
	ld A, $ff
	ld [HL+], A
	ENDR

	; Ch3 volume, which is a basic shift of channel values...I think. Full for now.
	ld A, %00100000
	ld [SoundCh3Volume], A

	; Set frequency. We want 18396Hz so we set freq = 2^20/57. To get 57, we do 2048-57 = 1991.
	ld A, LOW(1991)
	ld [SoundCh3FreqLo], A
	ld A, HIGH(1991) | %10000000 ; flag to start playing
	ld [SoundCh3Control], A

	jp HaltForever
