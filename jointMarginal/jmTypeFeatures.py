import codecs
import sys
import os

def readJ(jfile,wordTypes):
    line=jfile.readline()
    frToEnToScores={}
    while line:
        line=line.strip().split("\t")
        if len(line)>4:
            joint=line[0]
            p_e_given_f=line[1]
            p_f_given_e=line[2]
            fr=line[3]
            en=line[4]
            if fr in wordTypes:
                if not fr in frToEnToScores:
                    frToEnToScores[fr]={}
                frToEnToScores[fr][en]=[joint,p_e_given_f,p_f_given_e]
        line=jfile.readline()
    return frToEnToScores

if __name__=="__main__":
    if len(sys.argv)!=5:
        print "Usage: python %s original-joints-file learned-joints-file types-file out-file" % sys.argv[0]
        exit()
    originalInJoints=codecs.open(sys.argv[1],'r')
    learnedInJoints=codecs.open(sys.argv[2],'r')
    wordTypes=[x.strip() for x in codecs.open(sys.argv[3],'r').readlines()]
    print "Number of word types of interest %s " % len(wordTypes)
    outfile_learned=codecs.open(sys.argv[4]+".learned",'w')
    outfile_original=codecs.open(sys.argv[4]+".original",'w')
    oldjoints=readJ(originalInJoints,wordTypes)
    learnedjoints=readJ(learnedInJoints,wordTypes)
    print "Number of word types found in original %s " % len(oldjoints)
    print "Number of word types found in learned %s " % len(learnedjoints)
    for w in wordTypes:
        for en in learnedjoints.get(w,[]):
            score=learnedjoints[w][en]
            outfile_learned.write(w+"\t"+en+"\t"+str("\t".join(score))+"\n")
        for en in oldjoints.get(w,[]):
            score=oldjoints[w][en]
            outfile_original.write(w+"\t"+en+"\t"+str("\t".join(score))+"\n")
        #if w in learnedjoints:
        #    print "IN-LEARNED\t"+w
        #else:
        #    print "NOT-FOUND\t"+w
