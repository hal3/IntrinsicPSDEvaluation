#!/usr/bin/perl -w
use strict;

my $numFolds = 2;
my $doBucketing = 0;
my $experiment = 'exp';

my $pruneMaxCount   = 20;   # keep at most 20 en translations for each fr word
my $pruneMaxProbSum = 0.95; # AND keep at most 95% of the probability mass for p(en|fr)
my $pruneMinRelProb = 0.01; # AND remove english translations that are more than 100* worse than the best one

my $srandNum = 2780;
my $seenFName = "source_data/seen.hansard32.gz";

my $USAGE = "usage: run_experiment.pl (dataspec) (options
where dataspec includes:
  -tr domain       train on data from domain (you can say -tr multiple times)
  -te domain       test on data from domain (you can say -te multiple times)
  -xv domain       cross-validate on domain (you can say -xv multiple times)
you may not use tr/te and xv at the same time, and if you specify training data,
you must also specify test data

where options includes:
  -nf #            number of folds for cross-validation [$numFolds]
  -exp string      experiment name (used for file prefix) [$experiment]
  -pruneMC #       keep at most # en translations for each fr word [$pruneMaxCount]
  -pruneMPS #      keep at most #% of the prob mass of p(en|fr) [$pruneMaxProbSum]
  -pruneMRL #      remove en trans with prob < #*most likely prob [$pruneMinRelProb]
  -noprune         turn off all pruning
  -srand #         seed random number generated with # [$srandNum]
  -seen file       read seen pairs from file [$seenFName]

";

my %trDom = ();
my %teDom  = ();
my %xvDom  = ();

while (1) {
    my $arg = shift or last;
    if    ($arg eq '-tr') { $trDom{shift or die $USAGE} = 1; }
    elsif ($arg eq '-te') { $teDom{shift or die $USAGE} = 1; }
    elsif ($arg eq '-xv') { $xvDom{shift or die $USAGE} = 1; }
    elsif ($arg eq '-nf') { $numFolds = shift or die $USAGE; }
    elsif ($arg eq '-bucket') { $doBucketing = 1; }
    elsif ($arg eq '-exp') { $experiment = shift or die $USAGE; }
    elsif ($arg eq '-pruneMC' ) { $pruneMaxCount = shift or die $USAGE; }
    elsif ($arg eq '-pruneMPS') { $pruneMaxProbSum = shift or die $USAGE; }
    elsif ($arg eq '-pruneMRP') { $pruneMinRelProb = shift or die $USAGE; }
    elsif ($arg eq '-noprune')  { $pruneMaxCount = 100000; $pruneMaxProbSum = 100000; $pruneMinRelProb = -1; }
    elsif ($arg eq '-srand')    { $srandNum = shift or die $USAGE; }
    elsif ($arg eq '-seen')     { $seenFName = shift or die $USAGE; }
    else { die $USAGE; }
}

srand($srandNum);

my $isXV = 0;
if (scalar keys %xvDom == 0) {
    if (scalar keys %trDom == 0) { die $USAGE . "error: no training data!"; }
    if (scalar keys %teDom == 0) { die $USAGE . "error: no test data!"; }

    foreach my $dom (keys %trDom) {
        if (exists $teDom{$dom}) { die $USAGE . "error: train and test on the same domain is disallowed: use xv"; }
    }
} else {
    $isXV = 1;
    if (scalar keys %trDom > 0) { die $USAGE . "error: cannot xv and have training data!"; }
    if (scalar keys %teDom > 0) { die $USAGE . "error: cannot xv and have test data!"; }
}

my %allDom = ();
foreach my $dom (keys %trDom) { $allDom{$dom} = 1; }
foreach my $dom (keys %teDom) { $allDom{$dom} = 1; }
foreach my $dom (keys %xvDom) { $allDom{$dom} = 1; }

if (not -d "source_data") { die "cannot find source_data directory"; }
if (not -d "features")    { die "cannot find features directory"; }
if (not -d "classifiers") { die "cannot find classifiers directory"; }

my %seen = readSeenList();
my %warnUnseen = ();

