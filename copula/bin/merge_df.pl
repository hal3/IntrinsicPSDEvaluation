#!/usr/bin/perl -w
use strict;

my %df = ();
while (<>) {
    chomp;
    my ($cnt,$w) = split;
    $df{$w}+=$cnt;
}
foreach my $w (sort { $df{$b} <=> $df{$a} } keys %df) {
    print $df{$w} . ' ' . $w . "\n";
}
