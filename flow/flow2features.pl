#!/usr/bin/perl -w
use strict;

my $intrinsicDir = shift or die;
my $domain = shift or die;

my %words = ();
open F, "$intrinsicDir/source_data/$domain.psd" or die;
while (<F>) {
    chomp;
    my ($a,$b,$c,$d,$e,$f,$g) = split /\t/, $_;
    $words{$f} = 1;
}

my %d = ();
open LS, "ls output/$domain.[0-9]* |" or die;
while (my $fname = <LS>) {
    chomp $fname;

    open F, $fname or die;
    while (<F>) {
        chomp;
        if (/^\#  /) { next; }
        my ($word, $score) = split;
        if (not defined $score) { next; }
        if (not defined $words{$word}) { next; }
        push @{$d{$word}}, 0-$score;
    }
}
close LS;


open O, "> $intrinsicDir/features/$domain.type.hal-flow" or die;
foreach my $w (sort keys %d) {
    my $cnt = scalar @{$d{$w}};
    my $sum = 0;
    my $min = $d{$w}[0];
    my $max = $min;
    my $mu  = 0;
    my $std = 0;
    foreach my $v (@{$d{$w}}) {
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

    print O "$w\tflow_mean:$mu flow_std:$std flow_cnt:$cnt flow_min:$min flow_max:$max flow_sum:$sum\n";
}
close O;

    
