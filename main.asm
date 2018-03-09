include "ioregs.asm"


SECTION "Main methods", ROM0

Start::
	; On startup, immediately disable sound and video while we init
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	jp HaltForever
