struct ElectricLogger <: Logger
    demand::Vector{Float64}
    shed::Vector{Float64}
    gen::Vector{Float64}
    time::Vector{Float64}
end

function ElectricLogger(; kwargs...)
    ElectricLogger(Float64[], Float64[], Float64[], Float64[])
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
    


