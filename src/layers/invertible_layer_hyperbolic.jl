# Hyperbolic network layer from Lensink et al. (2019)
# Author: Philipp Witte, pwitte3@gatech.edu
# Date: January 2020

export HyperbolicLayer, HyperbolicLayer3D

"""
    HyperbolicLayer(n_in, kernel, stride, pad; action=0, α=1f0, n_hidden=1)
    HyperbolicLayer(n_in, kernel, stride, pad; action=0, α=1f0, n_hidden=1, ndims=2)
    HyperbolicLayer3D(n_in, kernel, stride, pad; action=0, α=1f0, n_hidden=1)

or

    HyperbolicLayer(W, b, stride, pad; action=0, α=1f0)
    HyperbolicLayer3D(W, b, stride, pad; action=0, α=1f0)

Create an invertible hyperbolic coupling layer.

*Input*:

 - `kernel`, `stride`, `pad`: Kernel size, stride and padding of the convolutional operator

 - `action`: String that defines whether layer keeps the number of channels fixed (`0`),
    increases it by a factor of 4 (or 8 in 3D) (`1`) or decreased it by a factor of 4 (or 8) (`-1`).

 - `W`, `b`: Convolutional weight and bias. `W` has dimensions of `(kernel, kernel, n_in, n_in)`.
   `b` has dimensions of `n_in`.

 - `α`: Step size for second time derivative. Default is 1.

 - `n_hidden`: Increase the no. of channels by `n_hidden` in the forward convolution.
    After applying the transpose convolution, the dimensions are back to the input dimensions.

 - `ndims`: Number of dimension of the input (2 for 2D, 3 for 3D)

*Output*:

 - `HL`: Invertible hyperbolic coupling layer

 *Usage:*

 - Forward mode: `X_curr, X_new = HL.forward(X_prev, X_curr)`

 - Inverse mode: `X_prev, X_curr = HL.inverse(X_curr, X_new)`

 - Backward mode: `ΔX_prev, ΔX_curr, X_prev, X_curr = HL.backward(ΔX_curr, ΔX_new, X_curr, X_new)`

 *Trainable parameters:*

 - `HL.W`: Convolutional kernel

 - `HL.b`: Bias

 See also: [`get_params`](@ref), [`clear_grad!`](@ref)
"""
struct HyperbolicLayer{S, P, A} <: NeuralNetLayer
    W::Parameter
    b::Parameter
    α::Float32
end

@Flux.functor HyperbolicLayer

scale_a = Dict(0 => 1, 1 => 1/2, -1 => 2, "same" => 1)

# Constructor 2D
function HyperbolicLayer(n_in::Int64, kernel::Int64, stride::Int64,
                         pad::Int64; action="same", α=1f0, n_hidden=nothing, ndims=2)

    # Set ouput/hidden dimensions
    n_out = Int(n_in*scale_a[action]^ndims)
    isnothing(n_hidden) && (n_hidden = n_in)

    k = Tuple(kernel for i=1:ndims)
    W = Parameter(glorot_uniform(k..., n_out, n_hidden))
    b = Parameter(zeros(Float32, n_hidden))

    return HyperbolicLayer{stride, pad, action}(W, b, α)
end

HyperbolicLayer3D(args...; kw...) =  HyperbolicLayer(args...; kw..., ndims=3)

# Constructor for given weights 2D
function HyperbolicLayer(W::AbstractArray{Float32, N}, b::AbstractArray{Float32, 1}, 
                         stride::Int64, pad::Int64; action=0, α=1f0) where N

    kernel, n_in, n_hidden = size(W)[N-3:N]

    # Set ouput/hidden dimensions
    n_out = Int(n_in*scale_a[action]^(N-2))
    W = Parameter(W)
    b = Parameter(b)

    return HyperbolicLayer{stride, pad, action}(W, b, α)
end

HyperbolicLayer3D(W::AbstractArray{Float32, N}, b, stride, pad;
                  action=0, α=1f0) where N =
        HyperbolicLayer(W, b, stride, pad;action=actin, α=α)

