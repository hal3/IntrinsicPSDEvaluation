#!/usr/bin/python

from os import mkdir, path
from shutil import copyfile
import re

try:
    mkdir('fr')
except OSError:
    print ''

try:
    mkdir('en')
except OSError:
    print ''

def openMaybeGz(filename, mode):
    if filename.endswith('.gz'):
        return gzip.open(filename, mode)
    else:
        return open(filename, mode)

def fileLines(filename):
    with openMaybeGz(filename, 'r') as fh:
        for line in fh:
            yield line

i = 0
for line in fileLines('allsofar.sorted.200lengthlimit'):
    (score, frSrc) = line.split('\t')
    frSrc = frSrc.strip()
    frTgt = path.join('fr', path.basename(frSrc))
    copyfile(frSrc, frTgt)
    enSrc = re.sub(r'\.fr\.tok', r'.en.tok', frSrc)
    enTgt = re.sub(r'\.fr\.tok', r'.en.tok', frTgt)
    enTgt = re.sub(r'fr/', 'en/', enTgt)
    copyfile(enSrc, enTgt)
    i += 1
    if i >= 100: break

#  vi:ts=4:sw=4:et:ai
