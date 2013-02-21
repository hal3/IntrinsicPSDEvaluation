#!/bin/bash
grep ^ ablation/abl*.done | sed 's/^ablation.abl//' | sort -g | tr '. ' ' \t' | sort -s  -k3,3 | tr ' ' . | cut -d: -f2 | grep -v flow | cut -f1 | xargs tail -n3 | bin/result_to_table.pl | egrep 'ablation|AUC|Macro-F' | perl -ne 'if (/^\%/) { m/abl[0-9]+\.([^\.]+)\./; $d=$1; s/^.*=//; s/[^a-z]//g; $_="\\minusFT\\FT$_".(" "x10)."% $d\n"; } print;'
