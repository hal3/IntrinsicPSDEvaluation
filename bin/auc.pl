#!/usr/bin/perl -w
use strict;

my $bootstrap = 0;
my $doPRF = 0;
while (1) {
    my $tmp = shift or last;
    if ($tmp eq '-prf') { $doPRF = 1; next; }
    elsif ($tmp eq '-bootstrap') { $bootstrap = shift or die; next; }
    elsif ($tmp eq '-rand') { 
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
    my @P = (); my @Y = (); my @S = ();
    while (<>) {
        chomp;
        my ($p,$y,$set) = split;   # set is only used for micro PRF
        push @P, $p;
        push @Y, $y;
        if (not defined $set) { $set = ''; }
        push @S, $set;
    }
    if ($bootstrap <= 1) {
        if ($doPRF) { print compute_prf(\@P, \@Y, \@S); }
        else {        print compute_auroc(0, \@P, \@Y); }
    } else {
        my @all = ();
        for (my $bs=0; $bs<$bootstrap; $bs++) {
            my @P0 = (); my @Y0 = (); my @S0 = ();
            for (my $n=0; $n<@P; $n++) {
                my $m = int(rand() * scalar @P);
                $P0[$n] = $P[$m];
                $Y0[$n] = $Y[$m];
                $S0[$n] = $S[$m];
            }
            if ($doPRF) { push @all, compute_prf(\@P0, \@Y0, \@S0); }
            else {        push @all, compute_auroc(0 , \@P0, \@Y0); }
        }
        printBootstrap(@all);
    }
}

sub printBootstrap {
    my @l = @_;
    my @x = split /\s+/, $l[0];
    my @mu = ();
    my @st = ();
    my $N = scalar @l;
    for (my $i=0; $i<@x; $i++) {
        if (not ($x[$i] =~ /^[0-9\.e+-]*$/)) {
            push @mu, $x[$i];
            push @st, $x[$i];
        } else {
            my $mu = 0;
            my $st = 0;
            for (my $n=0; $n<@l; $n++) {
                my @y = split /\s+/, $l[$n];
                $mu += $y[$i];
                $st += $y[$i]*$y[$i];
            }
            $mu /= $N;
            $st /= $N;
            $st = sqrt($st - $mu*$mu);
            push @mu, $mu;
            push @st, $st;
        }
    }
    print 'bootstrap-mean: ' . (join ' ', @mu) . "\n";
    print 'bootstrap-stdd: ' . (join ' ', @st) . "\n";
}

sub compute_prf {
    my ($P, $Y, $S) = @_;

    my %thresh = ();
    foreach my $p (@$P) { $thresh{$p} = 1; }
    
    my $bestMac = 0;
    my $bestStr = '';
    foreach my $thresh (0) { # keys %thresh) {
        my $str = compute_prf0($P, $Y, $S, $thresh);
        my ($mac) = split /\s+/, $str;
        if ($mac >= $bestMac) {
            $bestMac = $mac;
            $bestStr = $str;
        }
    }

    return $bestStr;
}

sub compute_prf0 {
    my ($P, $Y, $S, $threshold) = @_;

    my %macro = ();
    my %prf = ();
    for (my $n=0; $n<@$P; $n++) {
        my $y = $Y->[$n]; my $p = $P->[$n];
        if ($y>0) { $prf{$S->[$n]}{Y}++; }
        if ($p>$threshold) { $prf{$S->[$n]}{P}++; 
                             if ($y>0) { $prf{$S->[$n]}{I}++; }
        }
    }
    foreach my $s (keys %prf) {
        foreach my $a (keys %{$prf{$s}}) {
            $macro{$a} += $prf{$s}{$a};
        }
    }
    my ($macP, $macR, $macF) = compute_prf1(\%macro);
    my $micP = 0; my $micR = 0; my $micF = 0;
    foreach my $s (keys %prf) {
        my ($p, $r, $f) = compute_prf1(\%{$prf{$s}});
        $micP += $p; $micR += $r; $micF += $f;
    }
    $micP /= scalar keys %prf;
    $micR /= scalar keys %prf;
    $micF /= scalar keys %prf;

    return "$macF $macP $macR <-macroFPR-|-microFPR-> $micF $micP $micR";
}

sub compute_prf1 {
    my ($prf) = @_;
    $prf->{Y} += 0;
    $prf->{P} += 0;
    $prf->{I} += 0;
    my $pre = ($prf->{P} <= 0) ? 1 : ($prf->{I} / $prf->{P});
    my $rec = ($prf->{Y} <= 0) ? 1 : ($prf->{I} / $prf->{Y});
    my $f   = ($pre + $rec > 0) ? (2 * $pre * $rec / ($pre + $rec)) : 0;
    return ($pre,$rec,$f);
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
