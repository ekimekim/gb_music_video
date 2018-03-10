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

	; Set volume to both channels
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
	ld A, $ff
	REPT 16
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

	; At 2048Hz (1024 cycles), modulate volume up/down
	ld C, LOW(SoundVolume)
	ld B, $ff
.loop3
	ld D, 16
.loop2
	ld E, 0
.loop
	ld A, $00
	ld [C], A
	REPT 508
	nop
	ENDR
	ld A, $77
	ld [C], A
	REPT 503
	nop
	ENDR
	dec E
	jp nz, .loop
	dec D
	jp nz, .loop2

	ld HL, SoundCh3Control
	res 7, [HL]

	ld A, B
	sub $11
	jr c, .break

	ld B, A
	ld HL, SoundCh3Data
	REPT 16
	ld [HL+], A
	ENDR

	ld HL, SoundCh3Control
	set 7, [HL]

	jp .loop3

.break
	jp HaltForever
