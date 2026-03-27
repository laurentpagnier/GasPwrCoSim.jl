export FixedDurationGasFault

mutable struct FixedDurationGasFault <: GasPwrCoSim.Daemon
    duration::Float64
    t_start::Float64
    reduction # define where and how severe the insult is
    stored_values::Dict{String,Any}
end

function FixedDurationGasFault(;fault_duration=1000, start_at= 100, reduction=0.0, kwargs...)
    FixedDurationGasFault(fault_duration, start_at, reduction, Dict{String,Any}())
end

function GasPwrCoSim.perturb!(daemon::FixedDurationGasFault, gas_sys::LinepackModel, t::Float64)
    if t > daemon.t_start
        gas_sys.max_injection = (1.0 - daemon.reduction) * daemon.stored_values["max_injection"]
        gas_sys.injection = min(gas_sys.injection, gas_sys.max_injection)
    end
    if t > daemon.t_start + daemon.duration
        # restore to default value
        gas_sys.max_injection = daemon.stored_values["max_injection"]
    end
end


function GasPwrCoSim.perturb!(daemon::FixedDurationGasFault,  gas_sys::GasNetworkModel, t::Float64)
    if t > daemon.t_start
        if typeof(daemon.reduction) <: Real
            for (i, inj) = gas_sys.max_injections
                gas_sys.max_injections[i] = (1.0 - daemon.reduction) * daemon.stored_values["max_injections"][i]
                gas_sys.gas_injections[i] = min(gas_sys.gas_injections[i], gas_sys.max_injections[i])
            end
        else
            # DOTO reduction is a dictionary
        end
    end
    if t > daemon.t_start + daemon.duration
        # restore to default value
        gas_sys.max_injections = deepcopy(daemon.stored_values["max_injections"])
    end
end


function GasPwrCoSim.copy!(daemon::FixedDurationGasFault, gas_sys::LinepackModel)
	daemon.stored_values["max_injection"] = gas_sys.max_injection
end

function GasPwrCoSim.restore!(daemon::FixedDurationGasFault, gas_sys::LinepackModel)
	gas_sys.max_injection = daemon.stored_values["max_injection"]
end

function GasPwrCoSim.copy!(daemon::FixedDurationGasFault, gas_sys::GasNetworkModel)
	daemon.stored_values["max_injections"] = deepcopy(gas_sys.max_injections)
end

function GasPwrCoSim.restore!(daemon::FixedDurationGasFault, gas_sys::GasNetworkModel)
	gas_sys.max_injections = deepcopy(daemon.stored_values["max_injections"])
end
