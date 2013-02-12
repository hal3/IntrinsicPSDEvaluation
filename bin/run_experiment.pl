#!/usr/bin/perl -w
use strict;

my $numFolds = 8;
my $doBucketing = 1;
my $experiment = 'exp';
my $classifier = 'vw';
my $showclassifier = 0;
my $evensplit = 1;
my $regularize = 1;
my $maxBuckets = 10;
my %ignoreFeatures = ();
my $maxTokPerType = 10;
my $mostFreqSenseEval = 0;
my $quiet = 0;

my $pruneMaxCount   = 20;    # keep at most 20 en translations for each fr word
my $pruneMaxProbSum = 0.95;  # AND keep at most 95% of the probability mass for p(en|fr)
my $pruneMinRelProb = 0.01;  # AND remove english translations that are more than 100* worse than the best one
my $doPrune = 0;

my $srandNum = 2780;
my $seenFName = "source_data/seen.hansard.gz";

my $USAGE = "usage: run_experiment.pl (dataspec) (options)

where dataspec includes:
  -tr domain       train on data from domain (you can say -tr multiple times)
  -te domain       test on data from domain (you can say -te multiple times)
  -xv domain       cross-validate on domain (you can say -xv multiple times)
you may not use tr/te and xv at the same time, and if you specify training data,
you must also specify test data

where options includes:
  -nf #            number of folds for cross-validation [$numFolds]
  -maxbuckets #    make at most # buckets per feature [$maxBuckets]
  -exp str         experiment name (used for file prefix) [$experiment]
  -seen file       read seen pairs from file [$seenFName]
  -ignore str      ignore features named string (multiple allowed)
  -srand #         seed random number generated with # or X for prng [$srandNum]
  -classifier str  specify classifier to use [$classifier] (eg: vw, bfgw, dt, oracleType)
  -showclassifier  show output from classifier
  -dontbucket      bucket features (make them all binary)
  -dontevensplit   don't run the (hacky) thing for making even splits
  -dontregularize  turn of (search for) regularization parameters
  -maxtokpertype # only keep at most # tokens for each unique type [$maxTokPerType]
  -mfs             change eval to 'is this OLD mfs'? [def: is this a new sense?]
  -q               be (sort of) quiet

  -pruneMC #       keep at most # en translations for each fr word [$pruneMaxCount]
  -pruneMPS #      keep at most #% of the prob mass of p(en|fr) [$pruneMaxProbSum]
  -pruneMRL #      remove en trans with prob < #*most likely prob [$pruneMinRelProb]
  -prune           turn on pruning (turned on by default if you specify any other -prune*)

";

my %trDom = ();
my %teDom  = ();
my %xvDom  = ();

while (1) {
    my $arg = shift or last;
    if    ($arg eq '-tr') { $trDom{shift or die "-tr needs an argument"} = 1; }
    elsif ($arg eq '-te') { $teDom{shift or die "-te needs an argument"} = 1; }
    elsif ($arg eq '-xv') { $xvDom{shift or die "-xv needs an argument"} = 1; }
    elsif ($arg eq '-nf') { $numFolds = shift or die "-nf needs an argument"; }
    elsif ($arg eq '-dontbucket') { $doBucketing = 0; }
    elsif ($arg eq '-maxbuckets') { $maxBuckets = shift or die "-maxbuckets needs an argument"; }
    elsif ($arg eq '-exp') { $experiment = shift or die "-exp needs an argument"; }
    elsif ($arg eq '-maxtokpertype') { $maxTokPerType = shift or die "-maxtokpertype needs an argument"; }
    elsif ($arg eq '-pruneMC' ) { $pruneMaxCount = shift or die "-pruneMC needs an argument"; $doPrune = 1; }
    elsif ($arg eq '-pruneMPS') { $pruneMaxProbSum = shift or die "-pruneMPS needs an argument"; $doPrune = 1; }
    elsif ($arg eq '-pruneMRP') { $pruneMinRelProb = shift or die "-pruneMRP needs an argument"; $doPrune = 1; }
    elsif ($arg eq '-prune')    { $doPrune = 1; }
    elsif ($arg eq '-noprune')  { $pruneMaxCount = 100000; $pruneMaxProbSum = 100000; $pruneMinRelProb = -1; }
    elsif ($arg eq '-srand')    { $srandNum = shift or die "-srand needs an argument"; }
    elsif ($arg eq '-seen')     { $seenFName = shift or die "-seen needs an argument"; }
    elsif ($arg eq '-ignore')   { $ignoreFeatures{shift or die "-ignore needs an argument"} = 1; }
    elsif ($arg eq '-classifier')  { $classifier = shift or die "-classifier needs an argument"; }
    elsif ($arg eq '-showclassifier') { $showclassifier = 1; }
    elsif ($arg eq '-dontevensplit') { $evensplit = 0; }
    elsif ($arg eq '-dontregularize') { $regularize = 0; }
    elsif ($arg eq '-mfs') { $mostFreqSenseEval = 1; }
    elsif ($arg eq '-q') { $quiet = 1; }
    else { die $USAGE; }
}

