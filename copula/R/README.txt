this is R code for looking at copulas of parallel data.

first you need to install R

http://www.r-project.org/

then you need to install necessary packages. start R and run

install.packages("lsa", dependencies = TRUE)
install.packages("CDVine", dependencies = TRUE)

finally copy some data into the 'fr' and 'en' subdirectories here
see copy.py for some example copying

note that the docs should be just lists of whitespace delimited tokens

then you can run 

R copula.R

that'll use lsa to find a 10 dimensional representation of each document,
then put them side by side, so if you have D docs, you'll get a D x 20
matrix.

next it converts the column values from their raw scores into CDF values

finally it uses CDVineCopSelect to look for a copula structure that models
this.


needs work
