#!/usr/bin/python

from itertools import imap
from qutils import fileLines, timer
from math import log, sqrt

def getUnigrams(filename, mincount = 0):
    d = dict()
    try:
        for line in fileLines(filename):
            pcs = line.strip().split(' ')
            if len(pcs) != 2: continue
            key = pcs[1]
            if len(key) == 0: continue
            d[key] = d.get(key, 0) + int(pcs[0])
        if mincount > 0:
            d2 = dict()
            for p in d.iteritems():
                if p[1] < mincount: continue
                d2[p[0]] = p[1]
            d = d2
    except IOError as e:
        print "I/O error({0}): {1}".format(e.errno, e.strerror)
        print "error reading from " + filename
    return d

def tfidf(termFreq, docFreq, numDocs):
    return termFreq * log ( numDocs / float(docFreq) )

def bm25(termFreq, docFreq, docLen, avgDocLen, numDocs, k1 = 1.5, b = 0.75):
    idf = log( (numDocs - docFreq + 0.5) / float(docFreq + 0.5) )
    if idf < 1e-2: idf = 1e-2
    num = termFreq * (k1 + 1)
    denom = termFreq + k1 * (1 - b + b * docLen / avgDocLen)
    return idf * num / float(denom)

def docTermCountMatrix(fileList, mincount = 0):
    with timer('building termcount matrix') as tim:
        matrix = []
        for filename in fileList:
            matrix.append(getUnigrams(filename, mincount))
        return matrix

def docFreqFromCountMatrix(matrix):
    df = dict()
    for row in matrix:
        for pair in row.iteritems():
            df[pair[0]] = df.get(pair[0], 0) + 1
    return df

def countMatrixToBinary(matrix):
    tmatrix = []
    for row in matrix:
        trow = dict()
        for pair in row.iteritems():
            trow[pair[0]] = 1
        tmatrix.append(trow)
    return tmatrix

def countMatrixToTfidf(matrix):
    docFreqs = docFreqFromCountMatrix(matrix)
    numDocs = float(len(matrix))
    tmatrix = []
    for row in matrix:
        trow = dict()
        for pair in row.iteritems():
            termFreq = pair[1]
            docFreq = docFreqs[pair[0]]
            trow[pair[0]] = tfidf(termFreq, docFreq, numDocs)
        tmatrix.append(trow)
    return tmatrix

def countMatrixToBm25(matrix):
    with timer('counts->bm25') as tim:
        docFreqs = docFreqFromCountMatrix(matrix)
        numDocs = float(len(matrix))
        avgDocLen = sum(map(len, matrix)) / numDocs
        bmatrix = []
        for row in matrix:
            docLen = len(row)
            brow = dict()
            for pair in row.iteritems():
                termFreq = pair[1]
                docFreq = docFreqs[pair[0]]
                bm = bm25(termFreq, docFreq, docLen, avgDocLen, numDocs)
                #print '\t'.join(map(str, [termFreq, docFreq, docLen, avgDocLen, numDocs, bm]))
                brow[pair[0]] = bm
            bmatrix.append(brow)
        return bmatrix

def printMatrixToHtml(matrix, filename):
    with open(filename, 'w') as fh:
        fh.write('<html><body>\n')
        fh.write('<table>\n')
        for row in matrix:
            fh.write('<tr>')
            for pair in sorted(row.iteritems(), reverse=True, key=lambda x: x[1]):
                fh.write('<td style="text-align : right">{1}:</td><td>{0}</td>'.format(pair[0], pair[1]))
            fh.write('</tr>\n')
        fh.write('</table>\n')
        fh.write('</body></html>\n')

def printLabeledMatrixToHtml(matrix, filename):
    with open(filename, 'w') as fh:
        fh.write('<html><body>\n')
        fh.write('<table>\n')
        for (name, row) in matrix.iteritems():
            fh.write('<tr>')
            fh.write('<td>{0}</td>'.format(name))
            for pair in sorted(row.iteritems(), reverse=True, key=lambda x: x[1]):
                fh.write('<td style="text-align : right">{1}:</td><td>{0}</td>'.format(pair[0], pair[1]))
            fh.write('</tr>\n')
        fh.write('</table>\n')
        fh.write('</body></html>\n')

def printLabeledMatrixToTxt(matrix, filename):
    with open(filename, 'w') as fh:
        for (name, row) in matrix.iteritems():
            fh.write(name)
            for pair in sorted(row.iteritems(), reverse=True, key=lambda x: x[1]):
                fh.write('\t{0[1]:.3f}:{0[0]}'.format(pair))
            fh.write('\n')

def normalizeMatrix(matrix):
    with timer('normalizing matrix') as tim:
        s = dict()
        for row in matrix:
            for (k,v) in row.iteritems():
                s[k] = s.get(k, 0) + v * v
        for (k,v) in s.iteritems():
            s[k] = sqrt(v)
        nmatrix = []
        for row in matrix:
            nrow = dict()
            for (k, v) in row.iteritems():
                nrow[k] = v / s[k]
            nmatrix.append(nrow)
        return nmatrix

def cosSim(m1, m2, keep=10):
    with timer('computing cosine sim') as tim:
        E = dict()
        for r in m1:
            for (k,v) in r.iteritems():
                E[k] = 1
        print 'source term count : ', len(E)
        t = dict()
        for e in E:
            if len(t) % 100 == 0: print len(t)
            s = 0
            rr = dict()
            for d in range(len(m1)):
                r1 = m1[d]
                r2 = m2[d]
                if e not in r1: continue
                se = r1[e]
                for (f, sf) in r2.iteritems():
                    rr[f] = rr.get(f, 0) + se * sf
            rr2 = dict()
            for (k, v) in sorted(rr.iteritems(), reverse=True, key=lambda p: p[1]):
                rr2[k] = v
                if len(rr2) >= keep: break
            t[e] = rr2
        return t

#  vi:ts=4:sw=4:et:ai
