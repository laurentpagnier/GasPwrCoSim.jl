export CombinedModel, reset!, run_sim

using Distributions, StatsBase

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
    

function reset!(model::CombinedModel)
    model.t = 0.0
    restore!(model.daemon, model.pwr_sys)
    restore!(model.daemon, model.gas_sys)
    reset!(model.pwr_sys)
    reset!(model.gas_sys)
    reset!(model.controller)
    reset!(model.logger)
    nothing
end

function CombinedModel(;        
        gas_model = LinepackModel,
        pwr_model = CongestionFreeModel,
        control_model = NoController,
        logger_model = NoLogger,
        daemon_model = NoDaemon,
        dt = 5.0,
        duration = 100.0,
        kwargs...
    )   
    pwr_sys = pwr_model(;kwargs...)    
    gas_sys = gas_model(;dt=dt, kwargs...)
    controller = control_model(;kwargs...)
    daemon = daemon_model(;kwargs...)
    logger = logger_model(;kwargs...)
    copy!(daemon, gas_sys)
    copy!(daemon, pwr_sys)
    CombinedModel(pwr_sys, gas_sys, controller, logger, daemon, dt, 0.0, duration)
end


function step!(model::CombinedModel)
    perturb!(model)
    control!(model.pwr_sys, model.gas_sys, model.controller, model.t)
    step!(model.pwr_sys, model.gas_sys, model.t)
    record!(model)
    model.t += model.dt
    nothing
end


function record!(model)
    record!(model.logger, model.pwr_sys, model.t)
    record!(model.logger, model.gas_sys, model.t)
end


function perturb!(model)
    perturb!(model.daemon, model.pwr_sys, model.t)
    perturb!(model.daemon, model.gas_sys, model.t)
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
    display(model.controller)
    println("")
end
