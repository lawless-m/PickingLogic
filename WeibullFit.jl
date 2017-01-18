module WeibullFit

using univariate_opt

#=

I got this code from

http://stats.stackexchange.com/questions/19866/how-to-fit-a-weibull-distribution-to-input-data-containing-zeroes

Blischke-Scheuer method-of-moments estimation of (a,b)
for the Weibull distribution F(t) = 1 - exp(-(t/a)^b)


one can check the answer at http://www.weibull.com/itools/index.htm
Note that the calculated value for "Eta" is displayed in the "scale parameter" box after you click Compute (even though the label is not visible in the page).

=#

export fit_mom

function fit_mom(data; low=0.02, high=50.0)
    xbar = mean(data)
    xvar = var(data)
	f(b) = gamma(1+2/b) / gamma(1+1/b)^2 - 1 - xvar / xbar^2
	beta = findzero(f, low, high, eps()) # aka bhat
	eta = xbar / gamma(1+1/beta) # aka ahat
	beta, eta # Weibull(shape, scale) - http://distributionsjl.readthedocs.io/en/latest/univariate-continuous.html?highlight=Weibull#Weibull
end

#=
using Plots
using Distributions
scale = 1
shapes = [0.5 1 1.5 5]
plot(0:0.01:2.5, [n->pdf(Weibull(k,scale),n) for k in shapes], ylims=(0,2.5), xlims=(0, 2.5), lab=["\$\\lambda\$=$scale, k=$k" for k in shapes]')
png("weibull.wiki")
=#




# stahhhppp

end

