#!/usr/bin/env python3

INPUT_FILE = 'trace/single-mds.txt'
OUTPUT_FILE = 'output/real-pop.png'

import sys
import numpy as np
import cv2

pixel_gray = lambda curval, maxval: int(255*curval/maxval)

class Canvas(object):
	def __init__(self, length, height):
		self._canvas = np.zeros((height, length, 3), dtype='uint8')

	def pixel(self, gray_value, length, height):
		#if gray_value != 0:
		#	print("Set (%d,%d) -> %d" % (length, height, gray_value))

		#self._canvas[height-1][length-1][0] = gray_value

		#self._canvas[height-1][length-1][0] = 255
		#self._canvas[height-1][length-1][1] = 255 - gray_value
		#self._canvas[height-1][length-1][2] = 255 - gray_value

		self._canvas[height-1][length-1][0] = 255 - gray_value
		self._canvas[height-1][length-1][1] = 255 - gray_value
		self._canvas[height-1][length-1][2] = 255

	def save(self):
		cv2.imwrite(OUTPUT_FILE, self._canvas)

def prepare():
	try:
		fin = open(INPUT_FILE, 'r')
	except IOError as e:
		sys.stderr.write(str(e) + '\n')
		sys.stderr.write('Fatal: input file \'%s\' not readable.' % INPUT_FILE)
		sys.exit(e.errno)
	return fin

def cleanup(fin):
	if fin:	fin.close()

"""
Parameters:
	line: current line
	curmaxval: current max value

Returns:
	a tuple (length, newmaxval):
	length: length of this line
	newmaxval: update maxval if a larger number found
"""
def checkline(line, curmaxval):
	nums = [ int(numstr) for numstr in line.strip().split(', ') ]
	return len(nums), max(curmaxval, *nums)

def main():
	# Step 0: Prepare file descriptors
	fin = prepare()

	# Step 1: Scan file for the first time: find rows, columns, max value
	first_line = fin.readline()
	height, length, maxval = 1, *checkline(first_line, 0)
	#print(height, length, maxval)
	for line in fin:
		height += 1
		mylength, maxval = checkline(line, maxval)
		#print(height, mylength, maxval)
		if length != mylength:
			raise ValueError( \
					'Fatal: line %d has length %d != %d in first line' \
					% (height, mylength, length))

	# Step 2: Scan file for the second time: draw figure
	fin.seek(0, 0)
	canvas = Canvas(length, height)
	height = 0
	for line in fin:
		height += 1
		nums = [ int(numstr) for numstr in line.strip().split(', ') ]
		for idx in range(len(nums)):
			#if nums[idx] != 0:	print(int(256*nums[idx]/maxval))
			canvas.pixel(pixel_gray(nums[idx], maxval), idx + 1, height)
	canvas.save()

	# Step : Clean up
	cleanup(fin)

if __name__ == '__main__':
	sys.exit(main())
