### Fetch required packages and reaction networks ###
using Catalyst, Random, Statistics, StochasticDiffEq, Test
using ModelingToolkit: get_states, get_ps
include("test_networks.jl")

using StableRNGs
rng = StableRNG(12345)

### Compares to the manually calcualted function ###
identical_networks = Vector{Pair}()

function real_f_1(du, u, p, t)
    X1, X2, X3 = u
    p, k1, k2, k3, d = p
    du[1] = 2 * p - k1 * X1
    du[2] = k1 * X1 - k2 * X2 - k3 * X2
    du[3] = k2 * X2 + k3 * X2 - d * X3
end
function real_g_1(du, u, p, t)
    X1, X2, X3 = u
    p, k1, k2, k3, d = p
    du[1, 1] = 2 * sqrt(p)
    du[1, 2] = -sqrt(k1 * X1)
    du[1, 3] = 0
    du[1, 4] = 0
    du[1, 5] = 0
    du[2, 1] = 0
    du[2, 2] = sqrt(k1 * X1)
    du[2, 3] = -sqrt(k2 * X2)
    du[2, 4] = -sqrt(k3 * X2)
    du[2, 5] = 0
    du[3, 1] = 0
    du[3, 2] = 0
    du[3, 3] = sqrt(k2 * X2)
    du[3, 4] = sqrt(k3 * X2)
    du[3, 5] = -sqrt(d * X3)
end
push!(identical_networks,
      reaction_networks_standard[8] => (real_f_1, real_g_1, zeros(3, 5)))

function real_f_2(du, u, p, t)
    X1, = u
    v, K, n, d = p
    du[1] = v / 10 + v * X1^n / (X1^n + K^n) - d * X1
end
function real_g_2(du, u, p, t)
    X1, = u
    v, K, n, d = p
    du[1, 1] = sqrt(v / 10 + v * X1^n / (X1^n + K^n))
    du[1, 2] = -sqrt(d * X1)
end
push!(identical_networks, reaction_networks_hill[6] => (real_f_2, real_g_2, zeros(1, 2)))

function real_f_3(du, u, p, t)
    X1, X2, X3, X4, X5, X6, X7 = u
    k1, k2, k3, k4, k5, k6 = p
    du[1] = -k1 * X1 * X2 + k2 * X3
    du[2] = -k1 * X1 * X2 + k2 * X3
    du[3] = k1 * X1 * X2 - k2 * X3 - k3 * X3 * X4 + k4 * X5
    du[4] = -k3 * X3 * X4 + k4 * X5
    du[5] = k3 * X3 * X4 - k4 * X5 - k5 * X5 * X6 + k6 * X7
    du[6] = -k5 * X5 * X6 + k6 * X7
    du[7] = k5 * X5 * X6 - k6 * X7
end
function real_g_3(du, u, p, t)
    X1, X2, X3, X4, X5, X6, X7 = u
    k1, k2, k3, k4, k5, k6 = p
    fill!(du, 0)
    du[1, 1] = -sqrt(k1 * X1 * X2)
    du[1, 2] = sqrt(k2 * X3)
    du[2, 1] = -sqrt(k1 * X1 * X2)
    du[2, 2] = sqrt(k2 * X3)
    du[3, 1] = sqrt(k1 * X1 * X2)
    du[3, 2] = -sqrt(k2 * X3)
    du[3, 3] = -sqrt(k3 * X3 * X4)
    du[3, 4] = sqrt(k4 * X5)
    du[4, 3] = -sqrt(k3 * X3 * X4)
    du[4, 4] = sqrt(k4 * X5)
    du[5, 3] = sqrt(k3 * X3 * X4)
    du[5, 4] = -sqrt(k4 * X5)
    du[5, 5] = -sqrt(k5 * X5 * X6)
    du[5, 6] = sqrt(k6 * X7)
    du[6, 5] = -sqrt(k5 * X5 * X6)
    du[6, 6] = sqrt(k6 * X7)
    du[7, 5] = sqrt(k5 * X5 * X6)
    du[7, 6] = -sqrt(k6 * X7)
