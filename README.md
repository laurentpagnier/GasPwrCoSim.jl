# GasPwrCoSim.jl: a Co-Simulation and Co-Optimization Framework for Gas and Power Operations

## Install

Install julia by visiting: https://julialang.org/downloads/. 

### Recommended

Download using git,  with ``git clone --recurse-submodules <repo>``
here \<repo\> depends on the version you want, default is ``git@github.com:laurentpagnier/GasPwrCoSim.jl.git``

This will require to set up a [ssh key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh).

This could be shortcutted by is to use https instead, e.g.:
```
git clone https://github.com/laurentpagnier/GasPwrCoSim.jl.git
```
then go in GasPwrCoSim.jl/deps and clone GasNetModel.jl with
```
git clone https://github.com/laurentpagnier/GasNetModel.jl.git
```
This won't offer a way to ``push`` to the repo, but allow for simple updates with ``pull``.

The package is in active development. We recommend to add the package in development mode. 
1. open pkg manager (press ])
2. ``dev git@github.com:laurentpagnier/GasPwrCoSim.jl.git``


### Deprecated 

If for some reason you cannot or do not want to use git:
1. Download a zipped version of GasPwrCoSim.jl, eg., https://github.com/laurentpagnier/GasPwrCoSim.jl/archive/refs/heads/main.zip
2. Download a zipped (compatible) version of GasNetModel.jl, e.g., https://github.com/laurentpagnier/GasNetModel.jl/archive/refs/heads/main.zip
3. Place GasNetModel.jl folder within  GasPwrCoSim.jl at the right location (i.e. in deps). (The main file should be accessible as GasPwrCoSim.jl/deps/GasNetModel.jl/src/GasNetModel.jl.)  
4. In GasPwrCoSim.jl folder,  open julia terminal (or inversely open it and go to the folder) 
	1. open pkg manager (press ])
	2. run ```activate .```  
	3. run  ```instantiate``` 
	4. Return to the julia terminal by pressing backspace.


## Citation
If you used this package, please cite our work as

```
@inproceedings{pagnier2024system,
  title={System-Wide Emergency Policy for Transitioning from Main to Secondary Fuel},
  author={Pagnier, Laurent and Hyett, Criston and Ferrando, Robert and Goldshtein, Igal and Alisse, Jean and Saban, Lilah and Chertkov, Michael},
  booktitle={2024 IEEE 63rd Conference on Decision and Control (CDC)},
  pages={90--97},
  year={2024},
  organization={IEEE}
}
```
and
```
@inproceedings{hyett2024differentiable,
  title={Differentiable Simulator For Dynamic \& Stochastic Optimal Gas \& Power Flows},
  author={Hyett, Criston and Pagnier, Laurent and Alisse, Jean and Goldshtein, Igal and Saban, Lilah and Ferrando, Robert and Chertkov, Michael},
  booktitle={2024 IEEE 63rd Conference on Decision and Control (CDC)},
  pages={98--105},
  year={2024},
  organization={IEEE}
}
```

## Description

See documentation.

