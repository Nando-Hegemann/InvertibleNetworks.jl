# Invertible network based on Glow (Kingma and Dhariwal, 2018)
# Includes 1x1 convolution and residual block
# Author: Philipp Witte, pwitte3@gatech.edu
# Date: February 2020

export NetworkConditionalGlowFrank

"""
    G = NetworkGlow(n_in, n_hidden, L, K; k1=3, k2=1, p1=1, p2=0, s1=1, s2=1)

    G = NetworkGlow3D(n_in, n_hidden, L, K; k1=3, k2=1, p1=1, p2=0, s1=1, s2=1)

 Create an invertible network based on the Glow architecture. Each flow step in the inner loop 
 consists of an activation normalization layer, followed by an invertible coupling layer with
 1x1 convolutions and a residual block. The outer loop performs a squeezing operation prior 
 to the inner loop, and a splitting operation afterwards.

 *Input*: 

 - 'n_in': number of input channels

 - `n_hidden`: number of hidden units in residual blocks

 - `L`: number of scales (outer loop)

 - `K`: number of flow steps per scale (inner loop)

 - `split_scales`: if true, perform squeeze operation which halves spatial dimensions and duplicates channel dimensions
    then split output in half along channel dimension after each scale. Feed one half through the next layers,
    while saving the remaining channels for the output.

 - `k1`, `k2`: kernel size of convolutions in residual block. `k1` is the kernel of the first and third 
 operator, `k2` is the kernel size of the second operator.

 - `p1`, `p2`: padding for the first and third convolution (`p1`) and the second convolution (`p2`)

 - `s1`, `s2`: stride for the first and third convolution (`s1`) and the second convolution (`s2`)

 - `ndims` : number of dimensions

 - `squeeze_type` : squeeze type that happens at each multiscale level

 *Output*:
 
 - `G`: invertible Glow network.

 *Usage:*

 - Forward mode: `Y, logdet = G.forward(X)`

 - Backward mode: `ΔX, X = G.backward(ΔY, Y)`

 *Trainable parameters:*

 - None in `G` itself

 - Trainable parameters in activation normalizations `G.AN[i,j]` and coupling layers `G.C[i,j]`,
   where `i` and `j` range from `1` to `L` and `K` respectively.

 See also: [`ActNorm`](@ref), [`CouplingLayerGlow!`](@ref), [`get_params`](@ref), [`clear_grad!`](@ref)
"""
struct NetworkConditionalGlowFrank <: InvertibleNetwork
    AN::AbstractArray{ActNorm, 2}
    NCL::AbstractArray{CouplingLayerGlow, 2}

    AN_c::Union{AbstractArray{ActNorm, 2},Nothing}
    CL::Union{AbstractArray{ConditionalLayerGlow, 2},Nothing}
    
    Z_dims::Union{Array{Array, 1}, Nothing}

    L::Int64
    K::Int64
    squeezer::Squeezer
    split_scales::Bool
    summary_net::Union{InvertibleNetwork, Nothing}
    cond::Bool
end

@Flux.functor NetworkConditionalGlowFrank

# Constructor
function NetworkConditionalGlowFrank(n_in, n_cond, n_hidden, L, K; cond=false, summary_net = nothing, spade=false, split_scales=false, k1=3, k2=1, p1=1, p2=0, s1=1, s2=1, ndims=2, squeezer::Squeezer=ShuffleLayer(), activation::ActivationFunction=SigmoidLayer())
    AN = Array{ActNorm}(undef, L, K)    # activation normalization
    NCL = Array{CouplingLayerGlow}(undef, L, K)  # coupling layers w/ 1x1 convolution and residual block
 
    AN_c = nothing 
    CL   = nothing
    if cond
        AN_c = Array{ActNorm}(undef, L, K)    # activation normalization
        CL = Array{ConditionalLayerGlow}(undef, L, K)  # coupling layers w/ 1x1 convolution and residual block
    end

    if split_scales
        Z_dims = fill!(Array{Array}(undef, L-1), [1,1]) #fill in with dummy values so that |> gpu accepts it   # save dimensions for inverse/backward pass
        channel_factor = 4
    else
        Z_dims = nothing
        channel_factor = 1
    end

    for i=1:L
        n_in *= channel_factor # squeeze if split_scales is turned on
        n_cond *= channel_factor # squeeze if split_scales is turned on
        for j=1:K
            AN[i, j] = ActNorm(n_in; logdet=true)
            NCL[i, j]  = CouplingLayerGlow(n_in, n_hidden; k1=k1, k2=k2, p1=p1, p2=p2, s1=s1, s2=s2, logdet=true, activation=activation, ndims=ndims)
            if cond
                AN_c[i, j] = ActNorm(n_in; logdet=true)
                CL[i, j]   = ConditionalLayerGlow(n_in, n_cond, n_hidden; spade=spade, k1=k1, k2=k2, p1=p1, p2=p2, s1=s1, s2=s2, logdet=true, activation=activation, ndims=ndims)
            end
        end
        (i < L && split_scales) && (n_in = Int64(n_in/2)) # split
    end

    return NetworkConditionalGlowFrank(AN, NCL, AN_c, CL, Z_dims, L, K, squeezer, split_scales, summary_net,cond)
