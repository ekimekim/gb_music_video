
import math


ceil = lambda x: int(math.ceil(x))


def values_to_asm(section, first_bank, values):
	lines = []
	for i, v in enumerate(values):
		if i % 2**14 == 0:
			bank = i / 2**14
			lines.append('SECTION "{} {}", ROMX, BANK[{}]'.format(section, bank, first_bank + bank))
		lines.append("\tdb {}".format(v))
	return '\n'.join(lines) + '\n'


def write_asm(filename, items, first_bank, encode, *args, **kwargs):
	terminator = kwargs.pop('terminator', [])
	if kwargs:
		raise TypeError("unexpected kwargs")
	values = [encode(item, *args) for item in items]
	values = sum(values, []) # flatten
	values += terminator
	values = values_to_asm(filename, first_bank, values)
	with open("data/{}.asm".format(filename), 'w') as f:
		f.write(values)


def index_to_bank_addr(base_bank, size, index):
	return base_bank + (size * index) / 0x4000, 0x4000 + (size * index) % 0x4000


def pad(items, size):
	return items + [0] * (size - len(items))


def main():
	palette_groups, textures, palette_changes, frames, frame_order = get_video_data()

	# determine banks
	pg_banks = ceil(len(palette_groups) / 512.)
	pc_banks = ceil(len(palette_changes) / 32.)
	frame_banks = ceil(len(frames) / 8.)
	frame_order_banks = ceil(len(frame_order) / 4096.)

	texture_bank = 1
	frame_order_bank = texture_bank + 1
	frame_bank = frame_order_bank + frame_order_banks
	assert frame_bank + frame_banks <= 256

	pg_bank = 256
	pc_bank = pg_bank + pg_banks
	audio_bank = pc_bank + pc_banks

	write_asm('palette_groups', palette_groups, pg_bank, encode_palette_group)
	write_asm('textures', textures, texture_bank, encode_texture)
	write_asm('palette_changes', palette_changes, pc_bank, encode_palette_change, pg_bank)
	write_asm('frames', frames, frame_bank, encode_frame, pg_bank)
	write_asm('frame_order', frame_order, frame_order_bank, encode_frame_order_item, frame_bank, pc_bank, terminator=[0])

	with open('include/banks.asm', 'w') as f:
		banks = [
			('PALETTE_GROUPS', pg_bank),
			('TEXTURES', texture_bank),
			('PALETTE_CHANGES', pc_bank),
			('FRAMES', frame_bank),
			('FRAME_LIST', frame_order_bank),
			('AUDIO', audio_bank),
		]
		for name, bank in banks:
			f.write("BANK_{} EQU {}\n".format(name, bank))


def encode_palette_group(pg):
	# a palette group is a list of 4 palettes, each palette is a list of 4 colors (r, g, b)
	result = []
	for palette in pg:
		for r,g,b in palette:
			value = r + (g << 5) + (b << 10)
			result += [value % 256, value / 256]
	return result


def encode_texture(texture):
	# a texture is a 8-list of rows, each row is a 8-list of values 0-3
	result = []
	for row in texture:
		lower = sum((v % 2) << i for i, v in enumerate(row))
		upper = sum((v / 2) << i for i, v in enumerate(row))
		result += [lower, upper]
	return result


def encode_palette_change(pc, pg_bank):
	# a palette change list is a 144-list of palette group indexes
	result = []
	for pg_index in pc:
		bank, addr = index_to_bank_addr(pg_bank, 32, pg_index)
		result += [addr % 256, addr / 256, bank % 256]
	return pad(result, 512)


def encode_frame(frame, pg_bank):
	# a frame contains:
	#	'tiles': a 19-list of rows
	#		each row is a 21-list of (texture index, vertical flip, horizontal flip, palette number)
	#	'scroll': (scroll x, scroll y)
	#	'pg': frame-wide palette group index
	rows_a = []
	rows_b = []
	for row in frame['tiles']:
		row_a = []
		row_b = []
		for texture, vflip, hflip, palette in row:
			row_a.append(texture % 256)
			row_b.append(palette + ((texture / 256) << 3) + (hflip << 5) + (vflip << 6))
		rows_a += pad(row_a, 32)
		rows_b += pad(row_b, 32)
	result = rows_a + rows_b
	result += list(frame['scroll'])
	bank, addr = index_to_bank_addr(pg_bank, 32, frame['pg'])
	result += [addr % 256, addr / 256, bank % 256]
	return pad(result, 2048)


def encode_frame_order_item(index, frame_bank, pc_bank):
	# a frame order item is just a frame index
	frame_bank, frame_addr = index_to_bank_addr(frame_bank, 2048, index)
	pc_bank, pc_addr = index_to_bank_addr(pc_bank, 512, index)
	assert frame_addr % 256 == 0 and pc_addr % 256 == 0
	return [frame_bank, frame_addr / 256, pc_bank % 256, pc_addr / 256]


def get_video_data():
	"""Returns palette_groups, textures, palette_changes, frames, frame_order"""
	# test data
	return (
		# palette groups 0-2
		[[[(c * 8, p * 8, x * 8) for c in range(4)] for p in range(4)] for x in range(3)],
		# textures 0-2
		[[[(c+r+t) % 4 for c in range(8)] for r in range(8)] for t in range(3)],
		# palette changes for frames 0-2
		[[(l+f) % 3 for l in range(144)] for f in range(3)],
		# frames 0-2
		[{
			'tiles': [[((r+c+f) % 3, r % 2, c % 2, (r+c+f) % 8) for c in range(21)] for r in range(19)],
			'scroll': s,
			'pg': f % 3,
		} for f, s in enumerate([(0, 0), (4, 0), (0, 4)])],
		# frame list: loop between 0, 1 and 2, then stay 1sec on each, then repeat 10 times.
		([0, 1, 2] + [0] * 60 + [1] * 60 + [2] * 60) * 10,
	)


if __name__ == "__main__":
	main()