#################################################

# Forward pass
function forward(X_prev_in, X_curr_in, HL::HyperbolicLayer{s, p, a}) where {s, p, a}

    # Change dimensions
    if a == 0
        X_prev = identity(X_prev_in)
        X_curr = identity(X_curr_in)
    elseif a == 1
        X_prev = wavelet_unsqueeze(X_prev_in)
        X_curr = wavelet_unsqueeze(X_curr_in)
    elseif a == -1
        X_prev = wavelet_squeeze(X_prev_in)
        X_curr = wavelet_squeeze(X_curr_in)
    else
        throw("Specified operation not defined.")
    end

    # Symmetric convolution w/ relu activation
    cdims = DCDims(X_curr, HL.W.data; stride=s, padding=p)
    if length(size(X_curr)) == 4
        X_conv = conv(X_curr, HL.W.data, cdims) .+ reshape(HL.b.data, 1, 1, :, 1)
    else
        X_conv = conv(X_curr, HL.W.data, cdims) .+ reshape(HL.b.data, 1, 1, 1, :, 1)
    end
    X_relu = ReLU(X_conv)
    X_convT = -∇conv_data(X_relu, HL.W.data, cdims)

    # Update
    X_new = 2f0*X_curr - X_prev + HL.α*X_convT

    return X_curr, X_new
end

# Inverse pass
function inverse(X_curr, X_new, HL::HyperbolicLayer{s, p, a}; save=false) where {s, p, a}
    cdims = DCDims(X_curr, HL.W.data; stride=s, padding=p)
    # Symmetric convolution w/ relu activation
    if length(size(X_curr)) == 4
        X_conv = conv(X_curr, HL.W.data, cdims) .+ reshape(HL.b.data, 1, 1, :, 1)
    else
        X_conv = conv(X_curr, HL.W.data, cdims) .+ reshape(HL.b.data, 1, 1, 1, :, 1)
    end
    X_relu = ReLU(X_conv)
    X_convT = -∇conv_data(X_relu, HL.W.data, cdims)

    # Update
    X_prev = 2*X_curr - X_new + HL.α*X_convT

    # Change dimensions
    if a == 0
        X_prev_in = identity(X_prev)
        X_curr_in = identity(X_curr)
    elseif a == -1
        X_prev_in = wavelet_unsqueeze(X_prev)
        X_curr_in = wavelet_unsqueeze(X_curr)
    elseif a == 1
        X_prev_in = wavelet_squeeze(X_prev)
        X_curr_in = wavelet_squeeze(X_curr)
    else
        throw("Specified operation not defined.")
    end

    if save == false
        return X_prev_in, X_curr_in
    else
        return X_prev_in, X_curr_in, X_conv, X_relu
    end
end

# Backward pass
function backward(ΔX_curr, ΔX_new, X_curr, X_new, HL::HyperbolicLayer{s, p, a}; set_grad::Bool=true) where {s, p, a}

    # Recompute forward states
    X_prev_in, X_curr_in, X_conv, X_relu = inverse(X_curr, X_new, HL; save=true)

    # Backpropagate data residual and compute gradients
    cdims = DCDims(X_curr, HL.W.data; stride=s, padding=p)
    ΔX_convT = copy(ΔX_new)
    ΔX_relu = -HL.α*conv(ΔX_convT, HL.W.data, cdims)
    ΔW = -HL.α*∇conv_filter(ΔX_convT, X_relu, cdims)

    ΔX_conv = ReLUgrad(ΔX_relu, X_conv)
    ΔX_curr += ∇conv_data(ΔX_conv, HL.W.data, cdims)
    ΔW += ∇conv_filter(X_curr, ΔX_conv, cdims)
    if length(size(X_curr)) == 4
        Δb = sum(ΔX_conv; dims=[1,2,4])[1,1,:,1]
    else
        Δb = sum(ΔX_conv; dims=[1,2,3,5])[1,1,1,:,1]
    end
    ΔX_curr += 2f0*ΔX_new
    ΔX_prev = -ΔX_new

    # Set gradients
    if set_grad
        HL.W.grad = ΔW
        HL.b.grad = Δb
    else
        Δθ = [Parameter(ΔW), Parameter(Δb)]
    end

    # Change dimensions
    if a == 0
        ΔX_prev_in = identity(ΔX_prev)
        ΔX_curr_in = identity(ΔX_curr)
    elseif a == -1
        ΔX_prev_in = wavelet_unsqueeze(ΔX_prev)
        ΔX_curr_in = wavelet_unsqueeze(ΔX_curr)
    elseif a == 1
        ΔX_prev_in = wavelet_squeeze(ΔX_prev)
        ΔX_curr_in = wavelet_squeeze(ΔX_curr)
    else
        throw("Specified operation not defined.")
    end

    set_grad ? (return ΔX_prev_in, ΔX_curr_in, X_prev_in, X_curr_in) : (return ΔX_prev_in, ΔX_curr_in, Δθ, X_prev_in, X_curr_in)
