# Invertible CNN layer from Dinh et al. (2017)/Kingma and Dhariwal (2018)
# Author: Philipp Witte, pwitte3@gatech.edu
# Date: January 2020

using InvertibleNetworks, LinearAlgebra, Test, Random, Flux

mean(x) = sum(x)/length(x)

# Input
nx = 24
ny = 24
k = 4
n_hidden = 4
batchsize = 2

# Input images
X = randn(Float32, nx, ny, k, batchsize)
X0 = randn(Float32, nx, ny, k, batchsize)
dX = X - X0

# 1x1 convolution and residual blocks
C = Conv1x1(k)
RB = ResidualBlock(div(k,2), n_hidden; n_out=k, k1=3, k2=3, p1=1, p2=1, fan=true)
L = CouplingLayerGlow(C, RB; logdet=true)

# Test invertibility
X_ = L.inverse(L.forward(X)[1])
@test isapprox(norm(X - X_)/norm(X), 0f0; atol=1e-2)

X_ = L.forward(L.inverse(X))[1]
@test isapprox(norm(X - X_)/norm(X), 0f0; atol=1e-2)

###################################################################################################
# Gradient tests

# Loss Function
function loss(L, X, Y)
    Y_, logdet = L.forward(X)
    f = mse(Y_, Y) - logdet
    ΔY = ∇mse(Y_, Y)
    ΔX = L.backward(ΔY, Y_)[1]

    # Pass back gradients w.r.t. input X and from the residual block and 1x1 conv. layer
    return f, ΔX, L.C.v1.grad, L.C.v2.grad, L.C.v3.grad, L.RB.W1.grad, L.RB.W2.grad, L.RB.W3.grad
end

# Invertible layers
C0 = Conv1x1(k)
RB0 = ResidualBlock(div(k,2), n_hidden;n_out=k, k1=3, k2=3, p1=1, p2=1, fan=true)
L01 = CouplingLayerGlow(C0, RB; logdet=true)


hfactor=8f-1
expected_f1 = 1f0 / hfactor
expected_f2 = 1f0 / hfactor ^2f0

# Gradient test w.r.t. input X0
Y = L.forward(X)[1]
f0, ΔX = loss(L, X0, Y)[1:2]
h = 0.1f0
maxiter = 6
err1 = zeros(Float32, maxiter)
err2 = zeros(Float32, maxiter)

print("\nGradient test coupling layer\n")
for j=1:maxiter
    f = loss(L, X0 + h*dX, Y)[1]
    err1[j] = abs(f - f0)
    err2[j] = abs(f - f0 - h*dot(dX, ΔX))
    print(err1[j], "; ", err2[j], "\n")
    global h = h * hfactor
end

factor1 = err1[1:end-1]./err1[2:end]
factor2 = err2[1:end-1]./err2[2:end]

@test isapprox(mean(factor1), expected_f1; atol=1f0)
@test isapprox(mean(factor2), expected_f2; atol=1f0)


# Gradient test w.r.t. weights of residual block
num_attempts = 3
results_1 = []
results_2 = []
for i in 1:num_attempts
    Random.seed!(i)

    X = randn(Float32, nx, ny, k, batchsize)
    Y = L.forward(X)[1]

    L02 = CouplingLayerGlow(C, RB0; logdet=true)
    Lini = deepcopy(L02)
    dW1 = L.RB.W1.data - L02.RB.W1.data
    dW2 = L.RB.W2.data - L02.RB.W2.data
    dW3 = L.RB.W3.data - L02.RB.W3.data

    f0, ΔX, Δv1, Δv2, Δv3, ΔW1, ΔW2, ΔW3 = loss(L02, X, Y)
    h = 0.1f0
    maxiter = 4
    err3 = zeros(Float32, maxiter)
    err4 = zeros(Float32, maxiter)

    print("\nGradient test coupling layer\n")
    for j=1:maxiter
        L02.RB.W1.data = Lini.RB.W1.data + h*dW1
        L02.RB.W2.data = Lini.RB.W2.data + h*dW2
        L02.RB.W3.data = Lini.RB.W3.data + h*dW3
        f = loss(L02, X, Y)[1]
        err3[j] = abs(f - f0)
        err4[j] = abs(f - f0 - h*dot(dW1, ΔW1) - h*dot(dW2, ΔW2) - h*dot(dW3, ΔW3))
        print(err3[j], "; ", err4[j], "\n")
        h = h*hfactor
    end

    factor1 = err3[1:end-1]./err3[2:end]
    factor2 = err4[1:end-1]./err4[2:end]

    append!(results_1,isapprox(mean(factor1), expected_f1; atol=1f0))
    append!(results_2,isapprox(mean(factor2), expected_f2; atol=1f0))
