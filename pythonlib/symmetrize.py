#!/usr/bin/python

import gzip
from sys import *
from qutils import *
from wa import *
from itertools import *

def enumGiza(filename):
    with openMaybeGz(filename, 'r') as fh:
        while True:
            comment = fh.readline()
            if not comment: break
            tgt = fh.readline()
            align = fh.readline()
            wap = WordAlignedPair()
            wap.loadGiza(comment, tgt, align)
            yield wap

def writeAligns(s, t, a, als):
    with openMaybeGz(s, 'w') as src:
        with openMaybeGz(t, 'w') as tgt:
            with openMaybeGz(a, 'w') as align:
                for wap in als:
                    wap.writeSource(src)
                    wap.writeTarget(tgt)
                    wap.writeAlignment(align)

globalCount = 0

def intersectWithFlip(x, y):
    yy = y.flip()
    z = x.intersect(yy)
    #if len(x.sourceWords) <= 10 and len(y.sourceWords) <= 10:
        #x.prettyPrint()
        #yy.prettyPrint()
        #z.prettyPrint()
    global globalCount
    globalCount += 1
    if (globalCount % 1000) == 0:
        stderr.write(str(globalCount) + '\r')
        stderr.flush()
    return z

def intersect(fore, back, src, tgt, align):
    writeAligns(src, tgt, align,
        imap(intersectWithFlip, enumGiza(fore), enumGiza(back)))

with timer("intersecting") as tim:
    intersect(argv[1], argv[2], argv[3], argv[4], argv[5])

#  vi:ts=4:sw=4:et:ai
