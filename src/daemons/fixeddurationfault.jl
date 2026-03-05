mutable struct FixedDurationFault <: GasPwrCoSim.Daemon
    duration::Float64
    timer::Float64
    stored_values::Dict{String,Any}
end

function FixedDurationFault(;fault_duration=1000, kwargs...)
    FixedDurationFault(fault_duration,0.0, Dict{String,Any}())
end

function GasPwrCoSim.perturb!(daemon::FixedDurationFault, gas_sys::LinepackModel, t::Float64)
    if t == 0.0
        daemon.stored_values["max_injection"] = gas_sys.max_injection
    end
    if t > 100.0
        gas_sys.max_injection = 0.0
    end
    if t > 1200.0
        gas_sys.max_injection = daemon.stored_values["max_injection"]
    end
end