end
@test true in results_1
@test true in results_2


# Gradient test w.r.t. 1x1 conv weights
num_attempts = 3
results_1 = []
results_2 = []
for i in 1:num_attempts
    Random.seed!(i)

    X = randn(Float32, nx, ny, k, batchsize)
    Y = L.forward(X)[1]
    L01 = CouplingLayerGlow(C0, RB; logdet=true)
    Lini = deepcopy(L01)
    dv1 = C.v1.data - C0.v1.data
    dv2 = C.v2.data - C0.v2.data
    dv3 = C.v3.data - C0.v3.data

    f0, ΔX, Δv1, Δv2, Δv3, ΔW1, ΔW2, ΔW3 = loss(L01, X, Y)
    h = 0.1f0
    maxiter = 4
    err5 = zeros(Float32, maxiter)
    err6 = zeros(Float32, maxiter)

    print("\nGradient test coupling layer\n")
    for j=1:maxiter
        L01.C.v1.data = Lini.C.v1.data + h*dv1
        L01.C.v2.data = Lini.C.v2.data + h*dv2
        L01.C.v3.data = Lini.C.v3.data + h*dv3
        f = loss(L01, X, Y)[1]
        err5[j] = abs(f - f0)
        err6[j] = abs(f - f0 - h*dot(dv1, Δv1) - h*dot(dv2, Δv2) - h*dot(dv3, Δv3))
        print(err5[j], "; ", err6[j], "\n")
        h = h*hfactor
    end

    factor1 = err5[1:end-1]./err5[2:end]
    factor2 = err6[1:end-1]./err6[2:end]

    append!(results_1,isapprox(mean(factor1), expected_f1; atol=1f0))
    append!(results_2,isapprox(mean(factor2), expected_f2; atol=1f0))
end
@test true in results_1
@test true in results_2

###################################################################################################
# Jacobian-related tests

# Gradient test


# Initialization
L = CouplingLayerGlow(k, n_hidden; k1=3, k2=3, p1=1, p2=1, s1=1, s2=1, logdet=true)
θ = deepcopy(get_params(L))
L0 = CouplingLayerGlow(k, n_hidden; k1=3, k2=3, p1=1, p2=1, s1=1, s2=1, logdet=true)
θ0 = deepcopy(get_params(L0))
X = randn(Float32, nx, ny, k, batchsize)

# Perturbation (normalized)
dθ = θ-θ0; dθ .*= norm.(θ0)./(norm.(dθ).+1f-10)
dX = randn(Float32, nx, ny, k, batchsize); dX *= norm(X)/norm(dX)

# Jacobian eval
dY, Y, _, _ = L.jacobian(dX, dθ, X)

# Test
print("\nJacobian test\n")
h = 0.1f0
maxiter = 7
err7 = zeros(Float32, maxiter)
err8 = zeros(Float32, maxiter)
for j=1:maxiter
    set_params!(L, θ+h*dθ)
    Y_loc, _ = L.forward(X+h*dX)
    err7[j] = norm(Y_loc - Y)
    err8[j] = norm(Y_loc - Y - h*dY)
    print(err7[j], "; ", err8[j], "\n")
    global h = h*hfactor
end

factor1 = err7[1:end-1]./err7[2:end]
factor2 = err8[1:end-1]./err8[2:end]

@test isapprox(mean(factor1), expected_f1; atol=1f0)
@test isapprox(mean(factor2), expected_f2; atol=1f0)

# Adjoint test

