
"""A tool for generating .asm files that run unit tests for asm functions.

Rather than trying to actually document everything, see meta_test.py as an example.
"""

import os
import random
import sys
import time

from easycmd import cmd
import argh


class Memory(object):
	def __init__(self, *args):
		contents = []
		for arg in args:
			try:
				i = iter(arg)
			except TypeError:
				contents.append(arg)
			else:
				contents += list(i)
		# this is needed for passing in binary strings
		self.contents = [ord(x) if isinstance(x, basestring) else x for x in contents]


test_order = 0
class Test(object):
	def __init__(self, target=None, pre_asm=[], post_asm=[], **kwargs):
		global test_order
		self.order = test_order
		test_order += 1

		self.target = target
		self.pre_asm = [pre_asm] if isinstance(pre_asm, basestring) else pre_asm
		self.post_asm = [post_asm] if isinstance(post_asm, basestring) else post_asm
		self.ins = {
			'regs': {},
			'flags': {},
			'mems': {},
		}
		self.outs = {
			'regs': {},
			'flags': {},
			'mems': {},
		}
		for key, value in kwargs.items():
			if key.startswith('in_'):
				state = self.ins
			elif key.startswith('out_'):
				state = self.outs
			else:
				raise ValueError("Bad keyword: {!r} (must be specified 'in_' or 'out_')".format(key))
			_, name = key.split('_', 1)

			if isinstance(value, Memory):
				state['mems'][name] = value.contents
			elif name in ('zflag', 'cflag'):
				flag = name[0]
				state['flags'][flag] = value
			elif name in ['A', 'B', 'C', 'D', 'E', 'H', 'L']:
				state['regs'][name] = value
			elif name in ('BC', 'DE', 'HL'):
				high, low = name
				state['regs'][high] = '({}) >> 8'.format(value)
				state['regs'][low] = '({}) & $ff'.format(value)
			else:
				raise ValueError("Bad keyword: {!r} (not a reg, flag or Memory)".format(key))

	def gen_asm(self, include_asm, target, extra_asm, mems):
		if self.target is not None:
			target = self.target

		return r"""
; --- GENERATED BY {argv[0]} on {now} ---


_IS_UNIT_TEST EQU "true"


; --- extra asm from test spec (may be empty) ---
{extra_asm}


; --- original target file ---
{include_asm}


; --- test harness ---
SECTION "{argv[0]} test stack", WRAM0

ds 128
_TestStack::

SECTION "{argv[0]} header", ROM0 [$100]
; This must be nop, then a jump, then blank up to 150
_Start::
	nop
	jp _TestStart
_Header::
	ds 76 ; Linker will fill this in

SECTION "{argv[0]} test harness", ROM0

_TestFailure::
	ld b, b ; bgb breakpoint
	di
	ld HL, $dead
.loop
	jp .loop

_TestSuccess::
	ld b, b ; bgb breakpoint
	di
	ld HL, $face
.loop
	jp .loop

_TestLog: MACRO
	ld d, d ; bgb debug message
	jr .end\@
	dw $6464, $0000
	db \1
.end\@
ENDM

_TestFailIfNot: MACRO
	jr \1, .nofail\@
	_TestLog \2
	jp _TestFailure
.nofail\@
ENDM

_TestStart::
	xor A
	ld [$ffff], A ; Disable all interrupts
	ld [$ff26], A ; Disable sound
	ld [$ff40], A ; Disable video
	ld SP, _TestStack
	; set up test
{prepare}
	; run test
	call {target}
	; check results
{check}
	_TestLog "=== Success ==="
	jp _TestSuccess
""".format(
	argv=sys.argv,
	now=time.strftime("%F %T"),
	include_asm=include_asm,
	extra_asm=extra_asm,
	prepare=self.gen_asm_prepare(mems),
	target=target,
	check=self.gen_asm_check(),
)

	def gen_asm_prepare(self, global_mems):
		regs = self.ins['regs']
		flags = self.ins['flags']
		local_mems = self.ins['mems']

		# merge mems. in the simple case, use either
		mems = global_mems.copy()
		mems.update(local_mems)
		# the only hard case is when both have it - we favor local_mems but if global_mems
		# is longer then we take the remainder from there
		for label in set(local_mems) & set(global_mems):
			l, g = local_mems[label], global_mems[label]
			mems[label] = l + g[len(l):]

		# our approach: mems first, then flags, then regs
		lines = list(self.pre_asm)
		for label, values in mems.items():
			lines += ["\tld HL, {}".format(label)]
			for value in values:
				if value is not None:
					lines.append("\tld [HL], {}".format(value))
				lines.append("\tinc HL")
		for flag, value in flags.items():
			if flag == 'z':
				if value:
					lines += ["\txor A"]
				else:
					lines += ["\tor $ff"]
			elif flag == 'c':
				lines += ['\tscf'] # set carry
				if not value:
					lines += ['\tccf'] # flip carry, ie. unset since we just set it
		for reg, value in regs.items():
			lines += ["\tld {}, {}".format(reg, value)]

		return '\n'.join(lines)

	def gen_asm_check(self):
		regs = self.outs['regs']
		flags = self.outs['flags']
		mems = self.outs['mems']

		# we need to be careful here not to clobber state as we go.
		# we check flags, then reg A, then other regs, then mems.
		lines = list(self.post_asm)
		for flag, value in flags.items():
			predicate = '{}{}'.format(('' if value else 'n'), flag) # eg. for z, True -> 'z'
			lines += ['\t_TestFailIfNot {}, "Flag {} not {} as expected"'.format(predicate, flag, value)]
		# special case reg A since we need to check it first
		if 'A' in regs:
			value = regs['A']
			lines += [
				'\tcp {}'.format(value),
				'\t_TestFailIfNot z, "Reg A expected {} but got %A%"'.format(value),
			]
		for reg, value in regs.items():
			if reg == 'A':
				continue
			lines += [
				'\tld A, {}'.format(reg),
				'\tcp {}'.format(value),
				'\t_TestFailIfNot z, "Reg {} expected {} but got %A%"'.format(reg, value),
			]
		for label, values in mems.items():
			# To save rom space, we make a little common routine for each label
			# to call into. We record expected value in B and index in DE.
			lines += [
				"\tld HL, {}".format(label),
				"\tjr .afterLabelFailRoutine{}".format(label),
				".labelFailRoutine{}".format(label),
				'\t_TestLog "Addr {}+%DE% expected %B% but got %A%"'.format(label),
				"\tjp _TestFailure",
				".afterLabelFailRoutine{}".format(label),
				"\tld DE, 0",
			]
			for value in values:
				if value is None:
					lines += [
						'\tinc HL',
						'\tinc DE',
					]
				else:
					lines += [
						'\tld A, [HL+]',
						'\tld B, {}'.format(value),
						'\tcp B',
						'\tjp nz, .labelFailRoutine{}'.format(label),
						'\tinc DE',
					]
		return '\n'.join(lines)


