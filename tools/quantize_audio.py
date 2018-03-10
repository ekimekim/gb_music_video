
import sys

values = {(x+1) * (y - 7.5) + 60: (x, y) for x in range(8) for y in range(16)}
ceil = max(values)

BANK_SIZE = 16*1024

def main(asm_path, first_bank=1):
	asm_values = []
	while True:
		c = sys.stdin.read(1)
		if not c:
			break
		i = ord(c)
		i = quantize(i)
		assert i in values
		x, y = values[i]
		asm_values.append((x,y))
		sys.stdout.write(chr(int(i*2)))

	if len(asm_values) % 2 == 1:
		# even it up with a neutral value. easier than handling special case of odd total samples.
		asm_values.append(values[quantize(128)])

	with open(asm_path, 'w') as f:
		for n, ((x1, y1), (x2, y2)) in enumerate(zip(asm_values[::2], asm_values[1::2])):
			n = n * 2
			if n % BANK_SIZE == 0:
				f.write('SECTION "Audio data part {}", ROMX, BANK[{}]\n'.format(n, first_bank+n/BANK_SIZE))
			# pair of volumes first, then pair of samples. in both cases first sample is most signifigant nibble
			f.write("\tdb ${:x}{:x}\n".format(x1, x2))
			f.write("\tdb ${:x}{:x}\n".format(y1, y2))


def quantize(i):
	i = i * ceil / 256.

	lower = max(x for x in values if x <= i)
	upper = [x for x in values if x >= i]
	if not upper:
		return lower
	upper = min(upper) if upper else None

	if i - lower <= upper - i:
		# lower is closer or tied
		return lower
	return upper


if __name__ == '__main__':
	import argh
	argh.dispatch_command(main)