my @allData = ();
my $N = 0;  my $Np = 0; my $Nn = 0;
foreach my $dom (keys %allDom) {
    my @thisData = generateData($dom);
    for (my $i=0; $i<@thisData; $i++) {
        if ($thisData[$i]{'label'} eq '') { next; }
        %{$allData[$N]} = %{$thisData[$i]};
        $allData[$N]{'domain'} = $dom;
        if    ($allData[$N]{'label'} eq '') {}
        elsif ($allData[$N]{'label'} > 0  ) { $Np++; }
        else                                { $Nn++; }
        $N++;
    }
}

if (scalar keys %warnUnseen > 0) {
    print STDERR "warning: data included " . (scalar keys %warnUnseen) . " unseen french phrases: " . (join ' ', sort keys %warnUnseen) . "\n";
}

if ($N == 0) { die "did not read any data!"; }

print STDERR "Read $N examples ($Np positive and $Nn negative, which is " . (int($Np/$N*1000)/10) . "% positive)\n";

if ($isXV) {
    # assign data points to folds
    my %allPhrases = ();
    for (my $n=0; $n<$N; $n++) {
        $allPhrases{  $allData[$n]{'phrase'}  } = -1;
    }

    my @allPhrases = keys %allPhrases;
    my @fold = ();
    for (my $i=0; $i<@allPhrases; $i++) {
        $fold[$i] = $i % $numFolds;
    }
    for (my $i=0; $i<@allPhrases; $i++) {
        my $j = int($i + rand() * (@allPhrases - $i));
        my $t = $fold[$i];
        $fold[$i] = $fold[$j];
        $fold[$j] = $t;

        $allPhrases{ $allPhrases[$i] } = $fold[$i];
    }

    for (my $n=0; $n<$N; $n++) {
        $allData[$n]{'testfold'} = $allPhrases{ $allData[$n]{'phrase'} };
    }
} else {
    for (my $n=0; $n<$N; $n++) {
        $allData[$n]{'testfold'} = (exists $teDom{  $allData[$n]{'domain'}  }) ? 0 : 1;
    }
    my $numFolds = 1;
}


for (my $fold=0; $fold<$numFolds; $fold++) {
    # training data is everything for which {'testfold'} != fold
    # test data is the rest
    my @train = ();
    my @test  = ();
    for (my $n=0; $n<$N; $n++) {
        if ($allData[$n]{'testfold'} == $fold) { 
            %{$test[@test]} = %{$allData[$n]};
        } else {
            %{$train[@train]} = %{$allData[$n]};
        }
    }
    if (@train ==  0) { die "hit a fold with no training data: try reducing number of folds!"; }
    if (@train == $N) { die "hit a fold with no test data: try reducing number of folds!"; }

    if ($doBucketing) {
        my %bucketInfo = makeBuckets(@train);
        @train = applyBuckets(\%bucketInfo, @train);
        @test  = applyBuckets(\%bucketInfo, @test);
    }

    writeFile("classifiers/$experiment.train", @allData);
    writeFile("classifiers/$experiment.test" , @test);

    # train the classifiers and evaluate
}



sub writeFile {
    my ($fname, @data) = @_;
    open O, "> $fname" or die $!;

    my @perm = ();
    for (my $n=0; $n<@data; $n++) { $perm[$n] = $n;}
    for (my $n=0; $n<@data; $n++) {
        my $m = int($n + rand() * (@data - $n));
        my $t = $perm[$n];
        $perm[$n] = $perm[$m];
        $perm[$m] = $t;
    }


    my $Np = 0; my $Nn = 0;
    for (my $nn=0; $nn<@data; $nn++) {
        my $n = $perm[$nn];
        print O $data[$n]{'label'};
        if ($data[$n]{'label'} > 0) { $Np++; } else { $Nn++; }
        foreach my $f (keys %{$data[$n]}) {
            if ($f =~ /___/) {
                if ($data[$n]{$f} == 0) { next; }
                print O ' ' . $f;
                if ($data[$n]{$f} != 1) {
                    print O ':' . $data[$n]{$f};
                }
            }
        }
        print O "\n";
    }
    close O;
    if ($Np == 0) { print STDERR "warning: generated data with no positive examples in $fname\n"; }
    if ($Nn == 0) { print STDERR "warning: generated data with no positive examples in $fname\n"; }
}