set_params!(L, θ)
dY, Y, _, _ = L.jacobian(dX, dθ, X)
dY_ = randn(Float32, size(dY))
dX_, dθ_, _, _ = L.adjointJacobian(dY_, Y)
a = dot(dY, dY_)
b = dot(dX, dX_)+dot(dθ, dθ_)
@test isapprox(a, b; rtol=1f-3)



########################################## Test with dense layer ##############################
# Input
nx = 24
k = 3
n_hidden = 4
batchsize = 2

# Input images
X = randn(Float32, nx, k, batchsize)
X0 = randn(Float32, nx, k, batchsize)
dX = X - X0

# 1x1 convolution and residual blocks
C = Conv1x1(k)


#needs to be same logic as tensor_split
n_in=k
split_num = Int(round(n_in/2))
in_chan = n_in-split_num
out_chan = split_num*2
RB_dense = FluxBlock(Chain(x->reshape(x,nx*in_chan,:),Dense(nx*in_chan,nx*out_chan),x->reshape(x,nx,out_chan,:)))
L = CouplingLayerGlow(C, RB_dense; logdet=true)

# Test invertibility
X_ = L.inverse(L.forward(X)[1])
@test isapprox(norm(X - X_)/norm(X), 0f0; atol=1e-2)

X_ = L.forward(L.inverse(X))[1]
@test isapprox(norm(X - X_)/norm(X), 0f0; atol=1e-2)

###################################################################################################
# Gradient tests

# Loss Function
function loss_dense(L, X, Y)
    Y_, logdet = L.forward(X)
    f = mse(Y_, Y) - logdet
    ΔY = ∇mse(Y_, Y)
    ΔX = L.backward(ΔY, Y_)[1]

    # Pass back gradients w.r.t. input X and from the residual block and 1x1 conv. layer
    return f, ΔX, L.RB.params[1].grad
end

# Invertible layers
C0 = Conv1x1(k)
RB_dense0 = FluxBlock(Chain(x->reshape(x,nx*in_chan,:),Dense(nx*in_chan,nx*out_chan),x->reshape(x,nx,out_chan,:)))
L01 = CouplingLayerGlow(C0, RB_dense; logdet=true)
L02 = CouplingLayerGlow(C, RB_dense0; logdet=true)

# Gradient test w.r.t. input X0
Y = L.forward(X)[1]
f0, ΔX = loss_dense(L, X0, Y)[1:2]
h = 0.1f0
maxiter = 6
err1 = zeros(Float32, maxiter)
err2 = zeros(Float32, maxiter)

print("\nGradient test coupling layer\n")
for j=1:maxiter
    f = loss_dense(L, X0 + h*dX, Y)[1]
    err1[j] = abs(f - f0)
    err2[j] = abs(f - f0 - h*dot(dX, ΔX))
    print(err1[j], "; ", err2[j], "\n")
    global h = h/2f0
end

@test isapprox(err1[end] / (err1[1]/2^(maxiter-1)), 1f0; atol=1f0)
@test isapprox(err2[end] / (err2[1]/4^(maxiter-1)), 1f0; atol=1f0)


# Gradient test w.r.t. weights of residual block
Y = L.forward(X)[1]
Lini = deepcopy(L02)
dW1 = L.RB.params - L02.RB.params
f0, ΔX, ΔW1 = loss_dense(L02, X, Y)
h = 0.1f0
maxiter = 4
err3 = zeros(Float32, maxiter)
err4 = zeros(Float32, maxiter)


print("\nGradient test coupling layer\n")
for j=1:maxiter
    set_params!(L02.RB,Lini.RB.params + h*dW1)
    f = loss_dense(L02, X, Y)[1]
    err3[j] = abs(f - f0)
    err4[j] = abs(f - f0 - h*dot(dW1[1].data, ΔW1))
    print(err3[j], "; ", err4[j], "\n")
    global h = h/2f0
end

@test isapprox(err3[end] / (err3[1]/2^(maxiter-1)), 1f0; atol=1f0)
@test isapprox(err4[end] / (err4[1]/4^(maxiter-1)), 1f0; atol=1f0)