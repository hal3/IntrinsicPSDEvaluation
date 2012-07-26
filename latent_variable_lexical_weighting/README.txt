
LATENT VARIABLE LEXICAL WEIGHTING.
==================================

1. Install a recent version of Mono
2. hit 'make' -- should compile to produce lvlw.exe
3. run 'mono lvlw.exe f e a model.txt'
   - f is the french sentences, one sentence per line, whitespace delimited tokens
   - e is english sentences, same format
   - a is alignments, moses format (one sentence per line, whitespace delimited tokens, each token is an association: <srcIndex>-<tgtIndex>)
   - model.txt is the output from this. Basically a dump of the alpha and beta distributions

INFOMRATION ON MODEL
====================

We have D documents, each consisting of many word-aligned pairs F->E

There are K topics

Each document has a distribution theta_d over topics
alpha_k is a categorical distribution over french words f, for each topic k
beta_k,f is a categorical distribution over english words e, for each topic k and french word f

So it's something like:

theta_d ~ Dirichlet(mu)
alpha_k ~ Dirichlet(nu)
beta_{k,f} ~ Dirichlet(xi)
z_di ~ Categorical(theta_d)
f_di ~ Categorical(alpha_{z_di})
e_di ~ Categorical(beta_{z_di,f_di})

