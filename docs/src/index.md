
# InvertibleNetworks.jl documentation

## About

[InvertibleNetworks.jl](https://github.com/slimgroup/InvertibleNetworks.jl) is a package of invertible layers and networks for machine learning. The invertibility allows to backpropagate through the layers and networks without the need for storing the forward state that is recomputed on the fly, inverse propagating through it. This package is the first of its kind in Julia with memory efficient invertible layers, networks and activation functions for machine learning.

## Installation

This package is registered in the Julia general registry and can be installed in the REPL package manager (`]`):

```julia
] add InvertibleNetworks
```

## Authors

This package is developed and maintained by Felix J. Herrmann's [SlimGroup](https://slim.gatech.edu/) at Georgia Institute of Technology. The main contributors of this package are:
 - Rafael Orozco, Georgia Institute of Technology (rorozco@gatech.edu)
 - Philipp Witte, Microsoft Corporation (pwitte@microsoft.com)
 - Gabrio Rizzuti, Utrecht University (g.rizzuti@umcutrecht.nl)
 - Mathias Louboutin, Georgia Institute of Technology (mlouboutin3@gatech.edu)
 - Ali Siahkoohi, Georgia Institute of Technology (alisk@gatech.edu)

## References

 - Yann Dauphin, Angela Fan, Michael Auli and David Grangier, "Language modeling with gated convolutional networks", Proceedings of the 34th International Conference on Machine Learning, 2017. [ArXiv](https://arxiv.org/pdf/1612.08083.pdf)

 - Laurent Dinh, Jascha Sohl-Dickstein and Samy Bengio, "Density estimation using Real NVP",  International Conference on Learning Representations, 2017, [ArXiv](https://arxiv.org/abs/1605.08803)

 - Diederik P. Kingma and Prafulla Dhariwal, "Glow: Generative Flow with Invertible 1x1 Convolutions", Conference on Neural Information Processing Systems, 2018. [ArXiv](https://arxiv.org/abs/1807.03039)

 - Keegan Lensink, Eldad Haber and Bas Peters, "Fully Hyperbolic Convolutional Neural Networks", arXiv Computer Vision and Pattern Recognition, 2019. [ArXiv](https://arxiv.org/abs/1905.10484)

 - Patrick Putzky and Max Welling, "Invert to learn to invert", Advances in Neural Information Processing Systems, 2019. [ArXiv](https://arxiv.org/abs/1911.10914)

 - Jakob Kruse, Gianluca Detommaso, Robert Scheichl and Ullrich Köthe, "HINT: Hierarchical Invertible Neural Transport for Density Estimation and Bayesian Inference", arXiv Statistics and Machine Learning, 2020. [ArXiv](https://arxiv.org/abs/1905.10687)

## Related work and publications

The following publications use [InvertibleNetworks.jl]:

- **[“Preconditioned training of normalizing flows for variational inference in inverse problems”](https://slim.gatech.edu/content/preconditioned-training-normalizing-flows-variational-inference-inverse-problems)**
    - paper: [https://arxiv.org/abs/2101.03709](https://arxiv.org/abs/2101.03709)
    - [presentation](https://slim.gatech.edu/Publications/Public/Conferences/AABI/2021/siahkoohi2021AABIpto/siahkoohi2021AABIpto_pres.pdf)
    - code: [FastApproximateInference.jl](https://github.com/slimgroup/Software.siahkoohi2021AABIpto)

- **["Parameterizing uncertainty by deep invertible networks, an application to reservoir characterization"](https://slim.gatech.edu/content/parameterizing-uncertainty-deep-invertible-networks-application-reservoir-characterization)**
    - paper: [https://arxiv.org/abs/2004.07871](https://arxiv.org/abs/2004.07871)
    - [presentation](https://slim.gatech.edu/Publications/Public/Conferences/SEG/2020/rizzuti2020SEGuqavp/rizzuti2020SEGuqavp_pres.pdf)
    - code: [https://github.com/slimgroup/Software.SEG2020](https://github.com/slimgroup/Software.SEG2020)

- **["Generalized Minkowski sets for the regularization of inverse problems"](https://slim.gatech.edu/content/generalized-minkowski-sets-regularization-inverse-problems-1)**
    - paper: [http://arxiv.org/abs/1903.03942](http://arxiv.org/abs/1903.03942)
    - code: [SetIntersectionProjection.jl](https://github.com/slimgroup/SetIntersectionProjection.jl)


## Acknowledgments

This package uses functions from [NNlib.jl](https://github.com/FluxML/NNlib.jl), [Flux.jl](https://github.com/FluxML/Flux.jl) and [Wavelets.jl](https://github.com/JuliaDSP/Wavelets.jl)



