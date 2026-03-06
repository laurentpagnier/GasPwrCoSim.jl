# Logger

## Description
By default the model only stores its current state. If you interested in 
 the evolution of certain model variables you can store them using a logger.
 Loggers are called at the end of the time step,
 
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

To record something you need to define ``function record!(logger::Logger, sys::System, t::Float64)``. Here is a example

```
struct LinepackLogger <: Logger
    linepack::Vector{Float64}
    time::Vector{Float64}
end


function record!(logger::LinepackLogger, gas_sys::LinepackModel, t::Float64)
    push!(logger.linepack, gas_sys.linepack)
    push!(logger.time, t)
end

```
