export NoPowerSystem, NoGasSystem

struct NoPowerSystem <: PowerSystem
end

struct NoGasSystem <: GasSystem
end

reset!(model::Union{NoGasSystem, NoPowerSystem}) = nothing

function step!(pwr_sys::NoPowerSystem, gas_sys::GasSystem)
    step!(gas_sys)
end

function step!(pwr_sys::PowerSystem, gas_sys::NoGasSystem)
    step!(pwr_sys)
end
