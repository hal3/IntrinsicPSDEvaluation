#!/usr/bin/perl -w
use strict;

my $damt = $ENV{'damt'} or die;

my %types = ();
foreach my $dom qw(EMEA Science Subs) {
    open F, "source_data/$dom.psd" or die;
    while (<F>) {
        chomp;
        my ($snt_id, $fr_start, $fr_end, $en_start, $en_end, $fr_phrase, $en_phrase) = split /\t/, $_;
        $types{$fr_phrase}{$dom} = -20;
    }
    close F;

    open F, "zcat $damt/data/lms/fr/$dom.lm1.gz|" or die;
    while (<F>) {
        chomp;
        my ($prob,$word) = split;
        if (not defined $word) { next; }
        if (not exists $types{$word}) { next; }
        if (not exists $types{$word}{$dom}) { next; }
        $types{$word}{$dom} = $prob;
    }
    close F;
}

open F, "zcat $damt/data/lms/fr/hansard.lm1.gz|" or die;
while (<F>) {
    chomp;
    my ($prob,$word) = split;
    if (not defined $word) { next; }
    if (not exists $types{$word}) { next; }
    $types{$word}{'hansard'} = $prob;
}
close F;

foreach my $dom qw(EMEA Science Subs) {
    open O, "> features/$dom.type.hal-rf" or die;
    foreach my $w (keys %types) {
        if (not defined $types{$w}{$dom}) { next; }
        my $lpNew = $types{$w}{$dom};
        my $lpOld = (exists $types{$w}{'hansard'}) ? $types{$w}{'hansard'} : -20;
        my $lpDiff = $lpNew - $lpOld;
        print O "$w\tlpOld:$lpOld lpNew:$lpNew lpDiff:$lpDiff\n";
    }
    close O;
}