def process_file(top_level_dir, include_dir, tests_dir, extra_link_dirs, objs_dir, filename):
	name, _ = os.path.splitext(filename)
	filepath = os.path.join(tests_dir, filename)
	config = dict(Memory=Memory, Test=Test, random=random.Random(name))
	execfile(filepath, config) # loads config as defined globals
	if 'file' not in config:
		raise ValueError("You must specify a target file, or None")
	include_file = config['file']
	link_files = config.get('files')
	target = config.get('target')
	extra_asm = config.get('asm', '')
	mems = {label: value.contents for label, value in config.items() if isinstance(value, Memory) and not label.startswith('_')}
	tests = {testname: test for testname, test in config.items() if isinstance(test, Test)}
	if target is None and any(test.target is None for test in tests.values()):
		raise ValueError("You must specify a target function, either at top-level or for every test case")

	if include_file is None:
		include_asm = ''
	else:
		include_path = os.path.join(top_level_dir, '{}.asm'.format(include_file))
		with open(include_path) as f:
			include_asm = f.read()

	if link_files is None:
		asm_files = os.listdir(top_level_dir)
		for extra_link_dir in extra_link_dirs:
			asm_files += [os.path.join(extra_link_dir, filename) for filename in os.listdir(extra_link_dir)]
		link_files = [
			os.path.splitext(asm_file)[0]
			for asm_file in asm_files
			if asm_file.endswith('.asm') and asm_file != 'header.asm'
		]
		if include_file in link_files:
			link_files.remove(include_file)
		link_files = [os.path.join(objs_dir, link_file) for link_file in link_files]

	link_paths = [os.path.join(top_level_dir, '{}.o'.format(link_file)) for link_file in link_files]

	gendir = os.path.join(tests_dir, name)
	if not os.path.exists(gendir):
		os.mkdir(gendir)

	for i, (testname, test) in enumerate(sorted(tests.items(), key=lambda (n,t): t.order)):
		testname = '{i:0{w}d}_{t}'.format(i=i, t=testname, w=len(str(len(tests)-1)))
		asm = test.gen_asm(include_asm, target, extra_asm, mems)
		path = os.path.join(gendir, testname)
		asm_path = '{}.asm'.format(path)
		obj_path = '{}.o'.format(path)
		sym_path = '{}.sym'.format(path)
		rom_path = '{}.gb'.format(path)
		with open(asm_path, 'w') as f:
			f.write(asm)
		# We pad wth 0x40 = ld b, b = BGB breakpoint
		cmd(['rgbasm', '-DDEBUG', '-i', include_dir, '-v', '-o', obj_path, asm_path])
		cmd(['rgblink', '-n', sym_path, '-o', rom_path, '-p', '0x40', obj_path] + link_paths)
		cmd(['rgbfix', '-v', '-p', '0x40', rom_path])


def main(top_level_dir, include_dir='include/', tests_dir='tests', extra_link_dirs='tasks', objs_dir='build/debug'):
	include_dir = os.path.join(top_level_dir, include_dir)
	tests_dir = os.path.join(top_level_dir, tests_dir)
	extra_link_dirs = (
		[os.path.join(top_level_dir, link_dir) for link_dir in extra_link_dirs.split(',')]
		if extra_link_dirs else [] # because ''.split(',') == [''] when we want []
	)
	for filename in os.listdir(tests_dir):
		if filename.endswith('.py'):
			process_file(top_level_dir, include_dir, tests_dir, extra_link_dirs, objs_dir, filename)


if __name__ == '__main__':
	argh.dispatch_command(main)
