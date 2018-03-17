IF !DEF(_G_HRAM)
_G_HRAM EQU "true"

RSSET $ff80

; Current audio sample bank
AudioBank rb 1
; Current audio sample address (within banked ROM, so $4000-$8000).
; TODO Endianness is whichever makes "pop HL" work when SP = AudioAddr.
; TODO if little, don't forget to update usage.
AudioAddr rb 2

; Bank containing the palette change list for the current frame
PaletteChangeBank rb 1

; High byte of starting address for palette change list for current frame
PaletteChangeAddr rb 1

; Bank containing the palette group for the frame-wide palette
PaletteGroupBank rb 1

; Current frame list bank
FrameListBank rb 1
; Current frame list address (within banked ROM)
FrameListAddr rb 2

ENDC
