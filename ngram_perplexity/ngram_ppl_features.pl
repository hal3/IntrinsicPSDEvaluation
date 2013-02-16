#!/usr/bin/perl -w
use strict;

my $dom = shift or die;
my $bigN = 3;

my %words = ();
open F, "source_data/$dom.psd" or die;
while (<F>) {
    chomp;
    my ($a,$b,$c,$d,$e,$f,$g) = split /\t/, $_;
    $words{$f} = 1;
}
close F;

open W, "ngram_perplexity/$dom.fr" or die;
open GB, "zcat ngram_perplexity/$dom/train.fr.general.$bigN.gz|" or die;
open DB, "zcat ngram_perplexity/$dom/train.fr.$dom.$bigN.gz|" or die;
open GS, "zcat ngram_perplexity/$dom/train.fr.general.1.gz|" or die;
open DS, "zcat ngram_perplexity/$dom/train.fr.$dom.1.gz|" or die;

my %info = ();
while (<W>) {
    chomp;
    my @w = split;
    $_ = <GB>; my @gb = parsePPL($_);
    $_ = <DB>; my @db = parsePPL($_);
    $_ = <GS>; my @gs = parsePPL($_);
    $_ = <DS>; my @ds = parsePPL($_);

    for (my $i=0; $i<@w; $i++) {
        if (not defined $words{$w[$i]}) { next; }

        push @{$info{$w[$i]}{gb}}, $gb[$i];
        push @{$info{$w[$i]}{gb_gs}}, $gb[$i] - $gs[$i];
        push @{$info{$w[$i]}{db_gb}}, $db[$i] - $gb[$i];
        push @{$info{$w[$i]}{dbgs_gbds}}, $db[$i] + $gs[$i] - $gb[$i] - $ds[$i];
    }
}

close W;
close GB;
close DB;
close GS;
close DS;

open O, "> features/$dom.type.hal-ppl" or die;
foreach my $w (keys %info) {
    print O $w;
    foreach my $f (keys %{$info{$w}}) {
        printStats($f, @{$info{$w}{$f}});
    }
    print O "\n";
}
close O;

sub printStats {
    my ($f, @d) = @_;

    my $cnt = scalar @d;
    my $sum = 0;
    my $min = $d[0];
    my $max = $min;
    my $mu  = 0;
    my $std = 0;
    foreach my $v (@d) {
        $mu += $v;
        $std += $v*$v;
        if ($v < $min) { $min = $v; }
        if ($v > $max) { $max = $v; }
        $sum += $v;
    }
    $mu /= $cnt;
    $std /= $cnt;
    $std -= $mu*$mu;
    $std = sqrt($std);

    print O "\tf^mean:$mu\t$f^std:$std\t$f^cnt:$cnt\t$f^min:$min\t$f^max:$max\t$f^sum:$sum\n";
}
close O;

    


sub parsePPL {
    my ($t) = @_;
    if (not defined $t) { die; }
    chomp $t;
    my ($sentProb, $numOOV, $numZero, @probs) = split /\s+/, $t;
    my @logProbs = ();
    foreach my $p (@probs) {
        if ($p < 1e-6) { $p = 1e-6; }
        push @logProbs, log($p);
    }
    return (@logProbs);
#   SENTENCE_PERPLEXITY
#   NUMBER_OF_OOV_TOKENS
#   NUMBER_OF_ZERO_PROBABILITY_TOKENS
#   ACTUAL_PER_WORD_PROBABILITIES  (incl EOS)
}
