for d in EMEA Science Subs ; do
  for n in 0 1 2 3 4 ; do
    qsh.pl -hostname '!a0[12345]' cat data/$d.wiki \| drop $n \| every_nth_line 5 \| cut -f2 \| cut -d/ -f9 \| sed "'s/.fr.tok$//'" \| head -n400 \| ./subtract_distribution.py --ignorecp data/wpairs.gz - \> output/$d.ignorecp.$n
  done
done
