from wa import *
from qutils import *

def dictOverlap(d1, d2):
    otyp = 0
    otok = 0
    osin = 0
    ityp = 0
    itok = 0
    isin = 0
    ntyp = 0
    ntok = 0
    nsin = 0
    for (item, c1) in d1.iteritems():
        if item in d2:
            ityp += 1
            if c1 == 1: isin += 1
            c2 = d2[item]
            if c1 >= c2:
                otok += c1 - c2
                itok += c2
            else:
                itok += c1
                ntok += c2 - c1
        else:
            otyp += 1
            if c1 == 1: osin += 1
            otok += c1
    for (item, c2) in d2.iteritems():
        if item not in d1:
            ntyp += 1
            if c2 == 1: nsin += 1
            ntok += 1
    print '          {0:>10}|{1:>10}|{2:>20}|{3:>10}|{4:>10}|{5:>10}'.format('OLD', 'OLD-NEW', 'INTERSECT', 'NEW-OLD', 'NEW', 'UNION')
    print 'types     {0:10}|{1:10}|{2:4.0%}/{3:10}/{4:4.0%}|{5:10}|{6:10}|{7:10}'.format(otyp + ityp, otyp, ityp/float(otyp+ityp), ityp, ityp/float(ityp+ntyp), ntyp, ntyp + ityp, otyp + ityp + ntyp)
    print 'tokens    {0:10}|{1:10}|{2:4.0%}/{3:10}/{4:4.0%}|{5:10}|{6:10}|{7:10}'.format(otok + itok, otok, itok/float(otok+itok), itok, itok/float(itok+ntok), ntok, ntok + itok, otok + itok + ntok)
    print 'singletons{0:10}|{1:10}|{2:4.0%}/{3:10}/{4:4.0%}|{5:10}|{6:10}|{7:10}'.format(osin + isin, osin, isin/float(osin+isin), isin, isin/float(isin+nsin), nsin, nsin + isin, osin + isin + nsin)

class CorpusStats:

    def __init__(self, basename):
        s = basename + '.src.gz'
        t = basename + '.tgt.gz'
        a = basename + '.align.gz'
        self.srcM = countWords(s, s + '.P')
        self.tgtM = countWords(t, t + '.P')
        self.joint = countPairs(s, t, a, a + '.P')

    def printStats(self):
        print "source vocab size    : " + str(len(self.srcM))
        print "target vocab size    : " + str(len(self.tgtM))
        print "pairs                : " + str(len(self.joint))
        print "source singletons    : " + str(countif(self.srcM.iteritems(), lambda p: p[1] == 1))
        print "target singletons    : " + str(countif(self.tgtM.iteritems(), lambda p: p[1] == 1))
        print "joint singletons     : " + str(countif(self.joint.iteritems(), lambda p: p[1] == 1))

    def overlap(self, c):
        print "SOURCE WORDS"
        dictOverlap(self.srcM, c.srcM)
        print ""
        print "TARGET WORDS"
        dictOverlap(self.tgtM, c.tgtM)
        print ""
        print "WORD PAIRS"
        dictOverlap(self.joint, c.joint)

#  vi:ts=4:sw=4:et:ai
