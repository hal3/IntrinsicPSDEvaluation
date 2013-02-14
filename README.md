If you're making features, you need to read information from the
source_data/ directory to generate it.  As in everything, there are
three domains of data: EMEA, Science, Subs.  For each of these, we
have three files: xxx.en.gz and xxx.fr.gz (sentences) and xxx.psd
(word information).  The psd format is Marine's:

  snt_id  fr_start  fr_end  en_start  en_end  fr_phrase  en_phrase

Note: you should NOT use any of the ENGLISH information in generating
your features or you'll be cheating :).

You should read these files and create TYPE and TOKEN level features,
placed in the features directory.  You should create files with names
like:

  features/EMEA.type.hal
  features/EMEA.token.hal

and so on.

The "type" file should be one-word-type per line (order doesn't
matter) where the first column (tab separated) is the word type, and
all other columns (space/tab separated) are features.  The "token"
file should be one-token per line (order IDENTICAL to the
corresponding .psd file) where _all_ columns are features.  Features
should be in VW format (string:value or just string if the value=1).

Once you've created your features, you can run:

  bin/run_experiment.pl

To see how well you're doing :).  If you run this with no arguments,
it will tell you what you can specify.

Probably you will want to run something like (a) or (b) below:

(a) bin/run_experiment.pl -xv EMEA
(b) bin/run_experiment.pl -tr EMEA -te Subs

For (a), we'll only use EMEA data for both training and testing.  It
will cross-validate on a WORD TYPE level.  I.e., you will never test
on a word type that you actually saw at training.  For (b), we'll
train on EMEA data and test on Subs data.  In this case, you *will*
test on word types you saw at training.

===================

Notes from hal to himself:

Right now the data is based on the test1 data per Marine's email,
with data copied from the following locations:

/export/ws12/damt/data/intrinsic_eval/gold_standard/EMEA-new.test1.filtered.psd
/export/ws12/damt/data/pp/EMEA-new/test1.no-doc-boundary.normal.fr
/export/ws12/damt/data/pp/EMEA-new/test1.no-doc-boundary.normal.en


test by hal
