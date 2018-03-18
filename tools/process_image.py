
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

PALETTES_BY_ROW = [
	["back"],
	["back"],
	["back"],
	["cha_head", "back"],
	["back", "cha_head", "sey_head"],
	["back", "sey_head", "cha_head"],
	["back", "sey_head", "cha_head"],
	["back", "sey_head", "cha_head"],
	["cha_neck", "back", "sey_neck", "sey_head"],
	["chair_cloth", "back", "table_edge", "glass", "sey_neck"],
	["back", "chair_cloth", "table_edge", "sey_neck"],
	["chair_cloth", "table_edge", "glass", "hand", "sey_neck"],
	["chair_cloth", "table_edge", "back", "hand", "table_top"],
	["chair_cloth", "table_edge", "glass_bottom"],
	["chair_cloth", "table_edge", "glass_bottom"],
	["chair_cloth"],
	["chair_cloth"],
	["chair_cloth"],
]

def main():
	image = Image.open('hams.png').convert('RGB')

	tex = []
	for row, palettes in enumerate(PALETTES_BY_ROW):
		row_tex = []
		for col in range(20):
			tile = get_tile(image, row, col)
			for palette in palettes:
				try:
					texture = to_texture(tile, palette)
				except ValueError:
					pass
				else:
					break
			else:
				raise ValueError("Tile at {},{} has no matching palette out of {}: {}".format(row, col, palettes, tile))
			row_tex.append((texture, palette))
		tex.append(row_tex)

	print tex


def get_tile(image, row, col):
	return [
		[image.getpixel((y, x)) for y in range(col * 8, (col+1) * 8)]
	for x in range(row * 8, (row+1) * 8)]


def to_texture(tile, palette):
	palette = PALETTES[palette]
	palette = [COLORS[color] for color in palette]
	return [
		[palette.index(px) for px in row]
	for row in tile]


if __name__ == '__main__':
	main()
