#!/usr/bin/python

from ir import *
from qutils import *
from itertools import *
import os
import os.path

def changeExt(filename, newext):
    while True:
        base = os.path.splitext(filename)[0]
        if base == filename: break
        filename = base
    return base + newext

def changeDir(filename, newdir):
    base = os.path.basename(filename)
    return os.path.join(newdir, base)

toplines = islice(fileLines('../allsofar.sorted.200lengthlimit.tok'), 10000)
newDir = '/export/ws12/damt/data/pp/wikipedia/unigram-counts'
topffiles = list(imap(lambda x: changeDir(x.split('\t')[1].strip(), newDir), toplines))
topfrfiles = map(lambda x: changeExt(x, '.fr.tok.ucounts'), topffiles)
topenfiles = map(lambda x: changeExt(x, '.en.tok.ucounts'), topffiles)

me = normalizeMatrix(countMatrixToBm25(docTermCountMatrix(topenfiles, 2)))
mf = normalizeMatrix(countMatrixToBm25(docTermCountMatrix(topfrfiles, 2)))

fe = cosSim(mf, me)

printLabeledMatrixToHtml(fe, 'fe_pairs.html')
printLabeledMatrixToTxt(fe, 'fe_pairs.txt')

ef = cosSim(me, mf)

printLabeledMatrixToHtml(ef, 'ef_pairs.html')
printLabeledMatrixToTxt(ef, 'ef_pairs.txt')

with open('mutual.txt', 'w') as fh:
    for (f, row) in fe.iteritems():
        for (e, fe_cos) in row.iteritems():
            row2 = ef[e]
            if f in row2:
                ef_cos = row2[f]
                prod = fe_cos * ef_cos
                fh.write('\t'.join([f, e, str(fe_cos), str(ef_cos), str(prod)]) + '\n')

#  vi:ts=4:sw=4:et:ai
