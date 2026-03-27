export WorkloadLogger

mutable struct WorkloadLogger <: Logger
    transitioning::Vector{Int}
    starting::Vector{Int}
    time::Vector{Float64}
end

function WorkloadLogger(; kwargs...)
    WorkloadLogger(Int[], Int[], Float64[])
end

function reset!(logger::WorkloadLogger)
	logger.transitioning = Int[]
    logger.starting = Int[]
	logger.time = Float64[]
end


function record!(logger::WorkloadLogger, elc_sys::Union{CongestionFreeModel,OPFModel}, t::Float64) 
    push!(logger.transitioning, sum([is_transitioning(u) for u in elc_sys.units]))
    push!(logger.starting, sum([is_starting(u) for u in elc_sys.units]))
    push!(logger.time, t)
end
