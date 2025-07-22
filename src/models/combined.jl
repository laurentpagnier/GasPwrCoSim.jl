export CombinedModel, reset!, run_sim

using Distributions, StatsBase

mutable struct CombinedModel
    pwr_sys::PowerSystem
    gas_sys::GasSystem
    controller::Controller
    dt::Float64
    t::Float64
    duration::Float64
end
    

function reset!(model::CombinedModel)
    model.t = 0.0
    reset!(model.pwr_sys)
    reset!(model.gas_sys)
    nothing
end

function CombinedModel(;        
        gas_model = LinepackModel,
        pwr_model = CongestionFreeModel,
        control_model = NoController,
        dt = 5.0,
        duration = 100.0,
        kwargs...
    )   
    pwr_sys = pwr_model(;kwargs...)    
    gas_sys = gas_model(;kwargs...)
    controller = control_model(;kwargs...)
    CombinedModel(pwr_sys, gas_sys, controller, dt, 0.0, duration)
end


function step!(model::CombinedModel)
    control!(model.pwr_sys, model.gas_sys, model.controller, model.t)
    step!(model.pwr_sys, model.gas_sys, model.t)
    model.t += model.dt
    nothing
end


function control!(pwr_sys::PowerSystem, gas_sys::GasSystem, controller::Union{Controller,Nothing}, t)
    control!(pwr_sys, controller, t)
    control!(gas_sys, controller, t)
    nothing
end


function run_sim(model; on_display=true)
    reset!(model)
    while(model.t < model.duration)
        step!(model)
        if on_display == true
            display(model)
        end
    end
end

function display(model::CombinedModel)
    print("t=$(model.t) | ")
    display(model.gas_sys)
    display(model.pwr_sys)
    println("")
end
