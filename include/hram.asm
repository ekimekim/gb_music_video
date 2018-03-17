IF !DEF(_G_HRAM)
_G_HRAM EQU "true"

RSSET $ff80

; Current audio sample bank
AudioBank rb 1
; Current audio sample address (within banked ROM, so $4000-$8000).
; TODO Endianness is whichever makes "pop HL" work when SP = AudioAddr.
AudioAddr rb 2

; Bank containing the palette change list for the current frame
PaletteChangeBank rb 1

ENDC
