#!/usr/bin/perl -w
use strict;

my $dom = shift or die;
my $bigN = 3;

my $lastSentId = -1;
my %data = ();
open F, "source_data/$dom.psd" or die;
while (<F>) {
    chomp;
    my ($sentId, $frSt, $frEn, $enSt, $enEn, $frPh, $enPh) = split /\t/, $_;
    if (not defined $enPh) { die; }
    $data{$sentId}{$frSt}{EN} = $frEn;
    $data{$sentId}{$frSt}{PH} = $frPh;
    %{$data{$sentId}{$frSt}{F}} = ();
    $lastSentId = $sentId;
}
close F;

open GEN, "/export/ws12/damt/src/srilm/bin/i686-m64/ngram -order $bigN -lm /export/ws12/damt/data/lms/fr/hansard.lm$bigN.gz -ppl source_data/$dom.fr.gz -debug 2 |" or die;
open DOM, "/export/ws12/damt/src/srilm/bin/i686-m64/ngram -order $bigN -lm /export/ws12/damt/data/lms/fr/$dom.lm$bigN.gz    -ppl source_data/$dom.fr.gz -debug 2 |" or die;

# sentId is one based (i.e., first line is 1)
# position is zero based (i.e., first word is 0)
my $curSentId = 1;
for (my $curSentId=1; $curSentId<=$lastSentId; $curSentId++) {
    my ($sentG, @gen) = readPPL(*GEN{IO});
    my ($sentD, @dom) = readPPL(*DOM{IO});

    if ($sentG ne $sentD) { die; }
    if (not exists $data{$curSentId}) { next; }

    my @w = split /\s+/, $sentG;
    foreach my $st (keys %{$data{$curSentId}}) {
        my $en = $data{$curSentId}{$st}{EN};
        my $ph = $data{$curSentId}{$st}{PH};

        my $wph = $w[$st];
        for (my $j=$st+1; $j<=$en; $j++) { $wph .= ' ' . $w[$j]; }
        if ($wph ne $ph) { die; }

        $data{$curSentId}{$st}{F}{'gen_st'} = $gen[$st];
        $data{$curSentId}{$st}{F}{'dom_st'} = $dom[$st];
        $data{$curSentId}{$st}{F}{'diff_st'} = $gen[$st] - $dom[$st];

        $data{$curSentId}{$st}{F}{'gen_en'} = $gen[$en+1];
        $data{$curSentId}{$st}{F}{'dom_en'} = $dom[$en+1];
        $data{$curSentId}{$st}{F}{'diff_en'} = $gen[$en+1] - $dom[$en+1];
    }
}

close GEN;
close DOM;

open F, "source_data/$dom.psd" or die;
open O, "> features/$dom.token.hal-ppl" or die;
while (<F>) {
    chomp;
    my ($sentId, $frSt, $frEn, $enSt, $enEn, $frPh, $enPh) = split /\t/, $_;
    my $first = 1;
    foreach my $f (keys %{$data{$sentId}{$frSt}{F}}) {
        if (not $first) { print O ' '; }
        $first = 0;
        print O $f . ':' . $data{$sentId}{$frSt}{F}{$f};
    }
    print O "\n";
}
close F or die;
close O or die;

sub readPPL {
    my ($IO) = @_;

    my $sent = <$IO>;
    if (not defined $sent) { die; }
    chomp $sent;

    my @words = split /\s+/, $sent;
    my @logProb = ();
    for (my $i=0; $i<@words+1; $i++) {
        $_ = <$IO>;
        if (not defined $_) { die; }
        chomp;
        if (/^\tp\( [^\s]+ \| .+\) \t= \[[^]]+\] ([^\s]+) \[ ([^\s]+) \]$/) {
            my $ngram = $1;
            my $logp = $2;
            my $backoff = $3;

            if ($logp < -6) { $logp = -6; }
            push @logProb, $logp;
        } else {
            die "'$_'";
        }
    }

    $_ = <$IO>;
    if (not /^1 sentences/) { die; }
    $_ = <$IO>;
    if (not /^[0-9]+ zeroprob/) { die; }
    $_ = <$IO>;
    if (not /^\s*$/) { die; }

    return ($sent, @logProb);
}
