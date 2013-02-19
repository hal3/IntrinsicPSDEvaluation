#!/usr/bin/perl -w
use strict;

my $expName = shift or die;
my $ignoreStr = '';
my %ignore = ();
while (1) {
    my $tmp = shift or last;
    if ($tmp eq '--') { last; }
    if (defined $ignore{$tmp}) { next; }
    $ignoreStr = "$ignoreStr -ignore $tmp";
    $ignore{$tmp} = 1;
}

my $args = '';
while (1) {
    my $tmp = shift or last;
    $args .= ' ' . $tmp;
}

my %remaining = ();
open LS, "find features/ -iname \"*type.*\" |" or die $!;
while (my $fname = <LS>) {
    chomp $fname;
    $fname =~ /\/.*\.type\.(.+)$/;
    my $user = 'type.' . $1;
    if (not defined $ignore{$user}) {
        $remaining{$user} = 1;
    }
}
close LS;

open LS, "find features/ -iname \"*.token.*\" |" or die $!;
while (my $fname = <LS>) {
    chomp $fname;
    $fname =~ /^(.+)\.token\.(.+)$/;
    my $user = 'token.' . $2;
    if (not defined $ignore{$user}) {
        $remaining{$user} = 1;
    }
}
close LS;

foreach my $u (sort keys %remaining) {
    my $cmd = "bin/run_experiment.pl -exp $expName.remove=$u $ignoreStr -ignore $u $args \\> ablation/$expName.output.remove=$u 2\\>\\&1";
    print "qsh.pl $cmd\n";
}
