#!/bin/bash

echo "% task one results"
for d in EMEA Science Subs ; do
  echo "\hline"
  echo "\textbf{$d} &&&&&&&&&&&&&& \\"
  for c in random constant notoken oracleType notype withtoken ; do
#  for c in random constant oracleType notoken withtoken ; do
    echo $c
    bin/result_to_table.pl < paper-results/xv.$d.$c
  done
done

# echo ""
# echo "% task two results"
# for d in EMEA Science Subs ; do
#   echo "\hline"
#   echo "\textbf{$d}"
#   bin/result_to_table.pl < paper-results/xv.$d.withtoken | sed 's/{ }/{g}/'
#   for c in random constant oracleType notoken withtoken ; do
#     echo $c
#     bin/result_to_table.pl < paper-results/te.$d.$c
#   done
# done

echo ""
echo "% mfs (task one) results"
for d in EMEA Science Subs ; do
  echo "\hline"
  echo "\textbf{$d} &&&&&&&&&&&&&& \\"
  for c in random constant notoken oracleType notype withtoken ; do
    echo $c
    bin/result_to_table.pl < paper-results-mfs/xv.$d.$c
  done
done
