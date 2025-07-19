# GasPwrCoSim.jl: a Co-Simulation and Co-Optimization Framework for Gas and Power Operations

## Description of the Environment

The environment is consistent with the standard RL framework 

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

This package currently supports the following models:
*Gas Systems:*

<ul>
  <li>LinepackModel</li>
  <li>GasNetworkModel</li>
</ul> 

*Power Systems:*
<ul>
  <li>CongestionFreeModel</li>
  <li>OPFModel</li>
</ul> 

More models will be addded in future releases. 

You can also define your own models. The only requirements features are:
```
step!(model::Model, t)
control!(model::Model,controller::Controller, t)
```




The package provides a generaic class for generators. This class displays stochastic nature of fuel transitions and start-ups as [Markov process](https://en.wikipedia.org/wiki/Markov_chain).
```
mutable struct Unit
    pmin::Real  maximal output
    pmax::Real # minimal output
    p::Real # current output
    fuel_input::Function
    trans_steps::Int # # of steps based on the expected duration and chosen time step length
    start_steps::Int
    cost::Dict{Symbol, Any} # generation cost based on fuel
    prob::Dict{Symbol, Any}
    pressure_out::Real
    gas_loc::Int
    status::Symbol
    state2int::Dict{Symbol, Int}
    int2state::Dict{Int, Symbol}
    int2act::Dict{Int, Symbol}
    act2int::Dict{Symbol, Int}
end
```

The nitty-gritty are hidden in the model
```
mutable struct CombinedModel
    pwr_sys::PowerSystem
    gas_sys::GasSystem
    controller::Union{Nothing,Controller}
    dt::Float64
    t::Float64
    duration::Float64
end
```

To create a new compatible model it has to inherit from GasSystem (or PowerSystem) Here is the example of a LinepackModel
```
mutable struct LinepackModel <: GasSystem
    linepack::Float64
    initial_linepack::Union{Float64, ClosedInterval{Float64}}
    injection::Float64
    max_injection::Float64
end
```

In a nut-shell, the combined model is evolved as
```
reset!(model)
while(model.t < model.duration)
    step!(model)
end
```

A time step starts the controller acting on the two system. Then, the
systems are evolved for the duration of the time step.
```
function step!(model::CombinedModel)
    control!(model.pwr_sys, model.gas_sys, model.controller, model.t)
    step!(model.pwr_sys, model.gas_sys, model.t)
    model.t += model.dt
end
```

If no controller is defined the default control is *do nothing*


The gas system is described as 
```
function control!(pwr_sys::PowerSystem, gas_sys::GasSystem, controller::Union{Controller,Nothing}, t)
    control!(pwr_sys, controller, model.t)
    control!(gas_sys, controller, model.t)
    nothing
end
```

The power system is described as 
```
mutable struct PowerSystem
    units::Vector{Unit}
    demand::Extrapolation
    reserve::Float64
    generation::Float64
    load_shedding::Float64
end
```

Finally, the units are defined as
```
mutable struct Unit
    pmin::Real
    pmax::Real
    p::Real
    fuel_input::Function
    trans_steps::Int
    start_steps::Int
    cost::Dict{Symbol, Any}
    prob::Dict{Symbol, Any}
    pressure_out::Real
    gas_loc::Union{Int, Nothing}
    pwr_bus::Int
    status::Symbol
    state2int::Dict{Symbol, Int}
    int2state::Dict{Int, Symbol}
    act2int::Dict{Symbol, Int}
    int2act::Dict{Int, Symbol}
end
```
This class is generic enough to create different child classes.


## Interact with the Environment
This framework was designed wi. So it is readily available for RL, the combined model can be incorporareted into an RL environment
```
function run_policy(env::AbstractEnv, policy::AbstractPolicy, hook::AbstractHook)
    reset!(env)
    hook(PreEpisodeStage(), policy, env)
    while !env.done
        hook(PreActStage(), policy, env)
        a = policy(env)
        env(a)
        hook(PostActStage(), policy, env)
    end
    hook
end
```




