# Bifurcation Diagrams
Bifurcation diagrams can be produced from Catalyst generated models through the
use of the [BifurcationKit.jl](https://bifurcationkit.github.io/BifurcationKitDocs.jl/stable/)
package. This tutorial gives a simple example of how to create such a
bifurcation diagram.

First, we declare our reaction model. For this example we will use a bistable
switch, but one which also contains a Hopf bifurcation.
```@example ex1
using Catalyst
rn = @reaction_network begin
    (v0 + v*(S * X)^n / ((S*X)^n + (D*A)^n + K^n), d), ∅ ↔ X
    (X/τ, 1/τ), ∅ ↔ A
end S D τ v0 v K n d
```
Next, we specify the system parameters for which we wish to plot the bifurcation
diagram. We also set the parameter we wish to vary in our bifurcation diagram,
as well as the interval to vary it over. Finally, we set which variable we wish
to plot the steady state values of in the bifurcation plot.
```@example ex1
p = Dict(:S => 1., :D => 9., :τ => 1000., :v0 => 0.01,
         :v => 2., :K => 20., :n => 3, :d => 0.05)
bif_par = :S           # bifurcation parameter
p_span = (0.1, 20.)    # interval to vary S over
plot_var = :X          # we will plot X vs S
```
When creating a bifurcation diagram, we typically start at some point in
parameter phase-space. We will simply select the beginning of the interval over
which we wish to compute the bifurcation diagram, `p_span[1]`. We thus create a
modified parameter set where `S = .1`. For this parameter set, we also make a
guess for the steady-state of the system. While a good estimate could be
provided through an ODE simulation, BifurcationKit does not require the guess to
be very accurate.
```@example ex1
p_bstart = copy(p)
p_bstart[bif_par] = p_span[1]
u0 = [:X => 1.0, :A => 1.0]
```
Finally, we extract the ODE derivative function and its jacobian in a form that
BifurcationKit can use:
```@example ex1
oprob = ODEProblem(rn, u0, (0.0,0.0), p_bstart; jac = true)
F = (u,p) -> oprob.f(u, p, 0)
J = (u,p) -> oprob.f.jac(u, p, 0)
```

In creating an `ODEProblem` an ordering is chosen for the initial condition and
parameters, and regular `Float64` vectors of their numerical values are created
as `oprob.u0` and `oprob.p` respectively. BifurcationKit needs to know the index
in `oprob.p` of our bifurcation parameter, `:S`, and the index in `oprob.u0` of
the variable we wish to plot, `:X`. We calculate these as
```@example ex1
# get S and X as a symbolic variables
@unpack S, X = rn

# find their indices in oprob.p and oprob.u0 respectively
bif_idx  = findfirst(isequal(S), parameters(rn))
plot_idx = findfirst(isequal(X), species(rn))
```

Now, we load the required packages to create and plot the bifurcation diagram.
We also bundle the information we have compiled so far into a
`BifurcationProblem`.
```@example ex1
using BifurcationKit, Plots, LinearAlgebra, Setfield

bprob = BifurcationProblem(F, oprob.u0, oprob.p, (@lens _[bif_idx]);
                           recordFromSolution = (x, p) -> x[plot_idx], J = J)
```
Next, we need to specify the input options for the pseudo-arclength continuation method (PACM) which produces the diagram.
```@example ex1
bopts = ContinuationPar(dsmax = 0.05,          # Max arclength in PACM.
                        dsmin = 1e-4,          # Min arclength in PACM.
                        ds=0.001,              # Initial (positive) arclength in PACM.
                        maxSteps = 100000,     # Max number of steps.
                        pMin = p_span[1],      # Min p-val (if hit, the method stops).
                        pMax = p_span[2],      # Max p-val (if hit, the method stops).
                        detectBifurcation = 3) # Value in {0,1,2,3}
```
Here `detectBifurcation` determines to what extent bifurcation points are
detected and how accurately their values are determined. Three indicates to use the most
accurate method for calculating their values.

We are now ready to compute the bifurcation diagram:
```@example ex1
bf = bifurcationdiagram(bprob, PALC(), 2, (args...) -> bopts)
```
Finally, we can plot it:
```@example ex1
plot(bf, xlabel = string(bif_par), ylabel = string(plot_var))
```

Here, the Hopf bifurcation is marked with a red dot and the fold bifurcations
with blue dots. The region with a thinner line width corresponds to unstable
steady states.

This tutorial demonstrated how to make a simple bifurcation diagram where all
branches are connected. However, BifurcationKit.jl is a very powerful package
capable of a lot more. For more details, please see that package's
documentation:
[BifurcationKit.jl](https://bifurcationkit.github.io/BifurcationKitDocs.jl/dev/).