end


# Forward pass and compute logdet
function forward(X::AbstractArray{T, N}, G::NetworkConditionalGlowFrank; C=nothing) where {T, N}
    !isnothing(G.summary_net) && (C = G.summary_net.forward(C))
    G.split_scales && (Z_save = array_of_array(X, G.L-1))
    orig_shape = size(X)

    logdet = 0
    for i=1:G.L
        (G.split_scales) && (X = G.squeezer.forward(X))
        (G.split_scales && G.cond) && (C = G.squeezer.forward(C))
        for j=1:G.K            
            X, logdet1 = G.AN[i, j].forward(X)
            X, logdet2 = G.NCL[i, j].forward(X)
            logdet += (logdet1 + logdet2)
            if G.cond
                X, logdet3 = G.AN_c[i, j].forward(X)
                println(size(X))
                println(size(C))
                X, logdet4 = G.CL[i, j].forward(X, C)
                logdet += (logdet3 + logdet4)
            end
        end
        if G.split_scales && i < G.L    # don't split after last iteration
            X, Z = tensor_split(X)
            Z_save[i] = Z
            G.Z_dims[i] = collect(size(Z))
        end
    end
    G.split_scales && (X = reshape(cat_states(Z_save, X),orig_shape))
    if G.cond 
        return X, C, logdet
    else 
        return X, logdet 
    end
end

# Inverse pass 
function inverse(X::AbstractArray{T, N}, G::NetworkConditionalGlowFrank; C=nothing) where {T, N}
    G.split_scales && ((Z_save, X) = split_states(X[:], G.Z_dims))
    for i=G.L:-1:1
        if G.split_scales && i < G.L
            X = tensor_cat(X, Z_save[i])
        end
        for j=G.K:-1:1
            if G.cond
                X = G.CL[i, j].inverse(X, C)
                X = G.AN_c[i, j].inverse(X)
            end

            X = G.NCL[i, j].inverse(X)
            X = G.AN[i, j].inverse(X)
        end

        (G.split_scales) && (X = G.squeezer.inverse(X))
        (G.split_scales && G.cond) && (C = G.squeezer.inverse(C))
    end
    return X
end

# Backward pass and compute gradients
function backward(ΔX::AbstractArray{T, N}, X::AbstractArray{T, N},G::NetworkConditionalGlowFrank; C=nothing) where {T, N}
    
    # Split data and gradients
    if G.split_scales
        ΔZ_save, ΔX = split_states(ΔX[:], G.Z_dims)
        Z_save, X = split_states(X[:], G.Z_dims)
    end

    !isnothing(C) && (ΔC_total = T(0) .* C)

    for i=G.L:-1:1
        if G.split_scales && i < G.L
            X  = tensor_cat(X, Z_save[i])
            ΔX = tensor_cat(ΔX, ΔZ_save[i])
        end
        for j=G.K:-1:1
            ΔX, X =  G.NCL[i, j].backward(ΔX, X)
            ΔX, X = G.AN[i, j].backward(ΔX, X)

            if G.cond
                ΔX, X, ΔC = G.CL[i, j].backward(ΔX, X, C)
                ΔX, X     = G.AN_c[i, j].backward(ΔX, X)
                ΔC_total += ΔC
            end

        end

        if G.split_scales 
            if G.cond 
              ΔC_total = G.squeezer.inverse(ΔC_total)
              C = G.squeezer.inverse(C)
            end
          X = G.squeezer.inverse(X)
          ΔX = G.squeezer.inverse(ΔX)
        end
    end

    !isnothing(G.summary_net) && (G.summary_net.backward(ΔC_total, C))

    return ΔX, X
end

# Get parameters
function get_params(G::NetworkConditionalGlowFrank)
    L, K = size(G.AN)
    p = Array{Parameter, 1}(undef, 0)
    if G.cond
        for i=1:L
            for j=1:K
                p = cat(p, get_params(G.AN_c[i, j]); dims=1)
                p = cat(p, get_params(G.CL[i, j]); dims=1)
            end
        end
    else 
        for i=1:L
            for j=1:K
                p = cat(p, get_params(G.AN[i, j]); dims=1)
                p = cat(p, get_params(G.NCL[i, j]); dims=1)
            end
        end
    end
    return p
end