if ($srandNum eq 'X') { srand(); }
else { srand($srandNum); }

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

my %seen_or_mfs = ();
if ($mostFreqSenseEval) {
    %seen_or_mfs = readMFSList();
} else {
    %seen_or_mfs = readSeenList();
}

my %warnUnseen = ();
my %numTypes = ();

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
    print STDERR "warning: data included " . (scalar keys %warnUnseen) . " unseen french phrases";
    print STDERR ': ' . (join ' ', sort keys %warnUnseen) if not $quiet;
    print STDERR "\n";
}

if ($N == 0) { die "did not read any data!"; }

print STDERR "Read $N examples ($Np positive and $Nn negative, which is " . (int($Np/$N*1000)/10) . "% positive)\n" if not $quiet;

if ($isXV) {
    if ($evensplit) {
        doEvenSplit();
    } else {
        doUnevenSplit();
    }
} else {
    for (my $n=0; $n<$N; $n++) {
        $allData[$n]{'testfold'} = 1;
        $allData[$n]{'devfold' } = 1;
        if (exists $teDom{ $allData[$n]{'domain'} }) {
            $allData[$n]{'testfold'} = 0;
        } elsif (rand() < 0.11111) {
            $allData[$n]{'devfold'} = 0;
            $allData[$n]{'testfold'} = 2;
        }
    }
    $numFolds = 1;
}

=pod
my %foldSize = ();
for (my $n=0; $n<$N; $n++) {
    $foldSize{ $allData[$n]{'testfold'} }++;
}
=cut

