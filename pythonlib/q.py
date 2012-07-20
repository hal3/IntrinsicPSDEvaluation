#!/usr/bin/python

from corp import *

hans = CorpusStats('data/hansards')

emea = CorpusStats('data/emea')
science = CorpusStats('data/science')
subs = CorpusStats('data/subs')

print "old = hansards, new = emea"
hans.overlap(emea)
print ""
print "old = hansards, new = science"
hans.overlap(science)
print ""
print "old = hansards, new = subs"
hans.overlap(subs)
