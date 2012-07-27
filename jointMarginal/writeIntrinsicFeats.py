from __future__ import division
import codecs
import sys
import os

#Given a french word and a joint distribution, return en word with max p(en|fr) under joint
def getMaxEnWordFromJoint(frword,jointdist):
    correcten=""
    maxprob=0
    for en in jointdist.get(frword,[]):
        score=jointdist[frword][en][1] #get p_e_given_f
        if score>maxprob:
            maxprob=score
            correcten=en
    return correcten,maxprob

#Given a french word and a joint distribution, return K en words with max p(en|fr) under joint
def getMaxKEnWordFromJoint(frword,jointdist,k):
    correctEns=[]
    for i in range(k):
        correctEns.append(("",0))
    for en in jointdist.get(frword,[]):
        score=jointdist[frword][en][1] #get p_e_given_f
        replaced=False
        for i,epair in enumerate(correctEns):
            if score>epair[1] and not replaced:
                correctEns[i]=(en,score)
                replaced=True
    return correctEns

def wordMatch(word1,word2):
    word1=word1.strip()
    word2=word2.strip()
    if word2.startswith(word1) and word1.startswith(word2):
        return True
    else:
        return False

devtestvocab=[x.strip() for x in codecs.open("/home/hltcoe/airvine/damt/IntrinsicPSDEvaluation/source_data/EMEA.psd.frTypeVocab",'r').readlines()]
original_file=codecs.open("myout.original",'r').readlines()
original={}
for l in original_file:
    l=l.strip().split("\t")
    if len(l)>4:
        fr=l[0]
        en=l[1]
        joint=float(l[2])
        p_e_given_f=float(l[3])
        p_f_given_e=float(l[4])
        if fr not in original:
            original[fr]={}
        original[fr][en]=(joint,p_e_given_f,p_f_given_e)
learned_file=codecs.open("myout.learned",'r').readlines()
learned={}
for l in learned_file:
    l=l.strip().split("\t")
    if len(l)>4:
        fr=l[0]
        en=l[1]
        joint=float(l[2])
        p_e_given_f=float(l[3])
        p_f_given_e=float(l[4])
        if fr not in learned:
            learned[fr]={}
        learned[fr][en]=(joint,p_e_given_f,p_f_given_e)

print "Length of keys:", len(devtestvocab)
print "Length of original:", len(original.keys())
print "Length of learned:", len(learned.keys())

#In general, features with score of 1 I think will indicate likely to have a new sense
outfile=codecs.open("/home/hltcoe/airvine/damt/IntrinsicPSDEvaluation/features/EMEA.type.anni",'w')
for word in devtestvocab:
    outfile.write(word+"\t")
    #Feature 1: if got 0 probability mass in learned dist, score=0. Otherwise, score=1.
    if word in learned:
        outfile.write("a_PBML:"+str(1)+" ")
    else:
        outfile.write("a_PBML:"+str(0)+" ")
    #Feature 2: is max EN word different?
    maxEnLearned,learnedprob=getMaxEnWordFromJoint(word,learned)
    maxEnOriginal,originalprob=getMaxEnWordFromJoint(word,original)
    if wordMatch(maxEnLearned,maxEnOriginal):
        outfile.write("a_maxChange:"+str(0)+" ")        
    else:
        outfile.write("a_maxChange:"+str(1)+" ")                
    top5learned=getMaxKEnWordFromJoint(word,learned,5)
    top5learned_words=[x[0] for x in top5learned]
    top5original=getMaxKEnWordFromJoint(word,original,5)
    top5original_words=[x[0] for x in top5original]
    print top5learned_words, top5original_words
    # Feature 3: % of top 5 translations in both learned and original
    if word in learned and word in original:
        overlap=0
        for tword in top5original_words:
            if tword in top5learned_words:
                overlap+=1
        outfile.write("a_top5overlap:"+str(overlap/5)+" ")
    else:
        outfile.write("a_top5overlap:"+str(0.0)+" ")        
    # Feature 4: % of top 2 translations in both learned and original
    top2learned=getMaxKEnWordFromJoint(word,learned,2)
    top2learned_words=[x[0] for x in top2learned]
    top2original=getMaxKEnWordFromJoint(word,original,2)
    top2original_words=[x[0] for x in top2original]    
    if word in learned and word in original:
        overlap=0
        for tword in top2original_words:
            if tword in top2learned_words:
                overlap+=1
        outfile.write("a_top2overlap:"+str(overlap/2)+" ")
    else:
        outfile.write("a_top2overlap:"+str(0.0)+" ")        
    outfile.write("\n")


