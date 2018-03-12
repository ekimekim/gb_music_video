IF !DEF(_G_HRAM)
_G_HRAM EQU "true"

RSSET $ff80

; Current audio sample bank
AudioBank rb 1
; Current audio sample address (within banked ROM, so $4000-$8000), big-endian.
AudioAddr rb 2

ENDC