end
push!(identical_networks,
      reaction_networks_constraint[9] => (real_f_3, real_g_3, zeros(7, 6)))

for (i, networks) in enumerate(identical_networks)
    for factor in [1e-1, 1e0, 1e1], repeat in 1:3
        u0 = 100.0 .+ factor * rand(rng, length(get_states(networks[1])))
        p = 0.01 .+ factor * rand(rng, length(get_ps(networks[1])))
        (i == 2) && (u0[1] += 1000.0)
        (i == 3) ? (p[2:2:6] .*= 1000.0; u0 .+= 1000) : (p[1] += 500.0)
        prob1 = SDEProblem(networks[1], u0, (0.0, 100.0), p)
        prob2 = SDEProblem(networks[2][1], networks[2][2], u0, (0.0, 100.0), p,
                           noise_rate_prototype = networks[2][3])
        du1 = similar(u0)
        du2 = similar(u0)
        prob1.f.f(du1, u0, p, 0.0)
        prob2.f.f(du2, u0, p, 0.0)
        @test all(isapprox.(du1, du2))
        g1 = zeros(numspecies(networks[1]), numreactions(networks[1]))
        g2 = copy(g1)
        prob1.f.g(g1, u0, p, 0.0)
        prob2.f.g(g2, u0, p, 0.0)
        @test all(isapprox.(g1, g2))
    end
end

### Compares level of noise with noise scalling. ###

# Tests with a single noise scaling parameter.
noise_scaling_network = @reaction_network begin (k1, k2), X1 ↔ X2 end k1 k2
for repeat in 1:5
    p = 1.0 .+ rand(rng, 2)
    u0 = 10000 * (1.0 .+ rand(rng, 2))
    sol001 = solve(SDEProblem(noise_scaling_network, u0, (0.0, 1000.0), vcat(p, 0.01),
                              noise_scaling = (@variables η1)[1]), ImplicitEM())
    sol01 = solve(SDEProblem(noise_scaling_network, u0, (0.0, 1000.0), vcat(p, 0.1),
                             noise_scaling = (@variables η1)[1]), ImplicitEM())
    sol1 = solve(SDEProblem(noise_scaling_network, u0, (0.0, 1000.0), vcat(p, 1.0),
                            noise_scaling = (@variables η2)[1]), ImplicitEM())
    sol10 = solve(SDEProblem(noise_scaling_network, u0, (0.0, 1000.0), vcat(p, 10.0),
                             noise_scaling = (@variables η3)[1]), ImplicitEM())
    @test 2 * std(first.(sol001.u)[100:end]) < std(first.(sol01.u)[100:end])
    @test 2 * std(last.(sol001.u)[100:end]) < std(last.(sol01.u)[100:end])
    @test 2 * std(first.(sol01.u)[100:end]) < std(first.(sol1.u)[100:end])
    @test 2 * std(last.(sol01.u)[100:end]) < std(last.(sol1.u)[100:end])
    @test 2 * std(first.(sol1.u)[100:end]) < std(first.(sol10.u)[100:end])
    @test 2 * std(last.(sol1.u)[100:end]) < std(last.(sol10.u)[100:end])
end

### Tries to create a large number of problem, ensuring there are no errors (cannot solve as solution likely to go into negatives). ###
for reaction_network in reaction_networks_all
    for factor in [1e-2, 1e-1, 1e0, 1e1]
        u0 = factor * rand(rng, length(get_states(reaction_network)))
        p = factor * rand(rng, length(get_ps(reaction_network)))
        prob = SDEProblem(reaction_network, u0, (0.0, 1.0), p)
    end
end

### No parameter test ###

no_param_network = @reaction_network begin (1.2, 5), X1 ↔ X2 end
for factor in [1e3, 1e4]
    u0 = factor * (1.0 .+ rand(rng, length(get_states(no_param_network))))
    prob = SDEProblem(no_param_network, u0, (0.0, 1000.0))
    sol = solve(prob, ImplicitEM())
    vals1 = getindex.(sol.u[1:end], 1)
    vals2 = getindex.(sol.u[1:end], 2)
    @test mean(vals1) > mean(vals2)
end
