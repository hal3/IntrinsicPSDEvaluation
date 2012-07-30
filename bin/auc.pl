#!/usr/bin/perl -w
use strict;

while (1) {
    my $tmp = shift or last;
    if ($tmp eq '-rand') { 
        my $numRep = shift or die;
        my $nP = shift or die;
        my $nN = shift or die;

        my @Y = ();
        my @P = ();
        for (my $n=0; $n<$nN+$nP; $n++) {
            $Y[$n] = ($n < $nP) ? 1 : -1;
        }
        for (my $rep=1; $rep<=$numRep; $rep++) {
            for (my $n=0; $n<$nN+$nP; $n++) {
                $P[$n] = rand();
            }
            my $area = compute_auroc(\@P, \@Y);
            print $area . "\n";
        }

        exit;
    }
    die;
}

{
    my @P = (); my @Y = ();
    while (<>) {
        chomp;
        my ($p,$y) = split;
        push @P, $p;
        push @Y, $y;
    }
    my $area = compute_auroc(0, \@P, \@Y);
    print $area . "\n";
}


sub compute_aupr {
    my ($Ythresh, $P, $Y) = @_;

    my %p = ();
    my $T = 0;
    for (my $n=0; $n<@$P; $n++) {
        my $y = $Y->[$n]; my $p = $P->[$n];
        $y = ($y > $Ythresh) ? 1 : 0;
        $p{$p}{$y} += 1;
        $p{$p}{1-$y} += 0;
        $T++ if $y;
    }
    
    my %pre_at_rec = ();
    my $S = 0; my $I = 0;        
    foreach my $pval (sort { $b <=> $a } keys %p) {
        foreach my $v (values %{$p{$pval}}) { $S += $v; }
        $I += $p{$pval}{1};
        my $pre = ($I > 0) ? ($I / $S) : 0;
        my $rec = ($I > 0) ? ($I / $T) : 0;
        if ((not defined $pre_at_rec{$rec}) || ($pre > $pre_at_rec{$rec})) {
            $pre_at_rec{$rec} = $pre;
        }
    }

    my $area = 0;
    my $lastpre = 1;
    my $lastrec = 0;
    foreach my $rec (sort { $a <=> $b } keys %pre_at_rec) {
        my $pre = $pre_at_rec{$rec};
        my $width = $rec - $lastrec;
        my $min_pre = ($pre < $lastpre) ? $pre : $lastpre;
        my $max_pre = ($pre < $lastpre) ? $lastpre : $pre;
        
        # we have a box of size width*min_pre, and a triangle
        # width*(max_pre-min_pre) of which we get half
        if ($width > 0) {
            $area += $width * $min_pre + $width * ($max_pre - $min_pre) / 2;
        }
        $lastpre = $pre;
        $lastrec = $rec;
    }

    return $area;
}

sub compute_auroc {
    my ($Ythresh, $P, $Y) = @_;

    my %p = ();
    my $numY = 0; my $numN = 0;
    for (my $n=0; $n<@$P; $n++) {
        my $y = $Y->[$n]; my $p = $P->[$n];
        $y = ($y > $Ythresh) ? 1 : 0;
        $p{$p}{$y} += 1;
        $p{$p}{1-$y} += 0;
        $numY++ if $y;
        $numN++ if !$y;
    }
    
    my %tpr_at_fpr = ();
    my $predY = 0; my $predN = 0;
    foreach my $pval (sort { $b <=> $a } keys %p) {
        $predY += $p{$pval}{1};
        $predN += $p{$pval}{0};

        my $fpr = ($predN > 0) ? ($predN / $numN) : 0;
        my $tpr = ($predY > 0) ? ($predY / $numY) : 0;

        if ((not defined $tpr_at_fpr{$fpr}) || ($tpr > $tpr_at_fpr{$fpr})) {
            $tpr_at_fpr{$fpr} = $tpr;
        }
    }

    my $area = 0;
    my $last_tpr = 0;
    my $last_fpr = 0;
    foreach my $fpr (sort { $a <=> $b } keys %tpr_at_fpr) {
        my $tpr = $tpr_at_fpr{$fpr};
        my $width = $fpr - $last_fpr;
        my $min_tpr = ($tpr < $last_tpr) ? $tpr : $last_tpr;
        my $max_tpr = ($tpr < $last_tpr) ? $last_tpr : $tpr;
        
        # we have a box of size width*min_tpr, and a triangle
        # width*(max_tpr-min_tpr) of which we get half
        if ($width > 0) {
            $area += $width * $min_tpr + $width * ($max_tpr - $min_tpr) / 2;
        }
        $last_tpr = $tpr;
        $last_fpr = $fpr;
    }

    return $area;
}
