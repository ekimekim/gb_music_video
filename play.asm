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

; As PrepareVolumes but expects SP = AudioAddr and returns SP = AudioAddr+2. 
CYC_PREPARE_VOLUMES_TRANSITION EQU 22
PrepareVolumesTransition: MACRO
	; load bank
	ld A, [AudioBank]
	ld [DE], A ; note D is $20 so DE is $2000-$20ff
	; HL = addr
	pop HL
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

; As PrepareVolumes but clobbers D instead. Uses SP,
; and expects SP = AudioAddr. Expects H = $2f. Expects C odd.
CYC_PREPARE_VOLUMES_VBLANK EQU 25
PrepareVolumesVBlank: MACRO
	; load bank
	ld A, [AudioBank]
	ld [HL], A ; load bank
	inc H ; now HL sets rom bank high bit
	ld [HL], C ; C's bottom bit is set, so this sets rom bank high bit
	; HL = addr and SP = AudioAddr+2
	pop HL
	; load second volume first
	ld A, [HL+]
	ld D, A
	and $0f ; select second volume
	ld B, A
	swap A
	or B
	ld B, A ; A = B = second volume, copied to both nibbles
	xor D ; A = (2nd^1st, 2nd^2nd) = (1st^2nd, 0)
	swap A ; A = (0, 1st^2nd)
	xor D ; A = (0^1st, 1st^2nd^2nd) = (1st, 1st)
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

; Variant of UpdateSample that expects SP = AudioAddr+2 and resets to to AudioAddr.
CYC_UPDATE_SAMPLE_VBLANK EQU 22
UpdateSampleVBlank: MACRO
	ld A, [HL+] ; A = next sample
	ld [SoundCh3Data], A ; write next sample
	; check if HL >= 8000 by checking top bit of H
	ld A, H
	rla ; put top bit of H into c. ie. c is set if we should advance bank
	jp nc, .no_audio_bank_change_\1
	ld H, $40
	push HL
	ld HL, AudioBank
	inc [HL]
.after_audio_bank_change_\1
ENDM
; other branch of UpdateSampleVBlank. Must take 15 cycles including the jumps here and back.
_UpdateSampleVBlankExtra: MACRO
.no_audio_bank_change_\1
	push HL
	Wait 15 - 8 - 4 ; jumps = 8, instructions = 4
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
	ld [DE], A ; load palette change bank
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
	UpdateSample $1

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
; Sets PaletteChangeBank and PaletteChangeAddr.
; Can't clobber B. Clobbers C.
CYC_DETERMINE_FRAME EQU 60
DetermineFrame: MACRO
	ld D, $30
	xor A
	ld [CGBDMASourceLo], A ; need to do this at some point, and A = 0 here anyway
	ld [DE], A ; clear ROM bank high bit
	dec D ; DE now set up for bank loading
	ld A, [FrameListBank]
	ld C, A ; we'll need this later
	ld [DE], A ; load frame list bank
	ld A, [FrameListAddr]
	ld H, A
	ld A, [FrameListAddr + 1]
	ld L, A ; HL = frame list addr
	ld A, [HL+]
	ld E, A ; first byte is bank
	ld A, [HL+]
	ld [CGBDMASourceHi], A ; second byte is address upper byte
	ld A, [HL+]
	ld [PaletteChangeBank], A ; third byte is palette change list bank
	ld A, [HL+]
	ld [PaletteChangeAddr], A ; fourth byte is palette change list addr upper
	ld A, L
	ld [FrameListAddr+1], A ; store lower part of updated HL
	ld A, H
	rla ; rotate top bit of H into carry, ie. set c if H = $80
	jp nc, .no_frame_list_bank_change
	ld A, $40
	ld [FrameListAddr], A ; write new frame list addr value as $4000
	ld A, C ; load bank from earlier
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
CYC_DMA EQU 4
DMA: MACRO
	ld A, (\1) - 1
	ld [C], A
ENDM


; Set scroll values for frame, loads palette group bank into PaletteChangeBank (and loads it),
; sets top bit of rom bank, sets HL to address of first palette,
; sets up palette data to write palettes 4-7, sets D to 20-2f so DE writes rom bank.
CYC_LOAD_FRAME_MISC EQU 0 ; TODO
LoadFrameMisc: MACRO
	; TODO
ENDM


; Entry conditions:
;	cycles until audio switchover: CYC_PREPARE_VOLMUES + line_spare + 6
;	cycles until start of last hblank before vblank: 88 - padding
;	cycles until start of vblank proper: 190 - padding
;	D = $20-$2f
; upon exit:
;	cycles until audio switchover: CYC_PREPARE_VOLUMES + 3
;	cycles until end of vblank: 105 + CYC_PREPARE_VOLUMES + CYC_UPDATE_SAMPLE + CYC_PREPARE_PALETTE_COPY
VBlank: MACRO

	ld SP, AudioAddr
	; 3 for audio switch. 3 for ld SP above.
