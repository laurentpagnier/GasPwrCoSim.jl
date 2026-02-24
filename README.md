# GasPwrCoSim.jl: a Co-Simulation and Co-Optimization Framework for Gas and Power Operations

## Install

Install julia by visiting: https://julialang.org/downloads/. 

### Recommended

Download using git,  with ``git clone --recurse-submodules <repo>``
here \<repo\> depends on the version you want, default is ``git@github.com:laurentpagnier/GasPwrCoSim.jl.git``


The package is in active development. We recommend to either create an environment and add the package in development mode. 
**Environment**
1. open pkg manager (press ])
2. ``generate <my_env>``
3. ``dev git@github.com:laurentpagnier/GasPwrCoSim.jl.git``


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
Le
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

The main structure provided by this package is a combined model:

```
mutable struct CombinedModel
    pwr_sys::PowerSystem
    gas_sys::GasSystem
    controller::Controller
    dt::Float64
    t::Float64
    duration::Float64
end
```
It encompasses two infrastructure models and a controller that actuates  some of the joint system (but not necessary all of it). 


As of today, this package currently supports the following models:
*Gas Systems:*
- LinepackModel
- GasNetworkModel

*Power Systems:*
- CongestionFreeModel
- OPFModel

More models will be added in future releases. 

**Evolution:** Basically a run consists of 
```
reset!(model)
while(model.t < model.duration)
    step!(model)
end
```
In detail, a time step starts the controller acting on the two systems, then they are evolved for the duration of the time step.
```
function step!(model::CombinedModel)
    control!(model.pwr_sys, model.gas_sys, model.controller, model.t)
    step!(model.pwr_sys, model.gas_sys, model.t)
    model.t += model.dt
end
```


### Power Systems
As an example let's have a look at the ```CongestionFree``` model
```
mutable struct PowerSystem
    units::Vector{Unit}
    demand::Extrapolation
    reserve::Float64
    generation::Float64
    load_shedding::Float64
end
```
Units are defined as
```
mutable struct Unit
    pmin::Real
    pmax::Real
    p::Real
    gas_loc::Union{Int, Nothing}
    pwr_bus::Int
    status::Symbol
	<some other attributes>
end
```

### Gas Systems


```
mutable struct LinepackModel <: GasSystem
    linepack::Float64
    initial_linepack::Union{Float64, ClosedInterval{Float64}}
    injection::Float64
    max_injection::Float64
end
```

### Custom Models

You can easily create model that are bespoke to the particular . The only requirements features are:
```
step!(model::Model, t)
control!(model::Model, controller::Controller, t)
```
namely how to evolve it and how to actuate it.


### Controllers
If no controller is defined the default control is *do nothing*. If a controller has no specific rules of a model type it will *do nothing*. The abstract control reads
```
function control!(pwr_sys::PowerSystem, gas_sys::GasSystem, controller::Union{Controller,Nothing}, t)
    control!(pwr_sys, controller, model.t)
    control!(gas_sys, controller, model.t)
    nothing
end
```
and it therefore assumed that the two systems can be actuated separately. Interactions must be stored locally during ``step!``.



