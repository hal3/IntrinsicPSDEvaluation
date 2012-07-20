#! /usr/bin/python

from math import log, exp
from qutils import fileLines, openMaybeGz, timer
from sys import argv, stdout
from threaded_map import threaded_map

class PhrasePair:
    source = []
    target = []
    joint = 0
    sourceMarginal = 0
    targetMarginal = 0

    def __init__(self):
        self.source = []
        self.target = []
        self.joint = 0
        self.sourceMarginal = 0
        self.targetMarginal = 0

    def __init__(self, line):
        try:
            pcs = line.split(" ||| ")
            self.source = pcs[0].split(" ")
            self.target = pcs[1].split(" ")
            scores = pcs[2].split(' ')
            ccs = pcs[4].split(' ')
            self.sourceMarginal = float(ccs[0])
            self.targetMarginal = float(ccs[1])
            self.joint = max(
                float(scores[0]) * self.sourceMarginal,
                float(scores[2]) * self.targetMarginal)
        except:
            print "failed to parse " + line
            raise

    def prob(self):
        return self.joint / float(self.sourceMarginal)

    def logprob(self):
        return log(self.prob())

    def tostr(self):
        return "{0:.3f}[{1}/{2}]".format(self.logprob(), ' '.join(self.source), ' '.join(self.target))

class PhraseTable:
    d = dict()
    count = 0

    def __init__(self, lines):
        with timer('loading phrases') as tim:
            count = 0
            for line in lines:
                phrase = PhrasePair(line)
                key = ' '.join(phrase.source)
                l = self.d.get(key, [])
                l.append(phrase)
                self.d[key] = l
                count += 1
                if 0 == count % 10000: print "{0} phrases  \r".format(count), ; stdout.flush()
                if count == 100000: break
            self.count = count

    def match(self, words):
        N = len(words)
        for start in range(N):
            for end in range(start, N):
                l = self.d.get(' '.join(words[start : end + 1]), None)
                if l == None: continue
                yield (start, end, l)

class DoubleCoverage(Exception):
    def __init__(self, value):
        self.value = value

    def __str(self):
        return repr(self.value)

class Hyp:
    prefix = None
    phrase = None
    score = 0
    coverage = 0

    def __init__(self):
        prefix = None
        phrase = None
        score = 0
        coverage = 0

    def extend(self, pm):
        h = Hyp()
        h.prefix = self
        h.phrase = pm
        h.score = self.score + pm[2].logprob()
        h.coverage = self.coverage
        x = (1 << (pm[1] + 1)) - 1
        y = ((1 << pm[0]) - 1) if pm[0] > 0 else 0
        newCoverage = x - y
        if h.coverage & newCoverage > 0: raise DoubleCoverage('double coverage!')
        h.coverage = h.coverage & newCoverage
        #print h.tostr()
        return h

    def tostrh(self):
        if self.prefix == None: return ''
        return self.prefix.tostrh() + ' ' + self.phrase[2].tostr()

    def tostr(self):
        return '{0:.3f}'.format(self.score) + self.tostrh()

def match(sub, l):
    K = len(sub)
    N = len(l)
    if K <= N:
        for start in range(N - K + 1):
            allMatch = True
            for cur in range(K):
                if sub[cur] != l[start + cur]:
                    allMatch = False
                    break
            if allMatch:
                yield (start, start + K)

def forcedDecode(pt, S, T):
    #print 'DECODING ' + ' '.join(S) + ' -> ' + ' '.join(T)
    M = len(S)
    N = len(T)
    arcsByEndpoint = [[] for j in range(N + 1)]
    for pml in pt.match(S):
        for pp in pml[2]:
            #print pp.tostr()
            for t in match(pp.target, T):
                if t[0] == 0 and t[1] == N: continue
                #print ' >> ' + str(t[0]) + '-' + str(t[1])
                arcsByEndpoint[t[1]].append((t[0], (pml[0], pml[1], pp)))

    bestHyp = None
    beams = [[] for j in range(N + 1)]
    beams[0].append(Hyp())
    for j in range(1, N + 1):
        #print "..... beam " + str(j)
        l = []
        for arc in arcsByEndpoint[j]:
            (start, pm) = arc
            for hyp in beams[start]:
                try:
                    l.append(hyp.extend(pm))
                except DoubleCoverage:
                    continue
        cov = dict()
        count = 0
        #print '---finalizing beam---'
        for h in sorted(l, reverse=True, key=lambda x: x.score):
            #print h.tostr()
            if h.coverage in cov:
                #print ' . passing due to coverage'
                continue
            beams[j].append(h)
            if count > 5: break
            cov[h.coverage] = True
    if len(beams[N]) == 0:
        #print 'search failed!'
        #print '============================='
        bestHyp = None
    else:
        bestHyp = beams[N][0]
        #print 'best hyp ', bestHyp.tostr()
        #print exp(bestHyp.score)
        #print '============================='
    return bestHyp

def computeRelEnt(pt, chunk):
    result = ''
    for line in chunk.split('\n'):
        if len(line) == 0: continue
        phrase = PhrasePair(line)
        h = forcedDecode(pt, phrase.source, phrase.target)
        newLogprob = h.score if h != None else log(1e-10)
        ent = phrase.joint * ( phrase.logprob() - newLogprob )
        result += str(ent) + ' ||| ' + line + '\n'
    return result

def fileChunks(filename, chunkSize):
    with openMaybeGz(filename, 'r') as fh:
        chunk = ''
        ccount = 0
        for line in fh:
            chunk += line
            ccount += 1
            if ccount == chunkSize:
                yield chunk
                ccount = 0
                chunk = ''
        if ccount > 0:
            yield chunk
        
def pruneRelativeEntropy(filename, outfile):
    pt = PhraseTable(fileLines(filename))
    mapFn = lambda line: computeRelEnt(pt, line)
    with timer('pruning') as tim:
        with openMaybeGz(outfile, 'w') as o:
            count = 0
            chunksize = 100
            for line in threaded_map(mapFn, fileChunks(filename, chunksize), threadCount = 6, maxInputQ = 1024):
                o.write(line)
                count += chunksize
                if 0 == count % 500:
                    (elapsed, remaining, totalTime) = tim.predict(count, pt.count)
                    print "{0:.3f} elapsed; {1:.3f} remaining; {2:.3f} total; count = {3}  \r".format(elapsed, remaining, totalTime, count), ; stdout.flush()


if __name__ == "__main__":
    pruneRelativeEntropy(argv[1], argv[2])

#  vi:ts=4:sw=4:et:ai