vblank_start_padding = CYC_PREPARE_VOLUMES + line_spare + 6 - (CYC_PREPARE_VOLUMES_TRANSITION + 3 + 3)
	Wait vblank_start_padding

	; Do audio update and populate B with next volume. Clobbers A, HL, E and rom bank
	PrepareVolumesTransition
	ld [SoundCh3Volume], A ; Finishes at the same time as audio switch (line 144)
	UpdateSampleVBlank $2

	; Load next frame addr into CGBDMASource, along with its bank into E.
	; Clears ROM bank high bit and clobbers bank.
	; Sets D up for bank loading.
	; Can't clobber B.
	DetermineFrame

	; Register assignment for this loop
	; B - next audio volume
	; C - LOW(CGBDMAControl) = $55
	; D - scratch, clobbered by PrepareVolumes.
	; E - Frame bank
	; HL - scratch, clobbered by PrepareVolumes.
	;	L is always odd after PrepareVolumes, always even after UpdateSample
	;	H is always in range $40-$7f after either
	;	We set H=$30/$2f between UpdateSample and PrepareVolumes so [HL] writes upper bit / lower byte of rom bank

	; Set up initial values not already set by DetermineFrame
	ld C, LOW(CGBDMAControl)
	ld H, $2f
	ld [HL], E ; load frame bank
	xor A
	ld [CGBVRAMBank], A ; load vram bank 0
	ld [CGBDMADestLo], A
	ld A, $98
	ld [CGBDMADestHi], A ; Dest = $9800
	; We need to do a total of 38 16-byte blocks of DMA for this first half.

	; Pad to 4 cycles before audio switch
	; NOTE: if in final version we can drop above costs so this wait is 18c, then rearrange above
	; so A = 0 as final value, then we can DMA 1 here.
vblank_into_loop_padding = (((114 - CYC_UPDATE_SAMPLE_VBLANK) - 4) - CYC_DETERMINE_FRAME) - 20 ; 20 is for initial values setup
	Wait vblank_into_loop_padding
	PRINTT "Padding for {vblank_into_loop_padding} before loop. If this is >=$12, we can fit a DMA here.\n"

	; Some calculations for this loop
dma_cycles_before_sound = 114 - (CYC_PREPARE_VOLUMES_VBLANK + 3) ; 3 for volume update
dma_cycles_between_sound = 114 - (CYC_UPDATE_SAMPLE_VBLANK + 7) ; 7 for resetting rom bank

dma_blocks_before_sound = (dma_cycles_before_sound - CYC_DMA) / 16
dma_blocks_between_sound = (dma_cycles_between_sound - CYC_DMA) / 16

dma_padding_before_sound = (dma_cycles_before_sound - CYC_DMA) % 16
dma_padding_between_sound = (dma_cycles_between_sound - CYC_DMA) % 16

	PRINTT "before: {dma_blocks_before_sound} with {dma_padding_before_sound} padding\n"
	PRINTT "between: {dma_blocks_between_sound} with {dma_padding_between_sound} padding\n"

	; Make values concrete because easier
IF dma_blocks_before_sound != 5 || dma_blocks_between_sound != 5
	FAIL "Must fit 5 blocks of dma per half"
ENDC

	; For lines 144.5-147
n = 2
	REPT 3
n = n + 1

	ld A, B
	ld [SoundCh3Volume], A ; Finishes at same time as audio switch (line 144 + loop+.5)

	DMA 5
	Wait dma_padding_before_sound

	; Do audio update and populate B with next volume. Clobbers A, HL, rom bank and rom bank high bit
	PrepareVolumesVBlank
	ld [SoundCh3Volume], A ; Finishes at the same time as audio switch (line 144 + loop+1)
	UpdateSampleVBlank {n}

	; Now we set bank back
	ld H, $30
	ld [HL], A ; A will always be 0 here as its used to set new low value of AudioAddr, so reset rom bank high bit.
	dec H ; now HL is pointed to set bank
	ld [HL], E ; load frame bank

	DMA 5
	Wait dma_padding_between_sound

	ENDR
	; Now 30 blocks copied

	ld A, B
	ld [SoundCh3Volume], A ; Finishes at same time as audio switch (line 147.5)

	DMA 5 ; 35 blocks copied
	Wait dma_padding_before_sound

	; Do audio update and populate B with next volume. Clobbers A, HL, rom bank and rom bank high bit
	PrepareVolumesVBlank
	ld [SoundCh3Volume], A ; Finishes at the same time as audio switch (line 148)
	UpdateSampleVBlank $6

	; Now we set bank back
	ld H, $30
	ld [HL], A ; A will always be 0 here as its used to set new low value of AudioAddr, so reset rom bank high bit.
	dec H ; now HL is pointed to set bank
	ld [HL], E ; load frame bank

	DMA 3 ; 38 blocks copied. Now we need to switch to other VRAM bank, reset dest and copy next 38.
	; Note the above sets A = 2
	dec A ; A = 1
	ld [CGBVRAMBank], A ; load VRAM bank 1
	ld A, $98
	ld [CGBDMADestHi], A
	xor A
	ld [CGBDMADestLo], A ; Dest = $9800
	DMA 1 ; 1 block copied. 37 to go.

	; We only copied 4 blocks, so add 16 to available time. But we have two DMA overheads.
	Wait dma_padding_between_sound + 16 - (CYC_DMA + 13)

	; For lines 148.5-151
