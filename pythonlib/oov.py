#!/usr/bin/python

from sys import argv
from qutils import streamToCounts, wordsInStream, fileLines

def main(test, train):
    need = streamToCounts(wordsInStream(fileLines(test)))
    print len(need)
    count = 0
    have = dict()
    lastAdded = ''
    for tok in wordsInStream(fileLines(train)):
        count += 1
        if tok in need and tok not in have:
            have[tok] = 1
            lastAdded = tok
        if (count % 1000000) == 0:
            print str(len(have)) + " / " + str(len(need)) + ": " + lastAdded
    print count
    for p in need.iteritems():
        if p[0] not in have:
            print p[0]

if __name__ == "__main__":
    main(argv[1], argv[2])

# vim:sw=4:ts=4:et:ai
