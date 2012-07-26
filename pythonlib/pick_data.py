#!/usr/bin/python

from corp import *

#hans = CorpusStats('data/hansards')
emea = CorpusStats('data/emea')
science = CorpusStats('data/science')
#subs = CorpusStats('data/subs')

emea.overlap(science)

def where(l, f):
    for item in l:
        if f(item):
            yield item

def take(l, n):
    i = 0
    for item in l:
        i += 1
        if i > n: break
        yield item

#for item in take(where(sorted(emea.joint.iteritems(), key=lambda p: p[1], reverse=True), lambda x: "NULL" not in x[0]), 10):
    #print item[0] + ': ' + str(item[1])
with open('pairs.txt', 'w') as fh:
    for item in take(where(sorted(science.joint.iteritems(), key=lambda p: p[1], reverse=True), lambda x: "NULL" not in x[0] and x[0] in emea.joint), 1000):
        print >>fh, item[0] + ' ' + str(emea.joint[item[0]]) + ' ' + str(item[1])

#  vi:ts=4:sw=4:et:ai
