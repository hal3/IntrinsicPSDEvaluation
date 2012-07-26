#!/usr/bin/perl -w
use strict;

my %w = ();
foreach my $dom qw(EMEA Science Subs) {
    open F, "source_data/$dom.psd" or die "cannot open source_data/$dom.psd: $!";
    while (<F>) {
        chomp;
        my ($snt_id, $fr_start, $fr_end, $en_start, $en_end, $fr_phrase, $en_phrase) = split /\t/, $_;
        %{$w{$fr_phrase}} = ();
    }
    close F;
}

open F, "zcat /export/ws12/damt/builds/baselines/non-adapted/on-old/phrase-based/model/phrase-table.1.gz |" or die $!;
open O, "| gzip -9 > source_data/seen.gz" or die $!;
my %en = ();
my $this_fr = '';
while (<F>) {
    chomp;
    my ($fr,$en,$scores,$alignment,$counts) = split / \|\|\| /, $_;

    if ($fr ne $this_fr) {
        if ($this_fr ne '') {
            foreach my $en (sort { $en{$b} <=> $en{$a} } keys %en) { print O $this_fr . "\t" . $en . "\t" . $en{$en} . "\n"; }
        }
        $this_fr = $fr;
        %en = ();
    }

    if (exists $w{$fr}) {
        if (not defined $w{$fr}{$en}) {
            my ($phr_fe,$lex_fe,$phr_ef,$lex_ef) = split /\s+/, $scores;
            my ($cnt_en, $cnt_fr) = split /\s+/, $counts;
            $en{$en} = $phr_ef;
            #print O $fr . "\t" . $en . "\n";
            $w{$fr}{$en} = 1;
        }
    }
}
close F;
close O;
if ($this_fr ne '') {
    foreach my $en (sort { $en{$b} <=> $en{$a} } keys %en) { print O $this_fr . "\t" . $en . "\t" . $en{$en} . "\n"; }
}
