export CostLogger

mutable struct CostLogger <: Logger
    gen_cost::Vector{Float64}
    shed_cost::Vector{Float64}
    time::Vector{Float64}
end

function CostLogger(; kwargs...)
    CostLogger(Float64[], Float64[], Float64[])
end

function GasPwrCoSim.reset!(logger::CostLogger)
    logger.gen_cost = Float64[]
    logger.shed_cost = Float64[]
    logger.time = Float64[]
end

function record!(logger::CostLogger, elc_sys::OPFModel, t::Float64)
    push!(logger.gen_cost, get_hourly_generation_cost(elc_sys))
    push!(logger.shed_cost, get_hourly_shedding_cost(elc_sys))
    push!(logger.time, t)
end