n = 6
	REPT 3
n = n + 1

	ld A, B
	ld [SoundCh3Volume], A ; Finishes at same time as audio switch (line 148 + loop+.5)

	DMA 5
	Wait dma_padding_before_sound

	; Do audio update and populate B with next volume. Clobbers A, HL, rom bank and rom bank high bit
	PrepareVolumesVBlank
	ld [SoundCh3Volume], A ; Finishes at the same time as audio switch (line 148 + loop+1)
	UpdateSampleVBlank {n}

	; Now we set bank back
	ld H, $30
	ld [HL], A ; A will always be 0 here as its used to set new low value of AudioAddr, so reset rom bank high bit.
	dec H ; now HL is pointed to set bank
	ld [HL], E ; load frame bank

	DMA 5
	Wait dma_padding_between_sound

	ENDR
	; Now 31 blocks copied.

	ld A, B
	ld [SoundCh3Volume], A ; Finishes at same time as audio switch (line 151.5)

	DMA 5 ; 36 blocks copied
	Wait dma_padding_before_sound

	; Do audio update and populate B with next volume. Clobbers A, HL, rom bank and rom bank high bit
	PrepareVolumesVBlank
	ld [SoundCh3Volume], A ; Finishes at the same time as audio switch (line 152)
	UpdateSampleVBlank $A

	; Now we set bank back
	ld H, $30
	ld [HL], A ; A will always be 0 here as its used to set new low value of AudioAddr, so reset rom bank high bit.
	dec H ; now HL is pointed to set bank
	ld [HL], E ; load frame bank

	DMA 2 ; 38 blocks copied.

	; Set scroll values for frame, loads palette group bank into PaletteGroupBank (and loads it),
	; sets top bit of rom bank, sets HL to address of first palette,
	; sets up palette data to write palettes 4-7, sets D to 20-2f so DE writes rom bank.
	LoadFrameMisc
	; Note we now switch back to line loop versions of audio macros

	; 16*2 for two blocks
	Wait dma_cycles_between_sound + (- (16 * 2 + CYC_DMA + CYC_LOAD_FRAME_MISC))

	ld A, B
	ld [SoundCh3Volume], A ; Finishes at same time as audio switch (line 152.5)

	; 3 for volume update, 2 for saving HL, 2 for setting C.
vblank_palette_copy_cycles = 114 - (CYC_PREPARE_VOLUMES + 3 + 2 + 2)
vblank_palette_loops = vblank_palette_copy_cycles / 4
vblank_palette_padding = vblank_palette_copy_cycles % 4

	PRINTT "VBlank palette loop: {vblank_palette_loops} + {vblank_palette_padding} padding\n"

	ld C, LOW(TileGridPaletteData)

	REPT vblank_palette_loops
	ld A, [HL+] ; load next byte of palette data and increment
	ld [C], A ; write it to palette data reg and auto-increment
	ENDR

	ld SP, HL ; save HL

	Wait vblank_palette_padding

	; Do audio update and populate B with next volume. Clobbers A, HL, rom bank and E.
	PrepareVolumes
	ld [SoundCh3Volume], A ; Finishes at same time as audio switch (line 153)
	UpdateSample $B

	ld HL, SP+0 ; load HL
	ld A, [PaletteGroupBank]
	ld [DE], A ; load palette group bank

	REPT 32 - vblank_palette_loops
	ld A, [HL+] ; load next byte of palette data and increment
	ld [C], A ; write it to palette data reg and auto-increment
	ENDR

	; Final prep for line loop
	ld A, [PaletteChangeAddr]
	ld H, A
	xor A
	ld L, A
	ld SP, HL

	; 8 before palette loops, 4 per loop, 8 after palette loops
vblank_end_padding = 114 - (CYC_UPDATE_SAMPLE + 8 + 4 * (32 - vblank_palette_loops) + 8)
	PRINTT "VBlank end padding: {vblank_end_padding}\n"

	ld A, B
	ld [SoundCh3Volume], A ; Finishes at same time as audio switch (line 153.5)

	; wait until the timing for starting line loop is right, including 4 for outside loop.
	Wait 114 - (CYC_PREPARE_VOLUMES + 3 + 4)

ENDM


Play::
	jp .start
.frame_loop
	LineLoop
.start
	VBlank
	jp .frame_loop

	_UpdateSampleExtra $1
n = 1
	REPT 9
n = n + 1
	_UpdateSampleVBlankExtra {n}
	ENDR
	_UpdateSampleExtra $B
	_DetermineFrameExtra
