IF !DEF(_G_FRAME)
_G_FRAME EQU "true"

RSRESET

; note frame is ALIGN[8]

frame_tiles rb 32 * 19
frame_flags rb 32 * 19
frame_line_palettes rb 4 * 114
frame_palette rb 2
frame_scroll rb 1
frame_load_order_len rb 1
frame_load_orders rb 25 * LOAD_ORDER_SIZE
frame_padding_2 rb 0
FRAME_SIZE rb 2048

RSRESET

load_order_source rb 2
load_order_dest_bank rb 1
load_order_dest_index rb 2
load_order_length rb 1
LOAD_ORDER_SIZE rb 0

ENDC
