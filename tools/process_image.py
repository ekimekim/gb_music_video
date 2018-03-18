
from PIL import Image

COLORS = {
	"black": (34, 32, 52),
	"grey": (155, 173, 183),
	"purple": (118, 66, 138),
	"brown": (102, 57, 49),
	"cyan": (95, 205, 228),
	"yellow": (251, 242, 54),
	"white": (255, 255, 255),
	"blue": (91, 110, 225),
	"pink": (215, 123, 186),
}

PALETTES = {
	"back": ("black", "grey", "purple", "cyan"),
	"cha_head": ("black", "grey", "yellow", "cyan"),
	"sey_head": ("black", "purple", "yellow", "white"),
	"cha_neck": ("black", "grey", "blue", "yellow"),
	"sey_neck": ("black", "purple", "blue", "pink"),
	"glass": ("black", "purple", "cyan", "white"),
	"table_edge": ("black", "grey", "blue", "cyan"),
	"hand": ("black", "grey", "purple", "yellow"),
	"table_top": ("black", "grey", "purple", "blue"),
	"chair_cloth": ("black", "brown", "blue", "white"),
	"glass_bottom": ("black", "grey", "cyan", "white"),
}

FRAME_PALETTES = ["back", "chair_cloth", "table_edge", "back"]

PALETTES_BY_ROW = [
	[],
	[],
	[],
	["cha_head"],
	["cha_head", "sey_head"],
	["sey_head", "cha_head"],
	["sey_head", "cha_head"],
	["sey_head", "cha_head"],
	["cha_neck", "sey_neck", "sey_head"],
	["glass", "sey_neck"],
	["sey_neck"],
	["glass", "hand", "sey_neck"],
	["hand", "table_top"],
	["glass_bottom"],
	["glass_bottom"],
	[],
	[],
	[],
]
PALETTES_BY_ROW = [
	pg + ["back"] * (4 - len(pg))
	for pg in PALETTES_BY_ROW
]


def main():
	image = Image.open('hams.png').convert('RGB')

	tex = []
	for row, palettes in enumerate(PALETTES_BY_ROW):
		row_tex = []
		for col in range(20):
			tile = get_tile(image, row, col)
			
			for i, palette in enumerate(palettes + FRAME_PALETTES):
				try:
					texture = to_texture(tile, palette)
				except ValueError:
					pass
				else:
					pnum = i
					break
			else:
				raise ValueError("Tile at {},{} has no matching palette out of {}: {}".format(row, col, palettes, tile))
			row_tex.append((texture, pnum))
		row_tex.append(row_tex[-1])
		tex.append(row_tex)
	tex.append(tex[-1])

	frame = {
		'tiles': [
			[
				(r * 21 + c, False, False, p)
			for c, (t, p) in enumerate(row)]
		for r, row in enumerate(tex)],
		'scroll': (0, 0),
		'pg': 0,
	}
	palette_groups = [map(resolve, FRAME_PALETTES)] + [map(resolve, pg) for pg in PALETTES_BY_ROW]
	textures = [t for row in tex for t, p in row]
	palette_changes = [r + 1 for r in range(18) for x in range(8)]
	static_palette = resolve("back")
	frame_order = [0] * (2 * 3600 + 43 * 60)
	return palette_groups, textures, palette_changes, [frame], frame_order, static_palette


def get_tile(image, row, col):
	return [
		[image.getpixel((y, x)) for y in range(col * 8, (col+1) * 8)]
	for x in range(row * 8, (row+1) * 8)]


def resolve(palette):
	return [COLORS[color] for color in PALETTES[palette]]


def to_texture(tile, palette):
	palette = resolve(palette)
	return [
		[palette.index(px) for px in row]
	for row in tile]


if __name__ == '__main__':
	main()
