#!/usr/bin/env python3

#~ The MIT License (MIT)

#~ Copyright (c) 2016 Sofus Rose

#~ Permission is hereby granted, free of charge, to any person obtaining a copy
#~ of this software and associated documentation files (the "Software"), to deal
#~ in the Software without restriction, including without limitation the rights
#~ to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#~ copies of the Software, and to permit persons to whom the Software is
#~ furnished to do so, subject to the following conditions:
#~ 
#~ The above copyright notice and this permission notice shall be included in all
#~ copies or substantial portions of the Software.
#~ 
#~ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#~ IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#~ FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#~ AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#~ LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#~ OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#~ SOFTWARE.

import sys


	
def spSeq(seq, outLen) :
	perfSep = (1/outLen) * len(seq)
	return list(filter(len, [seq[round(perfSep * i):round(perfSep * (i + 1))] for i in range(len(seq))]))
	
def splitThreadRange(inNum, inThreads) :
	return [str(l[0]) + '-' + str(l[-1]) for l in spSeq(list(range(inNum)), inThreads)]


if __name__ == "__main__" :
	num = int(sys.argv[1])
	threads = int(sys.argv[2])
	if num == 1: print("0-0")
	else: print(*splitThreadRange(num, threads))

#mlv_dump cannot use 0-0.
