# Combined Model


This is the main structure provided by this package:

```
mutable struct CombinedModel
    pwr_sys::PowerSystem
    gas_sys::GasSystem
    controller::Controller
    logger::Logger
    daemon::Daemon
    dt::Float64 # in min
    t::Float64 # in min
    duration::Float64 # in min
end
```

It encompasses two infrastructure models and a controller that actuates some of the joint system (but not necessary all of it). 


As of today, this package currently supports the following models:
*Gas Systems:*
- LinepackModel
- GasNetworkModel

*Power Systems:*
- CongestionFreeModel
- OPFModel

More models will be added in future releases. 


# Model Evolution
```
function step!(model::CombinedModel)
    perturb!(model)
    control!(model.pwr_sys, model.gas_sys, model.controller, model.t)
    step!(model.pwr_sys, model.gas_sys, model.t)
    record!(model)
    model.t += model.dt
    nothing
end
```


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