my @aucs = ();
for (my $fold=0; $fold<$numFolds; $fold++) {
    print STDERR "===== FOLD " . ($fold+1) . " / $numFolds =====\n" if ($numFolds > 1) && (not $quiet);

    my @train = ();
    my @dev   = ();
    my @test  = ();

=pod
    # test data is that for which testfold==fold
    # for all fold' != fold, find the SMALLEST one and make that dev
    # the rest is train

    my $devFold = '';
    foreach my $f (keys %foldSize) {
        if ($f == $fold) { next; }
        if (($devFold eq '') || ($foldSize{$f} < $foldSize{$devFold})) {
            $devFold = $f;
        }
    }


    for (my $n=0; $n<$N; $n++) {
        if ($allData[$n]{'testfold'} == $fold) { 
            %{$test[@test]} = %{$allData[$n]};
        } elsif ($allData[$n]{'testfold'} == $devFold) {
            %{$dev[@dev]} = %{$allData[$n]};
        } else {
            %{$train[@train]} = %{$allData[$n]};
        }
    }
=cut

    # training data is everything for which {'testfold'} != fold
    # test data is the rest
    for (my $n=0; $n<$N; $n++) {
        if ($allData[$n]{'testfold'} == $fold) { 
            %{$test[@test]} = %{$allData[$n]};
        } elsif ($allData[$n]{'devfold'} == $fold) { 
            %{$dev[@dev]} = %{$allData[$n]};
        } else {
            %{$train[@train]} = %{$allData[$n]};
        }
    }


    if (@train ==  0) { die "hit a fold with no training data: try reducing number of folds!"; }
    if (@dev   ==  0) { die "hit a fold with no dev data: try reducing number of folds!"; }
    if (@test  ==  0) { die "hit a fold with no test data: try reducing number of folds!"; }

    my @traindev = ();
    foreach my $x (@train) { push @traindev, $x; }
    foreach my $x (@dev  ) { push @traindev, $x; }

    if ($doBucketing) {
        my %bucketInfo = makeBuckets(@train);
        @train    = applyBuckets(\%bucketInfo, \@train);
        @dev      = applyBuckets(\%bucketInfo, \@dev);
        @traindev = applyBuckets(\%bucketInfo, \@traindev);
        @test     = applyBuckets(\%bucketInfo, \@test);

        open O, "> classifiers/$experiment.buckets" or die $!;
        foreach my $f (sort keys %bucketInfo) {
            print O $f . "\t" . (join "\t", sort { $a <=> $b } keys %{$bucketInfo{$f}}) . "\n";
        }
        close O;

    }

    my $auc;
    if ($classifier ne 'oracleType') {
        writeFile("classifiers/$experiment.train", @train);
        writeFile("classifiers/$experiment.traindev", @traindev);
        writeFile("classifiers/$experiment.dev"  , @dev);
        writeFile("classifiers/$experiment.test" , @test);

        if (($classifier eq 'vw') || ($classifier eq 'bfgs')) {
            $auc = run_vw($fold,
                          "classifiers/$experiment.train",    scalar @train,
                          "classifiers/$experiment.dev",      scalar @dev,
                          "classifiers/$experiment.traindev", scalar @traindev,
                          "classifiers/$experiment.test",     scalar @test
                );
        } elsif ($classifier eq 'dt') {
            $auc = run_dt($fold,
                          "classifiers/$experiment.train",    scalar @train,
                          "classifiers/$experiment.dev",      scalar @dev,
                          "classifiers/$experiment.traindev", scalar @traindev,
                          "classifiers/$experiment.test",     scalar @test
                );
        } else {
            die "unknown classifier '$classifier'";
        }
    } else {
        $auc = compute_oracleType(\@traindev, \@test);
    }
    push @aucs, $auc;
    print STDERR "\n" if not $quiet;
}

my $avgAuc = 0;
my $stdAuc = 0;
foreach my $auc (@aucs) { $avgAuc += $auc; $stdAuc += $auc*$auc; }
$avgAuc /= $numFolds;
$stdAuc = sqrt($stdAuc / $numFolds - $avgAuc*$avgAuc);
print "Average score $avgAuc (std $stdAuc)\n";

sub compute_oracleType {
    my ($trainDev, $test) = @_;

    my %type = ();
    for (my $n=0; $n<@$trainDev; $n++) {
        my $y = $trainDev->[$n]{'label'};
        my $w = $trainDev->[$n]{'phrase'};
        $type{$w} += $y;
    }

    open ORAC, "> classifiers/.tmpforauc" or die;
    for (my $n=0; $n<@$test; $n++) {
        my $y = $test->[$n]{'label'};
        my $w = $test->[$n]{'phrase'};
        my $yhat = rand() * 2 - 1;
        if (defined $type{$w}) {
            $yhat = $type{$w};
        }
        print ORAC $yhat . ' ' . $y . "\n";
    }
    close ORAC or die;
    my $auc = `cat classifiers/.tmpforauc | bin/auc.pl`;
    chomp $auc;
    return $auc;
}


