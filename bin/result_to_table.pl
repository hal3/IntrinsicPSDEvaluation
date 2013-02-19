#!/usr/bin/perl -w
use strict;

# Average score 0.4864356701825 (std 0.0364538808148435)
# Average FPR: 0.443112331011141 0.413119763939634 0.484733986290199 <-macroFPR-|-microFPR-> 0.393544525390304 0.515347109788055 0.540969809673463
# Std.dev FPR: 0.0542077986977046 0.0698982119073345 0.0399103723990373 <-macroFPR-|-microFPR-> 0.111998027865143 0.172223463274267 0.106393995761347

# bootstrap-mean: 0.501432127693627
# bootstrap-stdd: 0.00314848728379665
# bootstrap-mean: 0.333170035185977 0.246982096359366 0.51192124732176 <-macroFPR-|-microFPR-> 0.336113494115467 0.468520003496778 0.638177862228504
# bootstrap-stdd: 0.00718112929677048 0.00613360525116241 0.0111373411969542 <-macroFPR-|-microFPR-> 0.00920702906927222 0.0115062549440381 0.0112628723088629

while (<>) {
    chomp;
    if (/Average score ([^ ]+) \(std (.+?)\)/) {
        printResult($1, $2, '    % AUC');
    } elsif (/^Average FPR:\s*([^\s]+)\s([^\s]+)\s([^\s]+)\s<-macroFPR-\|-microFPR->\s*([^\s]+)\s([^\s]+)\s([^\s]+)$/) {
        my $mu_maF = $1; my $mu_maP = $2; my $mu_maR = $3;
        my $mu_miF = $4; my $mu_miP = $5; my $mu_miR = $6;
        $_ = <>;
        chomp;
        if (/^Std\.dev FPR:\s*([^\s]+)\s([^\s]+)\s([^\s]+)\s<-macroFPR-\|-microFPR->\s*([^\s]+)\s([^\s]+)\s([^\s]+)$/) {
            my $st_maF = $1; my $st_maP = $2; my $st_maR = $3;
            my $st_miF = $4; my $st_miP = $5; my $st_miR = $6;

            printResult($mu_maP, $st_maP, '    % Macro-P');
            printResult($mu_maR, $st_maR, '    % Macro-R');
            printResult($mu_maF, $st_maF, '    % Macro-F');

            printResult($mu_miP, $st_miP, '    % Macro-P');
            printResult($mu_miR, $st_miR, '    % Macro-R');
            printResult($mu_miF, $st_miF, ' \\\\ % Macro-F');
        } else { die "oops: '$_'"; }
    } elsif (/^bootstrap-mean: ([^\s]+)$/) {
        my $mu_AUC = $1;
        $_ = <>;
        if (/^bootstrap-stdd: ([^\s]+)$/) {
            printResult($mu_AUC, $1, '    % AUC');
        } else { die; }
    } elsif (/^bootstrap-mean:\s*([^\s]+)\s([^\s]+)\s([^\s]+)\s<-macroFPR-\|-microFPR->\s*([^\s]+)\s([^\s]+)\s([^\s]+)$/) {
        my $mu_maF = $1; my $mu_maP = $2; my $mu_maR = $3;
        my $mu_miF = $4; my $mu_miP = $5; my $mu_miR = $6;
        $_ = <>;
        chomp;
        if (/^bootstrap-stdd:\s*([^\s]+)\s([^\s]+)\s([^\s]+)\s<-macroFPR-\|-microFPR->\s*([^\s]+)\s([^\s]+)\s([^\s]+)$/) {
            my $st_maF = $1; my $st_maP = $2; my $st_maR = $3;
            my $st_miF = $4; my $st_miP = $5; my $st_miR = $6;

            printResult($mu_maP, $st_maP, '    % Macro-P');
            printResult($mu_maR, $st_maR, '    % Macro-R');
            printResult($mu_maF, $st_maF, '    % Macro-F');

            printResult($mu_miP, $st_miP, '    % Macro-P');
            printResult($mu_miR, $st_miR, '    % Macro-R');
            printResult($mu_miF, $st_miF, ' \\\\ % Macro-F');
        } else { die "oops: '$_'"; }
    }
}


sub printResult {
    my ($a,$b,$str) = @_;
    print '    & \result{ }{' . fmtNum($a) . '}{' . fmtNum($b) . '}  ' . $str . "\n";
}

sub fmtNum {
    my ($v) = @_;

    if ($v > 100) { die; }
    if ($v < 0) { die; }

    $v = int($v * 10000) / 100;
    if ($v >= 100) { return '100.0'; }
    if ($v =~ /\...$/) { return $v; }
    elsif ($v =~ /\..$/) { return $v . '0'; }
    else { return $v . '.00'; }
}
