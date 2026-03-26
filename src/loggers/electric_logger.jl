export ElectricLogger, compute_shedding_metrics

mutable struct ElectricLogger <: Logger
    demand::Vector{Float64}
    shed::Vector{Float64}
    gen::Vector{Float64}
    time::Vector{Float64}
end

function ElectricLogger(; kwargs...)
    ElectricLogger(Float64[], Float64[], Float64[], Float64[])
end


function GasPwrCoSim.reset!(logger::ElectricLogger)
    logger.demand = Float64[]
    logger.shed = Float64[]
    logger.gen = Float64[]
    logger.time = Float64[]
end


function record!(logger::ElectricLogger, elc_sys::CongestionFreeModel, t::Float64)
    push!(logger.demand, get_current_demand(elc_sys, t))
    push!(logger.shed, elc_sys.load_shedding)
    push!(logger.gen, elc_sys.generation)
    push!(logger.time, t)
end

function record!(logger::ElectricLogger, elc_sys::OPFModel, t::Float64)
    push!(logger.demand, sum(u["pd"] for (i,u) in elc_sys.PMModel["load"]))
    push!(logger.shed, sum(u["shed"] for (i,u) in elc_sys.PMModel["load"]))
    push!(logger.gen, sum(u["pg"] for (i,u) in elc_sys.PMModel["gen"]))
    push!(logger.time, t)
end
    


function compute_shedding_metrics(logger::ElectricLogger)
    ENS = 0.0
    shedmax = 0.0
    told = 0.0
    for (t,s) in zip(logger.time, logger.shed)
        if shedmax < s
            shedmax = s
        end
        ENS += s*(t-told) / 60 # to convert MWh
        told = t
    end
    ENS, shedmax
end

