import gzip
import itertools
import os
import pickle
from time import time

def openMaybeGz(filename, mode):
    """ """
    if filename.endswith('.gz'):
        return gzip.open(filename, mode)
    else:
        return open(filename, mode)

class timer:
    name = ""
    start = 0
    def __init__(self, n):
        self.name = n
    def __enter__(self):
        print "[START " + self.name + ']'
        self.start = time()
        return self
    def __exit__(self, type, value, traceback):
        print "[  END " + self.name + ": " + str(self.elapsed()) + "]"

    def elapsed(self):
        return time() - self.start

    def predict(self, processedSoFar, total):
        el = self.elapsed()
        perItem = el / processedSoFar
        totalEst = total * perItem
        remaining = (total - processedSoFar) * perItem
        return (el, remaining, totalEst)

def streamToCounts(s):
    d = dict()
    c = 0
    for item in s:
        d[item] = d.setdefault(item, 0) + 1
        c += 1
    #print d
    return d

def countWords(filename, tgt):
    return fileMemoize(lambda: streamToCounts(wordsInStream(fileLines(filename))), tgt, [filename])

def fileLines(filename):
    with openMaybeGz(filename, 'r') as fh:
        for line in fh:
            yield line

def wordsInStream(s):
    for line in s:
        for token in line.split():
            yield token

def weave(l1, l2, l3):
    while True:
        try:
            yield (l1.next(), l2.next(), l3.next())
        except StopIteration:
            l1.close()
            l2.close()
            l3.close()
            break

def newer(f1, f2):
    return os.path.getmtime(f1) > os.path.getmtime(f2)

def forall(fn, l):
    for item in l:
        if not fn(item):
            return False
    return True

def fpickleLoad(filename):
    with open(filename, 'r') as fh:
        return pickle.load(fh)

def fpickleSave(obj, filename):
    with open(filename, 'w') as fh:
        pickle.dump(obj, fh)

def upToDate(target, sourceList):
    return os.path.exists(target) and forall(lambda x: newer(target, x), sourceList)

def fileMemoize(creator, targetFile, sourceFileList):
    with timer("creating " + targetFile) as tm:
        try:
            if upToDate(targetFile, sourceFileList):
                return fpickleLoad(targetFile)
        except:
            print "failed to unpickle saved file " + targetFile
        obj = creator()
        fpickleSave(obj, targetFile)
        return obj

def countif(l, f):
    c = 0
    for item in l:
        if f(item):
            c += 1
    return c

#  vi:ts=4:sw=4:et:ai
