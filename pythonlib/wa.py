from qutils import *

def gizaSrcGroups(l):
    srcWord = ''
    aligns = []
    state = 0
    for item in l.split(' '):
        if state == 0:
            srcWord = item
            aligns = []
            state = 1
        elif state == 1:
            if item != '({':
                print 'expected ({ but got ' + item
                raise Exception()
            state = 2
        elif state == 2:
            if item == '})':
                yield (srcWord, aligns)
                state = 0
            else:
                aligns.append(int(item) - 1)

def parsePair(p):
    pcs = p.split('-')
    return (int(pcs[0]), int(pcs[1]))

def pad(s, l):
    ll = len(s.decode('utf-8'))
    if ll >= l: return s
    return s + (' ' * (l - ll))

class WordAlignedPair:
    orig = ''
    sourceWords = []
    targetWords = []
    alignments = []

    def __init__(self):
        sourceWords = []
        targetWords = []
        alignments = []

    def load(self, s, t, a):
        self.sourceWords = s.split()
        self.targetWords = t.split()
        self.alignments = map(parsePair, a.split())
        self.checkalign()

    def checkalign(self):
        for p in self.alignments:
            if p[0] < 0 or p[0] >= len(self.sourceWords):
                print "bad alignment: source index was " + str(p[0]) + "; max was " + str(len(self.sourceWords))
                print self.orig
                print ' '.join(map(lambda (x, y): str(x) + '-' + str(y), self.alignments))
                raise Exception()
            if p[1] < 0 or p[1] >= len(self.targetWords):
                print "bad alignment: target index was " + str(p[1]) + "; max was " + str(len(self.targetWords))
                print self.orig
                print ' '.join(map(lambda (x, y): str(x) + '-' + str(y), self.alignments))
                raise Exception()

    def loadGiza(self, comment, tgt, srcalign):
        self.orig = '\n'.join([comment, tgt, srcalign])
        self.targetWords = tgt.rstrip('\r\n').split(' ')
        self.sourceWords = []
        self.alignments = []
        srcIndex = -1
        for pair in gizaSrcGroups(srcalign):
            if srcIndex >= 0:
                self.sourceWords.append(pair[0])
                #print pair[0] + ": " + ' '.join(map(str, pair[1]))
                for t in pair[1]:
                    self.alignments.append((srcIndex, t))
            srcIndex += 1
        self.checkalign()
        #self.prettyPrint()

    def wordPairs(self):
        vs = [False for s in self.sourceWords]
        vt = [False for t in self.targetWords]
        for item in self.alignments:
            yield (self.sourceWords[item[0]],self.targetWords[item[1]])
            vs[item[0]] = True
            vt[item[1]] = True
        for i in range(len(vs)):
            if not vs[i]:
                yield (self.sourceWords[i], "NULL")
        for j in range(len(vt)):
            if not vt[j]:
                yield ("NULL", self.targetWords[j])

    def flip(self):
        wap = WordAlignedPair()
        wap.targetWords = self.sourceWords
        wap.sourceWords = self.targetWords
        wap.alignments = map(lambda (x,y): (y,x), self.alignments)
        wap.checkalign()
        return wap

    def prettyPrint(self):
        sourceWidth = max(3, reduce(max, map(lambda x: len(x.decode('utf-8')), self.sourceWords)))
        widths = map(lambda x: max(len(x.decode('utf-8')), 3), self.targetWords)
        table = [ [ (' ' * widths[j]) for j in range(len(self.targetWords)) ] for i in range(len(self.sourceWords))]
        for p in self.alignments:
            table[p[0]][p[1]] = 'X' * widths[p[1]]
        print (' ' * sourceWidth) + ' ' + ' '.join(map(lambda x: pad(x, 3), self.targetWords))
        i = 0
        for l in table:
            print pad(self.sourceWords[i], sourceWidth) + ' ' + ' '.join(l)
            i += 1

    def intersect(self, other):
        wap = WordAlignedPair()
        wap.sourceWords = self.sourceWords
        wap.targetWords = self.targetWords
        wap.alignments = list(set(self.alignments) & set(other.alignments))
        wap.checkalign()
        return wap

    def writeSource(self, fh):
        fh.write(' '.join(self.sourceWords) + '\n')

    def writeTarget(self, fh):
        fh.write(' '.join(self.targetWords) + '\n')

    def writeAlignment(self, fh):
        fh.write(' '.join([ str(p[0]) + '-' + str(p[1]) for p in self.alignments ]) + '\n')

    def setAlignment(self, a):
        self.alignments = map(parsePair, a.split())

def enumAligns(s, t, a):
    fn = lambda x: fileLines(x)
    for x in weave(fn(s), fn(t), fn(a)):
        wa = WordAlignedPair()
        wa.load(x[0], x[1], x[2])
        yield wa

def enumAlignsT(b):
    return enumAligns(b + '.src.gz', b + '.tgt.gz', b + '.align.gz')

def pairs(s, t, a):
    for wa in enumAligns(s, t, a):
        for p in wa.wordPairs():
            yield '__'.join(p)

def countPairs(s, t, a, p):
    return fileMemoize(lambda: streamToCounts(pairs(s, t, a)), p, [s,t,a])

#  vi:ts=4:sw=4:et:ai
