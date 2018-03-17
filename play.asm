include "hram.asm"
include "macros.asm"
include "ioregs.asm"


SECTION "Main video update loop", ROM0

; NOTE: These routines are heavily optimised, and inlined for efficiency.
; We make heavy use of one-use macros just as a means of code organization.


; High-level overview of each line:
;	(starting in prev line, or in vblank for first line)
;	prepare new volume pair. save second volume to a reg
;	audio sample switchover occurs. write first volume.
;	write new audio sample pair, check for bank switch, etc
;	prepare regs for palette load, including loading palette group addr
;	hblank begins.
;	perform first half(ish) of palette load, until time for audio sample switchover
;	audio sample switchover occurs. write second volume.
;	perform second half of palette load.
;	hblank critical section over.
;	check if this is the last line, break if so
;	pad total loop time out to 228 cycles
;	loop
;	on break: go into vblank.
;
; High-level overview of vblank, without audio updates:
;	(starting while writing last line of prev frame)
;	load next frame to display
;	h-blank of last line begins (VRAM is writable from here to end of vblank)
;	Write 19 rows (38 * 16 bytes) of tile indexes to background map bank 0 using DMA
;	Write 19 rows (38 * 16 bytes) of tile flags to background map bank 1 using DMA
;	Write scroll values to ScrollX/ScrollY
;	Execute tile data load orders
;	Set up for line loop


; Sets A, B to volumes. Sets (rom bank, HL) to next audio sample pair.
; Expects D = $20-$2f
; Clobbers E.
CYC_PREPARE_VOLUMES EQU 27
PrepareVolumes: MACRO
	; load bank
	ld A, [AudioBank]
	ld [DE], A ; note D is $20 so DE is $2000-$20ff
	; HL = addr
	ld A, [AudioAddr]
	ld H, A
	ld A, [AudioAddr+1]
	ld L, A
	; load second volume first
	ld A, [HL+]
	ld E, A
	and $0f ; select second volume
	ld B, A
	swap A
	or B
	ld B, A ; A = B = second volume, copied to both nibbles
	xor E ; A = (2nd^1st, 2nd^2nd) = (1st^2nd, 0)
	swap A ; A = (0, 1st^2nd)
	xor E ; A = (0^1st, 1st^2nd^2nd) = (1st, 1st)
ENDM

; As PrepareVolumes but doesn't clobber E. Longer.
CYC_PREPARE_VOLUMES_SLOW EQU 30
PrepareVolumesSlow: MACRO
	; load bank
	ld A, [AudioBank]
	ld [DE], A ; load bank
	; HL = addr
	ld A, [AudioAddr]
	ld H, A
	ld A, [AudioAddr+1]
	ld L, A
	; load second volume first
	ld A, [HL]
	and $0f ; select second volume
	ld B, A
	swap A
	or B
	ld B, A ; A = B = second volume, copied to both nibbles
	xor [HL] ; A = (2nd^1st, 2nd^2nd) = (1st^2nd, 0)
	swap A ; A = (0, 1st^2nd)
	xor [HL] ; A = (0^1st, 1st^2nd^2nd) = (1st, 1st)
	inc HL
ENDM


; Expects HL = next audio sample. writes it to wave ram, checks for bank change
; and writes new values back to HRAM.
; For uniqueness, takes an int \1, which needs a matching _UpdateSampleExtra elsewhere.
CYC_UPDATE_SAMPLE EQU 25
UpdateSample: MACRO
	ld A, [HL+] ; A = next sample
	ld [SoundCh3Data], A ; write next sample
	; check if HL >= 8000 by checking top bit of H
	ld A, H
	rla ; put top bit of H into c. ie. c is set if we should advance bank
	jp nc, .no_audio_bank_change_\1
	ld HL, AudioBank
	inc [HL]
	ld A, $40
	ld [AudioAddr], A
	xor A
	ld [AudioAddr+1], A
.after_audio_bank_change_\1
ENDM

; other branch of UpdateSample. Must take 18 cycles including the jumps here and back.
_UpdateSampleExtra: MACRO
.no_audio_bank_change_\1
	ld A, H
	ld [AudioAddr], A
	ld A, L
	ld [AudioAddr+1], A
	Wait 18 - 8 - 8 ; jumps = 8, instructions = 8
	jp .after_audio_bank_change_\1
ENDM


; Sets HL, C for palette copy and loads palette group bank.
; Prepares palette index reg for auto-increment starting at 0.
; Expects SP to point to the address of the next palette group index.
; Expects D = $20.
CYC_PREPARE_PALETTE_COPY EQU 24
PreparePaletteCopy: MACRO
	ld A, %10000000 ; index 0, and auto-increment on write
	ld [TileGridPaletteIndex], A
	ld C, LOW(TileGridPaletteData)
	ld A, [PaletteChangeBank]
	ld [DE], A ; load frame bank
	pop HL ; load palette group addr into HL, point SP to (bank, half of next addr)
	pop AF ; load palette group bank into A, point SP to 1 past next addr
	add SP, -1 ; point SP to next addr
	ld [DE], A ; load palette group bank
