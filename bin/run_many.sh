n=1
for dom in EMEA Science Subs ; do
    qsh bin/run_experiment.pl -showclassifier -nf 16 -xv $dom -exp exp$n \> results/$dom.all
    let n=n+1
    qsh bin/run_experiment.pl -showclassifier -nf 16 -xv $dom -exp exp$n -ignore anni -ignore hal-flow -ignore hal-ppl -ignore rachel \> results/$dom.none
    let n=n+1
done

for ignore1 in anni hal-flow hal-ppl rachel ; do
    for dom in EMEA Science Subs ; do
        qsh bin/run_experiment.pl -showclassifier -nf 16 -xv $dom -exp exp$n -ignore $ignore1 \> results/$dom.$ignore1
        let n=n+1
    done
done

for ignore2 in anni hal-flow hal-ppl rachel ; do
    for ignore1 in anni hal-flow hal-ppl rachel ; do
        if [ "$ignore1" \< "$ignore2" ] ; then
            for dom in EMEA Science Subs ; do
                qsh bin/run_experiment.pl -showclassifier -nf 16 -xv $dom -exp exp$n -ignore $ignore1 -ignore $ignore2 \> results/$dom.$ignore1.$ignore2
                let n=n+1
            done
        fi
    done
done

for ignore3 in anni hal-flow hal-ppl rachel ; do
  for ignore2 in anni hal-flow hal-ppl rachel ; do
    for ignore1 in anni hal-flow hal-ppl rachel ; do
        if [ "$ignore1" \< "$ignore2" ] ; then
          if [ "$ignore2" \< "$ignore3" ] ; then
            for dom in EMEA Science Subs ; do
                qsh bin/run_experiment.pl -showclassifier -nf 16 -xv $dom -exp exp$n -ignore $ignore1 -ignore $ignore2 -ignore $ignore3 \> results/$dom.$ignore1.$ignore2.$ignore3
                let n=n+1
            done
          fi
        fi
    done
  done
done
