#!/usr/bin/perl -w
use strict;

my $vocabEFN = shift or die;
my $vocabFFN = shift or die;
my $maxVocab = shift or die;

my $DocNum = 1;
my %vocabE = (); my %idfE = ();
my %vocabF = (); my %idfF = ();
readVocab($vocabEFN, $maxVocab, \%vocabE, \%idfE, 0);
readVocab($vocabFFN, $maxVocab, \%vocabF, \%idfF, 1);

while (1) {
    my $tmp = shift or last;
    if ($tmp eq '-ttable') { runTTable(shift); }
    else { 
        runWikipedia("unigram-counts/" . $tmp . ".en.tok.ucounts", \%vocabE, \%idfE);
        runWikipedia("unigram-counts/" . $tmp . ".fr.tok.ucounts", \%vocabF, \%idfF);
        $DocNum++;
    }
}

sub readVocab {
    my ($fn, $maxVocab, $v, $idf, $lang) = @_;
    print STDERR "Reading vocab from $fn\n";
    open F, (($fn =~ /\.gz$/) ? "zcat $fn|" : $fn) or die;
    my $numDocs = -1;
    my $id = 0;
    while (<F>) {
        if (++$id > $maxVocab) { last; }
        chomp;
        my ($df, $word) = split;
        if ($numDocs == -1) { $numDocs = $df + 1; }
        if ($df < 1) { last; }
        $v->{$word} = 2 * $id + $lang;
        $idf->{$word} = log($numDocs / $df);
    }
    close F;
}

sub runWikipedia {
    my ($fn, $vocab, $idf) = @_;

    print STDERR "Reading wikipedia data from $fn\n";
    open F, (($fn =~ /\.gz$/) ? "zcat $fn|" : $fn) or die;
    while (<F>) {
        chomp;
        if (/^\s*([0-9]+)\s+([^\s]+)\s*$/) {
            my $tf = $1; my $w = $2;
            if (not exists $vocab->{$w}) { next; }
            print $DocNum . ' ' . $vocab->{$w} . ' ' . ($tf * $idf->{$w}) . "\n";
        }
    }
    close F;
}

sub runTTable {
    my ($fn) = @_;
    print STDERR "Reading ttable from $fn\n";
    open F, (($fn =~ /\.gz$/) ? "zcat $fn|" : $fn) or die;
    while (<F>) {
        chomp;
        my ($cnt, $fr, $en) = split;
        if (not exists $vocabE{$en}) { next; }
        if (not exists $vocabF{$fr}) { next; }
        print $DocNum . ' ' . $vocabE{$en} . ' ' . ($cnt * $idfE{$en}) . "\n";
        print $DocNum . ' ' . $vocabF{$fr} . ' ' . ($cnt * $idfF{$fr}) . "\n";
        $DocNum++;
    }
    close F;
}

