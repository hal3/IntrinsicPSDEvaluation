import codecs
import gzip

frlines=[x.strip() for x in gzip.open("/home/hltcoe/airvine/damt/IntrinsicPSDEvaluation/source_data/EMEA.fr.gz",'r').readlines()]

psdfile=codecs.open("/home/hltcoe/airvine/damt/IntrinsicPSDEvaluation/source_data/EMEA.psd.markedup",'r')

outfile=codecs.open("mani.tsv",'w')

written=[]

line=psdfile.readline()
while line:
    line.replace("&apos;","'")
    line=line.strip().replace("&apos;","'").split("\t")
    answer=int(line[0])
    if answer==1:
        linenum=int(line[1])
        frstart=int(line[2])
        frend=int(line[3])
        fr=line[4]
        lineofinterest=frlines[linenum-1].split(" ")
        if frstart>0:
            prefix=" ".join(lineofinterest[0:frstart])
            frword=" ".join(lineofinterest[frstart:frend+1])
            suffix=" ".join(lineofinterest[frend+1:])
        else:
            prefix=""
            frword=" ".join(lineofinterest[frstart:frend+1])
            suffix=" ".join(lineofinterest[frend+1:])
        print "PREFIX:", prefix
        print "FR:", frword
        print "SUFFIX:", suffix
        towrite=prefix+"\t"+frword+"\t"+suffix+"\n"
        if towrite not in written:
            outfile.write(towrite)
            written.append(towrite)
    line=psdfile.readline()
