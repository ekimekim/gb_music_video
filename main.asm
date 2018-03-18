include "ioregs.asm"
include "hram.asm"
include "debug.asm"
include "banks.asm"


SECTION "Stack", WRAM0

	ds 32
Stack:


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

	ld SP, Stack

	call LoadTiles
	call InitSound
	call InitHRAM

	jp Play ; does not return


InitSound::
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

	; Set freqency. We want 18396Hz so we set freq = 2^21/114. To get 114, we do 2048-114 = 1934.
	ld A, LOW(1934)
	ld [SoundCh3FreqLo], A
	ld A, HIGH(1934)
	ld [SoundCh3Control], A ; note we aren't actually beginning playback yet - do that later by setting bit 7

	ret


LoadTiles:
	xor A
	ld [CGBVRAMBank], A ; vram bank 0

	ld A, BANK_TEXTURES
	ld [$2000], A ; load tile data bank

	xor A
	ld [CGBDMASourceLo], A
	ld [CGBDMADestLo], A
	ld A, $40
	ld [CGBDMASourceHi], A ; source = $4000
	ld A, $80
	ld [CGBDMADestHi], A ; dest = $8000
	ld A, 127
	ld [CGBDMAControl], A
	ld [CGBDMAControl], A ; general DMA for 256 blocks = entire tile data section

	ld A, 1
	ld [CGBVRAMBank], A ; vram bank 1
	xor A
	ld [CGBDMADestLo], A
	ld A, $80
	ld [CGBDMADestHi], A ; dest = $8000
	; note source is unchanged, we keep going from where we left off
	ld A, 127
	ld [CGBDMAControl], A
	ld [CGBDMAControl], A ; general DMA for 256 blocks = entire tile data section

	ret


InitHRAM:
	ld A, LOW(BANK_AUDIO)
	ld [AudioBank], A
	ld A, BANK_FRAME_LIST
	ld [FrameListBank], A
	ld A, $40
	ld [AudioAddr+1], A
	ld [FrameListAddr], A
	xor A
	ld [AudioAddr], A ; Addr = $4000
	ld [FrameListAddr+1], A ; Addr = $4000
	ret
