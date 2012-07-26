#!/usr/bin/python

import Queue
import random
import sys
import threading
import time

class WorkerThread(threading.Thread):

    def __init__(self, inQ, sem, outQ, mapFn, debugPrint = False):
        threading.Thread.__init__(self)
        self.inQ = inQ
        self.sem = sem
        self.outQ = outQ
        self.mapFn = mapFn
        self.debugPrint = debugPrint

    def run(self):
        while True:
            item = self.inQ.get()
            if item == None: break
            if self.debugPrint: print "LEAF " + str(self.ident) + ": received " + str(item) + "\n",
            result = (item[0], self.mapFn(item[1]))
            if self.debugPrint: print "LEAF " + str(self.ident) + ": finished " + str(result) + "\n",
            self.outQ.put(result)
            self.sem.release()
            self.inQ.task_done()
        if self.debugPrint: print "LEAF " + str(self.ident) + ": finished; quitting\n",

class EnumThread(threading.Thread):

    def __init__(self, enum, threadCount, inQ, sem, outQ, workers, debugPrint):
        threading.Thread.__init__(self)
        self.enum = enum
        self.threadCount = threadCount
        self.inQ = inQ
        self.sem = sem
        self.outQ = outQ
        self.workers = workers
        self.debugPrint = debugPrint

    def run(self):
        count = 0
        for item in self.enum:
            self.inQ.put((count, item))
            count += 1
        if self.debugPrint: print "E: finished enum\n",
        for i in range(self.threadCount):
            self.inQ.put(None)
        if self.debugPrint: print "E: waiting for workers\n",
        for w in self.workers:
            w.join()
        if self.debugPrint: print "E: writing done marker\n",
        self.outQ.put((sys.maxint, None))
        self.sem.release()

def threaded_map(mapFn, enum, threadCount = 8, maxInputQ = 0, debugPrint = False):
    inQ = Queue.Queue(maxInputQ)
    sem = threading.Semaphore()
    outQ = Queue.PriorityQueue()
    workers = []
    for i in range(threadCount):
        w = WorkerThread(inQ, sem, outQ, mapFn, debugPrint)
        w.start()
    enummer = EnumThread(enum, threadCount, inQ, sem, outQ, workers, debugPrint)
    enummer.start()

    resultCount = 0
    alive = True
    while alive:
        sem.acquire()
        while not outQ.empty():
            res = outQ.get()
            if res[0] == sys.maxint: alive = False; break
            if res[0] > resultCount:
                outQ.put(res)
                break
            yield res[1]
            resultCount += 1

    enummer.join()

if __name__ == "__main__":
    for item in threaded_map(lambda x: x * 10, range(10)):
        print str(item) + "\n",

#  vi:ts=4:sw=4:et:ai
