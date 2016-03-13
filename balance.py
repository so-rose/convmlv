#!/usr/bin/env python3

'''
The MIT License (MIT)

Copyright (c) [year] [fullname]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'''

import sys, os
from glob import glob

import numpy as np
from PIL import Image
import tifffile as tff

def grey(numImg) :
	shifted = numImg.transpose(2, 0, 1)
	gAvg = np.average(shifted[1])
	
	al = gAvg / np.average(shifted[0])
	be = gAvg / np.average(shifted[2])
	
	return np.asarray([al, be])

def imgOpen(path) :
	if path[-4:] == '.tif' or path[-4:] == 'tiff' :
		return tff.TiffFile(path).asarray()
	else :
		return np.asarray(Image.open(path).convert('RGB'))

def greyAvg(paths) :
	wb = np.asarray([grey(imgOpen(path)) for path in paths])
	wbTrans = wb.transpose(1, 0)
	
	avgAl = np.average(wbTrans[0])
	avgBe = np.average(wbTrans[1])
	
	return (avgAl, avgBe)
	
if __name__ == '__main__' :
	if not sys.argv[1:]: print('No Arguments Given!'); sys.exit(1)
	
	if os.path.isdir(sys.argv[1]) :	
		bal = greyAvg([os.path.join(sys.argv[1], fil) for fil in os.listdir(sys.argv[1])])
		print(bal[0], 1.000000, bal[1])
	elif os.path.isfile(sys.argv[1]) :
		for fil in sys.argv[1:] :
			print(grey(imgOpen(fil)))
			
	'''
	eIn = False
	#~ print(bal)
	
	for path in sys.argv[1:] :
		#~ numImg = ndimage.imread(path)
		#~ print(numImg)
		numImg = np.asarray(Image.open(path).convert('RGB'))
		numImg.flags.writeable = True
		for x in range(numImg.shape[0]) :
			for y in range(numImg.shape[1]) :
				#~ print('Before', numImg[x][y])
				numImg[x][y][0] = sorted((0, int(numImg[x][y][0] * bal[0]), 255))[1]
				numImg[x][y][2] = sorted((0, int(numImg[x][y][2] * bal[1]), 255))[1]
				#~ print('After', numImg[x][y])
				
		if eIn: numImg *= 256
		img = Image.fromarray(np.uint16(numImg))
		img.show()
		img.save('bal_' + path[:-4] + '.tiff')
	'''