end


## Jacobian utilities

# 2D
function jacobian(ΔX_prev_in, ΔX_curr_in, Δθ, X_prev_in, X_curr_in, HL::HyperbolicLayer{s, p, a}) where {s, p, a}

    # Change dimensions
    if a == 0
        X_prev = identity(X_prev_in)
        X_curr = identity(X_curr_in)
        ΔX_prev = identity(ΔX_prev_in)
        ΔX_curr = identity(ΔX_curr_in)
    elseif a == 1
        X_prev = wavelet_unsqueeze(X_prev_in)
        X_curr = wavelet_unsqueeze(X_curr_in)
        ΔX_prev = wavelet_unsqueeze(ΔX_prev_in)
        ΔX_curr = wavelet_unsqueeze(ΔX_curr_in)
    elseif a == -1
        X_prev = wavelet_squeeze(X_prev_in)
        X_curr = wavelet_squeeze(X_curr_in)
        ΔX_prev = wavelet_squeeze(ΔX_prev_in)
        ΔX_curr = wavelet_squeeze(ΔX_curr_in)
    else
        throw("Specified operation not defined.")
    end

    cdims = DCDims(X_curr, HL.W.data; stride=s, padding=p)
    # Symmetric convolution w/ relu activation
    if length(size(X_curr)) == 4
        X_conv = conv(X_curr, HL.W.data, cdims) .+ reshape(HL.b.data, 1, 1, :, 1)
    else
        X_conv = conv(X_curr, HL.W.data, cdims) .+ reshape(HL.b.data, 1, 1, 1, :, 1)
    end
    ΔX_conv = conv(ΔX_curr, HL.W.data, cdims) .+ conv(X_curr, Δθ[1].data, cdims) .+ reshape(Δθ[2].data, 1, 1, :, 1)
    X_relu = ReLU(X_conv)
    ΔX_relu = ReLUgrad(ΔX_conv, X_conv)
    X_convT = -∇conv_data(X_relu, HL.W.data, cdims)
    ΔX_convT = -∇conv_data(ΔX_relu, HL.W.data, cdims)-∇conv_data(X_relu, Δθ[1].data, cdims)

    # Update
    X_new = 2f0*X_curr - X_prev + HL.α*X_convT
    ΔX_new = 2f0*ΔX_curr - ΔX_prev + HL.α*ΔX_convT

    return ΔX_curr, ΔX_new, X_curr, X_new
end

function adjointJacobian(ΔX_curr, ΔX_new, X_curr, X_new, HL::HyperbolicLayer)
    return backward(ΔX_curr, ΔX_new, X_curr, X_new, HL; set_grad=false)
end


## Other utils

# Clear gradients
function clear_grad!(HL::HyperbolicLayer)
    HL.W.grad = nothing
    HL.b.grad = nothing
end

# Get parameters
get_params(HL::HyperbolicLayer) = [HL.W, HL.b]