sub generateData {
    my ($dom) = @_;

    my @Y = (); my @W = ();
    open F, "source_data/$dom.psd" or die $!;
    open O, "> source_data/$dom.psd.markedup" or die $!;
    while (<F>) {
        chomp;
        my ($snt_id, $fr_start, $fr_end, $en_start, $en_end, $fr_phrase, $en_phrase) = split /\t/, $_;
        my $Y = '';
        if (not exists $seen{$fr_phrase}) {
            $warnUnseen{$fr_phrase} = 1;
        } else {
            $Y = (exists $seen{$fr_phrase}{$en_phrase}) ? -1 : 1;
        }
        print O $Y . "\t" . $_ . "\n";

        push @W, $fr_phrase;
        push @Y, $Y;
    }
    close F;
    close O;
    
    my %type = ();
    open LS, "find features/ -iname \"$dom.type.*\" |" or die $!;
    while (my $fname = <LS>) {
        $fname =~ /^$dom\.type\.(.+)$/;
        my $user = $1;
        
        print STDERR "Reading features from $fname\n";
        open F, $fname or die $!;
        while (<F>) {
            chomp;
            my ($fr_phrase,@feats) = split;
            foreach my $fval (@feats) {
                my ($f,$val) = split_fval($fval);
                $type{$fr_phrase}{$user . '___type_' . $f} = $val;
            }
        }
        close F;
    }
    close LS;

    my @F = ();
    for (my $n=0; $n<@W; $n++) {
        %{$F[$n]} = ();
        $F[$n]{'label'} = $Y[$n];
        if ($Y[$n] eq '') { next; }
        $F[$n]{'phrase'} = $W[$n];
        if (exists $type{$W[$n]}) {
            foreach my $f (keys %{$type{$W[$n]}}) {
                $F[$n]{$f} = $type{$W[$n]}{$f};
            }
        }
        $F[$n]{'___bias'} = 1;
    }

    open LS, "find features/ -iname \"$dom.token.*\" |" or die $!;
    while (my $fname = <LS>) {
        $fname =~ /^$dom\.token\.(.+)$/;
        my $user = $1;
        
        my $n = 0;
        print STDERR "Reading features from $fname\n";
        open F, $fname or die $!;
        while (<F>) {
            chomp;
            if ($n >= @F) { 
                print STDERR "error: too many lines in file $fname, ignoring the rest but things are wacky and you should harangue someone about this...\n";
                last;
            }
            my @feats = split;
            foreach my $fval (@feats) {
                my ($f,$val) = split_fval($fval);
                $F[$n]{$user . '___token_' . $f} = $val;
            }
            $n++;
        }
        close F;
        if ($n < @F) {
            print STDERR "error: too few lines in file $fname... things are wacky and you should harangue someone about this...\n";
        }
    }
    close LS;

    return (@F);
}

sub split_fval {
    my ($str) = @_;
    my $f = $str;
    my $v = 1;
    if ($str =~ /^(.+):([0-9\.]+)$/) {
        $f = $1;
        $v = $2;
    }
    return ($f,$v);
}

sub readSeenList {
    open F, "zcat $seenFName|" or die $!;
    my %seenTmp = ();
    while (<F>) {
        chomp;
        my ($fr_phrase, $en_phrase, $p_e_given_f) = split /\t/, $_;
        if (defined $p_e_given_f) {
            $seenTmp{$fr_phrase}{$en_phrase} = $p_e_given_f;
        }
    }
    close F;

    my %seen = ();
    foreach my $fr (keys %seenTmp) {
        # re-normalize
        my $sum = 0;
        foreach my $v (values %{$seenTmp{$fr}}) { $sum += $v; }
        foreach my $en (keys %{$seenTmp{$fr}}) { $seenTmp{$fr}{$en} /= $sum; }

        my @en = sort { $seenTmp{$fr}{$b} <=> $seenTmp{$fr}{$a} } keys %{$seenTmp{$fr}};
        if (scalar @en == 0) { next; }
        my $topProb = $seenTmp{$fr}{$en[0]};

        $seen{$fr}{$en[0]} = 1;
        my $count = 1; my $psum = $topProb;
        while (($count < $pruneMaxCount) &&
               ($psum  < $pruneMaxProbSum) && 
               ($count < @en)) {
            my $en = $en[$count];
            if ($seenTmp{$fr}{$en} / $topProb < $pruneMinRelProb) { last; }
            $seen{$fr}{$en} = 1;
            $count++;
            $psum += $seenTmp{$fr}{$en};
        }
    }

    return (%seen);
}

sub makeBuckets {
}