ENDM


; entry conditions:
;	cycles until audio switchover: CYC_PREPARE_VOLUMES + 3
;	cycles until "hblank" of LY=153: CYC_PREPARE_VOLUMES + CYC_UPDATE_SAMPLE + CYC_PREPARE_PALETTE_COPY + 3
;       another way of saying it, cycles until end of vblank:
;           105 + CYC_PREPARE_VOLUMES + CYC_UPDATE_SAMPLE + CYC_PREPARE_PALETTE_COPY
;	SP = address of first palette group index in current frame.
;	D = $20-$3f
;	C = LOW(TileGridPaletteData) = $69
;	ROM bank high bit = 1
; upon exit:
;	cycles until audio switchover: 114 - 4*(32-palette_loops) - 8
;		or equivalently, CYC_PREPARE_VOLUMES + line_spare + 6
;	cycles until last hblank that runs into vblank: 228 - (128 + 4 + padding + 8)
; Clobbers *SP*
LineLoop: MACRO
.line_loop
	; Persistent register usage across loops:
	; C = LOW(TileGridPaletteData) so we can write palettes fast
	; D = $20 so that DE is in range $2000-$20ff so we can change banks by writing to it.

	; Sets A, B to first, second volume.
	; Sets HL to current audio data offset + 1 and loads current audio data bank.
	PrepareVolumes

	; Syncronised to audio sample switch, write first volume.
	ld [SoundCh3Volume], A
	; AUDIO SAMPLE SWITCH

	; Writes next audio sample and advances audio data offset, updates bank if needed.
	UpdateSample

	; Sets HL, C for palette copy and loads palette group bank.
	; Prepares palette index reg for auto-increment starting at 0.
	PreparePaletteCopy

	; H-BLANK BEGINS

	; Copy palette bytes until we need to stop for audio switch
cycles = ((114 - CYC_UPDATE_SAMPLE) - CYC_PREPARE_PALETTE_COPY) - 4
	FailIf cycles < 0, "UpdateSample and PreparePaletteCopy too long"
palette_loops = cycles / 4
padding = cycles % 4
PRINTT "cycles: {cycles}, loops: {palette_loops}, padding: {padding}\n"
	Wait padding ; pad so that we end last loop at the right time
	REPT palette_loops
	ld A, [HL+] ; load next byte of palette data and increment
	ld [C], A ; write it to palette data reg and auto-increment
	ENDR

	; Syncronised to audio sample switch, write second volume.
	ld A, B
	ld [SoundCh3Volume], A
	; AUDIO SAMPLE SWITCH

	; Do the other half of the palette bytes copy
	REPT 32 - palette_loops
	ld A, [HL+] ; load next byte of palette data and increment
	ld [C], A ; write it to palette data reg and auto-increment
	ENDR

	; We're done with writing to VRAM, don't care if we're in H-blank anymore.
	; Total time since h-blank begin: 128 + 4 + padding
	; (worst cast 135, H-blank + OAM search is 142)

	; check LY to see if we're about to enter vblank (LY == 143), if so break
	ld A, [LCDYCoordinate]
	cp 143
	jr z, .line_loop_break

	; Loop gets padded out here. It takes into account all the time above + the loop instruction
line_total = CYC_PREPARE_VOLUMES + 3 + CYC_UPDATE_SAMPLE + CYC_PREPARE_PALETTE_COPY + 128 + 4 + padding + 7 + 4
line_spare = 228 - line_total
	PRINTT "Line loop cycles to spare: {line_spare}\n"
	Wait line_spare

	; Loop
	jp .line_loop

.line_loop_break

ENDM


; Load next frame addr into CGBDMASource, along with its bank into E.
; Clears ROM bank high bit and clobbers bank.
; Sets D up for bank loading.
CYC_DETERMINE_FRAME EQU 50
DetermineFrame: MACRO
	ld D, $30
	xor A
	ld [CGBDMASourceLo], A ; need to do this at some point, and A = 0 here anyway
	ld [DE], A ; clear ROM bank high bit
	dec D ; DE now set up for bank loading
	ld A, [FrameListBank]
	ld E, A ; we'll need this later
	ld [DE], A ; load frame list bank
	ld A, [FrameListAddr]
	ld H, A
	ld A, [FrameListAddr + 1]
	ld L, A ; HL = frame list addr
	ld A, [HL+]
	ld E, A ; first byte is bank
	ld A, [HL+]
	ld [CGBDMASourceHi], A ; second byte is address upper byte
	ld A, L
	ld [FrameListAddr+1], A ; store lower part of updated HL
	ld A, H
	rla ; rotate top bit of H into carry, ie. set c if H = $80
	jp nc, .no_frame_list_bank_change
	ld A, $40
	ld [FrameListAddr], A ; write new frame list addr value as $4000
	ld A, E ; load bank from earlier
	inc A
	ld [FrameListBank], A
