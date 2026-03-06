export FixedDurationGasFault

mutable struct FixedDurationGasFault <: Daemon
    duration::Float64
    timer::Float64
    stored_values::Dict{String,Any}
end

function FixedDurationGasFault(;fault_duration=1000, kwargs...)
    FixedDurationGasFault(fault_duration,0.0, Dict{String,Any}())
end

function GasPwrCoSim.perturb!(daemon::FixedDurationGasFault, gas_sys::LinepackModel, t::Float64)
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


function copy!(daemon::FixedDurationGasFault, gas_sys::LinepackModel)
	daemon.stored_values["max_injection"] = gas_sys.max_injection
end

function restore!(daemon::FixedDurationGasFault, gas_sys::LinepackModel)
	gas_sys.max_injection = daemon.stored_values["max_injection"]
end