sub run_vw {
    my ($fold, $trF, $trN, $deF, $deN, $trdeF, $trdeN, $teF, $teN) = @_;

    my $numPasses = 20;
    my $VWX = 'bin/vwx --vw /export/ws12/damt/src/vowpal_wabbit/vowpalwabbit/vw';
    
    my $largeReg = 10 / $trN;
    my $stepReg = $largeReg / 5;

    my $searchArgs = "--passes 20 --orsearch --l1 0. $largeReg +$stepReg --l2 $stepReg $largeReg +$stepReg";
    if (! $regularize) { $searchArgs = "--passes 20"; }

    my $bestScore; my $bestPass; my $bestConfig;
    my $cmd = "$VWX -d $trF --dev $deF --eval auroc --logistic $searchArgs";
    if ($classifier eq 'bfgs') { $cmd .= ' --args --bfgs'; }
    print STDERR "Running: $cmd\n" if not $quiet;
    open VWX, "$cmd 2>&1 |" or die;
    while (<VWX>) {
        print STDERR "." if (not $showclassifier) && (not $quiet);
        print STDERR "vwx>> $_" if $showclassifier;
        chomp;
        if (/overall best loss \(.*\) ([^ ]+) pass ([0-9]+)/) {
            $bestScore = 1-$1;
            $bestPass = $2+1;
            if (/with config (.+)/) {
                $bestConfig = $1;
            } else { $bestConfig = ''; }
        }
    }
    close VWX;
    if (not defined $bestScore) { die "vwx didn't succeed"; }
    print STDERR "\ndev  score = $bestScore on pass $bestPass with config $bestConfig\n" if not $quiet;


    my $score;
    $cmd = "$VWX -d $trdeF --dev $teF --eval auroc --logistic --passes $bestPass --noearlystop --readable classifiers/$experiment.fold=$fold.vwmodel --args $bestConfig";
    if ($classifier eq 'bfgs') { $cmd .= ' --bfgs'; }
    print STDERR "Running: $cmd\n"  if not $quiet;
    open VWX, "$cmd 2>&1 |" or die;
    while (<VWX>) {
        print STDERR "." if (not $showclassifier) && (not $quiet);
        print STDERR "vwx>> $_" if $showclassifier;
        chomp;
        if (/overall best loss \(.*\) ([^ ]+) pass/) {
            $score = 1-$1;
        }
    }
    close VWX;

    if (not defined $score) { die "vwx didn't succeed"; }

    print STDERR " \n"  if not $quiet;
    print "fold $fold score = $score\n";
    return $score;
}

sub run_dt {
    my ($fold, $trF, $trN, $deF, $deN, $trdeF, $trdeN, $teF, $teN) = @_;

    if (! $regularize) {
        my $auc = get_dt_auc($trdeF, $teF, '-maxd 10');
        print STDERR "test score = $auc\n";
        return $auc;
    }

    my @numBag = (2, 4, 8);
    my @numBoost = (1, 2, 4, 8);
    my @numDepth = (1, 2, 3, 4, 5, 6, 8, 10);

    my $bestAUC = get_dt_auc($trF, $deF, '');
    my $bestSettings = '';
    foreach my $depth (@numDepth) {
        my $settings0 = '-maxd ' . $depth;

        foreach my $bag (@numBag) {
            my $settings = $settings0 . ' -bag ' . $bag;
            my $auc = get_dt_auc($trF, $deF, $settings);
            if ($auc > $bestAUC) {
                $bestAUC = $auc;
                $bestSettings = $settings;
            }
        }

        foreach my $boost (@numBoost) {
            my $settings = $settings0 . ' -boost ' . $boost;
            my $auc = get_dt_auc($trF, $deF, $settings);
            if ($auc > $bestAUC) {
                $bestAUC = $auc;
                $bestSettings = $settings;
            }
        }
    }

    print STDERR "\ndev  score = $bestAUC with config $bestSettings\n";

    my $auc = get_dt_auc($trF, $teF, $bestSettings);
    print STDERR "\ntest score = $auc\n";
    return $auc;
}

sub get_dt_auc {
    my ($trF, $teF, $settings) = @_;

    my $cmd = "bin/FastDT $settings $trF > $trF.dt";
    print STDERR "running: $cmd\n" if $showclassifier;
    open F, "($cmd) 2>&1 |" or die $!;
    while (<F>) {
        print STDERR "." if not $showclassifier;
        print STDERR "dt>>> $_" if $showclassifier;
    }
    close F;

    $cmd = "bin/FastDT -load $trF.dt $teF > $teF.pred";
    print STDERR "running: $cmd\n" if $showclassifier;
    open F, "($cmd) 2>&1 |" or die $!;
    while (<F>) {
        print STDERR "." if not $showclassifier;
        print STDERR "dt>>> $_" if $showclassifier;
    }
    close F;

    my $auc = `paste $teF.pred $teF | bin/auc.pl`;
    chomp $auc;
    return $auc;
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

        if (($classifier eq 'vw') || ($classifier eq 'bfgs'))  { print O ' |'; }

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
    if ($Nn == 0) { print STDERR "warning: generated data with no negative examples in $fname\n"; }
#    print STDERR "$fname:\t$Np positive\t$Nn negative\t" . (int(1000*$Np/($Np+$Nn))/10) . "% positive\n";
}