.after_frame_list_bank_change
ENDM

_DetermineFrameExtra: MACRO
.no_frame_list_bank_change
	ld A, H
	ld [FrameListAddr], A
	Wait 1
	jp .after_frame_list_bank_change
ENDM

; Perform a DMA of \1 * 16 bytes from CGBDMASource to CGBDMADest
; Note: Cycle count doesn't include the 16 * \1 cycles of actual DMA time
CYC_DMA_NO_UPDATE EQU 5
DMA: MACRO
	ld A, (\1) - 1
	ld [CGBDMAControl], A
ENDM


; Entry conditions:
;	cycles until audio switchover: CYC_PREPARE_VOLMUES + line_spare + 6
;	cycles until start of last hblank before vblank: 88 - padding
;	cycles until start of vblank proper: 190 - padding
; upon exit:
;	cycles until audio switchover: CYC_PREPARE_VOLUMES + 3
;	cycles until end of vblank: 105 + CYC_PREPARE_VOLUMES + CYC_UPDATE_SAMPLE + CYC_PREPARE_PALETTE_COPY
VBlank: MACRO

	; Hard to do anything useful in this little time
	Wait line_spare + 3

	; Do audio update and populate B with next volume. Clobbers A, HL, E and rom bank
	PrepareVolumes
	ld [SoundCh3Volume], A ; Finishes at the same time as audio switch (line 144)
	UpdateSample

	; Load next frame addr into CGBDMASource, along with its bank into E.
	; Clears ROM bank high bit and clobbers bank.
	; Sets D up for bank loading.
	DetermineFrame

	; Register assignment for this loop
	; B - next audio volume
	; C - LOW(CGBDMAControl) = $55
	; D - $20, so that [DE] writes ROM bank lower byte
	; E - Frame bank
	; HL - scratch, clobbered by PrepareVolumes.
	;	L is always odd after PrepareVolumes, always even after UpdateSample
	;	H is always in range $40-$7f after either
	;	We set H=$30 between UpdateSample and PrepareVolumes so [HL] writes upper bit of ROM bank

	; Set up initial values not already set by DetermineFrame
	ld C, LOW(CGBDMAControl)
	ld H, $30
	ld A, E
	ld [DE], A ; load frame bank
	xor A
	ld [CGBVRAMBank], A ; load vram bank 0
	ld [CGBDMADestHi], A
	ld [CGBDMADestLo], A ; Dest = 0, which means $8000 as top 3 bits ignored
	; We need to do a total of 38 16-byte blocks of DMA for this first half.

	; Pad to 4 cycles before audio switch
	Wait (((114 - CYC_UPDATE_SAMPLE) - 4) - CYC_DETERMINE_FRAME) - 17

	; Some calculations for this loop TODO update
	dma_cycles_before_sound = 114 - (CYC_PREPARE_VOLUMES_SLOW + 5 + 3) ; 5 for setting high bit, 3 for volume update
	dma_cycles_between_sound = 114 - (CYC_UPDATE_SAMPLE + 7) ; 7 for resetting rom bank

	dma_blocks_before_sound = (dma_cycles_before_sound - CYC_DMA) / 16
	dma_blocks_between_sound = (dma_cycles_before_sound - CYC_DMA) / 16

	dma_padding_before_sound = (dma_cycles_before_sound - CYC_DMA) % 16
	dma_padding_between_sound = (dma_cycles_before_sound - CYC_DMA) % 16

	ld A, B
	ld [SoundCh3Volume], A ; Finishes at same time as audio switch (line 144.5)

	DMA dma_blocks_before_sound
	Wait dma_padding_before_sound

	; Do audio update and populate B with next volume. Clobbers A, HL, rom bank and rom bank high bit
	ld [HL], C ; C's bottom bit is set, so this sets rom bank high bit
	PrepareVolumesSlow
	ld [SoundCh3Volume], A ; Finishes at the same time as audio switch (line 145)
	UpdateSample

	; Now we set bank back
	ld H, $30
	ld [HL], A ; A will always be 0 here as its used to set new low value of AudioAddr, so reset rom bank high bit.
	ld A, E
	ld [DE], A ; load frame bank

	DMA dma_blocks_between_sound
	Wait dma_padding_between_sound


ENDM


Play::
	; TODO
	LineLoop

	_UpdateSampleExtra

