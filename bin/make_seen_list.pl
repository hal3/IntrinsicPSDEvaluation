#!/usr/bin/perl -w
use strict;

my %w = ();
#foreach my $dom qw(EMEA Science Subs) {
#    open F, "source_data/$dom.psd" or die "cannot open source_data/$dom.psd: $!";
open F, "cat source_data/*.psd |" or die;
    while (<F>) {
        chomp;
        my ($snt_id, $fr_start, $fr_end, $en_start, $en_end, $fr_phrase, $en_phrase) = split /\t/, $_;
        %{$w{$fr_phrase}} = ();
    }
close F;
#    close F;
#}

my %inputs = (
    'hansard32' => '/export/ws12/damt/builds/baselines/non-adapted/on-old/hansard32-sigtest-phrase-table.1.gz',
    'hansard'   => '/mnt/data/ws12/damt/experiments/fraser_PB_hansard_NEW_sigtest/model/phrase-table.2.gz'
    );

foreach my $outputName (keys %inputs) {
    my $inputName = $inputs{$outputName};

    print STDERR "Creating source_data/seen.$outputName.gz based on $inputName ...\n";
    open F, "zcat $inputName |" or die $!;
    open O, "| gzip -9 > source_data/seen.$outputName.gz" or die;

#open F, "zcat /export/ws12/damt/builds/baselines/non-adapted/on-old/phrase-based/model/phrase-table.1.gz |" or die $!;
#open O, "| gzip -9 > source_data/seen.gz" or die $!;

    my %en = ();
    my $this_fr = '';
    while (<F>) {
        chomp;
        my ($fr,$en,$scores,$alignment,$counts) = split / \|\|\| /, $_;

        if ($fr ne $this_fr) {
            if (($this_fr ne '') && (exists $w{$this_fr})) {
                print STDERR ".";
                foreach my $en (sort { $en{$b} <=> $en{$a} } keys %en) { print O $this_fr . "\t" . $en . "\t" . $en{$en} . "\n"; }
            }
            $this_fr = $fr;
            %en = ();
        }

        if (exists $w{$fr}) {
            my ($phr_fe,$lex_fe,$phr_ef,$lex_ef) = split /\s+/, $scores;
            my ($cnt_en, $cnt_fr) = split /\s+/, $counts;
            $en{$en} += $phr_ef;
        }
    }
    if ($this_fr ne '') {
        foreach my $en (sort { $en{$b} <=> $en{$a} } keys %en) { print O $this_fr . "\t" . $en . "\t" . $en{$en} . "\n"; }
    }
    close F;
    close O;
    print STDERR " done!\n\n";
}
