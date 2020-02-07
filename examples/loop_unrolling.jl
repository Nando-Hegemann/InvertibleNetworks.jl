# Example for loop unrolling using invertible networks
# Adapted from Putzky and Welling (2019)
# Author: Philipp Witte, pwitte3@gatech.edu
# Date: January 2020

using InvertibleNetworks, LinearAlgebra, Test
using Flux
import Flux.Optimise.update!

# Input
nx = 64
ny = 64
n_in = 10
n_hidden = 20
batchsize = 2
maxiter = 2

# Observed data
nrec = 50
nt = 100
d = randn(Float32, nt*nrec, batchsize)

# Modeling/imaging operator (can be JUDI operator or explicit matrix)
J = randn(Float32, nt*nrec, nx*ny)

# Link function
Ψ(η) = identity(η)

# Unrolled loop
L = NetworkLoop(nx, ny, n_in, n_hidden, batchsize, maxiter, Ψ)

# Initializations
η_obs = randn(Float32, nx, ny, 1, batchsize)
s_obs = randn(Float32, nx, ny, n_in-1, batchsize)
η_in = randn(Float32, nx, ny, 1, batchsize)
s_in = randn(Float32, nx, ny, n_in-1, batchsize)

# Forward pass and residual
η_out, s_out = L.forward(η_in, s_in, J, d)
Δη = η_out - η_obs
Δs = s_out - s_obs  # in practice there is no observed s, so Δs=0f0

# Backward pass
Δη_inv, Δs_inv, η_inv, s_inv = L.backward(Δη, Δs, η_out, s_out, J, d)

# Check invertibility
@test isapprox(norm(η_inv - η_in)/norm(η_inv), 0f0, atol=1e-6)
@test isapprox(norm(s_inv - s_in)/norm(s_inv), 0f0, atol=1e-6)

# Update using Flux optimizer
opt = Flux.ADAM()
P = get_params(L)
for p in P
    update!(opt, p.data, p.grad)
end
clear_grad!(L)

