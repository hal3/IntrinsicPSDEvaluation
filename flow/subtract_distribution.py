#!/usr/bin/python

from sys import *
import networkx as nx
import gzip

def readCounts(fn):
    h = open(fn)
    c = {}
    s = 0.0
    for line in h:
        l = line.split();
        if len(l) == 2:
            c[l[1]] = float(l[0])
            s += float(l[0])
    for k in c.iterkeys():
        c[k] /= s
    return c
        
def readDict(fn):
    p = {}
    if fn.endswith(".gz"):
        h = gzip.open(fn, "rb")
    else:
        h = open(fn)
    for line in h:
        l = line.split();
        if len(l) == 3:
            if not p.has_key(l[1]):
                p[l[1]] = {}
            p[l[1]][l[2]] = float(l[0])
    h.close()
    for f in p.iterkeys():
        s = 0.0
        for e in p[f].iterkeys():
            s = s + p[f][e]
        for e in p[f].iterkeys():
            p[f][e] /= s
    return p

def processWiki(page, p=None, ignoreConditionalProbabilities=False):
    if p == None: p = readDict("data/wpairs")
    pe = readCounts("data/unigram-counts/" + page + ".en.tok.ucounts")
    pf = readCounts("data/unigram-counts/" + page + ".fr.tok.ucounts")

    G = nx.DiGraph()
    # 1 is source (F), 2 is sink (E)
    # 3 is F-null, 4 is E-null

    G.add_node(1, {'demand': -1, 'name': '*SOURCE*'})
    G.add_node(2, {'demand':  1, 'name': '*SINK*'})
    G.add_node(3, {'name': '*F-NULL*'})
    G.add_node(4, {'name': '*E-NULL*'})

    G.add_edge(1, 3, {'capacity': 1, 'weight': 100000})
    G.add_edge(4, 2, {'capacity': 1, 'weight': 100000})

    nCnt = 5

    fID = {}
    for f in pf.iterkeys():
        fID[f] = nCnt
        G.add_node(nCnt, {'name': f, 'lang': 'f'})
        G.add_edge(1, nCnt, {'capacity': pf[f], 'weight': 1})
        G.add_edge(nCnt, 4, {'capacity': 1, 'weight': 100000})
        nCnt += 1

    eID = {}
    for e in pe.iterkeys():
        eID[e] = nCnt
        G.add_node(nCnt, {'name': e, 'lang': 'e'})
        G.add_edge(nCnt, 2, {'capacity': pe[e], 'weight': 1})
        G.add_edge(3, nCnt, {'capacity': 1, 'weight': 100000})
        nCnt += 1

    for f in pf.iterkeys():
        nf = fID[f]
        if p.has_key(f):
            for e in p[f].iterkeys():
                if eID.has_key(e):
                    ne = eID[e]
                    cap = p[f][e]
                    if ignoreConditionalProbabilities: cap = 1
                    G.add_edge(nf, ne, {'capacity': cap, 'weight': 1})
                    
    flowCost,flowDict = nx.network_simplex(G)

    return G,flowDict

def flowDifference(G, flowDict):
    for src in flowDict.iterkeys():
        if not G.node[src].has_key('outflow'):
            G.node[src]['outflow'] = 0
        for dst,flow in flowDict[src].iteritems():
            if dst <= 4: continue
            if not G.node[dst].has_key('inflow'):
                G.node[dst]['inflow'] = 0
            G.node[src]['outflow'] += flow
            G.node[dst]['inflow']  += flow

    for f in G[1].iterkeys():
        if G.node[f].has_key('lang') and G.node[f]['lang'] == 'f':
            outflow = 0
            inflow = 0
            if G.node[f].has_key('outflow'): outflow = G.node[f]['outflow']
            if G.node[f].has_key('inflow'): inflow = G.node[f]['inflow']
            diff = outflow - G[1][f]['capacity']
            print G.node[f]['name'], diff

if __name__ == "__main__":
    ignoreConditionalProbabilities = False
    startPos = 2
    if argv[1] == "--ignorecp":
        ignoreConditionalProbabilities = True
        startPos = 3
    pairsFile = argv[startPos-1]
    print >>stderr, "reading pairs from ", pairsFile
    p = readDict(pairsFile)
    for i in range(startPos, len(argv)):
        if argv[i] == "-":
            for fname in stdin:
                fname = fname.rstrip("\r\n")
                print >>stderr, "reading document from ", fname
                print "# ", fname
                G,flowDict = processWiki(fname, p, ignoreConditionalProbabilities)
                flowDifference(G, flowDict)
        else:
            print >>stderr, "reading document from ", argv[i]
            print "# ", argv[i]
            G,flowDict = processWiki(argv[i], p, ignoreConditionalProbabilities)
            flowDifference(G, flowDict)