sub generateData {
    my ($dom) = @_;

    my @Y = (); my @W = ();
    open F, "source_data/$dom.psd" or die $!;
#    open O, "> source_data/$dom.psd.markedup" or die $!;
    while (<F>) {
        chomp;
        my ($snt_id, $fr_start, $fr_end, $en_start, $en_end, $fr_phrase, $en_phrase) = split /\t/, $_;
        my $Y = '';
        if ($mostFreqSenseEval) {
            if (not exists $seen_or_mfs{$fr_phrase}) {
                $warnUnseen{$fr_phrase} = 1;
            } else {
                $Y = (exists $seen_or_mfs{$fr_phrase}{$en_phrase}) ? -1 : 1;
            }
        } else {
            if (not exists $seen_or_mfs{$fr_phrase}) {
                $warnUnseen{$fr_phrase} = 1;
            } else {
                $Y = (exists $seen_or_mfs{$fr_phrase}{$en_phrase}) ? -1 : 1;
            }
        }
#        print O $Y . "\t" . $_ . "\n";

        push @W, $fr_phrase;
        push @Y, $Y;
    }
    close F;
#    close O;
    
    my %type = ();
    my $domReal = $dom; $domReal =~ s/-(old|big)//;
    open LS, "find features/ -iname \"$domReal.type.*\" |" or die $!;
    while (my $fname = <LS>) {
        chomp $fname;
        $fname =~ /\/$domReal\.type\.(.+)$/;
        my $user = $1;
        if (not defined $user) { print STDERR "skipping file $fname...\n"  if not $quiet;; next; }
        if (exists $ignoreFeatures{$user}) {
            print STDERR "Skipping features from $fname\n" if not $quiet;
            next;
        }
        
        print STDERR "Reading features from $fname\n" if not $quiet;
        open F, $fname or die $!;
        while (<F>) {
            chomp;
            if (/^([^\t]+)\t(.+)$/) {
                my $fr_phrase = $1;
                my @feats = split /\s+/, $2;
                foreach my $fval (@feats) {
                    my ($f,$val) = split_fval($fval);
                    $type{$fr_phrase}{$user . '___type_' . $f} = $val;
                }
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

    open LS, "find features/ -iname \"$domReal.token.*\" |" or die $!;
    while (my $fname = <LS>) {
	chomp $fname;
        $fname =~ /^(.+)\.token\.(.+)$/;
        #$fname =~ /\/^$domReal\.token\.(.+)$/;
        my $user = $2;
        if (not defined $user) { print STDERR "skipping token file with name $fname ...\n" if not $quiet; next; }

        if (exists $ignoreFeatures{$user}) {
            print STDERR "Skipping features from $fname\n" if not $quiet;
            next;
        }

        my $n = 0;
        print STDERR "Reading features from $fname\n" if not $quiet;
        open F, $fname or die $!;
        while (<F>) {
            chomp;
            my @feats = split;
            if ($n < @F) {
                foreach my $fval (@feats) {
                    my ($f,$val) = split_fval($fval);
                    $F[$n]{$user . '___token_' . $f} = $val;
                }
            }
            $n++;
        }
        close F;
        if ($n > @F) { 
            print STDERR "error: too many lines in file $fname, ignoring the rest but things are wacky and you should harangue someone about this ($n versus " . (scalar @F) . ")...\n";
        }
        if ($n < @F) {
            print STDERR "error: too few lines in file $fname... things are wacky and you should harangue someone about this ($n versus " . (scalar @F) . ")...\n";
        }
    }
    close LS;

    my @Fpruned = ();
    for (my $n=0; $n<@F; $n++) {
        my $p = $F[$n]{'phrase'};
        
        if ((defined $numTypes{$p}) && ($numTypes{$p} >= $maxTokPerType)) { next; }
        $numTypes{$p}++;

        my $n0 = scalar @Fpruned;
        foreach my $k (keys %{$F[$n]}) {
            $Fpruned[$n0]{$k} = $F[$n]{$k};
        }
    }

    return (@Fpruned);
}

sub split_fval {
    my ($str) = @_;
    my $f = $str;
    my $v = 1;
    if ($str =~ /^(.+):(-?[0-9\.e+-]+)$/) {
        $f = $1;
        $v = $2;
    }
    return ($f,$v);
}

sub readMFSList {
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

    my %mfs = ();
    foreach my $fr (keys %seenTmp) {
        my $maxP = -1;
        foreach my $v (values %{$seenTmp{$fr}}) {
            if ($v > $maxP) { $maxP = $v; }
        }
        if ($maxP < 0) { next; }
        foreach my $en (keys %{$seenTmp{$fr}}) {
            if ($seenTmp{$fr}{$en} >= $maxP) {
                $mfs{$fr}{$en} = 1;
            }
        }
    }

    return (%mfs);
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

    if (not $doPrune) { return (%seenTmp); }

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

sub applyBuckets {
    my ($bucketInfo, $data) = @_;

    my @data_new = ();
    for (my $n=0; $n<@$data; $n++) {
        %{$data_new[$n]} = ();
        foreach my $f (keys %{$data->[$n]}) {
            if (not ($f =~ /___/)) { 
                $data_new[$n]{$f} = $data->[$n]{$f};
                next;
            }
            if (not defined $bucketInfo->{$f}) { 
                print STDERR "warning: no bucket info for '$f' -- skipping\n";
                next;
            }
            my $v = $data->[$n]{$f};
            foreach my $vmin (keys %{$bucketInfo->{$f}}) {
                if ($v >= $vmin) {
                    $data_new[$n]{$f . '>=' . $vmin} = 1;
                }
            }
        }
    }


    return (@data_new);
}

sub makeBuckets {
    my (@data) = @_;
    my %fvals = ();
    for (my $n=0; $n<@data; $n++) {
        foreach my $f (keys %{$data[$n]}) {
            if (not ($f =~ /___/)) { next; }
            $fvals{$f}{$data[$n]{$f}}++;
        }
    }
    for (my $n=0; $n<@data; $n++) {
        foreach my $f (keys %fvals) {
            if (not defined $data[$n]{$f}) {
                $fvals{$f}{0}++;
            }
        }
    }

    my %bucketInfo = ();
    foreach my $f (keys %fvals) {
        my @l = ();
        foreach my $v (keys %{$fvals{$f}}) {
            for (my $i=0; $i<$fvals{$f}{$v}; $i++) { push @l, $v; }
        }
        @l = sort @l;

        my $i = 0;
        my $step = (scalar @l) / $maxBuckets;
        if ($step < 1) { $step = 1; }
        while (int($i) < @l) {
            my $v = $l[int($i)];
            $bucketInfo{$f}{$v} = 1;
            $i += $step;
        }
    }

    return (%bucketInfo);
}


sub log0 {
    my ($v) = @_;
    if ($v <= 0) { return 0; }
    return log($v);
}

sub doEvenSplit {
    # replace numfolds with a power of 2
    my $oldNumFolds = $numFolds;
    my $logNumFolds = int(log($numFolds) / log(2));
    $numFolds = 2 ** $logNumFolds;
    if ($numFolds != $oldNumFolds) {
        print STDERR "warning: using $numFolds instead of $oldNumFolds (need a power of 2 for even splitting)\n";
        #if ($numFolds < 3) { die "cannot have fewer than 3 folds!!!"; }
    }

    my %typeSize = ();
    my %availableTypes = ();
    for (my $n=0; $n<$N; $n++) {
        my $type = $allData[$n]{'phrase'};
        $typeSize{ $type }{N} += ( $allData[$n]{'label'} > 0 ) ? 0 : 1;
        $typeSize{ $type }{P} += ( $allData[$n]{'label'} > 0 ) ? 1 : 0;
        $typeSize{ $type }{A} += 1;
        $availableTypes{ $type } = 1;
    }

    my %splitTree = doEvenSplit_rec(\%typeSize, $logNumFolds, \%availableTypes);
    my %typeToFold = ();
    doEvenSplit_assignFolds(\%splitTree, \%typeToFold, 0);

    my %foldInfo = ();
    for (my $n=0; $n<$N; $n++) {
        my $type = $allData[$n]{'phrase'};
        if (not defined $typeToFold{$type}) { die "type $type did not get a fold!"; }
        my $f = $typeToFold{$type};
        $allData[$n]{'devfold'}  = $f;
        $allData[$n]{'testfold'} = ($f+1) % $numFolds;
#        $allData[$n]{'testfold'}  = $f;
        $foldInfo{$f}{N} += ( $allData[$n]{'label'} > 0 ) ? 0 : 1;
        $foldInfo{$f}{P} += ( $allData[$n]{'label'} > 0 ) ? 1 : 0;
        $foldInfo{$f}{A} += 1;
        $foldInfo{$f}{T}{$type} = 1;
    }
#    foreach my $f (sort { $a <=> $b } keys %foldInfo) {
#        print STDERR "$f:\t" . (join "\t", ($foldInfo{$f}{A}, $foldInfo{$f}{N}/$foldInfo{$f}{A}, $foldInfo{$f}{P}/$foldInfo{$f}{A}, scalar keys %{$foldInfo{$f}{T}})) . "\n";
#    }
}

sub doEvenSplit_assignFolds {
    my ($tree, $typeToFold, $curFold) = @_;
    if (defined $tree->{TYPES}) {
        foreach my $type (keys %{$tree->{TYPES}}) {
            $typeToFold->{$type} = $curFold;
        }
        return $curFold+1;
    }
    $curFold = doEvenSplit_assignFolds(\%{$tree->{LEFT }}, $typeToFold, $curFold);
    $curFold = doEvenSplit_assignFolds(\%{$tree->{RIGHT}}, $typeToFold, $curFold);
    return $curFold;
}

sub doEvenSplit_rec {
    my ($typeSize, $splitsToGo, $availableTypes) = @_;
    my %this = ();
    if (($splitsToGo <= 0) || (scalar keys %$availableTypes < 2)) {
        %{$this{TYPES}} = %$availableTypes;
        return (%this);
    }

=pod
    my %side = ();
    {
        my ($t0) = sort { $typeSize->{$a}{A} <=> $typeSize->{$b}{A} } keys %$availableTypes;
        delete $availableTypes->{$t0};
        push @{$side{0}}, $t0;
        @{$side{1}} = ();
    }

    while (scalar keys %$availableTypes > 0) {
        my $bestScore = 0;
        my $bestType  = '';
        my $bestSide  = '';
        foreach my $s (0, 1) {
            foreach my $t (keys %$availableTypes) {
                push @{$side{$s}}, $t;
                my $score = evenSplitQuality($typeSize, \@{$side{0}}, \@{$side{1}});
                if (($bestType eq '') || ($score > $bestScore)) {
                    $bestScore = $score;
                    $bestType  = $t;
                    $bestSide  = $s;
                }
                pop @{$side{$s}};
            }
        }
        print STDERR "bestScore = $bestScore, bestType = $bestType, bestSide = $bestSide\n";
        push @{$side{$bestSide}}, $bestType;
        delete $availableTypes->{$bestType};
    }
=cut


    my @nextTypes = sort { $typeSize->{$a}{A} <=> $typeSize->{$b}{A} } keys %$availableTypes;
    my %side = ();
    @{$side{0}} = ();    @{$side{1}} = ();
    {
        my $t = pop @nextTypes;
        push @{$side{0}}, $t;
    }

    while (scalar @nextTypes > 0) {
        my $t = pop @nextTypes;
        my $bestScore = 0;
        my $bestSide  = '';
        foreach my $s (0, 1) {
            push @{$side{$s}}, $t;
            my $score = evenSplitQuality($typeSize, \@{$side{0}}, \@{$side{1}});
            if (($bestSide eq '') || ($score > $bestScore)) {
                $bestScore = $score;
                $bestSide  = $s;
            }
            pop @{$side{$s}};
        }
        #print STDERR "bestScore = $bestScore, bestSide = $bestSide\n";
        push @{$side{$bestSide}}, $t;
    }


=pod
    my %side = ();
    {
        my $t0 = popRandomKey($availableTypes);
        push @{$side{0}}, $t0;
        @{$side{1}} = ();
    }

    my $s = 1;
    while (scalar keys %$availableTypes > 0) {
        my $bestScore = 0;
        my $bestType  = '';
        foreach my $t (keys %$availableTypes) {
            push @{$side{$s}}, $t;
            my $score = evenSplitQuality($typeSize, \@{$side{0}}, \@{$side{1}});
            if (($bestType eq '') || ($score > $bestScore)) {
                $bestScore = $score;
                $bestType  = $t;
            }
            pop @{$side{$s}};
        }
        print STDERR "bestScore = $bestScore, bestType = $bestType\n";
        push @{$side{$s}}, $bestType;
        delete $availableTypes->{$bestType};
        $s = 1-$s;
    }
=cut

    my %left = (); foreach my $x (@{$side{0}}) { $left{$x} = 1; }
    my %right = (); foreach my $x (@{$side{1}}) { $right{$x} = 1; }
    %{$this{LEFT}}  = doEvenSplit_rec($typeSize, $splitsToGo-1, \%left);
    %{$this{RIGHT}} = doEvenSplit_rec($typeSize, $splitsToGo-1, \%right);
    return (%this);
}

sub popRandomKey {
    my ($h) = @_;
    my @k = keys %$h;
    if (@k == 0) { return undef; }
    my $i = int(rand() * scalar @k);
    delete $h->{$k[$i]};
    return $k[$i];
}

sub evenSplitQuality {
    my ($typeSize, $leftIDs, $rightIDs) = @_;

    my %leftInfo = (N => 0, P => 0, A => 0);
    foreach my $type (@$leftIDs) {
        $leftInfo{N} += $typeSize->{$type}{N};
        $leftInfo{P} += $typeSize->{$type}{P};
        $leftInfo{A} += $typeSize->{$type}{A};
    }
    $leftInfo{N} /= $leftInfo{A} if $leftInfo{A} > 0;
    $leftInfo{P} /= $leftInfo{A} if $leftInfo{A} > 0;

    my %rightInfo = (N => 0, P => 0, A => 0);
    foreach my $type (@$rightIDs) {
        $rightInfo{N} += $typeSize->{$type}{N};
        $rightInfo{P} += $typeSize->{$type}{P};
        $rightInfo{A} += $typeSize->{$type}{A};
    }
    $rightInfo{N} /= $rightInfo{A} if $rightInfo{A} > 0;
    $rightInfo{P} /= $rightInfo{A} if $rightInfo{A} > 0;

    my $nAvg = ($leftInfo{N} + $rightInfo{N}) / 2;
    my $pAvg = ($leftInfo{P} + $rightInfo{P}) / 2;

    my $klLeft  = (($leftInfo{N} <= 0) ? 0 : ( $leftInfo{N} * log0( $leftInfo{N} / $nAvg ) )) +
                  (($leftInfo{P} <= 0) ? 0 : ( $leftInfo{P} * log0( $leftInfo{P} / $pAvg ) ));
    my $klRight = (($rightInfo{N} <= 0) ? 0 : ( $rightInfo{N} * log0( $rightInfo{N} / $nAvg ) )) +
                  (($rightInfo{P} <= 0) ? 0 : ( $rightInfo{P} * log0( $rightInfo{P} / $pAvg ) ));

    my $js = ( $klLeft + $klRight ) / 2;
    my $sizeDiff = abs($leftInfo{A} - $rightInfo{A});

#    print STDERR "> $nAvg $pAvg $klLeft $klRight | $leftInfo{N} $leftInfo{P} $rightInfo{N} $rightInfo{P} | " . 
#        (join ' : ', ( $leftInfo{N}/($nAvg+0.0001) , $leftInfo{P} / ($pAvg+0.0001), $rightInfo{N} / ($nAvg+0.0001), $rightInfo{P} / ($pAvg+0.0001) ));
#    print STDERR "\n> js = $js, sizeDiff = $sizeDiff -> " . (exp(-$sizeDiff / scalar keys %$typeSize)) . "\n";
    return (-10*$js - ($sizeDiff / scalar keys %$typeSize)/10000);
}

sub doUnevenSplit {
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
        $allData[$n]{'devfold' } = (1+$allPhrases{ $allData[$n]{'phrase'} }) % $numFolds;
    }
}
