
import sys
from itertools import count

values = {(x+1) * (y - 7.5) + 60: (x, y) for x in range(8) for y in range(16)}
ceil = max(values)

BANK_SIZE = 16*1024

def main(asm_path, first_bank=1):
	asm = open(asm_path, 'w')
	for n in count():
		c = sys.stdin.read(1)
		if not c:
			break
		i = ord(c)
		i = quantize(i)
		assert i in values
		x, y = values[i]
		if n % BANK_SIZE == 0:
			asm.write('SECTION "Audio data part {}", ROMX, BANK[{}]\n'.format(n, first_bank+n/BANK_SIZE))
		asm.write("\tdb ${:x}{:x}\n".format(x, y))
		sys.stdout.write(chr(int(i*2)))


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
