IF !DEF(_G_MACROS)
_G_MACROS EQU "true"


; Copy BC bytes (non-zero) from [HL] to [DE]. Clobbers A.
LongCopy: MACRO
	; adjust for an off-by-one issue in the outer loop exit condition, unless ALSO affected
	; by an error in the inner loop exit condition that adds an extra round when C = 0
	xor A
	cp C
	jr z, .loop\@
	inc B
.loop\@
	ld A, [HL+]
	ld [DE], A
	inc DE
	dec C
	jr nz, .loop\@
	dec B
	jr nz, .loop\@
	ENDM

; Copy B bytes (non-zero) from [HL] to [DE]. Clobbers A.
Copy: MACRO
.loop\@
	ld A, [HL+]
	ld [DE], A
	inc DE
	dec B
	jr nz, .loop\@
	ENDM

; Shift unsigned \1 to the right \2 times, effectively dividing by 2^N
ShiftRN: MACRO
	IF (\2) >= 4
	swap \1
	and $0f
	N SET (\2) + (-4)
	ELSE
	N SET \2
	ENDC
	REPT N
	srl \1
	ENDR
	PURGE N
	ENDM

; More efficient (for N > 1) version of ShiftRN for reg A only.
; Shifts A right \1 times.
ShiftRN_A: MACRO
	IF (\1) >= 4
	swap A
	N SET (\1) + (-4)
	ELSE
	N SET (\1)
	ENDC
	REPT N
	rra ; note this is a rotate, hence the AND below
	ENDR
	and $ff >> (\1)
	ENDM

; Halts compilation if condition \1 is true with message \2
FailIf: MACRO
IF (\1)
FAIL (\2)
ENDC
ENDM

; Wait for \1 cycles (nops)
; Note that in some cases you may want to use a higher-density (cycles/space) instruction,
; but you need to pick one with side-effects you are ok with.
; push/pop pairs are a good one that average 7 cycles per 2 bytes, but has side effects if SP
; is not a valid stack.
Wait: MACRO
REPT (\1)
	nop
ENDR
ENDM

; Wait for \1 cycles by looping. Takes much, much less space than Wait, but clobbers A and F.
WaitLong: MACRO
; a full 256-loop is 256*4+1-1 = 1024 cycles
REPT (\1) / 1024
	xor A
.loop\@
	dec A
	jr z, .loop\@
ENDR
; a partial loop is 4*n+2-1 cycles, min 5
_remainder = (\1) % 1024
IF _remainder >= 5
	ld A, (_remainder - 1) / 4
.r_loop\@
	dec A
	jr z, .r_loop\@
	Wait (_remainder + (-1)) % 4
ELSE
	Wait _remainder
ENDC
ENDM

ENDC
