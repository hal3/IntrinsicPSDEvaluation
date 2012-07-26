require(lsa)
require(CDVine)

E = textmatrix('en')
d = length(E[1,])
print(d)
F = textmatrix('fr')
EE = lsa(E, 10)
FF = lsa(F, 10)
print(length(FF$dk[,1]))
print(length(FF$dk[1,]))

M = cbind(FF$dk, EE$dk)
print(length(M[,1]))
print(length(M[1,]))

Mcdf = matrix(rep(NA, 20 * d), nrow=d)
for (i in 1:20)
{
	ex = ecdf(M[,i])
	for (r in 1:d)
	{
		Mcdf[r,i] = ex(M[r,i])
	}
}
warnings()

M[1,]
Mcdf[1,]

CDVineCopSelect(Mcdf, type=2)
